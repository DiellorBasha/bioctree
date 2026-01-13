function D = distances(M, metric)
%DISTANCES All-pairs shortest path distances
%
% Syntax:
%   D = bct.manifold.query.distances(M)
%   D = bct.manifold.query.distances(M, metric)
%
% Inputs:
%   M      - bct.Manifold object
%   metric - "geometry" (default) | "fem" | "uniform"
%
% Returns:
%   D - [N×N] matrix of shortest path distances
%
% See also: bct.manifold.query.shortestPath, bct.manifold.out

arguments
    M (1,1) bct.Manifold
    metric (1,1) string = "geometry"
end

G = bct.manifold.out(M, 'graph', 'EdgeWeights', metric);
D = distances(G);

end
