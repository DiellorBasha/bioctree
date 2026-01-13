function [path, dist] = shortestPath(E, w, N, s, t)
%SHORTESTPATH Compute shortest path between two nodes
%
% Syntax:
%   path = bct.manifold.query.shortestPath(E, w, N, s, t)
%   [path, dist] = bct.manifold.query.shortestPath(E, w, N, s, t)
%
% Inputs:
%   E - [M×2] edge list
%   w - [M×1] edge weights
%   N - Number of nodes
%   s - Source node
%   t - Target node
%
% Returns:
%   path - Vector of node indices along shortest path
%   dist - Total path distance
%
% See also: bct.Manifold.shortestPath

arguments
    E (:,2) {mustBeInteger}
    w (:,1) double
    N (1,1) {mustBeInteger, mustBePositive}
    s (1,1) {mustBeInteger, mustBePositive}
    t (1,1) {mustBeInteger, mustBePositive}
end

G = graph(E(:,1), E(:,2), w, N);
[path, dist] = shortestpath(G, s, t);

end
