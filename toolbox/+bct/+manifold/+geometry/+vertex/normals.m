function [header, N] = normals(meshInput, varargin)
%NORMALS Compute vertex normals of a triangular mesh
%
% Syntax:
%   [header, N] = bct.manifold.geometry.vertex.normals(M)
%   [header, N] = bct.manifold.geometry.vertex.normals(V, F)
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
%   N - [Nv×3] vertex normals (unit vectors)
%
% Description:
%   Computes unit normal vectors at each mesh vertex. Vertex normals are
%   computed as area-weighted averages of adjacent face normals.
%
%   For Manifold objects, uses cached frames from bct.manifold.geometry.frame()
%   for efficiency. For V,F inputs, uses surfaceMesh.computeNormals().
%
%   Vertex normals provide smooth shading interpolation and are commonly used
%   for visualization and differential geometry computations.
%
% Examples:
%   % Vertex normals from Manifold object
%   M = bct.Manifold(V, F);
%   [header, VN] = bct.manifold.geometry.vertex.normals(M);
%
%   % Vertex normals from V, F directly
%   [header, VN] = bct.manifold.geometry.vertex.normals(V, F);
%
%   % Visualize vertex normals
%   [~, VN] = bct.manifold.geometry.vertex.normals(M);
%   quiver3(V(:,1), V(:,2), V(:,3), VN(:,1), VN(:,2), VN(:,3));
%
% See also: bct.manifold.geometry.face.normals, bct.manifold.geometry.frame,
%           bct.manifold.geometry.tangents

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:manifold:geometry:vertex:normals:NoInput', ...
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
        error('bct:manifold:geometry:vertex:normals:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:manifold:geometry:vertex:normals:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:manifold:geometry:vertex:normals:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:manifold:geometry:vertex:normals:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end
else
    error('bct:manifold:geometry:vertex:normals:InvalidInput', ...
        'Input must be either normals(M) or normals(V, F). Got %s.', class(meshInput));
end

% ----------------------------
% Compute vertex normals
% ----------------------------
if useManifold
    % Use cached frames for Manifold objects (efficient)
    fr = bct.manifold.geometry.frame(meshInput);
    N = fr.Vertex.N;
    method = 'frame';
else
    % For V, F inputs, compute directly using surfaceMesh
    mesh = surfaceMesh(V, F);
    computeNormals(mesh, "vertex");
    N = mesh.VertexNormals;
    method = 'surfaceMesh';
end

% Build header
header = struct();
header.method = method;

end
