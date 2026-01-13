function D = distances(Graph, metric)
%DISTANCES All-pairs shortest path distances
%
% Syntax:
%   D = bct.manifold.query.distances(Graph)
%   D = bct.manifold.query.distances(Graph, metric)
%
% Inputs:
%   Graph  - bct.manifold.Graph object
%   metric - "geometry" (default) | "fem" | custom
%
% Returns:
%   D - [N×N] matrix of shortest path distances
%
% See also: bct.manifold.query.shortestPath, bct.manifold.Graph.matlab

arguments
    Graph (1,1) bct.manifold.Graph
    metric (1,1) string = "geometry"
end

G = Graph.matlab(metric);
D = distances(G);

end
