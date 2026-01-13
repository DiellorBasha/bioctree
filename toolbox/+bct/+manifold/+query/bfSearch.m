function [T, pred] = bfSearch(Graph, s, metric)
%BFSEARCH Breadth-first search from source node
%
% Syntax:
%   T = bct.manifold.query.bfSearch(Graph, s)
%   [T, pred] = bct.manifold.query.bfSearch(Graph, s, metric)
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
% See also: bct.manifold.query.dfSearch, bct.manifold.Graph.matlab

arguments
    Graph (1,1) bct.manifold.Graph
    s (1,1) {mustBeInteger, mustBePositive}
    metric (1,1) string = "geometry"
end

G = Graph.matlab(metric);

if nargout > 1
    [T, pred] = bfsearch(G, s);
else
    T = bfsearch(G, s);
end

end
