classdef Manifold < bct.Domain
    %MANIFOLD  2D cortical surface manifold (triangular mesh)
    %
    % Properties:
    %   Vertices         - [N×3] vertex coordinates
    %   Faces            - [M×3] triangular face connectivity
    %   Laplacian        - Laplace-Beltrami operator
    %   MassMatrix       - Diagonal mass matrix (vertex areas)
    %   CotangentMatrix  - Cotangent stiffness matrix
    %   LaplacianType    - Type of Laplacian ("cotangent" or "cotangent-normalized")
    %   Graph            - Canonical graph representation (bct.Graph)
    %   DEC              - Discrete Exterior Calculus object (DECLab)
    %   Triangulation    - MATLAB triangulation object (cached)
    %   SurfaceMesh      - MATLAB surfaceMesh object (cached)
    %
    % Axis:
    %   Default = vertex index

    properties
        Vertices         % [N×3] vertex coordinates
        Faces            % [M×3] face connectivity
        Laplacian        % Laplace-Beltrami operator
        MassMatrix       % Diagonal mass matrix
        CotangentMatrix  % Cotangent stiffness matrix
        LaplacianType    % "cotangent" or "cotangent-normalized"
        Graph            % Canonical graph representation for navigation
        DEC              % Discrete Exterior Calculus object (DECLab)
        Triangulation    % MATLAB triangulation object (cached)
        SurfaceMesh      % MATLAB surfaceMesh object (cached)
    end

    methods
        % ---------------------------------------------------------------
        function obj = Manifold(meshStruct, laplacianType)
            % MANIFOLD Constructor for Manifold domain
            %
            % Syntax:
            %   obj = Manifold(meshStruct)
            %   obj = Manifold(meshStruct, laplacianType)
            %
            % Inputs:
            %   meshStruct     - Structure with fields:
            %                    .V or .Vertices - [N×3] vertex coordinates
            %                    .F or .Faces    - [M×3] face connectivity
            %   laplacianType  - (optional) "cotangent" (default) or "cotangent-normalized"
            
            % Call superclass constructor
            obj@bct.Domain("Manifold", "mm");

            % Default Laplacian type
            if nargin < 2 || isempty(laplacianType)
                laplacianType = "cotangent";
            end
            obj.LaplacianType = laplacianType;

            % Extract geometry (support both old and new naming)
            if isfield(meshStruct, 'Vertices')
                obj.Vertices = meshStruct.Vertices;
            elseif isfield(meshStruct, 'V')
                obj.Vertices = meshStruct.V;
            else
                error('bct:Manifold:MissingVertices', 'meshStruct must have Vertices or V field');
            end

            if isfield(meshStruct, 'Faces')
                obj.Faces = meshStruct.Faces;
            elseif isfield(meshStruct, 'F')
                obj.Faces = meshStruct.F;
            else
                error('bct:Manifold:MissingFaces', 'meshStruct must have Faces or F field');
            end

            % Compute Laplacian, MassMatrix, and CotangentMatrix
            obj = obj.computeLaplacian();
            
            % Initialize Discrete Exterior Calculus (DECLab)
            try
                % Ensure inputs are double matrices (DECLab requirement)
                Faces_double = double(obj.Faces);
                Vertices_double = double(obj.Vertices);
                obj.DEC = DiscreteExteriorCalculus(Faces_double, Vertices_double);
            catch ME
                warning('bct:Manifold:DECInitFailed', ...
                    'Failed to initialize DEC object: %s', ME.message);
                obj.DEC = [];
            end

            % Build canonical graph representation
            obj.Graph = bct.Graph(obj);

            obj.resolutionMode       = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Vertex;

            obj = obj.buildAxis();
        end

        % ---------------------------------------------------------------
        function obj = computeLaplacian(obj)
            % Compute Laplacian, MassMatrix, and CotangentMatrix using laplacian function
            [obj.Laplacian, obj.MassMatrix, obj.CotangentMatrix] = ...
                bct.Manifold.laplacian(obj.Vertices, obj.Faces, obj.LaplacianType);
        end

        % ---------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            N = size(obj.Vertices, 1);

            switch obj.displayCoordinateMode
                case bct.enum.CoordinateMode.Vertex
                    obj.axis = (1:N).';
                    obj.units = "vertex";  % Vertex index units

                case bct.enum.CoordinateMode.Geodesic
                    % Future: geodesic distance coordinates
                    error("Geodesic coordinate mode not yet implemented.");

                otherwise
                    error("Unsupported coordinate mode for Manifold.");
            end
        end

        % ---------------------------------------------------------------
        function M = M(obj)
            % Alias for MassMatrix (for transform compatibility)
            M = obj.MassMatrix;
        end
        
        % ---------------------------------------------------------------
        function A = adjacency(obj)
            % adjacency - Compute binary adjacency matrix from faces
            %
            % Syntax:
            %   A = M.adjacency()
            %
            % Outputs:
            %   A - [N×N] sparse logical adjacency matrix (symmetric, no self-loops)
            %
            % The adjacency is derived from mesh edges: two vertices are adjacent
            % if they share an edge in any triangle face.
            %
            % Example:
            %   A = B.Manifold.adjacency();
            %   nnz(A) / 2  % Number of edges
            %
            % See also: bct.io.construct.edgesFromFaces
            
            F = obj.Faces;
            if isempty(F)
                % No faces: return empty sparse matrix
                N = size(obj.Vertices, 1);
                A = sparse(N, N);
                return;
            end
            
            % Extract unique edges from faces
            e = unique(sort([F(:,[1 2]); F(:,[2 3]); F(:,[3 1])], 2), 'rows');
            
            % Build symmetric adjacency matrix
            N = size(obj.Vertices, 1);
            A = sparse(e(:,1), e(:,2), true, N, N);
            A = A + A.';                % Make symmetric
            A = A - diag(diag(A));      % Remove self-loops
            A = spones(A) > 0;          % Binary adjacency
        end
        
        % ---------------------------------------------------------------
        function obj = updateResolution(obj)
            % Future: decimation
            if obj.resolutionMode == bct.enum.ResolutionMode.Full
                return;
            elseif obj.resolutionMode == bct.enum.ResolutionMode.Instrument
                warning("Instrument-resolution mesh decimation not implemented.");
            else
                error("Unknown resolution mode in Manifold.");
            end
        end

        % ---------------------------------------------------------------
        function obj = updateCoordinateMode(obj)
            obj = obj.buildAxis();
        end

        % ---------------------------------------------------------------
        function N = numVertices(obj)
            % Get number of vertices
            N = size(obj.Vertices, 1);
        end

        % ---------------------------------------------------------------
        function M = numFaces(obj)
            % Get number of faces
            M = size(obj.Faces, 1);
        end
        
        % ---------------------------------------------------------------
        function TR = getTriangulation(obj)
            % GETTRIANGULATION Return MATLAB triangulation object
            %
            % Syntax:
            %   TR = obj.getTriangulation()
            %
            % Outputs:
            %   TR - MATLAB triangulation object created from Faces and Vertices
            %
            % Example:
            %   TR = M.getTriangulation();
            %   P = incenter(TR);  % Face incenters
            %   N = faceNormal(TR);  % Face normals
            %
            % Note: Result is cached for subsequent calls.
            %
            % See also: triangulation
            
            if isempty(obj.Triangulation)
                obj.Triangulation = triangulation(obj.Faces, obj.Vertices);
            end
            TR = obj.Triangulation;
        end
        
        % ---------------------------------------------------------------
        function SM = getSurfaceMesh(obj)
            % GETSURFACEMESH Return MATLAB surfaceMesh object
            %
            % Syntax:
            %   SM = obj.getSurfaceMesh()
            %
            % Outputs:
            %   SM - MATLAB surfaceMesh object created from Vertices and Faces
            %
            % Example:
            %   SM = M.getSurfaceMesh();
            %   area = surfaceArea(SM);
            %   curv = meanCurvature(SM);
            %
            % Note: Result is cached for subsequent calls.
            %
            % See also: surfaceMesh
            
            if isempty(obj.SurfaceMesh)
                obj.SurfaceMesh = surfaceMesh(obj.Vertices, obj.Faces);
            end
            SM = obj.SurfaceMesh;
        end
        
        % ---------------------------------------------------------------
        function C = centroid(obj)
            % CENTROID Compute face centroids
            %
            % Syntax:
            %   C = obj.centroid()
            %
            % Outputs:
            %   C - [M×3] matrix of face centroids where M is number of faces
            %
            % Description:
            %   Computes the geometric center (centroid) of each triangular face
            %   as the average of its three vertex positions.
            %
            % Example:
            %   C = M.centroid();
            %   plot3(C(:,1), C(:,2), C(:,3), 'r.');
            %
            % See also: getTriangulation, getSurfaceMesh
            
            V = obj.Vertices;
            F = obj.Faces;
            C = (V(F(:,1),:) + V(F(:,2),:) + V(F(:,3),:)) / 3;
        end
        
        % ---------------------------------------------------------------
        function FN = faceNormal(obj)
            % FACENORMAL Get face normals from surfaceMesh
            %
            % Syntax:
            %   FN = obj.faceNormal()
            %
            % Outputs:
            %   FN - [M×3] matrix of face normal vectors where M is number of faces
            %
            % Description:
            %   Returns face normals from the cached surfaceMesh object.
            %   Computes normals if not already computed.
            %
            % Example:
            %   FN = M.faceNormal();
            %   quiver3(C(:,1), C(:,2), C(:,3), FN(:,1), FN(:,2), FN(:,3));
            %
            % See also: vertexNormal, getSurfaceMesh
            
            SM = obj.getSurfaceMesh();
            
            if isempty(SM.FaceNormals)
                SM.computeNormals();
            end
            
            FN = SM.FaceNormals;
        end
        
        % ---------------------------------------------------------------
        function VN = vertexNormal(obj)
            % VERTEXNORMAL Get vertex normals from surfaceMesh
            %
            % Syntax:
            %   VN = obj.vertexNormal()
            %
            % Outputs:
            %   VN - [N×3] matrix of vertex normal vectors where N is number of vertices
            %
            % Description:
            %   Returns vertex normals from the cached surfaceMesh object.
            %   Computes normals if not already computed.
            %
            % Example:
            %   VN = M.vertexNormal();
            %   quiver3(V(:,1), V(:,2), V(:,3), VN(:,1), VN(:,2), VN(:,3));
            %
            % See also: faceNormal, getSurfaceMesh
            
            SM = obj.getSurfaceMesh();
            
            if isempty(SM.VertexNormals)
                SM.computeNormals();
            end
            
            VN = SM.VertexNormals;
        end
        
        % ---------------------------------------------------------------
        function [Nf_vec, e1, e2] = computeTangentFrame(obj)
            % COMPUTETANGENTFRAME Compute orthonormal tangent frame for each face
            %
            % Syntax:
            %   [Nf_vec, e1, e2] = obj.computeTangentFrame()
            %
            % Outputs:
            %   Nf_vec - [M×3] face normal vectors (normalized)
            %   e1     - [M×3] first tangent basis vector (orthogonal to Nf_vec)
            %   e2     - [M×3] second tangent basis vector (orthogonal to both)
            %
            % Description:
            %   Computes an orthonormal coordinate frame {e1, e2, Nf_vec} for each
            %   triangular face. The frame is right-handed with:
            %   - Nf_vec: face normal (cross product of two edges)
            %   - e1: first edge projected onto tangent plane and normalized
            %   - e2: cross product of Nf_vec and e1
            %
            % Example:
            %   [N, e1, e2] = M.computeTangentFrame();
            %   C = M.centroid();
            %   quiver3(C(:,1), C(:,2), C(:,3), e1(:,1), e1(:,2), e1(:,3), 'r');
            %
            % See also: faceNormal, centroid
            
            V = obj.Vertices;
            F = obj.Faces;
            
            % Face normals (cross product of two edges)
            Nf_vec = cross( ...
                V(F(:,2),:) - V(F(:,1),:), ...
                V(F(:,3),:) - V(F(:,1),:) );
            Nf_vec = Nf_vec ./ vecnorm(Nf_vec, 2, 2);
            
            % First tangent vector (edge projected onto tangent plane)
            e1 = V(F(:,2),:) - V(F(:,1),:);
            e1 = e1 - sum(e1 .* Nf_vec, 2) .* Nf_vec;
            e1 = e1 ./ vecnorm(e1, 2, 2);
            
            % Second tangent vector (orthogonal to both)
            e2 = cross(Nf_vec, e1, 2);
        end
        
        % ---------------------------------------------------------------
        function obj = initializeTransform(obj)
            % Initialize MFT transform (Manifold → Lambda)
            % Requires Lambda dual to be set with computed eigenvectors
            % Silently returns if prerequisites not met (expected in standard workflow)
            
            if isempty(obj.dual)
                % Dual not set - transform cannot be created yet
                return;
            end
            
            if isempty(obj.dual.U)
                % Eigenvectors not computed - transform cannot be created yet
                return;
            end
            
            % Create MFT transform object
            obj.transform = bct.factory.transforms.MFT(obj);
        end

    end

    methods (Static)
        [L, M, K] = laplacian(V, F, laplacianType);
        lambda_max = maxLambda(obj, scope);
        
        function obj = fromHDF5(filename)
            %FROMHDF5 Load Manifold from HDF5 file (lazy loading)
            %
            % Syntax:
            %   obj = bct.Manifold.fromHDF5(filename)
            %
            % Inputs:
            %   filename - Path to HDF5 file
            %
            % Outputs:
            %   obj - Manifold object with geometry loaded from HDF5
            
            % Read vertices and faces from HDF5
            V = h5read(filename, '/manifold/vertices');
            F = h5read(filename, '/manifold/faces');
            
            % Create meshStruct
            meshStruct = struct('V', V, 'F', F);
            
            % Create Manifold object
            obj = bct.Manifold(meshStruct);
        end
    end
end
