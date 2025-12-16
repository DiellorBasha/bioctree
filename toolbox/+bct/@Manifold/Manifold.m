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
