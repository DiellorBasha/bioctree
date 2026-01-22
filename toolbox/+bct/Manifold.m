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
    % See also: bct.manifold.operator, bct.manifold.geometry, bct.manifold.topology

    properties (SetAccess = private)
        Vertices         % [N×3] vertex coordinates (immutable)
        Faces            % [M×3] face connectivity (immutable)
        Edges            % [E×2] edge connectivity (derived from faces)
        Header           % Metadata and rendering descriptors (schema-driven)
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
            
            % Normalize types to canonical forms
            % This ensures consistent types regardless of construction path
            obj.Vertices = double(obj.Vertices);  % Always double for precision
            obj.Faces = uint32(obj.Faces);        % Always uint32 for indices
            
            % Extract or compute edges
            obj.Edges = bct.manifold.topology.edges(obj.Faces);
            
            % Initialize Header with defaults from schema
            % (This creates ID and Metric internally)
            obj.Header = bct.Manifold.buildDefaultHeaderStatic();
            
            % Initialize unified cache structure with namespaces
            obj.Cache = struct(...
                'geometry', struct('data', struct(), 'meta', struct()), ...
                'topology', struct('data', struct(), 'meta', struct()), ...
                'halfedge', struct('data', struct(), 'meta', struct()), ...
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
            %     .hd0, .hd1, .hd2 - Hodge stars
            %     .hdd0, .hdd1, .hdd2 - Inverse Hodge stars
            %     .flatPP, .flatDP, .flatDD - Flat operators
            %     .sharpPD, .sharpDD - Sharp operators
            %     .gradient, .divergence, .curl - Vector calculus operators
            %     .hodgelaplacian  - Hodge Laplacian struct (kform0, kform1, kform2)
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
            %   % Access DEC operators (all at top level)
            %   hd0 = ops.hd0;
            %   hd1 = ops.hd1;
            %   sharpPD = ops.sharpPD;
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
            
            % Get edges and weights
            E = obj.Edges;
            N = size(obj.Vertices, 1);
            
            % Get or compute edge weights
            if obj.hasCached('geometry')
                geom = obj.Cache.geometry.data;
                if isfield(geom, 'edge')
                    % Use new schema structure (weights_cotangent, weights_euclidean)
                    if options.Metric == "cotangent"
                        w = geom.edge.weights_cotangent;
                    else
                        w = geom.edge.weights_euclidean;
                    end
                else
                    % Compute edge weights directly
                    edgeGeom = bct.manifold.geometry.edge(obj);
                    if options.Metric == "cotangent"
                        w = edgeGeom.weights_cotangent;
                    else
                        w = edgeGeom.weights_euclidean;
                    end
                end
            else
                % No cache, compute edge weights directly
                edgeGeom = bct.manifold.geometry.edge(obj);
                if options.Metric == "cotangent"
                    w = edgeGeom.weights_cotangent;
                else
                    w = edgeGeom.weights_euclidean;
                end
            end
            
            % Convert sparse weights to full for graph construction
            if issparse(w)
                w = full(w);
            end
            
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
            
            % Use new schema structure
            if options.Metric == "cotangent"
                w = geom.edge.weights_cotangent;
            else
                w = geom.edge.weights_euclidean;
            end
            
            D = bct.manifold.query.distances(E, w, N);
        end
        
        function idx = neighbors(obj, v)
            %NEIGHBORS Get topological neighbors of vertex
            %
            % Syntax:
            %   idx = M.neighbors(v)
            %
            % Inputs:
            %   v - Vertex index
            %
            % Outputs:
            %   idx - Indices of neighboring vertices
            %
            % Description:
            %   Returns the indices of all vertices directly connected to
            %   vertex v in the mesh topology. Uses cached adjacency matrix.
            %
            % Examples:
            %   M = bct.manifold.load();
            %   nbrs = M.neighbors(100);  % Get neighbors of vertex 100
            %
            % See also: bct.manifold.query.neighbors, adjacency
            
            arguments
                obj (1,1) bct.Manifold
                v (1,1) {mustBeInteger, mustBePositive}
            end
            
            A = obj.adjacency();
            idx = bct.manifold.query.neighbors(A, v);
        end
        
        function deg = degree(obj, varargin)
            %DEGREE Get degree of vertex or all vertices
            %
            % Syntax:
            %   deg = M.degree()
            %   deg = M.degree(v)
            %   deg = M.degree(v1, v2, ...)
            %
            % Inputs:
            %   v - Vertex index or indices (optional)
            %
            % Outputs:
            %   deg - Vertex degrees (scalar, vector, or full degree list)
            %
            % Description:
            %   Computes the degree (number of neighbors) for vertices.
            %   With no arguments, returns degrees for all vertices.
            %   With vertex indices, returns degrees for those vertices only.
            %   Uses cached adjacency matrix.
            %
            % Examples:
            %   M = bct.manifold.load();
            %   
            %   % Get all vertex degrees
            %   deg_all = M.degree();
            %   
            %   % Get degree of specific vertex
            %   deg_v = M.degree(100);
            %   
            %   % Get degrees of multiple vertices
            %   deg_verts = M.degree([10, 20, 30]);
            %
            % See also: bct.manifold.query.degree, neighbors, adjacency
            
            arguments
                obj (1,1) bct.Manifold
            end
            
            arguments (Repeating)
                varargin
            end
            
            A = obj.adjacency();
            deg = bct.manifold.query.degree(A, varargin{:});
        end
        
        function d = delta(obj, vertexIdx)
            %DELTA Create Dirac delta vector at specified vertex
            %
            % Syntax:
            %   d = M.delta(vertexIdx)
            %
            % Inputs:
            %   vertexIdx - Index of vertex where delta is 1 (scalar, 1-based)
            %
            % Outputs:
            %   d - [N×1] sparse column vector
            %       Value is 1 at vertexIdx, 0 elsewhere
            %
            % Description:
            %   Creates a Dirac delta function on the discrete manifold - a vector
            %   with value 1 at the specified vertex and 0 at all other vertices.
            %   This is useful for:
            %   - Point source initialization
            %   - Green's function computation
            %   - Testing operators at specific locations
            %   - Localized field generation
            %
            % Examples:
            %   M = bct.manifold.load();
            %   
            %   % Create delta at vertex 23
            %   d = M.delta(23);
            %   % d(23) = 1, all other entries are 0
            %   
            %   % Use as point source for heat equation
            %   ops = M.operators();
            %   result = ops.laplacebeltrami * d;
            %   
            %   % Create field with multiple sources
            %   sources = [10, 50, 100];
            %   field = M.delta(sources(1)) + M.delta(sources(2)) + M.delta(sources(3));
            %
            % See also: bct.manifold.query.delta
            
            arguments
                obj (1,1) bct.Manifold
                vertexIdx (1,1) {mustBeInteger, mustBePositive}
            end
            
            d = bct.manifold.query.delta(obj.numVertices(), vertexIdx);
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
        
        function obj = invalidateMetricDependentCaches(obj)
            %INVALIDATEMETRICDEPENDENTCACHES Clear caches that depend on vertex scale/units
            %
            % Syntax:
            %   M = M.invalidateMetricDependentCaches()
            %
            % Outputs:
            %   M - Manifold with cleared metric-dependent caches
            %
            % Description:
            %   Clears all cached data that depends on vertex coordinates with
            %   physical units. Called automatically by bct.manifold.metric.rescale.
            %
            %   Invalidates:
            %   - geometry: edge lengths, face areas, dual areas, centroids, etc.
            %   - operators: mass, stiffness, Laplacians, DEC operators
            %   - eigenmodes: spectral decompositions of metric-dependent operators
            %
            %   Does NOT invalidate:
            %   - topology: adjacency, edges, halfedge (combinatorial, scale-invariant)
            %   - health: mesh quality metrics (recomputed on demand)
            %
            % See also: bct.manifold.metric.rescale
            
            % Clear geometry-derived caches
            obj.Cache.geometry.data = struct();
            obj.Cache.geometry.meta = struct();
            
            % Clear operator-derived caches
            obj.Cache.operators.data = struct();
            obj.Cache.operators.meta = struct();
            
            % Clear spectral caches
            obj.Cache.eigenmodes.data = struct();
            obj.Cache.eigenmodes.meta = struct();
            
            % Topology remains valid (combinatorial structure)
            % Health will be recomputed on demand
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
            %   Eigen - Structure matching bct.manifold.eigen.schema:
            %           .attributes    - Group-level metadata
            %             .schema      - "bct.manifold.eigen@1.0.0"
            %             .package     - "bct.manifold.eigen"
            %             .numModes    - Number of modes (k)
            %             .numVertices - Number of vertices (N)
            %             .operator    - "Laplace-Beltrami"
            %             .basis       - "P1-FEM"
            %             .ordering    - "ascending"
            %             .massType    - Mass matrix type used
            %             .removedDC   - Whether DC mode was removed
            %           .values        - [k×1] eigenvalues (sorted ascending)
            %           .vectors       - [N×k] eigenvectors (M-orthonormal)
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
            %   k = E.attributes.numModes;
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
            %   % With unit annotations
            %   E = M.eigenmodes(100, 'annotate', true);
            %   E.values.unit   % '1/m^2' (Laplacian eigenvalues)
            %   E.vectors.unit  % '1' (normalized modes)
            %
            % See also: bct.manifold.eigenmodes, bct.manifold.eigen.schema
            p = inputParser;
            p.addOptional('k', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
            p.addParameter('RemoveDC', true, @islogical);
            p.addParameter('MassType', "voronoi", @(x) isstring(x) || ischar(x));
            p.addParameter('EigsOpts', struct(), @isstruct);
            p.addParameter('Force', false, @islogical);
            p.addParameter('annotate', false, @islogical);
            p.parse(varargin{:});
            
            k_requested = p.Results.k;
            removeDC = p.Results.RemoveDC;
            massType = string(p.Results.MassType);
            eigsOpts = p.Results.EigsOpts;
            force = p.Results.Force;
            annotate = p.Results.annotate;
            
            % Determine if we need to compute (early return if cached)
            if force
                % Forced recomputation
                if isempty(k_requested)
                    % Use cached k if available, otherwise default
                    if ~isempty(fieldnames(obj.Cache.eigenmodes.data)) && ...
                       isfield(obj.Cache.eigenmodes.data, 'attributes') && ...
                       isfield(obj.Cache.eigenmodes.data.attributes, 'numModes')
                        k_requested = double(obj.Cache.eigenmodes.data.attributes.numModes);
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
                % Apply annotation if requested
                if annotate
                    Eigen = bct.manifold.metric.annotate(Eigen, 'eigen');
                end
                return;
            end
            
            % Compute eigenmodes using bct.manifold.eigenmodes
            Eigen = bct.manifold.eigenmodes(...
                obj, k_requested, ...
                'RemoveDC', removeDC, ...
                'MassType', massType, ...
                'EigsOpts', eigsOpts);
            
            % Apply annotation if requested (before caching to keep cache numeric)
            if annotate
                Eigen = bct.manifold.metric.annotate(Eigen, 'eigen');
            end
            
            % Cache for future use (always cache schema-compliant version)
            if annotate
                % Store un-annotated version in cache (recompute to avoid annotated values)
                EigenNumeric = bct.manifold.eigenmodes(...
                    obj, k_requested, ...
                    'RemoveDC', removeDC, ...
                    'MassType', massType, ...
                    'EigsOpts', eigsOpts);
                obj.Cache.eigenmodes.data = EigenNumeric;
            else
                obj.Cache.eigenmodes.data = Eigen;
            end
            obj.Cache.eigenmodes.meta.computed = datetime('now');
            obj.Cache.eigenmodes.meta.numModes = Eigen.attributes.numModes;
            obj.Cache.eigenmodes.meta.massType = massType;
            obj.Cache.eigenmodes.meta.removedDC = removeDC;
        end
        
        function e = eigenvalues(obj)
            %EIGENVALUES Get eigenvalues from cached eigenmodes
            %
            % Syntax:
            %   e = M.eigenvalues()
            %
            % Outputs:
            %   e - [k×1] eigenvalues from cached eigenmodes
            %
            % Description:
            %   Returns the eigenvalues from the cached eigenmode structure.
            %   If eigenmodes are not cached, returns empty array.
            %
            % Examples:
            %   M.eigenmodes(100);
            %   e = M.eigenvalues();  % Returns cached eigenvalues
            %
            % See also: eigenmodes
            
            if isempty(fieldnames(obj.Cache.eigenmodes.data))
                e = [];
            else
                e = obj.Cache.eigenmodes.data.values;
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
        
        function Mflipped = flip(obj)
            %FLIP Create new Manifold with flipped face orientation (normals pointing outward)
            %
            % Syntax:
            %   Mflipped = M.flip()
            %
            % Outputs:
            %   Mflipped - New bct.Manifold object with corrected face orientation
            %
            % Description:
            %   Creates a new Manifold object with face orientation corrected to ensure
            %   normals point outward. Uses signed volume computation to detect if faces
            %   need flipping. If the signed volume is negative, all faces are flipped by
            %   swapping their second and third vertices.
            %
            %   This is a wrapper for bct.manifold.geometry.face.flip() that returns a
            %   new Manifold object rather than just the flipped faces. This is necessary
            %   because the Vertices and Faces properties are private.
            %
            %   The original Manifold object is not modified - a new object is created.
            %
            % Examples:
            %   % Check and correct face orientation
            %   M = bct.Manifold(V, F);
            %   Mflipped = M.flip();
            %
            %   % Check if faces were actually flipped
            %   [header, ~] = bct.manifold.geometry.face.flip(M);
            %   if header.flippedAllFaces
            %       disp('Faces needed flipping');
            %       M = M.flip();  % Update to corrected version
            %   end
            %
            %   % Verify normals point outward after flipping
            %   Mflipped = M.flip();
            %   [~, FN] = bct.manifold.geometry.face.normals(Mflipped);
            %   C = bct.manifold.geometry.face.centroids(Mflipped);
            %   % Face normals should point away from centroid of surface
            %
            % See also: bct.manifold.geometry.face.flip, bct.manifold.geometry.face.normals
            
            % Get flipped faces using the geometry function
            [~, Fflipped] = bct.manifold.geometry.face.flip(obj);
            
            % Create new Manifold with same vertices but flipped faces
            Mflipped = bct.Manifold(obj.Vertices, Fflipped);
        end
        
        function geom = geometry(obj, varargin)
            %GEOMETRY Compute and cache all geometric properties
            %
            % Syntax:
            %   geom = M.geometry()
            %   geom = M.geometry(Name, Value)
            %
            % Name-Value Arguments:
            %   'precision'          - 'double' (default) or 'single' for numeric precision
            %   'circumcenterMethod' - 'native' (default) or 'triangulation'
            %   'boundaryPolicy'     - 'error' (default) for dual measures with boundaries
            %   'dualCellType'       - 'circumcentric' (default) for dual vertex areas
            %   'annotate'           - false (default) or true to wrap outputs as quantity structs
            %   'Force'              - false (default) or true to force recomputation
            %
            % Outputs:
            %   geom - Structure matching bct.manifold.geometry.schema:
            %     .attributes - Group-level metadata (computation options)
            %     .face       - Face geometry (areas, centroids, normals, frame, cotan)
            %     .vertex     - Vertex geometry (normals, frame)
            %     .edge       - Edge geometry (lengths, weights_cotangent, weights_euclidean)
            %     .dual       - Dual mesh geometry (edgeLengths, vertexAreas)
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
            %   C = geom.face.centroids;    % [nF×3] Face centroids
            %   A = geom.face.areas;        % [nF×1] Face areas
            %   VN = geom.vertex.normals;   % [nV×3] Vertex normals
            %   L = geom.edge.lengths;      % [nE×1] Edge lengths
            %   
            %   % Force recomputation
            %   geom = M.geometry('Force', true);
            %   
            %   % Compute with single precision
            %   geom = M.geometry('precision', 'single');
            %
            % See also: bct.manifold.geometry, bct.manifold.geometry.face,
            %           bct.manifold.geometry.vertex, bct.manifold.geometry.edge
            
            % Parse inputs
            p = inputParser;
            p.FunctionName = 'bct.Manifold.geometry';
            addParameter(p, 'Force', false, @islogical);
            addParameter(p, 'precision', 'double', @(x) ischar(x) || isstring(x));
            addParameter(p, 'circumcenterMethod', 'native', @(x) ischar(x) || isstring(x));
            addParameter(p, 'boundaryPolicy', 'error', @(x) ischar(x) || isstring(x));
            addParameter(p, 'dualCellType', 'circumcentric', @(x) ischar(x) || isstring(x));
            addParameter(p, 'annotate', false, @islogical);
            parse(p, varargin{:});
            
            force = p.Results.Force;
            
            % Check if we have cached geometry and not forcing recomputation
            if ~force && ~isempty(fieldnames(obj.Cache.geometry.data))
                geom = obj.Cache.geometry.data;
                return;
            end
            
            % Compute all geometry using bct.manifold.geometry
            geom = bct.manifold.geometry(obj, ...
                'precision', p.Results.precision, ...
                'circumcenterMethod', p.Results.circumcenterMethod, ...
                'boundaryPolicy', p.Results.boundaryPolicy, ...
                'dualCellType', p.Results.dualCellType, ...
                'annotate', p.Results.annotate);
            
            % Cache the result
            obj.Cache.geometry.data = geom;
            obj.Cache.geometry.meta.computed = datetime('now');
            obj.Cache.geometry.meta.precision = p.Results.precision;
            obj.Cache.geometry.meta.circumcenterMethod = p.Results.circumcenterMethod;
        end
        
        function faceGeom = faceGeometry(obj, varargin)
            %FACEGEOMETRY Get or compute face-based geometry
            %
            % Syntax:
            %   faceGeom = M.faceGeometry()
            %   faceGeom = M.faceGeometry('Force', true)
            %
            % Name-Value Arguments:
            %   'Force'     - false (default) or true to force recomputation
            %   'precision' - 'double' (default) or 'single'
            %
            % Outputs:
            %   faceGeom - Structure with fields:
            %     .areas          - [nF×1] Face areas
            %     .centroids      - [nF×3] Face centroids (barycenters)
            %     .circumcenters  - [nF×3] Face circumcenters
            %     .normals        - [nF×3] Face normal vectors
            %     .cotan          - [nF×3] Cotangent weights per face vertex
            %     .tangent1       - [nF×3] First tangent vectors
            %     .tangent2       - [nF×3] Second tangent vectors
            %
            % Description:
            %   Returns cached face geometry if available, or computes using
            %   bct.manifold.geometry.face(). Result is cached in geometry
            %   namespace for future calls.
            %
            % Examples:
            %   M = bct.Manifold(V, F);
            %   faceGeom = M.faceGeometry();
            %   areas = faceGeom.areas;
            %   normals = faceGeom.normals;
            %
            % See also: bct.manifold.geometry.face, vertexGeometry, edgeGeometry
            
            p = inputParser;
            addParameter(p, 'Force', false, @islogical);
            addParameter(p, 'precision', 'double', @(x) ischar(x) || isstring(x));
            parse(p, varargin{:});
            
            force = p.Results.Force;
            
            % Check if cached
            if ~force && ~isempty(fieldnames(obj.Cache.geometry.data)) && ...
               isfield(obj.Cache.geometry.data, 'face')
                faceGeom = obj.Cache.geometry.data.face;
                return;
            end
            
            % Compute face geometry
            faceGeom = bct.manifold.geometry.face(obj, 'precision', p.Results.precision);
            
            % Cache the result
            if isempty(fieldnames(obj.Cache.geometry.data))
                obj.Cache.geometry.data = struct();
            end
            obj.Cache.geometry.data.face = faceGeom;
            obj.Cache.geometry.meta.faceComputed = datetime('now');
        end
        
        function vertexGeom = vertexGeometry(obj, varargin)
            %VERTEXGEOMETRY Get or compute vertex-based geometry
            %
            % Syntax:
            %   vertexGeom = M.vertexGeometry()
            %   vertexGeom = M.vertexGeometry('Force', true)
            %
            % Name-Value Arguments:
            %   'Force'     - false (default) or true to force recomputation
            %   'precision' - 'double' (default) or 'single'
            %
            % Outputs:
            %   vertexGeom - Structure with fields:
            %     .normals  - [nV×3] Vertex normal vectors
            %     .tangent1 - [nV×3] First tangent vectors
            %     .tangent2 - [nV×3] Second tangent vectors
            %
            % Description:
            %   Returns cached vertex geometry if available, or computes using
            %   bct.manifold.geometry.vertex(). Result is cached in geometry
            %   namespace for future calls.
            %
            % Examples:
            %   M = bct.Manifold(V, F);
            %   vertexGeom = M.vertexGeometry();
            %   normals = vertexGeom.normals;
            %
            % See also: bct.manifold.geometry.vertex, faceGeometry, edgeGeometry
            
            p = inputParser;
            addParameter(p, 'Force', false, @islogical);
            addParameter(p, 'precision', 'double', @(x) ischar(x) || isstring(x));
            parse(p, varargin{:});
            
            force = p.Results.Force;
            
            % Check if cached
            if ~force && ~isempty(fieldnames(obj.Cache.geometry.data)) && ...
               isfield(obj.Cache.geometry.data, 'vertex')
                vertexGeom = obj.Cache.geometry.data.vertex;
                return;
            end
            
            % Compute vertex geometry
            vertexGeom = bct.manifold.geometry.vertex(obj, 'precision', p.Results.precision);
            
            % Cache the result
            if isempty(fieldnames(obj.Cache.geometry.data))
                obj.Cache.geometry.data = struct();
            end
            obj.Cache.geometry.data.vertex = vertexGeom;
            obj.Cache.geometry.meta.vertexComputed = datetime('now');
        end
        
        function edgeGeom = edgeGeometry(obj, varargin)
            %EDGEGEOMETRY Get or compute edge-based geometry
            %
            % Syntax:
            %   edgeGeom = M.edgeGeometry()
            %   edgeGeom = M.edgeGeometry('Force', true)
            %
            % Name-Value Arguments:
            %   'Force'     - false (default) or true to force recomputation
            %   'precision' - 'double' (default) or 'single'
            %
            % Outputs:
            %   edgeGeom - Structure with fields:
            %     .lengths - [nE×1] Edge lengths
            %     .weights - Structure with .cotangent and .euclidean
            %
            % Description:
            %   Returns cached edge geometry if available, or computes using
            %   bct.manifold.geometry.edge(). Result is cached in geometry
            %   namespace for future calls.
            %
            % Examples:
            %   M = bct.Manifold(V, F);
            %   edgeGeom = M.edgeGeometry();
            %   lengths = edgeGeom.lengths;
            %
            % See also: bct.manifold.geometry.edge, faceGeometry, vertexGeometry
            
            p = inputParser;
            addParameter(p, 'Force', false, @islogical);
            addParameter(p, 'precision', 'double', @(x) ischar(x) || isstring(x));
            parse(p, varargin{:});
            
            force = p.Results.Force;
            
            % Check if cached
            if ~force && ~isempty(fieldnames(obj.Cache.geometry.data)) && ...
               isfield(obj.Cache.geometry.data, 'edge')
                edgeGeom = obj.Cache.geometry.data.edge;
                return;
            end
            
            % Compute edge geometry
            edgeGeom = bct.manifold.geometry.edge(obj, 'precision', p.Results.precision);
            
            % Cache the result
            if isempty(fieldnames(obj.Cache.geometry.data))
                obj.Cache.geometry.data = struct();
            end
            obj.Cache.geometry.data.edge = edgeGeom;
            obj.Cache.geometry.meta.edgeComputed = datetime('now');
        end
        
        function dualGeom = dualGeometry(obj, varargin)
            %DUALGEOMETRY Get or compute dual mesh geometry
            %
            % Syntax:
            %   dualGeom = M.dualGeometry()
            %   dualGeom = M.dualGeometry('Force', true)
            %
            % Name-Value Arguments:
            %   'Force'          - false (default) or true to force recomputation
            %   'precision'      - 'double' (default) or 'single'
            %   'boundaryPolicy' - 'error' (default) for boundary handling
            %   'dualCellType'   - 'circumcentric' (default) for dual vertex areas
            %
            % Outputs:
            %   dualGeom - Structure with fields:
            %     .edgeLengths - [nE×1] Dual edge lengths
            %     .vertexAreas - [nV×1] Dual vertex areas (Voronoi cells)
            %
            % Description:
            %   Returns cached dual geometry if available, or computes using
            %   bct.manifold.geometry.dual(). Result is cached in geometry
            %   namespace for future calls.
            %
            %   Dual geometry requires closed mesh (no boundary edges).
            %
            % Examples:
            %   M = bct.Manifold(V, F);
            %   dualGeom = M.dualGeometry();
            %   dualEdges = dualGeom.edgeLengths;
            %   voronoiAreas = dualGeom.vertexAreas;
            %
            % See also: bct.manifold.geometry.dual, faceGeometry, edgeGeometry
            
            p = inputParser;
            addParameter(p, 'Force', false, @islogical);
            addParameter(p, 'precision', 'double', @(x) ischar(x) || isstring(x));
            addParameter(p, 'boundaryPolicy', 'error', @(x) ischar(x) || isstring(x));
            addParameter(p, 'dualCellType', 'circumcentric', @(x) ischar(x) || isstring(x));
            parse(p, varargin{:});
            
            force = p.Results.Force;
            
            % Check if cached
            if ~force && ~isempty(fieldnames(obj.Cache.geometry.data)) && ...
               isfield(obj.Cache.geometry.data, 'dual')
                dualGeom = obj.Cache.geometry.data.dual;
                return;
            end
            
            % Compute dual geometry
            dualGeom = bct.manifold.geometry.dual(obj, ...
                'precision', p.Results.precision, ...
                'boundaryPolicy', p.Results.boundaryPolicy, ...
                'dualCellType', p.Results.dualCellType);
            
            % Cache the result
            if isempty(fieldnames(obj.Cache.geometry.data))
                obj.Cache.geometry.data = struct();
            end
            obj.Cache.geometry.data.dual = dualGeom;
            obj.Cache.geometry.meta.dualComputed = datetime('now');
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
            %   topo - Structure matching bct.manifold.topology.schema:
            %     .attributes      - Group-level metadata (numVertices, numFaces, numHalfedges)
            %     .tailVertex      - [nH×1 uint32] Tail vertex indices
            %     .headVertex      - [nH×1 uint32] Head vertex indices
            %     .face            - [nH×1 uint32] Incident face indices
            %     .next            - [nH×1 uint32] Next halfedge (CCW)
            %     .prev            - [nH×1 uint32] Previous halfedge (CCW)
            %     .twin            - [nH×1 uint32] Twin halfedge (0 if boundary)
            %     .edge            - [nH×1 uint32] Undirected edge indices
            %     .isBoundary      - [nH×1 logical] Boundary flags
            %     .edgeList        - [nE×2 uint32] Undirected edge list
            %     .faceHalfedges   - [nF×3 uint32] Halfedge indices per face
            %     .faceNeighbors   - [nF×3 int32] Adjacent face indices
            %     .neighborEdge    - [nF×3 uint8] Local edge index in neighbors
            %     .adjacency       - [nV×nV sparse logical] Adjacency matrix
            %
            % Description:
            %   Computes all topological properties of the manifold and caches
            %   the result for future calls. Output conforms to 
            %   bct.manifold.topology.schema for HDF5/Zarr serialization.
            %
            %   Topology is coordinate-free and depends only on face
            %   connectivity. The structure IS a halfedge structure with all
            %   navigation fields at the top level. On first call, computes all
            %   topology. Subsequent calls return cached result unless 'Force' is true.
            %
            % Examples:
            %   % Compute and cache all topology
            %   M = bct.Manifold(V, F);
            %   topo = M.topology();
            %   
            %   % Access halfedge navigation (flattened structure)
            %   h = topo.faceHalfedges(1, 1);  % First halfedge of face 1
            %   h_next = topo.next(h);          % Next halfedge (CCW)
            %   h_twin = topo.twin(h);          % Twin across edge
            %   
            %   % Access edges and adjacency
            %   E = topo.edgeList;              % [nE×2] edge list
            %   A = topo.adjacency;             % [nV×nV] adjacency matrix
            %   
            %   % Force recomputation
            %   topo = M.topology('Force', true);
            %
            % See also: bct.manifold.topology, bct.manifold.topology.schema, geometry
            
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
        
        function he = halfedge(obj, varargin)
            %HALFEDGE Get or compute halfedge data structure
            %
            % Syntax:
            %   he = M.halfedge()
            %   he = M.halfedge('Force', true)
            %
            % Name-Value Arguments:
            %   'Force' - false (default) or true to force recomputation
            %
            % Outputs:
            %   he - Halfedge data structure (convenience, not schema-compliant):
            %        .numVertices    - Number of vertices
            %        .numFaces       - Number of faces
            %        .numHalfedges   - Number of halfedges
            %        .tailVertex     - [nH×1] Tail vertex indices
            %        .headVertex     - [nH×1] Head vertex indices
            %        .next           - [nH×1] Next halfedge in face
            %        .prev           - [nH×1] Previous halfedge in face
            %        .twin           - [nH×1] Opposite halfedge
            %        .face           - [nH×1] Face containing halfedge
            %        .edge           - [nH×1] Edge index for halfedge
            %        .isBoundary     - [nH×1] Logical array for boundary halfedges
            %        .edgeList       - [nE×2] Unique edge list
            %        .faceHalfedges  - [nF×3] Halfedge indices per face
            %        .faceNeighbors  - [nF×3] Adjacent face indices
            %        .neighborEdge   - [nF×3] Local edge in neighbor
            %
            % Description:
            %   Returns a convenience halfedge structure (without adjacency).
            %   This is cached separately from topology for algorithms that
            %   only need halfedge navigation without adjacency matrix.
            %
            %   For schema-compliant topology (includes adjacency), use
            %   M.topology() instead.
            %
            % Examples:
            %   % Get halfedge structure
            %   M = bct.Manifold(V, F);
            %   he = M.halfedge();
            %   
            %   % Navigate mesh
            %   h = he.faceHalfedges(1, 1);  % First halfedge of face 1
            %   next_h = he.next(h);
            %   twin_h = he.twin(h);
            %   
            %   % Get edge list
            %   E = he.edgeList;
            %   
            %   % Force recomputation
            %   he = M.halfedge('Force', true);
            %
            % See also: bct.manifold.topology.halfedge, topology
            
            % Parse inputs
            p = inputParser;
            p.FunctionName = 'bct.Manifold.halfedge';
            addParameter(p, 'Force', false, @islogical);
            parse(p, varargin{:});
            
            force = p.Results.Force;
            
            % Check if halfedge is cached
            if ~force && ~isempty(fieldnames(obj.Cache.halfedge.data))
                he = obj.Cache.halfedge.data;
                return;
            end
            
            % Compute halfedge using bct.manifold.topology.halfedge
            he = bct.manifold.topology.halfedge(obj.Vertices, obj.Faces);
            
            % Cache the result
            obj.Cache.halfedge.data = he;
            obj.Cache.halfedge.meta.computed = datetime('now');
        end
        
        function h = health(obj, varargin)
            %HEALTH Get or compute mesh health check (lazy creation with caching)
            %
            % Syntax:
            %   h = M.health()
            %   h = M.health(Name, Value)
            %
            % Optional Parameters:
            %   Level             - "quick" | "standard" (default) | "full"
            %                       * quick: topology (faces, degeneracy, edges, boundary)
            %                       * standard: quick + orientation + directed duplicates
            %                       * full: standard + vertex manifoldness + outward
            %   RequireManifold   - logical, error on non-manifold edges (default: true)
            %   RequireOriented   - logical, error on orientation inconsistency (default: true)
            %   RequireClosed     - logical, error on boundary edges (default: false)
            %   FailOnWarnings    - logical, set ok=false for warnings (default: false)
            %   Verbose           - logical, store canonical E and index sets in h.data (default: false)
            %   Force             - false (default) or true to force recomputation
            %
            % Outputs:
            %   h - Health check report structure with fields:
            %     .ok          - logical, overall pass/fail
            %     .severity    - "ok" | "warn" | "error"
            %     .scope       - "bct.manifold.health"
            %     .level       - check level performed
            %     .summary     - string array of high-level messages
            %     .issues      - struct array of detected issues
            %     .is          - canonical boolean flags (NEW):
            %                    .facesValid, .facesNondegenerate, .hasDuplicateFaces,
            %                    .hasDuplicateDirectedEdges, .edgeManifold, .hasBoundary,
            %                    .oriented, .vertexManifold, .outward
            %     .stats       - mesh statistics (nV, nF, nE, nBoundaryEdges, etc.)
            %     .statsByCheck- detailed stats grouped by check
            %     .timing      - performance timers
            %     .data        - optional cached data (canonical E indices if Verbose)
            %
            % Description:
            %   Performs comprehensive mesh health validation using modular architecture
            %   and caches the result. First call computes health check, subsequent
            %   calls return cached result unless 'Force' is true.
            %
            %   All edge-indexed outputs (boundary, non-manifold, inconsistent) refer
            %   to indices in M.Edges (canonical edge list).
            %
            %   New h.is flags provide direct boolean access to mesh state for gating
            %   DEC operators and other analysis.
            %
            % Examples:
            %   % Quick DEC gating check
            %   M = bct.Manifold(V, F);
            %   h = M.health('Level', 'quick');
            %   assert(h.is.facesValid && h.is.edgeManifold && h.is.oriented);
            %
            %   % Standard check (cached)
            %   h = M.health();  % First call computes
            %   h = M.health();  % Second call returns cached
            %
            %   % Force recomputation
            %   h = M.health('Force', true);
            %
            %   % Check for DEC compatibility
            %   h = M.health('RequireManifold', true, 'RequireOriented', true);
            %   if h.is.hasBoundary
            %       fprintf('Mesh has %d boundary edges\n', h.stats.nBoundaryEdges);
            %   end
            %
            %   % Access canonical edge indices (with Verbose)
            %   h = M.health('Verbose', true);
            %   if h.is.hasBoundary
            %       boundaryEdges = M.Edges(h.data.boundaryEdges.boundaryEdgeIdx, :);
            %   end
            %
            %   % View formatted report
            %   disp(bct.manifold.health.report(h));
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
            addParameter(p, 'Verbose', false, @islogical);
            parse(p, varargin{:});
            
            force = p.Results.Force;
            level = string(p.Results.Level);
            
            % Check if we have cached health report and not forcing recomputation
            if ~force && ~isempty(fieldnames(obj.Cache.health.data))
                h = obj.Cache.health.data;
                return;
            end
            
            % Compute health check using bct.manifold.health.check
            h = bct.manifold.health.check(obj, ...
                'Level', level, ...
                'RequireManifold', p.Results.RequireManifold, ...
                'RequireOriented', p.Results.RequireOriented, ...
                'RequireClosed', p.Results.RequireClosed, ...
                'FailOnWarnings', p.Results.FailOnWarnings, ...
                'Verbose', p.Results.Verbose);
            
            % Cache the result
            obj.Cache.health.data = h;
            obj.Cache.health.meta.computed = datetime('now');
            obj.Cache.health.meta.level = level;
            obj.Cache.health.meta.requireManifold = p.Results.RequireManifold;
            obj.Cache.health.meta.requireOriented = p.Results.RequireOriented;
            obj.Cache.health.meta.requireClosed = p.Results.RequireClosed;
        end
        
        function M_repaired = repair(obj)
            %REPAIR Automatically repair all detected mesh defects
            %
            % Syntax:
            %   M_repaired = M.repair()
            %
            % Outputs:
            %   M_repaired - New Manifold with defects repaired
            %
            % Description:
            %   Convenience method that runs health check and automatically
            %   applies repairs for all detected issues. Equivalent to:
            %   
            %   h = M.health();
            %   M_repaired = bct.manifold.health.repair(M, h);
            %
            %   Repairs applied (in optimal order):
            %   - duplicate-vertices
            %   - unreferenced-vertices  
            %   - duplicate-faces
            %   - degenerate-faces
            %   - nonmanifold-edges
            %
            % Examples:
            %   % Quick repair
            %   M_clean = M.repair();
            %
            %   % Check what was fixed
            %   h_before = M.health();
            %   M_clean = M.repair();
            %   h_after = M_clean.health();
            %
            % See also: bct.Manifold.health, bct.manifold.health.repair
            
            % Get health report
            h = obj.health();
            
            % Apply repairs via bct.manifold.health.repair
            M_repaired = bct.manifold.health.repair(obj, h);
        end
        
        function M_scaled = rescale(obj, varargin)
            %RESCALE Rescale manifold vertices from source unit to meters
            %
            % Syntax:
            %   M_scaled = M.rescale('From', unit)
            %   M_scaled = M.rescale('Factor', scaleFactor)
            %
            % Inputs:
            %   unit        - Source unit: "m" | "cm" | "mm" | "um" | "nm"
            %   scaleFactor - Direct scaling factor
            %
            % Outputs:
            %   M_scaled - New Manifold with rescaled vertices
            %
            % Examples:
            %   % Anatomical data in millimeters
            %   M = bct.Manifold(anat.Vertices, anat.Faces);
            %   M = M.rescale('From', 'mm');
            %
            %   % Direct scaling
            %   M = M.rescale('Factor', 0.001);
            %
            % See also: bct.manifold.metric.rescale
            
            % Delegate to bct.manifold.metric.rescale
            M_scaled = bct.manifold.metric.rescale(obj, varargin{:});
        end
        
        function result = components(obj)
            %COMPONENTS Get connected component vertex indices
            %
            % Syntax:
            %   result = M.components()
            %
            % Outputs:
            %   result - 'connected' if single component, or cell array of
            %            vertex index vectors for each component
            %
            % Description:
            %   Detects disconnected components and returns vertex indices
            %   for each component. If manifold is connected (single component),
            %   returns the string 'connected'.
            %
            % Examples:
            %   result = M.components();
            %   if ischar(result)
            %       fprintf('Manifold is connected\n');
            %   else
            %       fprintf('Found %d components\n', length(result));
            %       for i = 1:length(result)
            %           fprintf('  Component %d: %d vertices\n', ...
            %               i, length(result{i}));
            %       end
            %   end
            %
            % See also: bct.Manifold.split, bct.manifold.health.check.connectivity
            
            % Run connectivity check with verbose to get component indices
            h = obj.health('Verbose', true);
            
            if h.is.connected
                result = 'connected';
            else
                % Return component vertex indices
                if isfield(h.data, 'connectivity') && ...
                   isfield(h.data.connectivity, 'components')
                    result = h.data.connectivity.components;
                else
                    % Fallback if data not available
                    result = 'connected';
                end
            end
        end
        
        function manifolds = split(obj)
            %SPLIT Split disconnected manifold into component manifolds
            %
            % Syntax:
            %   manifolds = M.split()
            %
            % Outputs:
            %   manifolds - Cell array of Manifold objects (one per component)
            %
            % Description:
            %   Detects disconnected components and returns each as a separate
            %   Manifold object with compacted vertex indices.
            %   
            %   If already connected, returns {M} (cell array with original).
            %   
            %   Components are sorted by size (largest first).
            %
            % Examples:
            %   % Split disconnected mesh
            %   manifolds = M.split();
            %   if length(manifolds) > 1
            %       fprintf('Split into %d components\n', length(manifolds));
            %       M1 = manifolds{1};  % Largest component
            %       M2 = manifolds{2};  % Second largest
            %   end
            %
            % See also: bct.Manifold.components, 
            %           bct.manifold.health.repair.splitComponents
            
            % Get component indices
            comp = obj.components();
            
            % If connected, return original as cell array
            if ischar(comp) && strcmp(comp, 'connected')
                manifolds = {obj};
                return;
            end
            
            % Multiple components - use splitComponents function
            manifolds = bct.manifold.health.repair.splitComponents(obj);
        end
        
        function components = splitComponents(obj, varargin)
            %SPLITCOMPONENTS Split disconnected components into separate manifolds
            %
            % Syntax:
            %   components = M.splitComponents()
            %   components = M.splitComponents('MinSize', n)
            %
            % Outputs:
            %   components - Cell array of Manifold objects
            %
            % Description:
            %   Automatically detects disconnected components and returns
            %   each as a separate Manifold (sorted by size, largest first).
            %
            % Examples:
            %   % Split and analyze each component
            %   comps = M.splitComponents();
            %   for i = 1:length(comps)
            %       fprintf('Component %d: %d vertices\n', ...
            %           i, comps{i}.numVertices);
            %   end
            %
            %   % Keep only large components
            %   comps = M.splitComponents('MinSize', 100);
            %
            % See also: bct.manifold.health.repair.splitComponents
            
            % Delegate to repair function
            components = bct.manifold.health.repair.splitComponents(obj, varargin{:});
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
            
            % Get full absolute path for Source metadata
            fileInfo = dir(fileName);
            if ~isempty(fileInfo)
                fullPath = fullfile(fileInfo.folder, fileInfo.name);
            else
                fullPath = fileName;  % Fallback to provided path
            end
            
            % Extract filename without extension for Name
            [~, baseName, ~] = fileparts(fileName);
            
            % Set Source and Name metadata
            obj = obj.setHeader('Name', string(baseName), ...
                               'Source', string(fullPath), ...
                               'CreatedAt', datetime('now'), ...
                               'CreatedBy', getenv('USERNAME'));
        end
    end
    
    % ===================================================================
    % METADATA MANAGEMENT
    % ===================================================================
    methods
        function obj = setHeader(obj, varargin)
            %SETHEADER Set or update Header metadata fields
            %
            % Syntax:
            %   M = M.setHeader('FieldName', value, ...)
            %
            % Description:
            %   Updates Header metadata with name-value pairs. Values are
            %   normalized according to the schema specification.
            %
            % Supported Fields:
            %   Rendering/Interoperability:
            %     IndexBase        - 0 (JavaScript/Python) or 1 (MATLAB)
            %     FaceWinding      - "CCW" (counter-clockwise) or "CW"
            %     NormalConvention - "right-hand-rule" or "left-hand-rule"
            %     CoordinateSystem - "RAS", "LPS", or "unknown"
            %     Units            - Physical units (e.g., 'mm', 'm')
            %   
            %   Provenance:
            %     Name      - Semantic identifier (e.g., filename without extension)
            %     Source    - Data source (file path, URL, description)
            %     CreatedAt - Timestamp (datetime or string)
            %     CreatedBy - User or process identifier
            %     BctVersion - Toolbox version string
            %     GitCommit  - Git commit hash
            %
            % Examples:
            %   % Set provenance metadata
            %   M = M.setHeader('Source', 'bunny.obj', ...
            %                   'CreatedAt', datetime('now'), ...
            %                   'CreatedBy', 'user123');
            %
            %   % Set rendering metadata
            %   M = M.setHeader('FaceWinding', 'CCW', ...
            %                   'CoordinateSystem', 'RAS', ...
            %                   'Units', 'mm');
            %
            %   % Update single field
            %   M = M.setHeader('Source', 'new_source.mat');
            %
            % See also: bct.manifold.schema.manifold, bct.manifold.schema.normalize
            
            % Parse name-value pairs
            if mod(numel(varargin), 2) ~= 0
                error('bct:Manifold:InvalidArguments', ...
                    'setHeader requires name-value pairs.');
            end
            
            % Get schema for metadata section
            spec = bct.manifold.schema.manifold();
            
            % Update Header fields with normalization
            for i = 1:2:numel(varargin)
                fieldName = varargin{i};
                value = varargin{i+1};
                
                % Validate field exists in schema
                if ~isfield(spec.meta.fields, fieldName)
                    warning('bct:Manifold:UnknownField', ...
                        'Field "%s" is not defined in schema. Setting anyway.', fieldName);
                    obj.Header.(fieldName) = value;
                    continue;
                end
                
                % Get field spec and normalize value
                fieldSpec = spec.meta.fields.(fieldName);
                if isfield(fieldSpec, 'normalize') && isa(fieldSpec.normalize, 'function_handle')
                    try
                        normalizedValue = fieldSpec.normalize(value);
                        obj.Header.(fieldName) = normalizedValue;
                    catch ME
                        warning('bct:Manifold:NormalizeFailed', ...
                            'Failed to normalize field "%s": %s. Using raw value.', ...
                            fieldName, ME.message);
                        obj.Header.(fieldName) = value;
                    end
                else
                    obj.Header.(fieldName) = value;
                end
            end
        end
    end
    
    methods (Static, Access = private)
        function header = buildDefaultHeaderStatic()
            %BUILDDEFAULTHEADER Initialize Header with default values from schema
            %
            % Returns a struct with default values for all metadata fields.
            % Provenance fields are left empty, rendering fields get defaults.
            
            % Get schema
            spec = bct.manifold.schema.manifold();
            
            % Initialize empty header
            header = struct();
            
            % Apply defaults from schema
            fieldNames = fieldnames(spec.meta.fields);
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                fieldSpec = spec.meta.fields.(fieldName);
                
                % Only set defaults for rendering/interoperability fields
                % Leave provenance fields empty
                provenanceFields = ["Name", "Source", "CreatedAt", "CreatedBy", "BctVersion", "GitCommit"];
                
                if isfield(fieldSpec, 'default') && ~ismember(fieldName, provenanceFields)
                    header.(fieldName) = fieldSpec.default;
                end
            end
            
            % Generate unique ID for this manifold
            header.ID = string(java.util.UUID.randomUUID());
            
            % Initialize metric provenance (all manifolds are in meters by default)
            header.Metric = struct( ...
                'unit', "m", ...
                'rescale', struct( ...
                    'applied', false, ...
                    'fromUnit', "", ...
                    'factor', 1.0, ...
                    'timestamp', "") );
        end
    end
    
    % ===================================================================
    % INDIVIDUAL OPERATOR WRAPPERS (Modular Caching)
    % ===================================================================
    methods
        function op = mass(obj, varargin)
            %MASS Get or compute mass matrix (modular caching)
            %
            % Syntax:
            %   M = obj.mass()
            %   M = obj.mass('variant', 'voronoi')
            %
            % Outputs:
            %   M - Mass matrix dataset structure with:
            %       .value - [N×N sparse double] Mass matrix
            %       .attributes - Dataset-level metadata
            %
            % Description:
            %   Computes and caches the mass matrix operator. Returns the
            %   schema-compliant dataset structure. For backward compatibility,
            %   access the matrix via M.value.
            %
            % See also: bct.manifold.operator.mass, operators
            
            % Check if mass is already in cache
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'mass')
                op = obj.Cache.operators.data.mass;
                return;
            end
            
            % Compute mass matrix (returns structure with .value and .attributes)
            op = bct.manifold.operator.mass(obj, varargin{:});
            
            % Cache the result
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.mass = op;
        end
        
        function op = stiffness(obj, varargin)
            %STIFFNESS Get or compute stiffness matrix (modular caching)
            %
            % Syntax:
            %   K = obj.stiffness()
            %   K = obj.stiffness('variant', 'cotan')
            %
            % Outputs:
            %   K - Stiffness matrix dataset structure with:
            %       .value - [N×N sparse double] Stiffness matrix
            %       .attributes - Dataset-level metadata
            %
            % Description:
            %   Computes and caches the stiffness matrix operator. Returns the
            %   schema-compliant dataset structure. For backward compatibility,
            %   access the matrix via K.value.
            %
            % See also: bct.manifold.operator.stiffness, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'stiffness')
                op = obj.Cache.operators.data.stiffness;
                return;
            end
            
            % Compute stiffness matrix (returns structure with .value and .attributes)
            op = bct.manifold.operator.stiffness(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.stiffness = op;
        end
        
        function [header, op] = laplacebeltrami(obj, varargin)
            %LAPLACEBELTRAMI Get or compute Laplace-Beltrami operator (modular caching)
            %
            % Syntax:
            %   [header, L] = obj.laplacebeltrami()
            %
            % Description:
            %   Computes and caches the Laplace-Beltrami operator.
            %
            % See also: bct.manifold.operator.laplacebeltrami, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'laplacebeltrami')
                op = obj.Cache.operators.data.laplacebeltrami;
                if nargout > 1
                    header = struct('source', 'cache');
                end
                return;
            end
            
            [header, op] = bct.manifold.operator.laplacebeltrami(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.laplacebeltrami = op;
        end
        
        function [header, op] = graphlaplacian(obj, varargin)
            %GRAPHLAPLACIAN Get or compute graph Laplacian (modular caching)
            %
            % Syntax:
            %   [header, L] = obj.graphlaplacian()
            %
            % Description:
            %   Computes and caches the graph Laplacian operator.
            %
            % See also: bct.manifold.operator.graphlaplacian, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'graphlaplacian')
                op = obj.Cache.operators.data.graphlaplacian;
                if nargout > 1
                    header = struct('source', 'cache');
                end
                return;
            end
            
            [header, op] = bct.manifold.operator.graphlaplacian(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.graphlaplacian = op;
        end
        
        function [header, op] = gradient(obj, varargin)
            %GRADIENT Get or compute gradient operator (modular caching)
            %
            % Syntax:
            %   [header, grad] = obj.gradient()
            %
            % Description:
            %   Computes and caches the gradient operator and its metadata.
            %   Both the operator matrix and header information are cached
            %   for consistent output on subsequent calls.
            %
            % See also: bct.manifold.operator.gradient, operators
            
            % Check if gradient is already cached
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'gradient')
                cached = obj.Cache.operators.data.gradient;
                op = cached.op;
                if nargout > 1
                    header = cached.header;
                end
                return;
            end
            
            % Compute gradient operator
            % First ensure DEC operators exist (must compute all together)
            if isempty(fieldnames(obj.Cache.operators.data)) || ...
               ~isfield(obj.Cache.operators.data, 'd0') || ...
               ~isfield(obj.Cache.operators.data, 'sharpPD')
                % Compute all DEC operators (cannot compute individually)
                obj.dec();
            end
            
            [header, op] = bct.manifold.operator.gradient(obj, varargin{:});
            
            % Cache both operator and header
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.gradient = struct('op', op, 'header', header);
        end
        
        function [header, op] = divergence(obj, varargin)
            %DIVERGENCE Get or compute divergence operator (modular caching)
            %
            % Syntax:
            %   [header, div] = obj.divergence()
            %
            % Description:
            %   Computes and caches the divergence operator.
            %
            % See also: bct.manifold.operator.divergence, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'divergence')
                op = obj.Cache.operators.data.divergence;
                if nargout > 1
                    header = struct('source', 'cache');
                end
                return;
            end
            
            % Ensure DEC operators exist (must compute all together)
            if isempty(fieldnames(obj.Cache.operators.data)) || ...
               ~isfield(obj.Cache.operators.data, 'dd1') || ...
               ~isfield(obj.Cache.operators.data, 'hd1') || ...
               ~isfield(obj.Cache.operators.data, 'hdd2')
                % Compute all DEC operators (cannot compute individually)
                obj.dec();
            end
            
            [header, op] = bct.manifold.operator.divergence(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.divergence = op;
        end
        
        function [header, op] = curl(obj, varargin)
            %CURL Get or compute curl operator (modular caching)
            %
            % Syntax:
            %   [header, curl] = obj.curl()
            %
            % Description:
            %   Computes and caches the curl operator.
            %
            % See also: bct.manifold.operator.curl, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'curl')
                op = obj.Cache.operators.data.curl;
                if nargout > 1
                    header = struct('source', 'cache');
                end
                return;
            end
            
            % Ensure DEC operators exist (must compute all together)
            if isempty(fieldnames(obj.Cache.operators.data)) || ...
               ~isfield(obj.Cache.operators.data, 'd1') || ...
               ~isfield(obj.Cache.operators.data, 'hd2')
                % Compute all DEC operators (cannot compute individually)
                obj.dec();
            end
            
            [header, op] = bct.manifold.operator.curl(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.curl = op;
        end
        
        function [header, op] = hodgelaplacian(obj, varargin)
            %HODGELAPLACIAN Get or compute Hodge Laplacian operators (modular caching)
            %
            % Syntax:
            %   [header, hodgeLap] = obj.hodgelaplacian()
            %
            % Description:
            %   Computes and caches the Hodge Laplacian operators (struct).
            %   Ensures DEC operators are available before computation.
            %
            % See also: bct.manifold.operator.hodgelaplacian, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'hodgelaplacian')
                op = obj.Cache.operators.data.hodgelaplacian;
                if nargout > 1
                    header = struct('source', 'cache');
                end
                return;
            end
            
            % Ensure DEC operators exist (must compute all together)
            if isempty(fieldnames(obj.Cache.operators.data)) || ...
               ~isfield(obj.Cache.operators.data, 'd0') || ...
               ~isfield(obj.Cache.operators.data, 'd1') || ...
               ~isfield(obj.Cache.operators.data, 'dd0') || ...
               ~isfield(obj.Cache.operators.data, 'dd1')
                % Compute all DEC operators (cannot compute individually)
                obj.dec();
            end
            
            [header, op] = bct.manifold.operator.hodgelaplacian(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.hodgelaplacian = op;
        end
        
        function decOps = dec(obj, varargin)
            %DEC Get or compute all DEC operators (modular caching)
            %
            % Syntax:
            %   decOps = obj.dec()
            %
            % Description:
            %   Computes and caches all 14 DEC operators from DiscreteExteriorCalculus.
            %   Returns the complete DEC operator group structure with schema-compliant
            %   datasets. Each operator has .value and .attributes fields.
            %
            %   All DEC operators are computed together (cannot compute individually)
            %   because they come from the external DiscreteExteriorCalculus object.
            %   This method caches the entire DEC structure.
            %
            % See also: bct.manifold.operator.dec, operators
            
            % Check if DEC operators are already cached
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'dec')
                decOps = obj.Cache.operators.data.dec;
                return;
            end
            
            % Compute all DEC operators (returns schema-compliant structure)
            decOps = bct.manifold.operator.dec(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            
            % Cache the entire DEC structure
            obj.Cache.operators.data.dec = decOps;
        end
        
        function [header, op] = mft(obj, varargin)
            %MFT Get or compute forward manifold Fourier transform operator (modular caching)
            %
            % Syntax:
            %   [header, mft] = obj.mft()
            %
            % Description:
            %   Computes and caches the MFT operator.
            %
            % See also: bct.manifold.operator.mft, imft, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'mft')
                op = obj.Cache.operators.data.mft;
                if nargout > 1
                    header = struct('source', 'cache');
                end
                return;
            end
            
            [header, op] = bct.manifold.operator.mft(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.mft = op;
        end
        
        function [header, op] = imft(obj, varargin)
            %IMFT Get or compute inverse manifold Fourier transform operator (modular caching)
            %
            % Syntax:
            %   [header, imft] = obj.imft()
            %
            % Description:
            %   Computes and caches the IMFT operator.
            %
            % See also: bct.manifold.operator.imft, mft, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'imft')
                op = obj.Cache.operators.data.imft;
                if nargout > 1
                    header = struct('source', 'cache');
                end
                return;
            end
            
            [header, op] = bct.manifold.operator.imft(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.imft = op;
        end
        
        function localizedField = localize(obj, filterSpec, vertexIdx, varargin)
            %LOCALIZE Localize a spectral filter to a vertex (not cached)
            %
            % Syntax:
            %   localField = obj.localize(filterSpec, vertexIdx)
            %   localField = obj.localize(filterSpec, vertexIdx, 'OutputFormat', 'cell')
            %
            % Inputs:
            %   filterSpec  - Filter struct from bct.filter.design
            %   vertexIdx   - Vertex index for localization
            %
            % Description:
            %   Direct wrapper for bct.manifold.operator.localize.
            %   Does not cache results as output depends on filter parameters.
            %
            % See also: bct.manifold.operator.localize, modulate
            
            localizedField = bct.manifold.operator.localize(obj, vertexIdx, filterSpec, varargin{:});
        end
        
        function modulatedSignal = modulate(obj, signal, eigenmodeSpec, varargin)
            %MODULATE Modulate a signal by an eigenmode (not cached)
            %
            % Syntax:
            %   modulated = obj.modulate(signal, k)
            %   modulated = obj.modulate(signal, eigenvector)
            %   modulated = obj.modulate(signal, k, 'NormalizationScale', scale)
            %
            % Inputs:
            %   signal        - [N×T] vertex-domain signal
            %   eigenmodeSpec - Eigenmode index k or [N×1] eigenvector
            %
            % Description:
            %   Direct wrapper for bct.manifold.operator.modulate.
            %   Does not cache results as output depends on input signal.
            %
            % See also: bct.manifold.operator.modulate, localize
            
            modulatedSignal = bct.manifold.operator.modulate(obj, signal, eigenmodeSpec, varargin{:});
        end
    end
end
