function [header, normal, tangent1, tangent2] = frame(meshInput, varargin)
%FRAME Compute orthonormal coordinate frame for each face
%
% Syntax:
%   [header, normal, tangent1, tangent2] = bct.manifold.geometry.face.frame(M)
%   [header, normal, tangent1, tangent2] = bct.manifold.geometry.face.frame(V, F)
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
%   normal   - [Nf×3] face normal vectors (unit)
%   tangent1 - [Nf×3] first tangent vectors (unit, orthogonal to normal)
%   tangent2 - [Nf×3] second tangent vectors (unit, orthogonal to normal and tangent1)
%
% Description:
%   Computes right-handed orthonormal coordinate frames {N, T1, T2} for
%   each triangular face on the manifold.
%
%   Frame properties:
%   - normal:   Unit normal vector perpendicular to face
%   - tangent1: Unit tangent along first edge (v2-v1) projected to tangent plane
%   - tangent2: Unit tangent orthogonal to both normal and tangent1
%   - Right-handed: tangent2 = normal × tangent1
%
%   These frames define local coordinate systems for differential operators,
%   vector field decomposition, and tangent space computations on faces.
%
% Examples:
%   % Compute face frames
%   M = bct.Manifold(V, F);
%   [header, normal, tangent1, tangent2] = bct.manifold.geometry.face.frame(M);
%
%   % Visualize frame at face centroids
%   [~, C] = bct.manifold.geometry.face.centroids(M);
%   [~, N, T1, T2] = bct.manifold.geometry.face.frame(M);
%   quiver3(C(:,1), C(:,2), C(:,3), N(:,1), N(:,2), N(:,3), 0.5, 'b');
%   hold on;
%   quiver3(C(:,1), C(:,2), C(:,3), T1(:,1), T1(:,2), T1(:,3), 0.5, 'r');
%   quiver3(C(:,1), C(:,2), C(:,3), T2(:,1), T2(:,2), T2(:,3), 0.5, 'g');
%
% See also: bct.manifold.geometry.vertex.frame, bct.manifold.geometry.face.normals,
%           bct.manifold.geometry.tangents

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:manifold:geometry:face:frame:NoInput', ...
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
        error('bct:manifold:geometry:face:frame:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:manifold:geometry:face:frame:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:manifold:geometry:face:frame:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:manifold:geometry:face:frame:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end
else
    error('bct:manifold:geometry:face:frame:InvalidInput', ...
        'Input must be either frame(M) or frame(V, F). Got %s.', class(meshInput));
end

% ----------------------------
% Compute face frames
% ----------------------------

% Compute face normals
mesh = surfaceMesh(V, F);
computeNormals(mesh, "face");
normal = mesh.FaceNormals;  % [Nf×3], unit

% Compute first tangent: first edge projected to tangent plane
tangent1 = V(F(:,2),:) - V(F(:,1),:);                    % First edge (v2 - v1)
tangent1 = tangent1 - sum(tangent1 .* normal, 2) .* normal;  % Project to tangent plane
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
