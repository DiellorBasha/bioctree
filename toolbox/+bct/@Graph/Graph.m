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
                w = obj.Weights.(metric);
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
            % Metric-aware shortest path
            
            if nargin < 4
                G = graph(obj.Adjacency);
            else
                G = obj.matlabGraph(metric);
            end
            
            [path, dist] = shortestpath(G, s, t);
        end
        
        function idx = neighbors(obj, v)
            idx = find(obj.Adjacency(v,:));
        end
    end
end
