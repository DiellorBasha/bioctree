function [header, C] = centroids(meshInput, varargin)
%CENTROIDS Compute face centroids of a triangular mesh
%
% Syntax:
%   [header, C] = bct.manifold.geometry.face.centroids(M)
%   [header, C] = bct.manifold.geometry.face.centroids(V, F)
%
% Inputs:
%   M - bct.Manifold object
%   OR
%   V - [N×3] vertex coordinates
%   F - [nF×3] face connectivity (1-indexed)
%
% Outputs:
%   header - Structure containing:
%            .method - 'barycentric'
%   C - [nF×3] matrix of face centroids where nF is number of faces
%
% Description:
%   Computes the geometric center (centroid) of each triangular face
%   as the average of its three vertex positions.
%
% Examples:
%   % From Manifold object
%   M = bct.Manifold(V, F);
%   [header, C] = bct.manifold.geometry.face.centroids(M);
%
%   % From V, F directly
%   [header, C] = bct.manifold.geometry.face.centroids(V, F);
%
%   % Visualize centroids
%   [~, C] = bct.manifold.geometry.face.centroids(M);
%   plot3(C(:,1), C(:,2), C(:,3), 'r.');
%
% See also: bct.manifold.geometry.face.areas, bct.manifold.geometry.normals

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:geometry:face:centroids:NoInput', ...
        'At least one input required: centroids(M) or centroids(V, F)');
end

% Check if first argument is Manifold, surfaceMesh, or numeric
if isa(meshInput, 'surfaceMesh')
    % Case: centroids(surfaceMesh) - optimization path
    V = meshInput.Vertices;
    F = meshInput.Faces;
elseif isa(meshInput, 'bct.Manifold')
    % Case: centroids(M)
    V = meshInput.Vertices;
    F = meshInput.Faces;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % Case: centroids(V, F)
    V = meshInput;
    F = varargin{1};
    
    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:geometry:face:centroids:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:geometry:face:centroids:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:geometry:face:centroids:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:geometry:face:centroids:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end
else
    error('bct:geometry:face:centroids:InvalidInput', ...
        'Input must be centroids(M), centroids(surfaceMesh), or centroids(V, F). Got %s.', class(meshInput));
end

% Build header
header = struct();
header.method = 'barycentric';

% Compute centroids as average of three vertices
C = (V(F(:,1),:) + V(F(:,2),:) + V(F(:,3),:)) / 3;

end
