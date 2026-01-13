function [header, faceAreas] = faceAreas(meshOrManifold, options)
%FACEAREAS Compute area of each triangular face.
%
%   [header, faceAreas] = bct.manifold.geometry.faceAreas(meshOrManifold)
%   [header, faceAreas] = bct.manifold.geometry.faceAreas(__, 'precision', p)
%
% Inputs
%   meshOrManifold : bct.Manifold object or {V, F} cell array
%
% Name-Value Parameters
%   precision : 'double' (default) | 'single'
%
% Outputs
%   header : struct with fields
%     .method    : 'crossProduct'
%     .precision : precision used
%   faceAreas : [nF × 1] area of each face
%
% Algorithm
%   For each triangular face (v1, v2, v3):
%     area = 0.5 * ||cross(v2 - v1, v3 - v1)||
%
% Example
%   [header, A] = bct.manifold.geometry.faceAreas(M);
%   totalArea = sum(A);
%
% See also: bct.manifold.geometry, bct.manifold.geometry.edgeLengths

arguments
    meshOrManifold
    options.precision (1,1) string {mustBeMember(options.precision, ...
        ["double", "single"])} = "double"
end

% Normalize input
mesh = bct.manifold.health.internal.normalizeInput(meshOrManifold);
V = mesh.V;
F = mesh.F;
nF = mesh.nF;

% Validate inputs
if ~mesh.hasV
    error('bct:manifold:geometry:faceAreas:NoVertices', ...
        'Vertices required to compute face areas');
end

if nF == 0
    faceAreas = zeros(0, 1, options.precision);
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
faceAreas = 0.5 * sqrt(sum(cp.^2, 2));  % nF × 1

% Convert precision if requested
if options.precision == "single"
    faceAreas = single(faceAreas);
end

% Check for degenerate faces (zero or NaN area)
degenerateMask = isnan(faceAreas) | (faceAreas == 0);
if any(degenerateMask)
    degenerateIdx = find(degenerateMask);
    error('bct:manifold:geometry:faceAreas:DegenerateFaces', ...
        '%d faces have zero or NaN area. Sample indices: %s', ...
        length(degenerateIdx), mat2str(degenerateIdx(1:min(5, end))'));
end

% Build header
header = struct( ...
    'method', "crossProduct", ...
    'precision', options.precision ...
);

end
