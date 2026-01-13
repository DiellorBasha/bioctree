classdef Graph < handle
    %GRAPH Graph representation derived from Manifold
    %
    % Graph converts Manifold topology into graph structures for
    % navigation, search, and path analysis.
    %
    % Design principles:
    %   - MATLAB graph is a backend adapter, not canonical
    %   - Graph owns: Manifold, Edges (topology), Weights (metrics)
    %   - Algorithms live in bct.manifold.query package
    %
    % Properties (Canonical):
    %   Manifold - Source bct.Manifold object
    %   Edges    - [E×2] Edge list (canonical topology)
    %   Weights  - Struct of weight metrics (geometry, fem, etc.)
    %   NumNodes - Number of vertices
    %
    % Properties (Derived via bct.manifold.query):
    %   Adjacency - Sparse adjacency matrix
    %   Degree    - Sparse degree matrix
    %   Laplacian - Sparse Laplacian matrix
    %
    % Methods (Adapters):
    %   matlab() - Get MATLAB graph object (cached backend)
    %   gsp()    - Get GSP Toolbox graph (cached backend)
    %
    % See also: bct.Manifold, bct.manifold.query.matlabGraph
    
    properties (SetAccess = private)
        Manifold            % bct.Manifold object
        Edges               % [E×2] edge list
        Weights             % struct of edge weight metrics
        NumNodes            % number of vertices
        LaplacianType       % "combinatorial" | "normalized" | "randomwalk"
    end
    
    properties (Access = private)
        GraphMATLABCache    % containers.Map of cached MATLAB graphs
        GraphGSPCache       % containers.Map of cached GSP graphs
        GraphVersion        % version counter for cache invalidation
    end
    
    properties (Dependent)
        Adjacency           % [N×N] sparse adjacency (via bct.manifold.topology.adjacency)
        Degree              % [N×N] sparse degree matrix (computed from adjacency)
        Laplacian           % [N×N] sparse Laplacian (via bct.manifold.operator.graphlaplacian)
    end
    
    methods
        function obj = Graph(manifold, laplacianType)
            %GRAPH Construct Graph from Manifold
            %
            % Syntax:
            %   G = bct.manifold.Graph(manifold)
            %   G = bct.manifold.Graph(manifold, laplacianType)
            %
            % Inputs:
            %   manifold      - bct.Manifold object
            %   laplacianType - "combinatorial" (default), "normalized", "randomwalk"
            
            arguments
                manifold (1,1) bct.Manifold
                laplacianType (1,1) string {mustBeMember(laplacianType, ...
                    ["combinatorial","normalized","randomwalk"])} = "combinatorial"
            end
            
            obj.Manifold = manifold;
            obj.NumNodes = size(manifold.Vertices, 1);
            obj.LaplacianType = laplacianType;
            
            % Build canonical topology (use Edges property, not method)
            obj.Edges = obj.Manifold.Edges;
            
            % Initialize cache
            obj.GraphVersion = 1;
            obj.GraphMATLABCache = containers.Map();
            obj.GraphGSPCache = containers.Map();
            
            % Initialize metrics (use Manifold's cached computations directly)
            obj.Weights = struct();
            
            % Geometric weights: edge lengths from cached geometry
            geom = obj.Manifold.geometry();
            obj.Weights.geometry = geom.edgeLengths;
            
            % FEM weights: extract from stiffness matrix
            ops = obj.Manifold.operators();
            K = ops.stiffness;
            i = obj.Edges(:,1);
            j = obj.Edges(:,2);
            w = -K(sub2ind(size(K), i, j));
            w(w < 0) = 0;  % numerical safety
            obj.Weights.fem = w;
        end
    end
    
    %% Dependent properties (lazy computed)
    methods
        function A = get.Adjacency(obj)
            A = obj.Manifold.adjacency();
        end
        
        function D = get.Degree(obj)
            % Inline computation: D = diag(sum(A, 2))
            A = obj.Adjacency;
            d = sum(A, 2);
            N = size(A, 1);
            D = spdiags(d, 0, N, N);
        end
        
        function L = get.Laplacian(obj)
            L = bct.manifold.operator.graphlaplacian(obj.Manifold, 'Type', obj.LaplacianType);
        end
    end
    
    %% Cache management
    methods (Access = private)
        function invalidateCache(obj)
            obj.GraphVersion = obj.GraphVersion + 1;
        end
    end
    
    %% Metric management
    methods
        function addMetric(obj, name, weights)
            %ADDMETRIC Add custom edge weight metric
            %
            % Syntax:
            %   Graph.addMetric(name, weights)
            %
            % Inputs:
            %   name    - Metric name (string)
            %   weights - [E×1] edge weights
            
            arguments
                obj (1,1) bct.manifold.Graph
                name (1,1) string
                weights (:,1) double
            end
            
            if numel(weights) ~= size(obj.Edges, 1)
                error('bct:manifold:Graph:WeightSizeMismatch', ...
                    'Weights must be [E×1] where E = %d', size(obj.Edges, 1));
            end
            
            obj.Weights.(name) = weights;
            obj.invalidateCache();
        end
        
        function metrics = listMetrics(obj)
            %LISTMETRICS Get names of all available metrics
            metrics = string(fieldnames(obj.Weights));
        end
    end
    
    %% Backend adapters (cached)
    methods
        function G = matlab(obj, metric)
            %MATLAB Get MATLAB graph object (cached backend adapter)
            %
            % Syntax:
            %   G = Graph.matlab()
            %   G = Graph.matlab(metric)
            %
            % Inputs:
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Returns:
            %   G - MATLAB graph object (cached)
            %
            % Notes:
            %   - This is a backend adapter, not canonical
            %   - Result is cached and rebuilt on invalidation
            
            arguments
                obj (1,1) bct.manifold.Graph
                metric (1,1) string = "geometry"
            end
            
            key = metric + "_" + string(obj.GraphVersion);
            
            if ~isKey(obj.GraphMATLABCache, key)
                % Use bct.manifold.out for standard metrics, manual build for custom
                if ismember(metric, ["geometry", "fem"])
                    G = bct.manifold.out(obj.Manifold, 'graph', 'EdgeWeights', metric);
                else
                    % Custom metric: build manually
                    if ~isfield(obj.Weights, metric)
                        error('bct:manifold:Graph:UnknownMetric', ...
                            'Metric "%s" not defined. Available: %s', ...
                            metric, strjoin(string(fieldnames(obj.Weights)), ", "));
                    end
                    
                    % Get edge weights
                    w = full(obj.Weights.(metric));
                    
                    % Create weighted graph
                    G = graph(obj.Edges(:,1), obj.Edges(:,2), w, obj.NumNodes);
                    
                    % Attach coordinates as node properties
                    V = obj.Manifold.Vertices;
                    G.Nodes.X = V(:,1);
                    G.Nodes.Y = V(:,2);
                    G.Nodes.Z = V(:,3);
                end
                
                obj.GraphMATLABCache(key) = G;
            else
                G = obj.GraphMATLABCache(key);
            end
        end
        
        function G = gsp(obj, metric)
            %GSP Get GSPBox graph object (cached backend adapter)
            %
            % Syntax:
            %   G = Graph.gsp()
            %   G = Graph.gsp(metric)
            %
            % Inputs:
            %   metric - "geometry" (default) | "fem" | custom
            %
            % Returns:
            %   G - GSPBox graph structure (cached)
            %
            % Notes:
            %   - This is a backend adapter, not canonical
            %   - Result is cached and rebuilt on invalidation
            
            arguments
                obj (1,1) bct.manifold.Graph
                metric (1,1) string = "geometry"
            end
            
            if ~isfield(obj.Weights, metric)
                error('bct:manifold:Graph:UnknownMetric', ...
                    'Metric "%s" not defined. Available: %s', ...
                    metric, strjoin(string(fieldnames(obj.Weights)), ", "));
            end
            
            key = metric + "_" + obj.LaplacianType + "_" + string(obj.GraphVersion);
            
            if ~isKey(obj.GraphGSPCache, key)
                w = obj.Weights.(metric);
                
                % Build sparse symmetric adjacency
                W = sparse( ...
                    obj.Edges(:,1), ...
                    obj.Edges(:,2), ...
                    w, obj.NumNodes, obj.NumNodes);
                W = W + W.';  % ensure symmetry
                
                % Build GSP structure
                G = struct();
                G.N = obj.NumNodes;
                G.W = W;
                G.coords = obj.Manifold.Vertices;
                G.type = char(obj.LaplacianType);
                
                % Let GSPBox populate operators lazily
                G = gsp_graph_default_parameters(G);
                
                obj.GraphGSPCache(key) = G;
            else
                G = obj.GraphGSPCache(key);
            end
        end
    end
    
    %% Algorithm wrappers (delegate to bct.manifold.query package)
    methods
        function [path, dist] = shortestPath(obj, s, t, metric)
            %SHORTESTPATH Shortest path between two nodes
            %
            % Delegates to: bct.manifold.query.shortestPath
            
            arguments
                obj (1,1) bct.manifold.Graph
                s (1,1) {mustBeInteger, mustBePositive}
                t (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            [path, dist] = bct.manifold.query.shortestPath(obj, s, t, metric);
        end
        
        function D = distances(obj, metric)
            %DISTANCES All-pairs shortest path distances
            %
            % Delegates to: bct.manifold.query.distances
            
            arguments
                obj (1,1) bct.manifold.Graph
                metric (1,1) string = "geometry"
            end
            
            D = bct.manifold.query.distances(obj, metric);
        end
        
        function [T, pred] = bfSearch(obj, s, metric)
            %BFSEARCH Breadth-first search from source
            %
            % Delegates to: bct.manifold.query.bfSearch
            
            arguments
                obj (1,1) bct.manifold.Graph
                s (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            if nargout > 1
                [T, pred] = bct.manifold.query.bfSearch(obj, s, metric);
            else
                T = bct.manifold.query.bfSearch(obj, s, metric);
            end
        end
        
        function [T, pred] = dfSearch(obj, s, metric)
            %DFSEARCH Depth-first search from source
            %
            % Delegates to: bct.manifold.query.dfSearch
            
            arguments
                obj (1,1) bct.manifold.Graph
                s (1,1) {mustBeInteger, mustBePositive}
                metric (1,1) string = "geometry"
            end
            
            if nargout > 1
                [T, pred] = bct.manifold.query.dfSearch(obj, s, metric);
            else
                T = bct.manifold.query.dfSearch(obj, s, metric);
            end
        end
    end
    
    %% Spectral decomposition
    methods
        function E = eigenpairs(obj, k, options)
            %EIGENPAIRS Compute graph spectral eigenpairs
            %
            % Syntax:
            %   E = G.eigenpairs(k)
            %   E = G.eigenpairs(k, 'Force', true)
            %
            % Inputs:
            %   k - Number of eigenpairs to compute
            %
            % Optional Parameters:
            %   Force - Recompute even if cached (default: false)
            %
            % Outputs:
            %   E - Eigenmode structure (from bct.manifold.query.eigensolve)
            %
            % Note: Delegates to bct.manifold.query.eigensolve
            %
            % See also: bct.manifold.query.eigensolve, bct.manifold.eigen.solve
            
            arguments
                obj (1,1) bct.manifold.Graph
                k (1,1) {mustBePositive, mustBeInteger}
                options.Force (1,1) logical = false
            end
            
            % Check cache
            key = sprintf("k=%d", k);
            if ~options.Force && isKey(obj.GraphGSPCache, key)
                E = obj.GraphGSPCache(key);
                return;
            end
            
            % Delegate to bct.manifold.query.eigensolve
            E = bct.manifold.query.eigensolve(obj, k);
            
            % Cache result
            obj.GraphGSPCache(key) = E;
        end
    end
    
    %% Utility methods (simple topology queries)
    methods
        function idx = neighbors(obj, v)
            %NEIGHBORS Get topological neighbors of vertex
            
            arguments
                obj (1,1) bct.manifold.Graph
                v (1,1) {mustBeInteger, mustBePositive}
            end
            
            idx = find(obj.Adjacency(v,:));
        end
        
        function deg = degree(obj, v)
            %DEGREE Get degree of vertex/vertices
            
            arguments
                obj (1,1) bct.manifold.Graph
            end
            
            arguments (Repeating)
                v {mustBeInteger, mustBePositive}
            end
            
            if isempty(v)
                deg = full(diag(obj.Degree));
            else
                deg = full(diag(obj.Degree(v{1},v{1})));
            end
        end
    end
end
