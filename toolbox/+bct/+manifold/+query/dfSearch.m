function [T, pred] = dfSearch(Graph, s, metric)
%DFSEARCH Depth-first search from source node
%
% Syntax:
%   T = bct.manifold.query.dfSearch(Graph, s)
%   [T, pred] = bct.manifold.query.dfSearch(Graph, s, metric)
%
% Inputs:
%   Graph  - bct.manifold.Graph object
%   s      - Source node
%   metric - "geometry" (default) | "fem" | custom
%
% Returns:
%   T    - Vector of node discovery order
%   pred - Vector of predecessor nodes
%
% See also: bct.manifold.query.bfSearch, bct.manifold.Graph.matlab

arguments
    Graph (1,1) bct.manifold.Graph
    s (1,1) {mustBeInteger, mustBePositive}
    metric (1,1) string = "geometry"
end

G = Graph.matlab(metric);

if nargout > 1
    [T, pred] = dfsearch(G, s);
else
    T = dfsearch(G, s);
end

end
