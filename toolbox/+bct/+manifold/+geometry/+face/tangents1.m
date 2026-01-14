function [header, tangent1] = tangents1(meshInput, varargin)
%TANGENTS1 Compute first tangent vector for each face
%
% Syntax:
%   [header, tangent1] = bct.manifold.geometry.face.tangents1(M)
%   [header, tangent1] = bct.manifold.geometry.face.tangents1(V, F)
%
% Inputs:
%   M    - bct.Manifold object
%   OR
%   V    - [Nv×3] vertex coordinates
%   F    - [Nf×3] face connectivity (1-indexed)
%
% Outputs:
%   header   - Structure containing:
%              .method - 'edge'
%   tangent1 - [Nf×3] first tangent vectors (unit, along first edge projected to tangent plane)
%
% Description:
%   Computes the first tangent vector for each face along the direction
%   of the first edge (v2-v1), projected to the tangent plane and normalized.
%
% Examples:
%   M = bct.Manifold(V, F);
%   [header, T1] = bct.manifold.geometry.face.tangents1(M);
%
% See also: bct.manifold.geometry.face.tangents2,
%           bct.manifold.geometry.face.normals

% Parse inputs
if isa(meshInput, 'bct.Manifold')
    V = meshInput.Vertices;
    F = meshInput.Faces;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    V = meshInput;
    F = varargin{1};
else
    error('bct:manifold:geometry:face:tangents1:InvalidInput', ...
        'Input must be either tangents1(M) or tangents1(V, F).');
end

% Get face normals
[~, normals] = bct.manifold.geometry.face.normals(meshInput, varargin{:});

% Get first edge direction (v2 - v1)
v1 = V(F(:,1), :);
v2 = V(F(:,2), :);
edge = v2 - v1;

% Project edge to tangent plane
tangent1 = edge - sum(edge .* normals, 2) .* normals;
tangent1 = normalizeRows(tangent1);

% Build header
header = struct();
header.method = 'edge';

end

% ===== Helper: normalize each row safely =====
function X = normalizeRows(X)
    n = vecnorm(X, 2, 2);
    bad = (n < eps) | isnan(n);
    n(bad) = 1;
    X = X ./ n;
    X(bad,:) = 0;
end
