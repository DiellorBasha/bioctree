function [T, pred] = bfSearch(A, s)
%BFSEARCH Breadth-first search from source node
%
% Syntax:
%   T = bct.manifold.query.bfSearch(A, s)
%   [T, pred] = bct.manifold.query.bfSearch(A, s)
%
% Inputs:
%   A - Adjacency matrix (sparse)
%   s - Source node
%
% Returns:
%   T    - Vector of node discovery order
%   pred - Vector of predecessor nodes
%
% See also: bct.manifold.query.dfSearch, bct.Manifold.bfSearch

arguments
    A (:,:) {mustBeNumeric}
    s (1,1) {mustBeInteger, mustBePositive}
end

G = graph(A);

if nargout > 1
    [T, pred] = bfsearch(G, s);
else
    T = bfsearch(G, s);
end

end
