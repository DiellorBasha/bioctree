function [header, N] = normals(meshInput, varargin)
%NORMALS Compute face normals of a triangular mesh
%
% Syntax:
%   [header, N] = bct.manifold.geometry.face.normals(M)
%   [header, N] = bct.manifold.geometry.face.normals(V, F)
%
% Inputs:
%   M    - bct.Manifold object
%   OR
%   V    - [Nv×3] vertex coordinates
%   F    - [Nf×3] face connectivity (1-indexed)
%
% Outputs:
%   header - Structure containing:
%            .method - 'frame' (Manifold) or 'surfaceMesh' (V,F)
%   N - [Nf×3] face normals (unit vectors perpendicular to face plane)
%
% Description:
%   Computes unit normal vectors perpendicular to each triangular face.
%   For Manifold objects, uses cached frames from bct.manifold.geometry.frame()
%   for efficiency. For V,F inputs, uses surfaceMesh.computeNormals().
%
%   Face normals are computed using the cross product of two triangle edges
%   and normalized to unit length.
%
% Examples:
%   % Face normals from Manifold object
%   M = bct.Manifold(V, F);
%   [header, FN] = bct.manifold.geometry.face.normals(M);
%
%   % Face normals from V, F directly
%   [header, FN] = bct.manifold.geometry.face.normals(V, F);
%
%   % Visualize face normals at face centroids
%   [~, FN] = bct.manifold.geometry.face.normals(M);
%   [~, C] = bct.manifold.geometry.face.centroids(M);
%   quiver3(C(:,1), C(:,2), C(:,3), FN(:,1), FN(:,2), FN(:,3));
%
% See also: bct.manifold.geometry.vertex.normals, bct.manifold.geometry.frame,
%           bct.manifold.geometry.face.centroids, bct.manifold.geometry.tangents

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:manifold:geometry:face:normals:NoInput', ...
        'At least one input required: normals(M) or normals(V, F)');
end

% Check if first argument is Manifold or numeric
useManifold = false;
if isa(meshInput, 'bct.Manifold')
    % Case: normals(M)
    useManifold = true;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % Case: normals(V, F)
    V = meshInput;
    F = varargin{1};
    
    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:manifold:geometry:face:normals:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:manifold:geometry:face:normals:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:manifold:geometry:face:normals:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:manifold:geometry:face:normals:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end
else
    error('bct:manifold:geometry:face:normals:InvalidInput', ...
        'Input must be either normals(M) or normals(V, F). Got %s.', class(meshInput));
end

% ----------------------------
% Compute face normals
% ----------------------------
if useManifold
    % Use cached frames for Manifold objects (efficient)
    fr = bct.manifold.geometry.frame(meshInput);
    N = fr.Face.N;
    method = 'frame';
else
    % For V, F inputs, compute directly using surfaceMesh
    mesh = surfaceMesh(V, F);
    computeNormals(mesh, "face");
    N = mesh.FaceNormals;
    method = 'surfaceMesh';
end

% Build header
header = struct();
header.method = method;

end
