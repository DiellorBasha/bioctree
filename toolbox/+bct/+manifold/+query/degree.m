function deg = degree(A, v)
%DEGREE Get degree of vertex or all vertices
%
% Syntax:
%   deg = bct.manifold.query.degree(A)
%   deg = bct.manifold.query.degree(A, v)
%
% Inputs:
%   A - Adjacency matrix (sparse)
%   v - Vertex index or indices (optional)
%
% Outputs:
%   deg - Vertex degrees (scalar, vector, or full degree list)
%
% Description:
%   Computes the degree (number of neighbors) for vertices.
%   If no vertex index is provided, returns degrees for all vertices.
%   If vertex indices provided, returns degrees for those vertices only.
%
% Examples:
%   % Get all vertex degrees
%   deg = bct.manifold.query.degree(A);
%
%   % Get degree of specific vertex
%   deg_v = bct.manifold.query.degree(A, 100);
%
%   % Get degrees of multiple vertices
%   deg_verts = bct.manifold.query.degree(A, [10, 20, 30]);
%
% See also: bct.Manifold.degree, bct.manifold.query.neighbors

arguments
    A (:,:) {mustBeNumeric}
end

arguments (Repeating)
    v {mustBeInteger, mustBePositive}
end

if isempty(v)
    % Return degrees for all vertices
    deg = full(sum(A, 2));
else
    % Return degrees for specified vertices
    deg = full(sum(A(v{1}, :), 2));
end

end
