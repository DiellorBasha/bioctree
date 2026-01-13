function idx = neighbors(A, v)
%NEIGHBORS Get topological neighbors of vertex
%
% Syntax:
%   idx = bct.manifold.query.neighbors(A, v)
%
% Inputs:
%   A - Adjacency matrix (sparse)
%   v - Vertex index
%
% Outputs:
%   idx - Indices of neighboring vertices
%
% Description:
%   Returns the indices of all vertices directly connected to vertex v
%   in the adjacency graph. Uses sparse matrix row lookup.
%
% See also: bct.Manifold.neighbors

arguments
    A (:,:) {mustBeNumeric}
    v (1,1) {mustBeInteger, mustBePositive}
end

idx = find(A(v,:));

end
