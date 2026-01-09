function [T, pred] = bfSearch(Graph, s, metric)
%BFSEARCH Breadth-first search from source node
%
% Syntax:
%   T = bct.graph.bfSearch(Graph, s)
%   [T, pred] = bct.graph.bfSearch(Graph, s, metric)
%
% Inputs:
%   Graph  - bct.Graph object
%   s      - Source node
%   metric - "geometry" (default) | "fem" | custom
%
% Returns:
%   T    - Vector of node discovery order
%   pred - Vector of predecessor nodes
%
% See also: bct.graph.dfSearch, bct.graph.matlabGraph

arguments
    Graph (1,1) bct.Graph
    s (1,1) {mustBeInteger, mustBePositive}
    metric (1,1) string = "geometry"
end

G = bct.graph.matlabGraph(Graph, metric);

if nargout > 1
    [T, pred] = bfsearch(G, s);
else
    T = bfsearch(G, s);
end

end
