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
        end

        % ===============================================================
        % REPRESENTATION PORTS (FEM, DEC, Graph)
        % ===============================================================
        
        function fem = FEM(obj)
            %FEM Get FEM representation (lazy creation with caching)
            %
            % Syntax:
            %   fem = M.FEM()
            %
            % Outputs:
            %   fem - bct.FEM object (spectral representation)
            %
            % Note: First call creates FEM object, subsequent calls return cached version
            %
            % See also: bct.FEM
            
            if ~isKey(obj.Cache, "FEM")
                obj.Cache("FEM") = bct.FEM(obj);
            end
            fem = obj.Cache("FEM");
        end

        function dec = DEC(obj)
            %DEC Get DEC representation (lazy creation with caching)
            %
            % Syntax:
            %   dec = M.DEC()
            %
            % Outputs:
            %   dec - bct.DEC object (exterior calculus representation)
            %
            % Note: First call creates DEC wrapper, subsequent calls return cached version
            %
            % See also: bct.DEC, DiscreteExteriorCalculus
            
            if ~isKey(obj.Cache, "DEC")
                obj.Cache("DEC") = bct.DEC(obj);
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
    end
    
    methods (Access = private)
        function E = computeEdges(obj)
            %COMPUTEEDGES Extract unique edges from faces
            %
            % Returns:
            %   E - [E×2] matrix of vertex indices forming edges
            
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
        function obj = fromHDF5(filename)
            %FROMHDF5 Load Manifold from HDF5 file
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
