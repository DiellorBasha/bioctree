function [path, dist] = shortestPath(Graph, s, t, metric)
%SHORTESTPATH Compute shortest path between two nodes
%
% Syntax:
%   path = bct.graph.shortestPath(Graph, s, t)
%   [path, dist] = bct.graph.shortestPath(Graph, s, t, metric)
%
% Inputs:
%   Graph  - bct.Graph object
%   s      - Source node
%   t      - Target node
%   metric - "geometry" (default) | "fem" | custom
%
% Returns:
%   path - Vector of node indices along shortest path
%   dist - Total path distance
%
% See also: bct.graph.matlabGraph

arguments
    Graph (1,1) bct.Graph
    s (1,1) {mustBeInteger, mustBePositive}
    t (1,1) {mustBeInteger, mustBePositive}
    metric (1,1) string = "geometry"
end

G = bct.graph.matlabGraph(Graph, metric);
[path, dist] = shortestpath(G, s, t);

end
