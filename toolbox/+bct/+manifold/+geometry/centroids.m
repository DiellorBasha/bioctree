function C = centroids(varargin)
%CENTROIDS Compute face centroids of a triangular mesh
%
% Syntax:
%   C = bct.manifold.geometry.centroids(M)
%   C = bct.manifold.geometry.centroids(V, F)
%
% Inputs:
%   M - bct.Manifold object
%   V - [N×3] vertex coordinates
%   F - [M×3] face connectivity (1-indexed)
%
% Outputs:
%   C - [M×3] matrix of face centroids where M is number of faces
%
% Description:
%   Computes the geometric center (centroid) of each triangular face
%   as the average of its three vertex positions.
%
% Examples:
%   % From Manifold object
%   M = bct.Manifold(V, F);
%   C = bct.manifold.geometry.centroids(M);
%
%   % From V, F directly
%   C = bct.manifold.geometry.centroids(V, F);
%
%   % Visualize centroids
%   C = bct.manifold.geometry.centroids(M);
%   plot3(C(:,1), C(:,2), C(:,3), 'r.');
%
% See also: bct.manifold.geometry.normals, bct.manifold.geometry.tangents

% Parse inputs
if nargin == 1
    % Single argument: Manifold object
    if isa(varargin{1}, 'bct.Manifold')
        M = varargin{1};
        V = M.Vertices;
        F = M.Faces;
    else
        error('bct:geometry:centroids:InvalidInput', ...
            'Single argument must be a bct.Manifold object');
    end
elseif nargin == 2
    % Two arguments: V, F
    V = varargin{1};
    F = varargin{2};
    
    % Validate inputs
    if ~isnumeric(V) || size(V, 2) ~= 3
        error('bct:geometry:centroids:InvalidVertices', ...
            'Vertices must be N×3 numeric array');
    end
    if ~isnumeric(F) || size(F, 2) ~= 3
        error('bct:geometry:centroids:InvalidFaces', ...
            'Faces must be M×3 numeric array');
    end
else
    error('bct:geometry:centroids:InvalidNumArgs', ...
        'Expected 1 (Manifold) or 2 (V, F) input arguments');
end

% Compute centroids as average of three vertices
C = (V(F(:,1),:) + V(F(:,2),:) + V(F(:,3),:)) / 3;

end
