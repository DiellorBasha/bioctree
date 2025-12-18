classdef Graph < handle
    % bct.Graph
    %
    % Discrete graph representation derived from a Manifold.
    % Serves as the navigation and signal axis for Bct.
    %
    % Responsibilities:
    %   - Encode mesh topology
    %   - Provide multiple weighted metrics
    %   - Expose GSP operators (Adjacency, Degree, Laplacian)
    %
    % Does NOT:
    %   - Replace FEM Laplacian
    %   - Encode physical PDE operators
    
    properties (SetAccess = private)
        % --- Core references ---
        Manifold            % parent Manifold object
        Vertices            % Nx3 vertex coordinates (copy of Manifold.Vertices)
        
        % --- Topology ---
        Edges               % Ex2 edge list (vertex indices)
        Adjacency           % NxN sparse adjacency matrix
        
        % --- Metrics ---
        Weights             % struct of edge-weight vectors
        
        % --- GSP operators ---
        Degree              % NxN sparse degree matrix
        Laplacian           % NxN sparse graph Laplacian
        
        LaplacianType       % "combinatorial" | "normalized" | "randomwalk"
        
        N                   % number of vertices
    end
    
    properties (Access = private)
        % --- Cached derived representations ---
        % Rule: Canonical data is stored. Representations are cached.
        GraphMATLABCache    % containers.Map of cached MATLAB graphs (key: metric_version)
        GraphGSPCache       % containers.Map of cached GSP graphs (key: metric_laplacian_version)
        Incidence           % cached incidence matrix (topology-dependent only)
        
        GraphVersion        % version number of canonical graph state
    end
    
    methods
        function obj = Graph(manifold, laplacianType)
            %GRAPH Construct a Graph from a Manifold
            %
            %   G = Graph(manifold)
            %   G = Graph(manifold, laplacianType)
            
            arguments
                manifold (1,1)
                laplacianType (1,1) string = "combinatorial"
            end
            
            obj.Manifold = manifold;
            obj.Vertices = manifold.Vertices;
            obj.N = size(manifold.Vertices, 1);
            obj.LaplacianType = laplacianType;
            
            % --- Initialize cache versioning ---
            obj.GraphVersion = 1;
            obj.GraphMATLABCache = containers.Map();
            obj.GraphGSPCache = containers.Map();
            
            % --- Build topology ---
            obj.buildAdjacency();
            obj.buildEdges();
            
            % --- Initialize metrics ---
            obj.Weights = struct();
            obj.computeGeometricWeights();
            obj.computeFEMWeights();
            
            % --- Build GSP operators ---
            obj.buildDegree();
            obj.buildLaplacian();
        end
    end
    
    %% === Cache management ===
    methods (Access = private)
        function invalidateCache(obj)
            % Invalidate all cached representations
            % Call this whenever canonical graph data changes
            obj.GraphVersion = obj.GraphVersion + 1;
            obj.Incidence = [];  % clear topology-dependent caches
        end
    end
    
    %% === Topology construction ===
    methods (Access = private)
        function buildAdjacency(obj)
            % Use cotangent matrix sparsity as canonical topology
            K = obj.Manifold.CotangentMatrix;
            A = K ~= 0;
            A = A - diag(diag(A));   % remove self-loops
            obj.Adjacency = sparse(A);
        end
        
        function buildEdges(obj)
            [i,j] = find(triu(obj.Adjacency,1));
            obj.Edges = [i j];
        end
    end
    
    %% === Metric overlays ===
    methods
        function computeGeometricWeights(obj)
            % Euclidean edge-length weights (interaction metric)
            V = obj.Vertices;
            i = obj.Edges(:,1);
            j = obj.Edges(:,2);
            
            w = vecnorm(V(i,:) - V(j,:), 2, 2);
            obj.Weights.geometry = w;
        end
        
        function computeFEMWeights(obj)
            % Cotangent FEM weights (physics-aligned metric)
            K = obj.Manifold.CotangentMatrix;
            i = obj.Edges(:,1);
            j = obj.Edges(:,2);
            
            w = -K(sub2ind(size(K), i, j));
            w(w < 0) = 0;   % numerical safety
            obj.Weights.fem = w;
        end
    end
    
    %% === GSP operators ===
    methods (Access = private)
        function buildDegree(obj)
            d = sum(obj.Adjacency, 2);
            obj.Degree = spdiags(d, 0, obj.N, obj.N);
        end
        
        function buildLaplacian(obj)
            A = obj.Adjacency;
            D = obj.Degree;
            
            switch obj.LaplacianType
                
                case "combinatorial"
                    % L = D - A
                    obj.Laplacian = D - A;
                    
                case "normalized"
                    % L = I - D^{-1/2} A D^{-1/2}
                    d = diag(D);
                    d(d == 0) = eps;
                    Dinv2 = spdiags(1./sqrt(d), 0, obj.N, obj.N);
                    obj.Laplacian = speye(obj.N) - Dinv2 * A * Dinv2;
                    
                case "randomwalk"
                    % L = I - D^{-1} A
                    d = diag(D);
                    d(d == 0) = eps;
                    Dinv = spdiags(1./d, 0, obj.N, obj.N);
                    obj.Laplacian = speye(obj.N) - Dinv * A;
                    
                otherwise
                    error("Graph:UnknownLaplacianType", ...
                          "Unknown LaplacianType '%s'", obj.LaplacianType);
            end
        end
    end
    
    %% === Graph accessors ===
    methods
        function G = matlabGraph(obj, metric)
            % Return cached MATLAB graph with specified metric
            %
            % Syntax:
            %   G = matlabGraph(obj, metric)
            %
            % Inputs:
            %   metric - "geometry" (default) | "fem" | custom metric name
            %
            % Outputs:
            %   G - MATLAB graph object with edge weights and node coordinates
            %
            % Note: Result is cached and only rebuilt when canonical data changes
            
            arguments
                obj
                metric (1,1) string = "geometry"
            end
            
            if ~isfield(obj.Weights, metric)
                error("Graph:UnknownMetric", ...
                      "Metric '%s' not defined. Available: %s", ...
                      metric, strjoin(string(fieldnames(obj.Weights)), ", "));
            end
            
            % Build cache key
            key = metric + "_" + string(obj.GraphVersion);
            
            if ~isKey(obj.GraphMATLABCache, key)
                % Build weighted MATLAB graph
                w = full(obj.Weights.(metric));  % MATLAB graph requires full (non-sparse)
                G = graph( ...
                    obj.Edges(:,1), ...
                    obj.Edges(:,2), ...
                    w, obj.N);
                
                % Attach coordinates as node properties
                G.Nodes.X = obj.Vertices(:,1);
                G.Nodes.Y = obj.Vertices(:,2);
                G.Nodes.Z = obj.Vertices(:,3);
                
                obj.GraphMATLABCache(key) = G;
            end
            
            G = obj.GraphMATLABCache(key);
        end
        
        function G = gspGraph(obj, metric)
            % Return cached GSPBox graph structure with specified metric
            %
            % Syntax:
            %   G = gspGraph(obj, metric)
            %
            % Inputs:
            %   metric - "geometry" (default) | "fem" | custom metric name
            %
            % Outputs:
            %   G - GSPBox graph structure with operators
            %
            % Note: Result is cached and only rebuilt when canonical data changes
            
            arguments
                obj
                metric (1,1) string = "geometry"
            end
            
            if ~isfield(obj.Weights, metric)
                error("Graph:UnknownMetric", ...
                      "Metric '%s' not defined. Available: %s", ...
                      metric, strjoin(string(fieldnames(obj.Weights)), ", "));
            end
            
            % Build cache key (includes LaplacianType)
            key = metric + "_" + obj.LaplacianType + "_" + string(obj.GraphVersion);
            
            if ~isKey(obj.GraphGSPCache, key)
                w = obj.Weights.(metric);
                
                % Build sparse symmetric adjacency
                W = sparse( ...
                    obj.Edges(:,1), ...
                    obj.Edges(:,2), ...
                    w, obj.N, obj.N);
                W = W + W.';   % ensure symmetry
                
                % Build GSP structure
                G = struct();
                G.N = obj.N;
                G.W = W;
                G.coords = obj.Vertices;
                G.type = char(obj.LaplacianType);
                
                % Let GSPBox populate operators lazily
                G = gsp_graph_default_parameters(G);
                
                obj.GraphGSPCache(key) = G;
            end
            
            G = obj.GraphGSPCache(key);
        end
        
        function [path, dist] = shortestPath(obj, s, t, metric)
            % Shortest path between two nodes
            %
            % Syntax:
            %   [path, dist] = shortestPath(obj, s, t)
            %   [path, dist] = shortestPath(obj, s, t, metric)
            %
            % Inputs:
            %   s      - Source node
            %   t      - Target node
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Outputs:
            %   path - Vector of node indices along shortest path
            %   dist - Total path distance
            
            arguments
                obj
                s (1,1) {mustBeInteger, mustBePositive}
                t (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            G = obj.matlabGraph(metric);
            [path, dist] = shortestpath(G, s, t);
        end
        
        function T = shortestPathTree(obj, s, metric)
            % Shortest path tree from source node
            %
            % Syntax:
            %   T = shortestPathTree(obj, s)
            %   T = shortestPathTree(obj, s, metric)
            %
            % Inputs:
            %   s      - Source node
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Outputs:
            %   T - Directed graph representing shortest path tree
            
            arguments
                obj
                s (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            G = obj.matlabGraph(metric);
            T = shortestpathtree(G, s);
        end
        
        function D = distances(obj, metric)
            % All-pairs shortest path distances
            %
            % Syntax:
            %   D = distances(obj)
            %   D = distances(obj, metric)
            %
            % Inputs:
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Outputs:
            %   D - [N×N] matrix of shortest path distances
            
            arguments
                obj
                metric (1,1) string = "geometry"
            end
            
            G = obj.matlabGraph(metric);
            D = distances(G);
        end
        
        function [paths, costs] = allPaths(obj, s, t, metric)
            % Find all paths between two nodes
            %
            % Syntax:
            %   paths = allPaths(obj, s, t)
            %   [paths, costs] = allPaths(obj, s, t, metric)
            %
            % Inputs:
            %   s      - Source node
            %   t      - Target node
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Outputs:
            %   paths - Cell array of paths (each path is vector of node indices)
            %   costs - Vector of path costs
            %
            % Note: Available in MATLAB R2021a and later
            
            arguments
                obj
                s (1,1) {mustBeInteger, mustBePositive}
                t (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            G = obj.matlabGraph(metric);
            
            if nargout > 1
                [paths, costs] = allpaths(G, s, t);
            else
                paths = allpaths(G, s, t);
            end
        end
        
        function [mf, GF, cs, ct] = maxFlow(obj, s, t, metric)
            % Maximum flow from source to sink
            %
            % Syntax:
            %   mf = maxFlow(obj, s, t)
            %   [mf, GF, cs, ct] = maxFlow(obj, s, t, metric)
            %
            % Inputs:
            %   s      - Source node
            %   t      - Sink node
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Outputs:
            %   mf - Maximum flow value
            %   GF - Graph with flow values on edges
            %   cs - Nodes in source side of minimum cut
            %   ct - Nodes in sink side of minimum cut
            
            arguments
                obj
                s (1,1) {mustBeInteger, mustBePositive}
                t (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            G = obj.matlabGraph(metric);
            [mf, GF, cs, ct] = maxflow(G, s, t);
        end
        
        function [T, pred] = bfSearch(obj, s, metric)
            % Breadth-first search from source node
            %
            % Syntax:
            %   T = bfSearch(obj, s)
            %   [T, pred] = bfSearch(obj, s, metric)
            %
            % Inputs:
            %   s      - Source node
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Outputs:
            %   T    - Vector of node discovery order
            %   pred - Vector of predecessor nodes
            
            arguments
                obj
                s (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            G = obj.matlabGraph(metric);
            
            if nargout > 1
                [T, pred] = bfsearch(G, s);
            else
                T = bfsearch(G, s);
            end
        end
        
        function [T, pred] = dfSearch(obj, s, metric)
            % Depth-first search from source node
            %
            % Syntax:
            %   T = dfSearch(obj, s)
            %   [T, pred] = dfSearch(obj, s, metric)
            %
            % Inputs:
            %   s      - Source node
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Outputs:
            %   T    - Vector of node discovery order
            %   pred - Vector of predecessor nodes
            
            arguments
                obj
                s (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            G = obj.matlabGraph(metric);
            
            if nargout > 1
                [T, pred] = dfsearch(G, s);
            else
                T = dfsearch(G, s);
            end
        end
        
        function idx = neighbors(obj, v)
            % Topological neighbors of vertex
            %
            % Syntax:
            %   idx = neighbors(obj, v)
            %
            % Inputs:
            %   v - Vertex index
            %
            % Outputs:
            %   idx - Vector of neighbor vertex indices
            
            idx = find(obj.Adjacency(v,:));
        end
        
        function nodeIDs = nearest(obj, s, d, metric)
            % Nodes within distance d from source node
            %
            % Syntax:
            %   nodeIDs = nearest(obj, s, d)
            %   nodeIDs = nearest(obj, s, d, metric)
            %
            % Inputs:
            %   s      - Source node
            %   d      - Distance threshold
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Outputs:
            %   nodeIDs - Vector of node indices within distance d from s
            %
            % Note: Uses edge weights from specified metric
            
            arguments
                obj
                s (1,1) {mustBeInteger, mustBePositive}
                d (1,1) {mustBeNumeric, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            G = obj.matlabGraph(metric);
            nodeIDs = nearest(G, s, d);
        end
        
        function deg = degree(obj, v)
            % Degree of vertex (number of incident edges)
            %
            % Syntax:
            %   deg = degree(obj, v)
            %   deg = degree(obj)  % all vertices
            %
            % Inputs:
            %   v - Vertex index (scalar or vector), optional
            %
            % Outputs:
            %   deg - Vertex degree(s)
            %
            % Note: Uses cached Degree matrix
            
            if nargin < 2
                deg = full(diag(obj.Degree));
            else
                deg = full(diag(obj.Degree(v,v)));
            end
        end
        
        function edges = inedges(obj, v, metric)
            % Indices of edges incoming to vertex
            %
            % Syntax:
            %   edges = inedges(obj, v)
            %   edges = inedges(obj, v, metric)
            %
            % Inputs:
            %   v      - Vertex index
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Outputs:
            %   edges - Vector of edge indices incoming to v
            %
            % Note: For undirected graphs, inedges = outedges
            %       Useful for: GSP gradients, flux aggregation, net flow
            
            arguments
                obj
                v (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            G = obj.matlabGraph(metric);
            edges = inedges(G, v);
        end
        
        function edges = outedges(obj, v, metric)
            % Indices of edges outgoing from vertex
            %
            % Syntax:
            %   edges = outedges(obj, v)
            %   edges = outedges(obj, v, metric)
            %
            % Inputs:
            %   v      - Vertex index
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Outputs:
            %   edges - Vector of edge indices outgoing from v
            %
            % Note: For undirected graphs, outedges = inedges
            %       Useful for: GSP gradients, flux aggregation, net flow
            
            arguments
                obj
                v (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            G = obj.matlabGraph(metric);
            edges = outedges(G, v);
        end
        
        function B = incidence(obj)
            % Incidence matrix (topology-only, cached)
            %
            % Syntax:
            %   B = incidence(obj)
            %
            % Outputs:
            %   B - [N×E] incidence matrix where B(i,j) = ±1 if node i is 
            %       incident to edge j, 0 otherwise
            %
            % Note: Result is cached since it depends only on topology
            
            if isempty(obj.Incidence)
                % Compute from unweighted topology
                G = obj.matlabGraph();
                obj.Incidence = incidence(G);
            end
            B = obj.Incidence;
        end
    end
end
