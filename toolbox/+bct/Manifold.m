classdef Manifold < handle
    %MANIFOLD  Geometric substrate for surface-based analysis
    %
    % Defines geometry, topology, and metric. Provides unified caching of
    % computed properties (geometry, topology, operators, eigenmodes).
    %
    % Design principles (from ManifoldContract):
    %   - Manifold owns: Topology, Embedding, Metric, Intrinsic differential structure
    %   - Immutable geometry, mutable representations
    %   - Lazy computation with unified cache structure
    %   - No analysis, filters, brushes, spectral pipelines, or UI state
    %
    % Usage:
    %   % Construction
    %   M = bct.Manifold(struct('V', V, 'F', F));
    %   
    %   % Access cached properties
    %   ops = M.operators();  % All operators (mass, stiffness, DEC)
    %   geom = M.geometry();  % All geometry (centroids, normals, tangents)
    %   topo = M.topology();  % All topology (edges, adjacency, halfedge)
    %   graph = M.Graph();    % Graph representation (lightweight wrapper)
    %
    % See also: bct.manifold.Graph, bct.manifold.operator, bct.manifold.geometry, bct.manifold.topology

    properties (SetAccess = private)
        Vertices         % [N×3] vertex coordinates (immutable)
        Faces            % [M×3] face connectivity (immutable)
        Edges            % [E×2] edge connectivity (derived from faces)
        ID               % Unique identifier for compatibility tracking
    end

    properties (Access = private)
        Cache  % Unified cache structure with namespaces: geometry, topology, operators, eigenmodes
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
            obj.Edges = bct.manifold.topology.edges(obj.Faces);
            
            % Generate unique ID for this manifold
            obj.ID = string(java.util.UUID.randomUUID());
            
            % Initialize unified cache structure with namespaces
            obj.Cache = struct(...
                'geometry', struct('data', struct(), 'meta', struct()), ...
                'topology', struct('data', struct(), 'meta', struct()), ...
                'operators', struct('data', struct(), 'meta', struct()), ...
                'eigenmodes', struct('data', struct(), 'meta', struct()), ...
                'health', struct('data', struct(), 'meta', struct()));
        end

        % ===============================================================
        % REPRESENTATION PORTS (Graph)
        % ===============================================================

        function ops = operators(obj, varargin)
            %OPERATORS Get or compute all differential operators (lazy creation with caching)
            %
            % Syntax:
            %   ops = M.operators()
            %   ops = M.operators(Name, Value)
            %
            % Optional Parameters:
            %   MassVariant      - 'voronoi' (default), 'barycentric', 'full'
            %   StiffnessVariant - 'cotan' (default)
            %   StiffnessSign    - 'positive' (default), 'negative'
            %   Symmetrize       - true (default), false
            %   Force            - false (default) or true to force recomputation
            %
            % Outputs:
            %   ops - Structure with fields:
            %     .mass            - [N×N] FEM mass matrix
            %     .stiffness       - [N×N] FEM stiffness matrix
            %     .laplacebeltrami - [N×N] Laplace-Beltrami operator
            %     .d0, .d1         - Exterior derivatives
            %     .dd0, .dd1       - Codifferentials
            %     .dec             - Structure with all 15 DEC operators
            %
            % Description:
            %   Returns cached operator structure if available, or computes
            %   using bct.manifold.operator() with specified parameters.
            %   Result is cached for future calls.
            %
            %   On first call, computes all operators. Subsequent calls return
            %   the cached result unless 'Force' is true or parameters change.
            %
            % Examples:
            %   % Get cached or compute with defaults
            %   ops = M.operators();
            %   L = ops.laplacebeltrami;
            %   d0 = ops.d0;
            %
            %   % Compute with custom parameters (updates cache)
            %   ops = M.operators('MassVariant', 'barycentric');
            %
            %   % Force recomputation
            %   ops = M.operators('Force', true);
            %
            %   % Access DEC operators
            %   hd0 = ops.dec.hd0;
            %   hd1 = ops.dec.hd1;
            %
            % See also: bct.manifold.operator, massmatrix, cotmatrix
            
            % Parse inputs
            p = inputParser;
            p.addParameter('Force', false, @islogical);
            p.addParameter('MassVariant', 'voronoi', @(x) ischar(x) || isstring(x));
            p.addParameter('StiffnessVariant', 'cotan', @(x) ischar(x) || isstring(x));
            p.addParameter('StiffnessSign', 'positive', @(x) ischar(x) || isstring(x));
            p.addParameter('Symmetrize', true, @islogical);
            p.parse(varargin{:});
            
            force = p.Results.Force;
            
            % Check if we have cached operators and not forcing recomputation
            if ~force && ~isempty(fieldnames(obj.Cache.operators.data))
                ops = obj.Cache.operators.data;
                return;
            end
            
            % Compute all operators using bct.manifold.operator
            ops = bct.manifold.operator(obj, ...
                'MassVariant', p.Results.MassVariant, ...
                'StiffnessVariant', p.Results.StiffnessVariant, ...
                'StiffnessSign', p.Results.StiffnessSign, ...
                'Symmetrize', p.Results.Symmetrize);
            
            % Cache the result
            obj.Cache.operators.data = ops;
            obj.Cache.operators.meta.computed = datetime('now');
            obj.Cache.operators.meta.massVariant = string(p.Results.MassVariant);
            obj.Cache.operators.meta.stiffnessVariant = string(p.Results.StiffnessVariant);
            obj.Cache.operators.meta.stiffnessSign = string(p.Results.StiffnessSign);
            obj.Cache.operators.meta.symmetrize = p.Results.Symmetrize;
        end

        function M = massmatrix(obj, options)
            %MASSMATRIX Get or compute FEM mass matrix (lazy creation with caching)
            %
            % Syntax:
            %   M = manifold.massmatrix()
            %   M = manifold.massmatrix('Type', massType)
            %
            % Name-Value Parameters:
            %   Type - Mass matrix type (default: 'voronoi')
            %          'voronoi'     - Voronoi area cells (diagonal, default)
            %          'barycentric' - Equal area distribution (diagonal)
            %          'full'        - Consistent FEM mass matrix (sparse)
            %
            % Outputs:
            %   M - [N×N] sparse mass matrix
            %
            % Description:
            %   Returns the FEM mass matrix for the manifold. If type matches
            %   cached operators, returns from cache. Otherwise computes directly.
            %
            %   Note: Default 'voronoi' is recommended for discrete analysis.
            %
            % Examples:
            %   M = manifold.massmatrix();  % Default voronoi
            %   M = manifold.massmatrix('Type', 'barycentric');
            %
            % See also: bct.manifold.operator.mass, operators, cotmatrix
            
            arguments
                obj
                options.Type (1,1) string {mustBeMember(options.Type, ["voronoi","barycentric","full"])} = "voronoi"
            end
            
            massType = options.Type;
            
            % Check if cached operators exist and have matching mass variant
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.meta, 'massVariant') && ...
               obj.Cache.operators.meta.massVariant == massType
                M = obj.Cache.operators.data.mass;
                return;
            end
            
            % Compute mass matrix directly using bct.manifold.operator.mass
            [~, M] = bct.manifold.operator.mass(obj, 'variant', massType);
        end
        
        function K = cotmatrix(obj)
            %COTMATRIX Get or compute FEM stiffness/cotangent matrix (lazy creation with caching)
            %
            % Syntax:
            %   K = manifold.cotmatrix()
            %
            % Outputs:
            %   K - [N×N] sparse stiffness matrix (cotangent Laplacian)
            %
            % Description:
            %   Returns the FEM stiffness matrix (cotangent Laplacian) for the
            %   manifold. Returns from cached operators if available, otherwise
            %   computes directly.
            %
            %   The cotangent matrix represents:
            %   - Discrete Dirichlet energy: E(u) = u' * K * u
            %   - Laplace-Beltrami operator: Δu = M^(-1) * K * u
            %   - Positive semidefinite form (λ ≥ 0)
            %
            % Examples:
            %   K = manifold.cotmatrix();
            %   energy = u' * K * u;  % Dirichlet energy
            %
            % See also: bct.manifold.operator.stiffness, operators, massmatrix
            
            % Check if cached operators exist with matching stiffness parameters
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.meta, 'stiffnessVariant') && ...
               obj.Cache.operators.meta.stiffnessVariant == "cotan" && ...
               obj.Cache.operators.meta.stiffnessSign == "positive" && ...
               obj.Cache.operators.meta.symmetrize == true
                K = obj.Cache.operators.data.stiffness;
                return;
            end
            
            % Compute stiffness matrix directly using bct.manifold.operator.stiffness
            [~, K] = bct.manifold.operator.stiffness(obj, ...
                'variant', 'cotan', ...
                'sign', 'positive', ...
                'symmetrize', true);
        end

        function g = Graph(obj)
            %GRAPH Get Graph representation (lightweight wrapper)
            %
            % Syntax:
            %   g = M.Graph()
            %
            % Outputs:
            %   g - bct.manifold.Graph object (navigation/topology)
            %
            % Description:
            %   Returns a lightweight Graph wrapper around this Manifold.
            %   Graph objects are not cached since they only hold a reference
            %   to the Manifold and provide navigation/topology methods.
            %
            % See also: bct.manifold.Graph, topology
            
            g = bct.manifold.Graph(obj);
        end
        
        % ===============================================================
        % GRAPH QUERY METHODS
        % ===============================================================
        
        function [T, pred] = bfSearch(obj, s)
            %BFSEARCH Breadth-first search from source node
            %
            % Syntax:
            %   T = M.bfSearch(s)
            %   [T, pred] = M.bfSearch(s)
            %
            % Inputs:
            %   s - Source node index
            %
            % Outputs:
            %   T    - Vector of node discovery order
            %   pred - Vector of predecessor nodes
            %
            % Description:
            %   Performs breadth-first search on the manifold's topology.
            %   Uses cached adjacency matrix from topology namespace.
            %
            % See also: dfSearch, bct.manifold.query.bfSearch
            
            arguments
                obj (1,1) bct.Manifold
                s (1,1) {mustBeInteger, mustBePositive}
            end
            
            A = obj.adjacency();
            
            if nargout > 1
                [T, pred] = bct.manifold.query.bfSearch(A, s);
            else
                T = bct.manifold.query.bfSearch(A, s);
            end
        end
        
        function [T, pred] = dfSearch(obj, s)
            %DFSEARCH Depth-first search from source node
            %
            % Syntax:
            %   T = M.dfSearch(s)
            %   [T, pred] = M.dfSearch(s)
            %
            % Inputs:
            %   s - Source node index
            %
            % Outputs:
            %   T    - Vector of node discovery order
            %   pred - Vector of predecessor nodes
            %
            % Description:
            %   Performs depth-first search on the manifold's topology.
            %   Uses cached adjacency matrix from topology namespace.
            %
            % See also: bfSearch, bct.manifold.query.dfSearch
            
            arguments
                obj (1,1) bct.Manifold
                s (1,1) {mustBeInteger, mustBePositive}
            end
            
            A = obj.adjacency();
            
            if nargout > 1
                [T, pred] = bct.manifold.query.dfSearch(A, s);
            else
                T = bct.manifold.query.dfSearch(A, s);
            end
        end
        
        function [path, dist] = shortestPath(obj, s, t, options)
            %SHORTESTPATH Shortest path between two nodes
            %
            % Syntax:
            %   path = M.shortestPath(s, t)
            %   [path, dist] = M.shortestPath(s, t, 'Metric', 'cotangent')
            %
            % Inputs:
            %   s - Source node index
            %   t - Target node index
            %
            % Optional Parameters:
            %   Metric - 'euclidean' | 'cotangent' (default)
            %
            % Outputs:
            %   path - Vector of node indices along shortest path
            %   dist - Total path distance
            %
            % Description:
            %   Computes shortest path using cached edge weights from geometry.
            %   Cotangent weights provide better discrete approximation for
            %   spectral methods. Uses cached geometry data.
            %
            % See also: distances, bct.manifold.query.shortestPath
            
            arguments
                obj (1,1) bct.Manifold
                s (1,1) {mustBeInteger, mustBePositive}
                t (1,1) {mustBeInteger, mustBePositive}
                options.Metric (1,1) string {mustBeMember(options.Metric, ...
                    ["euclidean", "cotangent"])} = "cotangent"
            end
            
            % Get edges and weights from cache
            E = obj.Edges;
            N = size(obj.Vertices, 1);
            geom = obj.geometry();
            w = geom.edgeWeights.(options.Metric);
            
            [path, dist] = bct.manifold.query.shortestPath(E, w, N, s, t);
        end
        
        function D = distances(obj, options)
            %DISTANCES All-pairs shortest path distances
            %
            % Syntax:
            %   D = M.distances()
            %   D = M.distances('Metric', 'euclidean')
            %
            % Optional Parameters:
            %   Metric - 'euclidean' | 'cotangent' (default)
            %
            % Outputs:
            %   D - [N×N] matrix of shortest path distances
            %
            % Description:
            %   Computes all-pairs shortest path distances using cached
            %   edge weights from geometry. Cotangent weights provide
            %   better discrete approximation for spectral methods.
            %
            % See also: shortestPath, bct.manifold.query.distances
            
            arguments
                obj (1,1) bct.Manifold
                options.Metric (1,1) string {mustBeMember(options.Metric, ...
                    ["euclidean", "cotangent"])} = "cotangent"
            end
            
            % Get edges and weights from cache
            E = obj.Edges;
            N = size(obj.Vertices, 1);
            geom = obj.geometry();
            w = geom.edgeWeights.(options.Metric);
            
            D = bct.manifold.query.distances(E, w, N);
        end
        
        % ===============================================================
        % CACHE INSPECTION
        % ===============================================================
        
        function tf = hasCached(obj, namespace)
            %HASCACHED Check if a cache namespace has computed data
            %
            % Syntax:
            %   tf = M.hasCached(namespace)
            %
            % Inputs:
            %   namespace - String specifying cache namespace:
            %               'operators', 'geometry', 'topology', 'eigenmodes', 'health'
            %
            % Outputs:
            %   tf - Logical true if namespace has cached data, false otherwise
            %
            % Description:
            %   Checks whether a specific cache namespace contains computed data
            %   without triggering computation. Useful for external code that needs
            %   to check cache status before accessing cached properties.
            %
            % Examples:
            %   % Check if operators are cached
            %   M = bct.Manifold(V, F);
            %   if M.hasCached('operators')
            %       ops = M.operators();  % Won't trigger computation
            %   end
            %
            %   % Check multiple namespaces
            %   hasOps = M.hasCached('operators');
            %   hasGeom = M.hasCached('geometry');
            %   hasEigen = M.hasCached('eigenmodes');
            %
            %   % Conditional computation
            %   if ~M.hasCached('eigenmodes')
            %       E = M.eigenmodes(100);  % Compute with 100 modes
            %   end
            %
            % See also: operators, geometry, topology, eigenmodes, health
            
            arguments
                obj
                namespace {mustBeTextScalar, mustBeMember(namespace, ...
                    ["operators", "geometry", "topology", "eigenmodes", "health"])}
            end
            
            namespace = string(namespace);
            
            % Check if namespace exists in cache and has data
            if isfield(obj.Cache, namespace)
                cacheData = obj.Cache.(namespace).data;
                tf = ~isempty(fieldnames(cacheData));
            else
                tf = false;
            end
        end
        
        function status = cacheStatus(obj)
            %CACHESTATUS Get summary of cache state across all namespaces
            %
            % Syntax:
            %   status = M.cacheStatus()
            %
            % Outputs:
            %   status - Structure with fields for each namespace:
            %     .operators  - Logical, true if cached
            %     .geometry   - Logical, true if cached
            %     .topology   - Logical, true if cached
            %     .eigenmodes - Logical, true if cached
            %     .health     - Logical, true if cached
            %     .meta       - Structure with metadata for each namespace
            %
            % Description:
            %   Returns a summary of which cache namespaces contain computed
            %   data and their associated metadata (computation timestamps, etc.).
            %
            % Examples:
            %   % Check cache status
            %   M = bct.Manifold(V, F);
            %   ops = M.operators();  % Populate operators cache
            %   status = M.cacheStatus();
            %   disp(status);
            %
            %   % Use status to decide what to compute
            %   if ~status.eigenmodes
            %       E = M.eigenmodes(100);
            %   end
            %
            % See also: hasCached, operators, geometry, topology
            
            namespaces = ["operators", "geometry", "topology", "eigenmodes", "health"];
            
            % Initialize status structure
            status = struct();
            status.meta = struct();
            
            % Check each namespace
            for ns = namespaces
                status.(ns) = obj.hasCached(ns);
                
                % Include metadata if available
                if isfield(obj.Cache.(ns), 'meta')
                    status.meta.(ns) = obj.Cache.(ns).meta;
                else
                    status.meta.(ns) = struct();
                end
            end
        end
        
        % ===============================================================
        % SPECTRAL ANALYSIS
        % ===============================================================
        
        function Eigen = eigenmodes(obj, varargin)
            %EIGENMODES Get or compute eigenmodes of Laplace-Beltrami operator
            %
            % Syntax:
            %   Eigen = M.eigenmodes()          % Get cached or compute with k=50
            %   Eigen = M.eigenmodes(k)         % Recompute with k modes
            %   Eigen = M.eigenmodes('k', k)    % Recompute with k modes (named)
            %   Eigen = M.eigenmodes('k', k, 'RemoveDC', false)  % Additional options
            %
            % Inputs:
            %   k - Number of eigenmodes (default: 50 if not cached)
            %
            % Optional Parameters:
            %   k         - Number of modes (can be positional or named)
            %   RemoveDC  - Remove DC mode (default: true)
            %   MassType  - Mass matrix type: 'voronoi' (default), 'barycentric', 'full'
            %   EigsOpts  - Additional eigs options (struct)
            %   Force     - Force recomputation even if cached (default: false)
            %
            % Outputs:
            %   Eigen - Structure with fields:
            %           .values    - [k×1] eigenvalues (sorted ascending)
            %           .vectors   - [N×k] eigenvectors (M-orthonormal)
            %           .k         - Number of modes
            %           .operator  - 'Laplace-Beltrami'
            %           .basis     - 'P1-FEM'
            %           .ordering  - 'ascending'
            %           .massType  - Mass matrix type used
            %           .removedDC - Whether DC mode was removed
            %
            % Description:
            %   Returns cached eigenmode structure if available, or computes
            %   using bct.manifold.eigenmodes() with specified parameters.
            %   Result is cached for future calls.
            %
            %   When called without arguments, returns cached Eigen structure
            %   or computes with default k=50 modes if not cached.
            %
            %   When called with arguments (k value), recomputes eigenmodes
            %   and updates the cache.
            %
            % Examples:
            %   % Get cached or compute with default k=50
            %   E = M.eigenmodes();
            %   lambda = E.values;
            %   U = E.vectors;
            %
            %   % Compute with 100 modes (updates cache)
            %   E = M.eigenmodes(100);
            %
            %   % Named parameter
            %   E = M.eigenmodes('k', 100);
            %
            %   % With additional options
            %   E = M.eigenmodes(100, 'MassType', 'barycentric');
            %
            %   % Force recomputation
            %   E = M.eigenmodes('Force', true);
            %
            % See also: bct.manifold.eigenmodes
            
            % Parse input arguments
            p = inputParser;
            p.addOptional('k', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
            p.addParameter('RemoveDC', true, @islogical);
            p.addParameter('MassType', "voronoi", @(x) isstring(x) || ischar(x));
            p.addParameter('EigsOpts', struct(), @isstruct);
            p.addParameter('Force', false, @islogical);
            p.parse(varargin{:});
            
            k_requested = p.Results.k;
            removeDC = p.Results.RemoveDC;
            massType = string(p.Results.MassType);
            eigsOpts = p.Results.EigsOpts;
            force = p.Results.Force;
            
            % Determine if we need to compute (early return if cached)
            if force
                % Forced recomputation
                if isempty(k_requested)
                    % Use cached k if available, otherwise default
                    if isfield(obj.Cache.eigenmodes.data, 'k') && ~isempty(obj.Cache.eigenmodes.data.k)
                        k_requested = obj.Cache.eigenmodes.data.k;
                    else
                        k_requested = 50;  % Default
                    end
                end
            elseif ~isempty(k_requested)
                % k specified, need to recompute
            elseif isempty(fieldnames(obj.Cache.eigenmodes.data))
                % No cache exists, compute with default k=50
                k_requested = 50;
            else
                % Return cached
                Eigen = obj.Cache.eigenmodes.data;
                return;
            end
            
            % Compute eigenmodes using bct.manifold.eigenmodes
            [eigenvalues, eigenvectors] = bct.manifold.eigenmodes(...
                obj, k_requested, ...
                'RemoveDC', removeDC, ...
                'MassType', massType, ...
                'EigsOpts', eigsOpts);
            
            % Build Eigen structure
            Eigen = struct();
            Eigen.values = eigenvalues;
            Eigen.vectors = eigenvectors;
            Eigen.k = length(eigenvalues);
            Eigen.operator = "Laplace-Beltrami";
            Eigen.basis = "P1-FEM";
            Eigen.ordering = "ascending";
            Eigen.massType = massType;
            Eigen.removedDC = removeDC;
            
            % Cache for future use
            obj.Cache.eigenmodes.data = Eigen;
            obj.Cache.eigenmodes.meta.computed = datetime('now');
            obj.Cache.eigenmodes.meta.k = Eigen.k;
            obj.Cache.eigenmodes.meta.massType = massType;
            obj.Cache.eigenmodes.meta.removedDC = removeDC;
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
            
            A = bct.manifold.topology.adjacency(obj);
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
            %   for bct.manifold.geometry.centroids().
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
            % See also: bct.manifold.geometry.centroids
            
            C = bct.manifold.geometry.centroids(obj);
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
            %   This is a wrapper for bct.manifold.geometry.normals().
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
            % See also: bct.manifold.geometry.normals, centroids
            
            arguments
                obj
                type {mustBeTextScalar} = 'Vertex'
            end
            
            N = bct.manifold.geometry.normals(obj, type);
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
            %   This is a wrapper for bct.manifold.geometry.tangents().
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
            % See also: bct.manifold.geometry.tangents, normals, centroids
            
            arguments
                obj bct.Manifold
                options.Domain {mustBeMember(options.Domain, ["face", "vertex", "Face", "Vertex"])} = "face"
            end
            
            [N, e1, e2] = bct.manifold.geometry.tangents(obj, 'Domain', options.Domain);
        end
        
        function geom = geometry(obj, varargin)
            %GEOMETRY Compute and cache all geometric properties
            %
            % Syntax:
            %   geom = M.geometry()
            %   geom = M.geometry(Name, Value)
            %
            % Name-Value Arguments:
            %   'NormalType'    - 'vertex' (default) or 'face'
            %   'TangentDomain' - 'face' (default) or 'vertex'
            %   'ForceFrame'    - false (default) or true to force recomputation
            %   'Force'         - false (default) or true to force full recomputation
            %
            % Outputs:
            %   geom - Structure with fields:
            %     .centroids - [nF×3] Face centroids
            %     .normals   - [nV×3] or [nF×3] Normal vectors
            %     .tangents  - Structure with N, e1, e2 tangent frames
            %     .frame     - Cached orthonormal frame structure
            %     .cotan     - [nF×3] Cotangent values per face
            %
            % Description:
            %   Computes all geometric properties of the manifold and caches
            %   the result for future calls. This is a wrapper for
            %   bct.manifold.geometry() that handles caching.
            %
            %   On first call, computes all geometry. Subsequent calls return
            %   the cached result unless 'Force' is true.
            %
            % Examples:
            %   % Compute and cache all geometry
            %   M = bct.Manifold(V, F);
            %   geom = M.geometry();
            %   
            %   % Access individual properties
            %   C = geom.centroids;
            %   N = geom.normals;
            %   T1 = geom.tangents.e1;
            %   
            %   % Force recomputation
            %   geom = M.geometry('Force', true);
            %   
            %   % Compute with custom parameters
            %   geom = M.geometry('NormalType', 'face', 'TangentDomain', 'vertex');
            %
            % See also: bct.manifold.geometry, centroids, normals, tangents
            
            % Parse inputs
            p = inputParser;
            p.FunctionName = 'bct.Manifold.geometry';
            addParameter(p, 'Force', false, @islogical);
            addParameter(p, 'NormalType', 'vertex', @(x) ischar(x) || isstring(x));
            addParameter(p, 'TangentDomain', 'face', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ForceFrame', false, @islogical);
            parse(p, varargin{:});
            
            force = p.Results.Force;
            
            % Check if we have cached geometry and not forcing recomputation
            if ~force && ~isempty(fieldnames(obj.Cache.geometry.data))
                geom = obj.Cache.geometry.data;
                return;
            end
            
            % Compute all geometry using bct.manifold.geometry
            geom = bct.manifold.geometry(obj, ...
                'NormalType', p.Results.NormalType, ...
                'TangentDomain', p.Results.TangentDomain, ...
                'ForceFrame', p.Results.ForceFrame);
            
            % Cache the result
            obj.Cache.geometry.data = geom;
            obj.Cache.geometry.meta.computed = datetime('now');
            obj.Cache.geometry.meta.normalType = p.Results.NormalType;
            obj.Cache.geometry.meta.tangentDomain = p.Results.TangentDomain;
        end
        
        function topo = topology(obj, varargin)
            %TOPOLOGY Compute and cache all topological properties
            %
            % Syntax:
            %   topo = M.topology()
            %   topo = M.topology('Force', true)
            %
            % Name-Value Arguments:
            %   'Force' - false (default) or true to force recomputation
            %
            % Outputs:
            %   topo - Structure with fields:
            %     .edges     - [nE×2] Unique undirected edges
            %     .adjacency - [N×N] Sparse binary adjacency matrix
            %     .halfedge  - Halfedge data structure with navigation
            %
            % Description:
            %   Computes all topological properties of the manifold and caches
            %   the result for future calls. This is a wrapper for
            %   bct.manifold.topology() that handles caching.
            %
            %   Topology is coordinate-free and depends only on face
            %   connectivity. On first call, computes all topology. Subsequent
            %   calls return the cached result unless 'Force' is true.
            %
            % Examples:
            %   % Compute and cache all topology
            %   M = bct.Manifold(V, F);
            %   topo = M.topology();
            %   
            %   % Access individual properties
            %   E = topo.edges;          % [nE×2] edge list
            %   A = topo.adjacency;      % [N×N] adjacency matrix
            %   he = topo.halfedge;      % Halfedge structure
            %   
            %   % Navigate mesh using halfedge
            %   h = 1;  % First halfedge
            %   next_h = topo.halfedge.next(h);
            %   twin_h = topo.halfedge.twin(h);
            %   
            %   % Force recomputation
            %   topo = M.topology('Force', true);
            %
            % See also: bct.manifold.topology, geometry
            
            % Parse inputs
            p = inputParser;
            p.FunctionName = 'bct.Manifold.topology';
            addParameter(p, 'Force', false, @islogical);
            parse(p, varargin{:});
            
            force = p.Results.Force;
            
            % Check if we have cached topology and not forcing recomputation
            if ~force && ~isempty(fieldnames(obj.Cache.topology.data))
                topo = obj.Cache.topology.data;
                return;
            end
            
            % Compute all topology using bct.manifold.topology
            topo = bct.manifold.topology(obj);
            
            % Cache the result
            obj.Cache.topology.data = topo;
            obj.Cache.topology.meta.computed = datetime('now');
        end
        
        function R = health(obj, varargin)
            %HEALTH Get or compute mesh health check (lazy creation with caching)
            %
            % Syntax:
            %   R = M.health()
            %   R = M.health(Name, Value)
            %
            % Optional Parameters:
            %   Level             - "quick" | "standard" | "full" (default: "standard")
            %                       - quick: topology only (indices, degeneracy, manifoldness)
            %                       - standard: quick + orientation + boundary + geometry
            %                       - full: standard + self-intersection + quality metrics
            %   RequireManifold   - logical, error on non-manifold edges (default: true)
            %   RequireOriented   - logical, error on orientation conflicts (default: true)
            %   RequireClosed     - logical, error on boundary edges (default: false)
            %   FailOnWarnings    - logical, set ok=false for warnings (default: false)
            %   Force             - false (default) or true to force recomputation
            %
            % Outputs:
            %   R - Health check report structure with fields:
            %     .ok       - logical, overall pass/fail
            %     .severity - "ok" | "warn" | "error"
            %     .scope    - "bct.manifold.health"
            %     .level    - check level performed
            %     .summary  - string array of high-level messages
            %     .issues   - struct array of detected issues
            %     .stats    - mesh statistics (nV, nF, nE, boundary/nonmanifold counts)
            %     .timing   - performance timers
            %     .data     - optional cached data
            %
            % Description:
            %   Performs comprehensive mesh health validation and caches the result.
            %   First call computes health check, subsequent calls return cached
            %   result unless 'Force' is true or parameters change.
            %
            %   The health check validates mesh topology, orientation, and geometry
            %   to ensure compatibility with DEC operators, FEM computations, and
            %   graph algorithms.
            %
            % Examples:
            %   % Quick check during construction validation
            %   M = bct.Manifold(V, F);
            %   R = M.health('Level', 'quick');
            %   assert(R.ok, 'Invalid mesh topology');
            %
            %   % Standard check (cached)
            %   R = M.health();  % First call computes
            %   R = M.health();  % Second call returns cached
            %
            %   % Force recomputation
            %   R = M.health('Force', true);
            %
            %   % Check for DEC compatibility
            %   R = M.health('RequireManifold', true, 'RequireOriented', true);
            %
            %   % View formatted report
            %   disp(bct.manifold.health.report(R));
            %
            % See also: bct.manifold.health.check, bct.manifold.health.report
            
            % Parse inputs
            p = inputParser;
            p.FunctionName = 'bct.Manifold.health';
            addParameter(p, 'Force', false, @islogical);
            addParameter(p, 'Level', "standard", @(x) ischar(x) || isstring(x));
            addParameter(p, 'RequireManifold', true, @islogical);
            addParameter(p, 'RequireOriented', true, @islogical);
            addParameter(p, 'RequireClosed', false, @islogical);
            addParameter(p, 'FailOnWarnings', false, @islogical);
            parse(p, varargin{:});
            
            force = p.Results.Force;
            level = string(p.Results.Level);
            
            % Check if we have cached health report and not forcing recomputation
            if ~force && ~isempty(fieldnames(obj.Cache.health.data))
                R = obj.Cache.health.data;
                return;
            end
            
            % Compute health check using bct.manifold.health.check
            R = bct.manifold.health.check(obj, ...
                'Level', level, ...
                'RequireManifold', p.Results.RequireManifold, ...
                'RequireOriented', p.Results.RequireOriented, ...
                'RequireClosed', p.Results.RequireClosed, ...
                'FailOnWarnings', p.Results.FailOnWarnings);
            
            % Cache the result
            obj.Cache.health.data = R;
            obj.Cache.health.meta.computed = datetime('now');
            obj.Cache.health.meta.level = level;
            obj.Cache.health.meta.requireManifold = p.Results.RequireManifold;
            obj.Cache.health.meta.requireOriented = p.Results.RequireOriented;
            obj.Cache.health.meta.requireClosed = p.Results.RequireClosed;
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
