function [T, pred] = dfSearch(A, s)
%DFSEARCH Depth-first search from source node
%
% Syntax:
%   T = bct.manifold.query.dfSearch(A, s)
%   [T, pred] = bct.manifold.query.dfSearch(A, s)
%
% Inputs:
%   A - Adjacency matrix (sparse)
%   s - Source node
%
% Returns:
%   T    - Vector of node discovery order
%   pred - Vector of predecessor nodes
%
% See also: bct.manifold.query.bfSearch, bct.Manifold.dfSearch

arguments
    A (:,:) {mustBeNumeric}
    s (1,1) {mustBeInteger, mustBePositive}
end

G = graph(A);

if nargout > 1
    [T, pred] = dfsearch(G, s);
else
    T = dfsearch(G, s);
end

end
