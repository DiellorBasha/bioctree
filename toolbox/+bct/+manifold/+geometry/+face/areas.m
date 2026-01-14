function [header, areas] = areas(meshInput, options)
%AREAS Compute area of each triangular face.
%
%   [header, areas] = bct.manifold.geometry.face.areas(M)
%   [header, areas] = bct.manifold.geometry.face.areas(V, F)
%   [header, areas] = bct.manifold.geometry.face.areas(__, 'precision', p)
%
% Inputs
%   M : bct.Manifold object
%   OR
%   V, F : Vertices [N×3] and Faces [nF×3] (can be passed as {V, F} cell)
%
% Name-Value Parameters
%   precision : 'double' (default) | 'single'
%
% Outputs
%   header : struct with fields
%     .method    : 'crossProduct'
%     .precision : precision used
%   areas : [nF × 1] area of each face
%
% Algorithm
%   For each triangular face (v1, v2, v3):
%     area = 0.5 * ||cross(v2 - v1, v3 - v1)||
%
% Example
%   [header, A] = bct.manifold.geometry.face.areas(M);
%   totalArea = sum(A);
%
% See also: bct.manifold.geometry.face.circumcenters, bct.manifold.geometry.centroids

arguments
    meshInput
    options.precision (1,1) string {mustBeMember(options.precision, ...
        ["double", "single"])} = "double"
end

% Normalize input
mesh = bct.manifold.health.internal.normalizeInput(meshInput);
V = mesh.V;
F = mesh.F;
nF = mesh.nF;

% Validate inputs
if ~mesh.hasV
    error('bct:manifold:geometry:face:areas:NoVertices', ...
        'Vertices required to compute face areas');
end

if nF == 0
    areas = zeros(0, 1, options.precision);
    header = struct('method', "crossProduct", 'precision', options.precision);
    return;
end

% Get vertex coordinates for each face
v1 = V(F(:,1), :);  % nF × 3
v2 = V(F(:,2), :);  % nF × 3
v3 = V(F(:,3), :);  % nF × 3

% Compute edge vectors
e1 = v2 - v1;  % nF × 3
e2 = v3 - v1;  % nF × 3

% Cross product (vectorized)
cp = cross(e1, e2, 2);  % nF × 3

% Area = 0.5 * ||cross product||
areas = 0.5 * sqrt(sum(cp.^2, 2));  % nF × 1

% Convert precision if requested
if options.precision == "single"
    areas = single(areas);
end

% Check for degenerate faces (zero or NaN area)
degenerateMask = isnan(areas) | (areas == 0);
if any(degenerateMask)
    degenerateIdx = find(degenerateMask);
    error('bct:manifold:geometry:face:areas:DegenerateFaces', ...
        '%d faces have zero or NaN area. Sample indices: %s', ...
        length(degenerateIdx), mat2str(degenerateIdx(1:min(5, end))'));
end

% Build header
header = struct( ...
    'method', "crossProduct", ...
    'precision', options.precision ...
);

end
