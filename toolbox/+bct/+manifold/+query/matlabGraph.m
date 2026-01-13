function G = matlabGraph(Graph, metric)
%MATLABGRAPH Create MATLAB graph object with specified metric
%
% Syntax:
%   G = bct.manifold.query.matlabGraph(Graph, metric)
%
% Inputs:
%   Graph  - bct.manifold.Graph object
%   metric - "geometry" (default) | "fem" | custom metric name
%
% Returns:
%   G - MATLAB graph object with edge weights and node coordinates
%
% Notes:
%   - This is a backend adapter, not canonical representation
%   - Result should be cached by caller
%   - Node coordinates attached as node properties (X, Y, Z)
%
% See also: bct.manifold.Graph.matlab

arguments
    Graph (1,1) bct.manifold.Graph
    metric (1,1) string = "geometry"
end

% Validate metric exists
if ~isfield(Graph.Weights, metric)
    error('bct:manifold:query:UnknownMetric', ...
        'Metric "%s" not defined. Available: %s', ...
        metric, strjoin(string(fieldnames(Graph.Weights)), ", "));
end

% Get edge weights (must be full for MATLAB graph)
w = full(Graph.Weights.(metric));

% Create weighted graph
G = graph(...
    Graph.Edges(:,1), ...
    Graph.Edges(:,2), ...
    w, Graph.NumNodes);

% Attach coordinates as node properties
V = Graph.Manifold.Vertices;
G.Nodes.X = V(:,1);
G.Nodes.Y = V(:,2);
G.Nodes.Z = V(:,3);

end
