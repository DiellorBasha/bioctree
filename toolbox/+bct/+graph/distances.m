function D = distances(Graph, metric)
%DISTANCES All-pairs shortest path distances
%
% Syntax:
%   D = bct.graph.distances(Graph)
%   D = bct.graph.distances(Graph, metric)
%
% Inputs:
%   Graph  - bct.Graph object
%   metric - "geometry" (default) | "fem" | custom
%
% Returns:
%   D - [N×N] matrix of shortest path distances
%
% See also: bct.graph.shortestPath, bct.graph.matlabGraph

arguments
    Graph (1,1) bct.Graph
    metric (1,1) string = "geometry"
end

G = bct.graph.matlabGraph(Graph, metric);
D = distances(G);

end
