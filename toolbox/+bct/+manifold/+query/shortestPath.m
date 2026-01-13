function [path, dist] = shortestPath(M, s, t, metric)
%SHORTESTPATH Compute shortest path between two nodes
%
% Syntax:
%   path = bct.manifold.query.shortestPath(M, s, t)
%   [path, dist] = bct.manifold.query.shortestPath(M, s, t, metric)
%
% Inputs:
%   M      - bct.Manifold object
%   s      - Source node
%   t      - Target node
%   metric - "geometry" (default) | "fem" | "uniform"
%
% Returns:
%   path - Vector of node indices along shortest path
%   dist - Total path distance
%
% See also: bct.manifold.out

arguments
    M (1,1) bct.Manifold
    s (1,1) {mustBeInteger, mustBePositive}
    t (1,1) {mustBeInteger, mustBePositive}
    metric (1,1) string = "geometry"
end

G = bct.manifold.out(M, 'graph', 'EdgeWeights', metric);
[path, dist] = shortestpath(G, s, t);

end
