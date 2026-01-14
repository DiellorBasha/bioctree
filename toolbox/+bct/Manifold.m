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
        ID               % Unique identifier for compatibility tracking
        Metric           % Metric provenance (unit, rescale status)
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
            
            % Initialize metric provenance (all manifolds are in meters by default)
            obj.Metric = struct( ...
                'unit', "m", ...
                'rescale', struct( ...
                    'applied', false, ...
                    'fromUnit', "", ...
                    'factor', 1.0, ...
                    'timestamp', "") );
            
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
%   % With unit annotations
%   E = M.eigenmodes(100, 'annotate', true);
%   E.values.unit   % '1/m^2' (Laplacian eigenvalues)
%   E.vectors.unit  % '1' (normalized modes)
%
% See also: bct.manifold.eigenmodes, bct.manifold.metric.annotate
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
                % Apply annotation if requested
                if annotate
                    Eigen = bct.manifold.metric.annotate(Eigen, 'eigen');
                end
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
            
            % Apply annotation if requested (before caching to keep cache numeric)
            if annotate
                Eigen = bct.manifold.metric.annotate(Eigen, 'eigen');
            end
            
            % Cache for future use (always cache numeric version)
            if annotate
                % Store un-annotated version in cache
                EigenNumeric = struct();
                EigenNumeric.values = eigenvalues;
                EigenNumeric.vectors = eigenvectors;
                EigenNumeric.k = length(eigenvalues);
                EigenNumeric.operator = "Laplace-Beltrami";
                EigenNumeric.basis = "P1-FEM";
                EigenNumeric.ordering = "ascending";
                EigenNumeric.massType = massType;
                EigenNumeric.removedDC = removeDC;
                obj.Cache.eigenmodes.data = EigenNumeric;
            else
                obj.Cache.eigenmodes.data = Eigen;
            end
            obj.Cache.eigenmodes.meta.computed = datetime('now');
            obj.Cache.eigenmodes.meta.k = length(eigenvalues);
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
            %   'precision'          - 'double' (default) or 'single' for numeric precision
            %   'circumcenterMethod' - 'native' (default) or 'triangulation'
            %   'boundaryPolicy'     - 'error' (default) for dual measures with boundaries
            %   'dualCellType'       - 'circumcentric' (default) for dual vertex areas
            %   'annotate'           - false (default) or true to wrap outputs as quantity structs
            %   'Force'              - false (default) or true to force recomputation
            %
            % Outputs:
            %   geom - Structure with fields:
            %     .face   - Face geometry (areas, centroids, normals, frame, cotan)
            %     .vertex - Vertex geometry (normals, frame)
            %     .edge   - Edge geometry (lengths, weights)
            %     .dual   - Dual mesh geometry (edgeLengths, vertexAreas)
            %     .header - Metadata about computation options
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
            %   he - Halfedge data structure with fields:
            %        .next       - [nH×1] Next halfedge in face
            %        .twin       - [nH×1] Opposite halfedge
            %        .vertex     - [nH×1] Vertex at halfedge origin
            %        .face       - [nH×1] Face containing halfedge
            %        .edge       - [nH×1] Edge index for halfedge
            %        .isBoundary - [nH×1] Logical array for boundary halfedges
            %        .E          - [nE×2] Unique edge list
            %
            % Description:
            %   Returns cached halfedge structure if available, or computes
            %   using bct.manifold.topology.halfedge() with mesh connectivity.
            %   Result is cached within topology namespace for future calls.
            %
            %   The halfedge structure enables efficient mesh navigation and
            %   is used internally by dual mesh computations and differential
            %   operators.
            %
            % Examples:
            %   % Get halfedge structure
            %   M = bct.Manifold(V, F);
            %   he = M.halfedge();
            %   
            %   % Navigate mesh
            %   h = 1;  % First halfedge
            %   next_h = he.next(h);
            %   twin_h = he.twin(h);
            %   
            %   % Get edge list
            %   E = he.E;
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
            
            % Check if topology is cached and has halfedge
            if ~force && ~isempty(fieldnames(obj.Cache.topology.data)) && ...
               isfield(obj.Cache.topology.data, 'halfedge')
                he = obj.Cache.topology.data.halfedge;
                return;
            end
            
            % Compute halfedge using bct.manifold.topology.halfedge
            he = bct.manifold.topology.halfedge(obj.Vertices, obj.Faces);
            
            % Cache the result in topology namespace
            if isempty(fieldnames(obj.Cache.topology.data))
                obj.Cache.topology.data = struct();
            end
            obj.Cache.topology.data.halfedge = he;
            obj.Cache.topology.meta.halfedgeComputed = datetime('now');
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
    
    % ===================================================================
    % INDIVIDUAL OPERATOR WRAPPERS (Modular Caching)
    % ===================================================================
    methods
        function [header, op] = mass(obj, varargin)
            %MASS Get or compute mass matrix (modular caching)
            %
            % Syntax:
            %   [header, M] = obj.mass()
            %   [header, M] = obj.mass('variant', 'voronoi')
            %
            % Description:
            %   Computes and caches the mass matrix operator. Updates only
            %   the mass field in the operators cache, enabling modular access.
            %
            % See also: bct.manifold.operator.mass, operators
            
            % Check if mass is already in cache
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'mass')
                op = obj.Cache.operators.data.mass;
                if nargout > 1
                    header = struct('source', 'cache');
                end
                return;
            end
            
            % Compute mass matrix
            [header, op] = bct.manifold.operator.mass(obj, varargin{:});
            
            % Cache the result
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.mass = op;
        end
        
        function [header, op] = stiffness(obj, varargin)
            %STIFFNESS Get or compute stiffness matrix (modular caching)
            %
            % Syntax:
            %   [header, K] = obj.stiffness()
            %   [header, K] = obj.stiffness('variant', 'cotan')
            %
            % Description:
            %   Computes and caches the stiffness matrix operator.
            %
            % See also: bct.manifold.operator.stiffness, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'stiffness')
                op = obj.Cache.operators.data.stiffness;
                if nargout > 1
                    header = struct('source', 'cache');
                end
                return;
            end
            
            [header, op] = bct.manifold.operator.stiffness(obj, varargin{:});
            
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
            %   Computes and caches the gradient operator.
            %
            % See also: bct.manifold.operator.gradient, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'gradient')
                op = obj.Cache.operators.data.gradient;
                if nargout > 1
                    header = struct('source', 'cache');
                end
                return;
            end
            
            [header, op] = bct.manifold.operator.gradient(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.gradient = op;
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
            %   Computes and caches all DEC operators. Returns a structure
            %   containing d0, d1, dd0, dd1, hd0-2, etc. This populates
            %   the entire dec substructure in the cache.
            %
            % See also: bct.manifold.operator.dec, operators
            
            if ~isempty(fieldnames(obj.Cache.operators.data)) && ...
               isfield(obj.Cache.operators.data, 'dec')
                decOps = obj.Cache.operators.data.dec;
                return;
            end
            
            decOps = bct.manifold.operator.dec(obj, varargin{:});
            
            if isempty(fieldnames(obj.Cache.operators.data))
                obj.Cache.operators.data = struct();
            end
            obj.Cache.operators.data.dec = decOps;
            
            % Also populate top-level shortcuts
            if isfield(decOps, 'd0')
                obj.Cache.operators.data.d0 = decOps.d0;
            end
            if isfield(decOps, 'd1')
                obj.Cache.operators.data.d1 = decOps.d1;
            end
            if isfield(decOps, 'dd0')
                obj.Cache.operators.data.dd0 = decOps.dd0;
            end
            if isfield(decOps, 'dd1')
                obj.Cache.operators.data.dd1 = decOps.dd1;
            end
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
        
        function localizedField = localize(obj, vertexIdx, filterSpec, varargin)
            %LOCALIZE Localize a spectral filter to a vertex (not cached)
            %
            % Syntax:
            %   localField = obj.localize(vertexIdx, filterSpec)
            %   localField = obj.localize(vertexIdx, filterSpec, 'OutputFormat', 'cell')
            %
            % Inputs:
            %   vertexIdx   - Vertex index for localization
            %   filterSpec  - Filter struct from bct.filter.design
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
