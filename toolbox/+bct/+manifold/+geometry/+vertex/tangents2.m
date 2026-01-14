function [header, tangent2] = tangents2(meshInput, varargin)
%TANGENTS2 Compute second tangent vector for each vertex
%
% Syntax:
%   [header, tangent2] = bct.manifold.geometry.vertex.tangents2(M)
%   [header, tangent2] = bct.manifold.geometry.vertex.tangents2(V, F)
%
% Inputs:
%   M    - bct.Manifold object
%   OR
%   V    - [Nv×3] vertex coordinates
%   F    - [Nf×3] face connectivity (1-indexed)
%
% Outputs:
%   header   - Structure containing:
%              .method - 'cross'
%   tangent2 - [Nv×3] second tangent vectors (unit, orthogonal to normals and tangent1)
%
% Description:
%   Computes the second tangent vector at each vertex as the cross product
%   of the vertex normal and the first tangent vector, ensuring a right-handed
%   orthonormal frame.
%
%   tangent2 = normal × tangent1
%
% Examples:
%   M = bct.Manifold(V, F);
%   [header, T2] = bct.manifold.geometry.vertex.tangents2(M);
%
% See also: bct.manifold.geometry.vertex.tangents1,
%           bct.manifold.geometry.vertex.normals

% Get normals and tangent1
[~, normals] = bct.manifold.geometry.vertex.normals(meshInput, varargin{:});
[~, tangent1] = bct.manifold.geometry.vertex.tangents1(meshInput, varargin{:});

% Compute second tangent as cross product
tangent2 = cross(normals, tangent1, 2);
tangent2 = normalizeRows(tangent2);

% Build header
header = struct();
header.method = 'cross';

end

% ===== Helper: normalize each row safely =====
function X = normalizeRows(X)
    n = vecnorm(X, 2, 2);
    bad = (n < eps) | isnan(n);
    n(bad) = 1;
    X = X ./ n;
    X(bad,:) = 0;
end
