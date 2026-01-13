function D = distances(E, w, N)
%DISTANCES All-pairs shortest path distances
%
% Syntax:
%   D = bct.manifold.query.distances(E, w, N)
%
% Inputs:
%   E - [M×2] edge list
%   w - [M×1] edge weights
%   N - Number of nodes
%
% Returns:
%   D - [N×N] matrix of shortest path distances
%
% See also: bct.manifold.query.shortestPath, bct.Manifold.distances

arguments
    E (:,2) {mustBeInteger}
    w (:,1) double
    N (1,1) {mustBeInteger, mustBePositive}
end

G = graph(E(:,1), E(:,2), w, N);
D = distances(G);

end
