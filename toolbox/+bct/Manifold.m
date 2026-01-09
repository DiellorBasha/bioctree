classdef Manifold < handle
    %MANIFOLD  Geometric substrate for surface-based analysis
    %
    % Defines geometry, topology, and metric. Provides access to
    % FEM, DEC, and Graph representations via ports.
    %
    % Design principles (from ManifoldContract):
    %   - Manifold owns: Topology, Embedding, Metric, Intrinsic differential structure
    %   - FEM, DEC, Graph are views accessed through ports (not stored properties)
    %   - Immutable geometry, mutable representations
    %   - No analysis, filters, brushes, spectral pipelines, or UI state
    %
    % Usage:
    %   % Construction
    %   M = bct.Manifold(struct('V', V, 'F', F));
    %   
    %   % Access representations via ports
    %   fem = M.FEM();
    %   dec = M.DEC();
    %   graph = M.Graph();
    %
    % See also: bct.FEM, bct.Graph, DiscreteExteriorCalculus

    properties (SetAccess = private)
        Vertices         % [N×3] vertex coordinates (immutable)
        Faces            % [M×3] face connectivity (immutable)
        Edges            % [E×2] edge connectivity (derived from faces)
        ID               % Unique identifier for compatibility tracking
    end

    properties (Access = private)
        Cache            % containers.Map for lazy representation creation
        Geometry         % Struct for cached geometric computations (frames, etc.)
    end

    methods
        % ===============================================================
        % CONSTRUCTOR
        % ===============================================================
        
        function obj = Manifold(varargin)
            %MANIFOLD Constructor for Manifold domain
            %
            % Syntax:
            %   M = bct.Manifold(meshStruct)
            %   M = bct.Manifold(V, F)
            %
            % Inputs:
            %   meshStruct - Structure with fields:
            %                .V or .Vertices - [N×3] vertex coordinates
            %                .F or .Faces    - [M×3] face connectivity
            %   V          - [N×3] vertex coordinates
            %   F          - [M×3] face connectivity
            %
            % Outputs:
            %   M - Manifold object (immutable geometry)
            %
            % Examples:
            %   % From struct
            %   data = load('mesh.mat');
            %   M = bct.Manifold(struct('V', data.V, 'F', data.F));
            %
            %   % From V, F directly
            %   M = bct.Manifold(V, F);
            
            % Parse inputs
            if nargin == 1 && isstruct(varargin{1})
                % Struct interface: M = Manifold(meshStruct)
                meshStruct = varargin{1};
                
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
                
            elseif nargin == 2
                % Direct interface: M = Manifold(V, F)
                obj.Vertices = varargin{1};
                obj.Faces = varargin{2};
                
                % Validate inputs
                if isempty(obj.Vertices)
                    error('MATLAB:invalidInput', 'Vertices cannot be empty');
                end
                if isempty(obj.Faces)
                    error('MATLAB:invalidInput', 'Faces cannot be empty');
                end
                if size(obj.Vertices, 2) ~= 3
                    error('MATLAB:invalidInput', 'Vertices must be N×3 array');
                end
                if size(obj.Faces, 2) ~= 3
                    error('MATLAB:invalidInput', 'Faces must be M×3 array');
                end
            else
                error('bct:Manifold:InvalidArguments', ...
                    'Usage: Manifold(meshStruct) or Manifold(V, F)');
            end
            
            % Extract or compute edges
            obj.Edges = obj.computeEdges();
            
            % Generate unique ID for this manifold
            obj.ID = string(java.util.UUID.randomUUID());

            % Initialize cache for representations
            obj.Cache = containers.Map('KeyType','char','ValueType','any');
            
            % Initialize geometry cache for frames
            obj.Geometry = struct();
        end

        % ===============================================================
        % REPRESENTATION PORTS (FEM, DEC, Graph)
        % ===============================================================
        
        function fem = FEM(obj)
            %FEM Get FEM representation struct (lazy creation with caching)
            %
            % Syntax:
            %   fem = M.FEM()
            %
            % Outputs:
            %   fem - Struct with fields:
            %         * V - Vertices
            %         * F - Faces
            %         * G - Gradient operator (lazy-computed)
            %         * D - Divergence operator (lazy-computed)
            %         * Manifold - Reference to parent Manifold
            %
            % Note: 
            %   - First call creates FEM struct, subsequent calls return cached version
            %   - Gradient/Divergence matrices computed on first use and cached
            %   - Requires gptoolbox functions (grad, div) on path
            %
            % See also: bct.runtime.operators.femGradient, bct.runtime.operators.femDivergence
            
            if ~isKey(obj.Cache, "FEM")
                fem = struct();
                fem.V = obj.Vertices;
                fem.F = obj.Faces;
                fem.Manifold = obj;
                fem.G = [];  % Lazy-computed gradient matrix
                fem.D = [];  % Lazy-computed divergence matrix
                obj.Cache("FEM") = fem;
            end
            fem = obj.Cache("FEM");
        end

        function dec = DEC(obj)
            %DEC Get DECLab DiscreteExteriorCalculus backend (lazy creation with caching)
            %
            % Syntax:
            %   dec = M.DEC()
            %
            % Outputs:
            %   dec - DiscreteExteriorCalculus (DECLab backend)
            %
            % Note: 
            %   - First call creates DEC backend, subsequent calls return cached version
            %   - Returns DiscreteExteriorCalculus directly (not bct.DEC wrapper)
            %   - Use with bct.runtime.operators() for DEC operations
            %
            % See also: DiscreteExteriorCalculus, bct.runtime.operators
            
            if ~isKey(obj.Cache, "DEC")
                % Check for DECLab availability
                if exist("DiscreteExteriorCalculus", "class") ~= 8
                    error("bct:MissingDependency", ...
                        ['DECLab not found on MATLAB path (DiscreteExteriorCalculus missing). ' ...
                         'Add external/DECLab to your path.']);
                end
                
                F = double(obj.Faces);
                V = double(obj.Vertices);
                obj.Cache("DEC") = DiscreteExteriorCalculus(F, V);
            end
            dec = obj.Cache("DEC");
        end

        function g = Graph(obj)
            %GRAPH Get Graph representation (lazy creation with caching)
            %
            % Syntax:
            %   g = M.Graph()
            %
            % Outputs:
            %   g - bct.Graph object (navigation/topology)
            %
            % Note: First call creates Graph object, subsequent calls return cached version
            %
            % See also: bct.Graph
            
            if ~isKey(obj.Cache, "Graph")
                obj.Cache("Graph") = bct.Graph(obj);
            end
            g = obj.Cache("Graph");
        end
        
        % ===============================================================
        % GEOMETRY CACHE (Internal accessor methods)
        % ===============================================================
        
        function geom = getGeometry(obj)
            %GETGEOMETRY Get geometry cache (internal use by bct.geometry.*)
            geom = obj.Geometry;
        end
        
        function setGeometry(obj, geom)
            %SETGEOMETRY Set geometry cache (internal use by bct.geometry.*)
            obj.Geometry = geom;
        end
        
        % ===============================================================
        % SPECTRAL ANALYSIS
        % ===============================================================
        
        function [Psi, Lambda] = eigensolve(obj, k, options)
            %EIGENSOLVE Compute eigenpairs of Laplace-Beltrami operator
            %
            % Syntax:
            %   [Psi, Lambda] = M.eigensolve(k)
            %   [Psi, Lambda] = M.eigensolve(k, 'Method', 'FEM')
            %   [Psi, Lambda] = M.eigensolve(k, 'Force', true)
            %
            % Inputs:
            %   k - Number of eigenmodes to compute
            %
            % Optional Parameters:
            %   Method - Eigensolve method: 'FEM' (default)
            %            Future: 'DEC', 'Graph'
            %   Force  - If true, recompute even if cached (default: false)
            %
            % Outputs:
            %   Psi    - [N×k] matrix of eigenvectors (columns are eigenmodes)
            %   Lambda - [k×1] vector of eigenvalues (spatial frequencies)
            %
            % Note: Currently only 'FEM' method is implemented. This delegates
            %       to FEM().eigenpairs() for computation.
            %
            % Examples:
            %   % Compute first 100 eigenmodes
            %   [Psi, Lambda] = M.eigensolve(100);
            %
            %   % Use FEM method explicitly
            %   [Psi, Lambda] = M.eigensolve(100, 'Method', 'FEM');
            %
            % See also: bct.FEM.eigenpairs, bct.Eigenpairs
            
            arguments
                obj
                k (1,1) double {mustBePositive, mustBeInteger}
                options.Method (1,1) string {mustBeMember(options.Method, ["FEM"])} = "FEM"
                options.Force (1,1) logical = false
            end
            
            % Delegate to appropriate method
            switch options.Method
                case "FEM"
                    % Delegate to FEM eigenpairs method
                    fem = obj.FEM();
                    E = fem.eigenpairs(k, 'Force', options.Force);
                    
                    % Extract eigenvectors and eigenvalues
                    Psi = E.Vectors;
                    Lambda = E.Values;
                    
                otherwise
                    error('bct:Manifold:UnsupportedMethod', ...
                          'Method "%s" not yet implemented. Currently only "FEM" is supported.', ...
                          options.Method);
            end
        end
        
        % ===============================================================
        % GEOMETRIC QUERIES (thin delegations)
        % ===============================================================
        
        function N = numVertices(obj)
            %NUMVERTICES Get number of vertices
            N = size(obj.Vertices, 1);
        end

        function M = numFaces(obj)
            %NUMFACES Get number of faces
            M = size(obj.Faces, 1);
        end
        
        function E = numEdges(obj)
            %NUMEDGES Get number of edges
            E = size(obj.Edges, 1);
        end
        
        function A = adjacency(obj)
            %ADJACENCY Compute binary adjacency matrix from faces
            %
            % Syntax:
            %   A = M.adjacency()
            %
            % Outputs:
            %   A - [N×N] sparse logical adjacency matrix (symmetric, no self-loops)
            
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
        
        function bbox = boundingBox(obj)
            %BOUNDINGBOX Get axis-aligned bounding box
            %
            % Syntax:
            %   bbox = M.boundingBox()
            %
            % Outputs:
            %   bbox - [3×2] matrix: [xmin xmax; ymin ymax; zmin zmax]
            
            V = obj.Vertices;
            bbox = [min(V); max(V)].';
        end
        
        function C = centroids(obj)
            %CENTROIDS Compute face centroids
            %
            % Syntax:
            %   C = M.centroids()
            %
            % Outputs:
            %   C - [M×3] matrix of face centroids where M is number of faces
            %
            % Description:
            %   Computes the geometric center (centroid) of each triangular face
            %   as the average of its three vertex positions. This is a wrapper
            %   for bct.geometry.centroids().
            %
            % Examples:
            %   % Compute centroids
            %   M = bct.Manifold(V, F);
            %   C = M.centroids();
            %
            %   % Visualize centroids
            %   C = M.centroids();
            %   plot3(C(:,1), C(:,2), C(:,3), 'r.', 'MarkerSize', 10);
            %
            % See also: bct.geometry.centroids
            
            C = bct.geometry.centroids(obj);
        end
        
        function N = normals(obj, type)
            %NORMALS Compute vertex or face normals
            %
            % Syntax:
            %   N = M.normals()
            %   N = M.normals(Type)
            %
            % Inputs:
            %   Type - 'Vertex' (default) or 'Face'
            %
            % Outputs:
            %   N - [N×3] vertex normals or [M×3] face normals
            %
            % Description:
            %   Computes vertex or face normals using MATLAB's surfaceMesh object.
            %   By default returns vertex normals. Specify 'Face' to get face normals.
            %   This is a wrapper for bct.geometry.normals().
            %
            % Examples:
            %   % Compute vertex normals (default)
            %   M = bct.Manifold(V, F);
            %   VN = M.normals();
            %
            %   % Compute face normals
            %   FN = M.normals('Face');
            %
            %   % Visualize vertex normals
            %   VN = M.normals();
            %   quiver3(V(:,1), V(:,2), V(:,3), VN(:,1), VN(:,2), VN(:,3), 0.5);
            %
            % See also: bct.geometry.normals, centroids
            
            arguments
                obj
                type {mustBeTextScalar} = 'Vertex'
            end
            
            N = bct.geometry.normals(obj, type);
        end
        
        function [N, e1, e2] = tangents(obj, options)
            %TANGENTS Compute orthonormal tangent frame for each face or vertex
            %
            % Syntax:
            %   [N, e1, e2] = M.tangents()
            %   [N, e1, e2] = M.tangents('Domain', 'face')    % default
            %   [N, e1, e2] = M.tangents('Domain', 'vertex')
            %
            % Name-Value:
            %   'Domain' - 'face' (default) or 'vertex'
            %
            % Outputs:
            %   N  - normals:
            %        * face domain:   [Nf×3] face normals (unit)
            %        * vertex domain: [Nv×3] vertex normals (unit)
            %   e1 - first tangent basis vector (same size as N)
            %   e2 - second tangent basis vector (same size as N)
            %
            % Description:
            %   Computes an orthonormal coordinate frame {e1, e2, N} for each face or
            %   vertex. The frame is right-handed with:
            %   - N: face/vertex normal
            %   - e1: first tangent basis vector (orthogonal to N)
            %   - e2: second tangent basis vector (orthogonal to both N and e1)
            %
            %   Face tangents are computed per triangle using the first edge.
            %   Vertex tangents use a robust reference axis projection method.
            %   This is a wrapper for bct.geometry.tangents().
            %
            % Examples:
            %   % Face tangent frame
            %   M = bct.Manifold(V, F);
            %   [N, e1, e2] = M.tangents();
            %   [N, e1, e2] = M.tangents('Domain', 'face');
            %
            %   % Vertex tangent frame
            %   [N, e1, e2] = M.tangents('Domain', 'vertex');
            %
            %   % Visualize face tangent frame at centroids
            %   C = M.centroids();
            %   [N, e1, e2] = M.tangents('Domain', 'face');
            %   quiver3(C(:,1), C(:,2), C(:,3), e1(:,1), e1(:,2), e1(:,3), 0.5, 'r');
            %   hold on;
            %   quiver3(C(:,1), C(:,2), C(:,3), e2(:,1), e2(:,2), e2(:,3), 0.5, 'g');
            %   quiver3(C(:,1), C(:,2), C(:,3), N(:,1), N(:,2), N(:,3), 0.5, 'b');
            %
            %   % Visualize vertex tangent frame
            %   [N, e1, e2] = M.tangents('Domain', 'vertex');
            %   quiver3(M.Vertices(:,1), M.Vertices(:,2), M.Vertices(:,3), ...
            %           e1(:,1), e1(:,2), e1(:,3), 0.5, 'r');
            %
            % See also: bct.geometry.tangents, normals, centroids
            
            arguments
                obj bct.Manifold
                options.Domain {mustBeMember(options.Domain, ["face", "vertex", "Face", "Vertex"])} = "face"
            end
            
            [N, e1, e2] = bct.geometry.tangents(obj, 'Domain', options.Domain);
        end
        
        function write(obj, fileName, options)
            %WRITE Write Manifold to mesh file
            %
            % Syntax:
            %   M.write(fileName)
            %   M.write(fileName, 'Encoding', enc)
            %   M.write(fileName, 'Format', fmt)
            %
            % Supported File Formats:
            %   - .stl  - STL (STereoLithography) format
            %   - .ply  - PLY (Polygon File Format)
            %   - .obj  - OBJ (Wavefront) format
            %   - .glb  - GLB (Binary glTF)
            %   - .gltf - GLTF (GL Transmission Format)
            %   - .mat  - MATLAB data file (saves V and F variables)
            %   - .h5/.hdf5 - HDF5 format
            %
            % Inputs:
            %   fileName - String or char path for output file
            %
            % Optional Parameters:
            %   Encoding - 'binary' or 'ascii' (for formats that support it)
            %   Format   - Explicitly specify file format (auto-detected from extension)
            %
            % Examples:
            %   % Write to OBJ file
            %   M = bct.Manifold(V, F);
            %   M.write('output.obj');
            %
            %   % Write to GLB file
            %   M.write('model.glb');
            %
            %   % Write to HDF5 file
            %   M.write('mesh.h5');
            %
            %   % Write to STL with binary encoding
            %   M.write('output.stl', 'Encoding', 'binary');
            %
            % See also: bct.Manifold.read, bct.manifold.write
            
            arguments
                obj
                fileName string
                options.Encoding string = ""
                options.Format string = ""
            end
            
            % Delegate to bct.manifold.write function
            if options.Encoding ~= ""
                bct.manifold.write(obj, fileName, 'Encoding', options.Encoding, 'Format', options.Format);
            elseif options.Format ~= ""
                bct.manifold.write(obj, fileName, 'Format', options.Format);
            else
                bct.manifold.write(obj, fileName);
            end
        end
    end
    
    methods (Access = private)
        function E = computeEdges(obj)
            %COMPUTEEDGES Extract unique edges from faces
            %
            % Returns:
            %   E - [E×2] matrix of vertex indices forming edges
            %
            % Note: Manual unique() approach is faster than triangulation.edges()
            %       for large meshes (0.32s vs 0.50s on fsaverage6)
            
            F = obj.Faces;
            if isempty(F)
                E = zeros(0, 2);
                return;
            end
            
            % Extract all edges from triangular faces
            edges = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];
            
            % Sort each edge so that (i,j) and (j,i) become the same
            edges = sort(edges, 2);
            
            % Get unique edges
            E = unique(edges, 'rows');
        end
    end

    methods (Static)
        function obj = read(fileName, options)
            %READ Load Manifold from mesh file
            %
            % Syntax:
            %   M = bct.Manifold.read(fileName)
            %   M = bct.Manifold.read(fileName, 'Format', fmt)
            %
            % Supported File Formats:
            %   - .stl  - STL (STereoLithography) format
            %   - .ply  - PLY (Polygon File Format)
            %   - .obj  - OBJ (Wavefront) format
            %   - .glb  - GLB (Binary glTF)
            %   - .gltf - GLTF (GL Transmission Format)
            %   - .mat  - MATLAB data file
            %   - .h5/.hdf5 - HDF5 format
            %
            % Inputs:
            %   fileName - String or char path to mesh file
            %
            % Optional Parameters:
            %   Format - Explicitly specify file format (auto-detected from extension)
            %
            % Outputs:
            %   M - Manifold object loaded from file
            %
            % Examples:
            %   % Read from OBJ file
            %   M = bct.Manifold.read('mesh.obj');
            %
            %   % Read from GLB file
            %   M = bct.Manifold.read('model.glb');
            %
            %   % Read from HDF5 file
            %   M = bct.Manifold.read('data.h5');
            %
            %   % Read MATLAB data file
            %   M = bct.Manifold.read('data/mesh/fsaverage_lh_pial.mat');
            %
            % See also: bct.Manifold.write, bct.manifold.read
            
            arguments
                fileName {mustBeFile}
                options.Format string = ""
            end
            
            % Delegate to bct.manifold.read function
            if options.Format ~= ""
                obj = bct.manifold.read(fileName, 'Format', options.Format);
            else
                obj = bct.manifold.read(fileName);
            end
        end
    end
end
