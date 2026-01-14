function [header, tangent2] = tangents2(meshInput, varargin)
%TANGENTS2 Compute second tangent vector for each face
%
% Syntax:
%   [header, tangent2] = bct.manifold.geometry.face.tangents2(M)
%   [header, tangent2] = bct.manifold.geometry.face.tangents2(V, F)
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
%   tangent2 - [Nf×3] second tangent vectors (unit, orthogonal to normal and tangent1)
%
% Description:
%   Computes the second tangent vector for each face as the cross product
%   of the face normal and the first tangent vector, ensuring a right-handed
%   orthonormal frame.
%
%   tangent2 = normal × tangent1
%
% Examples:
%   M = bct.Manifold(V, F);
%   [header, T2] = bct.manifold.geometry.face.tangents2(M);
%
% See also: bct.manifold.geometry.face.tangents1,
%           bct.manifold.geometry.face.normals

% Get normals and tangent1
[~, normals] = bct.manifold.geometry.face.normals(meshInput, varargin{:});
[~, tangent1] = bct.manifold.geometry.face.tangents1(meshInput, varargin{:});

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
