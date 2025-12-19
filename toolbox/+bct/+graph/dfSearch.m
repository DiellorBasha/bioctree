function [T, pred] = dfSearch(Graph, s, metric)
%DFSEARCH Depth-first search from source node
%
% Syntax:
%   T = bct.graph.dfSearch(Graph, s)
%   [T, pred] = bct.graph.dfSearch(Graph, s, metric)
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
% See also: bct.graph.bfSearch, bct.graph.matlabGraph

arguments
    Graph (1,1) bct.Graph
    s (1,1) {mustBeInteger, mustBePositive}
    metric (1,1) string = "geometry"
end

G = bct.graph.matlabGraph(Graph, metric);

if nargout > 1
    [T, pred] = dfsearch(G, s);
else
    T = dfsearch(G, s);
end

end
