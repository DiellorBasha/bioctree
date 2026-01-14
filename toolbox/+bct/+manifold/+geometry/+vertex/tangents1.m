function [header, tangent1] = tangents1(meshInput, varargin)
%TANGENTS1 Compute first tangent vector for each vertex
%
% Syntax:
%   [header, tangent1] = bct.manifold.geometry.vertex.tangents1(M)
%   [header, tangent1] = bct.manifold.geometry.vertex.tangents1(V, F)
%
% Inputs:
%   M    - bct.Manifold object
%   OR
%   V    - [Nv×3] vertex coordinates
%   F    - [Nf×3] face connectivity (1-indexed)
%
% Outputs:
%   header   - Structure containing:
%              .method - 'projection'
%   tangent1 - [Nv×3] first tangent vectors (unit, orthogonal to normals)
%
% Description:
%   Computes the first tangent vector at each vertex by projecting a
%   reference axis onto the tangent plane defined by the vertex normal.
%
%   Uses reference axis [1,0,0] (X-axis) by default, switching to [0,1,0]
%   (Y-axis) when the normal is nearly parallel to the X-axis.
%
% Examples:
%   M = bct.Manifold(V, F);
%   [header, T1] = bct.manifold.geometry.vertex.tangents1(M);
%
% See also: bct.manifold.geometry.vertex.tangents2, 
%           bct.manifold.geometry.vertex.normals

% Get normals first
[~, normals] = bct.manifold.geometry.vertex.normals(meshInput, varargin{:});

nv = size(normals, 1);

% Reference axis projection
ref = repmat([1 0 0], nv, 1);                         % X-axis reference
parallel = abs(sum(ref .* normals, 2)) > 0.9;         % Too aligned?
ref(parallel,:) = repmat([0 1 0], sum(parallel), 1);  % Use Y-axis instead

% Project to tangent plane
tangent1 = ref - sum(ref .* normals, 2) .* normals;
tangent1 = normalizeRows(tangent1);

% Build header
header = struct();
header.method = 'projection';

end

% ===== Helper: normalize each row safely =====
function X = normalizeRows(X)
    n = vecnorm(X, 2, 2);
    bad = (n < eps) | isnan(n);
    n(bad) = 1;
    X = X ./ n;
    X(bad,:) = 0;
end
