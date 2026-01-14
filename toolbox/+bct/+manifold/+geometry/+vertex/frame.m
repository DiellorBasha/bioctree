function [header, normal, tangent1, tangent2] = frame(meshInput, varargin)
%FRAME Compute orthonormal coordinate frame for each vertex
%
% Syntax:
%   [header, normal, tangent1, tangent2] = bct.manifold.geometry.vertex.frame(M)
%   [header, normal, tangent1, tangent2] = bct.manifold.geometry.vertex.frame(V, F)
%
% Inputs:
%   M    - bct.Manifold object
%   OR
%   V    - [Nv×3] vertex coordinates
%   F    - [Nf×3] face connectivity (1-indexed)
%
% Outputs:
%   header   - Structure containing:
%              .method - 'surfaceMesh'
%   normal   - [Nv×3] vertex normal vectors (unit, area-weighted)
%   tangent1 - [Nv×3] first tangent vectors (unit, orthogonal to normal)
%   tangent2 - [Nv×3] second tangent vectors (unit, orthogonal to normal and tangent1)
%
% Description:
%   Computes right-handed orthonormal coordinate frames {N, T1, T2} for
%   each vertex on the manifold.
%
%   Frame properties:
%   - normal:   Unit normal vector (area-weighted average of adjacent face normals)
%   - tangent1: Unit tangent using robust reference axis projection
%   - tangent2: Unit tangent orthogonal to both normal and tangent1
%   - Right-handed: tangent2 = normal × tangent1
%
%   Vertex tangents use a reference axis ([1,0,0] or [0,1,0]) projected to
%   the tangent plane, ensuring consistent in-plane directions across the mesh.
%
%   These frames define local coordinate systems for differential operators,
%   vector field decomposition, and tangent space computations at vertices.
%
% Examples:
%   % Compute vertex frames
%   M = bct.Manifold(V, F);
%   [header, normal, tangent1, tangent2] = bct.manifold.geometry.vertex.frame(M);
%
%   % Visualize frame at vertices
%   [~, N, T1, T2] = bct.manifold.geometry.vertex.frame(M);
%   quiver3(V(:,1), V(:,2), V(:,3), N(:,1), N(:,2), N(:,3), 0.5, 'b');
%   hold on;
%   quiver3(V(:,1), V(:,2), V(:,3), T1(:,1), T1(:,2), T1(:,3), 0.5, 'r');
%   quiver3(V(:,1), V(:,2), V(:,3), T2(:,1), T2(:,2), T2(:,3), 0.5, 'g');
%
% See also: bct.manifold.geometry.face.frame, bct.manifold.geometry.vertex.normals,
%           bct.manifold.geometry.tangents

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:manifold:geometry:vertex:frame:NoInput', ...
        'At least one input required: frame(M) or frame(V, F)');
end

% Check if first argument is Manifold or numeric
if isa(meshInput, 'bct.Manifold')
    % Case: frame(M)
    V = meshInput.Vertices;
    F = meshInput.Faces;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % Case: frame(V, F)
    V = meshInput;
    F = varargin{1};
    
    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:manifold:geometry:vertex:frame:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:manifold:geometry:vertex:frame:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:manifold:geometry:vertex:frame:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:manifold:geometry:vertex:frame:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end
else
    error('bct:manifold:geometry:vertex:frame:InvalidInput', ...
        'Input must be either frame(M) or frame(V, F). Got %s.', class(meshInput));
end

% ----------------------------
% Compute vertex frames
% ----------------------------

% Compute vertex normals
mesh = surfaceMesh(V, F);
computeNormals(mesh, "vertex");
normal = mesh.VertexNormals;  % [Nv×3], unit (area-weighted)

% Compute first tangent: reference axis projected to tangent plane
nv = size(normal, 1);
ref = repmat([1 0 0], nv, 1);                 % X-axis reference
parallel = abs(sum(ref .* normal, 2)) > 0.9;  % Too aligned with X-axis?
ref(parallel,:) = repmat([0 1 0], sum(parallel), 1);  % Use Y-axis instead

tangent1 = ref - sum(ref .* normal, 2) .* normal;  % Project to tangent plane
tangent1 = normalizeRows(tangent1);

% Compute second tangent: cross product ensures right-handed frame
tangent2 = cross(normal, tangent1, 2);
tangent2 = normalizeRows(tangent2);

% Build header
header = struct();
header.method = 'surfaceMesh';

end

% ===== Helper: normalize each row safely =====
function X = normalizeRows(X)
    n = vecnorm(X, 2, 2);
    bad = (n < eps) | isnan(n);
    n(bad) = 1;          % Prevent divide-by-zero
    X = X ./ n;
    X(bad,:) = 0;        % Zero-out degenerate results
end
