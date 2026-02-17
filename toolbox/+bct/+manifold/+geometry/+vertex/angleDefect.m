function [header, K] = angleDefect(meshInput, options)
%ANGLEDEFECT Compute vertex angle defect (integrated Gaussian curvature)
%
%   [header, K] = bct.manifold.geometry.vertex.angleDefect(M)
%   [header, K] = bct.manifold.geometry.vertex.angleDefect(V, F)
%   [header, K] = bct.manifold.geometry.vertex.angleDefect(__, 'precision', p)
%
% Inputs
%   M : bct.Manifold object
%   OR
%   V, F : Vertices [nV×3] and Faces [nF×3] (can be passed as {V, F} cell)
%
% Name-Value Parameters
%   precision : 'double' (default) | 'single'
%
% Outputs
%   header : struct with fields
%     .method    : 'angleDefect'
%     .precision : precision used
%   K : [nV×1] integrated Gaussian curvature at each vertex
%
% Algorithm
%   For closed surfaces (sphere topology):
%     K(v) = 2π - Σ(angles at vertex v)
%   
%   The angle defect equals the integral of Gaussian curvature over
%   the dual cell (Voronoi region) surrounding each vertex.
%   
%   Corner angles are computed robustly using clamped dot products
%   to avoid numerical issues with acos near ±1.
%
% Notes
%   - Computation starts from face corner angles, then accumulates to vertices
%   - Assumes closed surface (no boundary) - K = 2π - sum(angles)
%   - For surfaces with boundary, modify to K = π - sum(angles) for boundary vertices
%
% Example
%   [header, K] = bct.manifold.geometry.vertex.angleDefect(M);
%   totalCurvature = sum(K);  % Should equal 4π for sphere (Gauss-Bonnet)
%
% See also: bct.manifold.geometry.face.cotan, bct.manifold.geometry.vertex.frame

arguments
    meshInput
    options.precision (1,1) string {mustBeMember(options.precision, ...
        ["double", "single"])} = "double"
end

% Normalize input
mesh = bct.manifold.health.internal.normalizeInput(meshInput);
V = mesh.V;
F = mesh.F;
nV = mesh.nV;
nF = mesh.nF;

% Validate inputs
if ~mesh.hasV
    error('bct:manifold:geometry:vertex:angleDefect:NoVertices', ...
        'Vertices required to compute angle defect');
end

if nF == 0
    K = zeros(nV, 1, options.precision);
    header = struct('method', "angleDefect", 'precision', options.precision);
    return;
end

% Get vertex indices for each face
i1 = F(:,1);
i2 = F(:,2);
i3 = F(:,3);

% Get vertex coordinates for each face corner
v1 = V(i1, :);  % nF × 3
v2 = V(i2, :);  % nF × 3
v3 = V(i3, :);  % nF × 3

% Compute edge vectors from each vertex
% Angle at v1: between edges (v2-v1) and (v3-v1)
a12 = v2 - v1;  % nF × 3
a13 = v3 - v1;  % nF × 3

% Angle at v2: between edges (v1-v2) and (v3-v2)
a21 = v1 - v2;  % nF × 3
a23 = v3 - v2;  % nF × 3

% Angle at v3: between edges (v1-v3) and (v2-v3)
a31 = v1 - v3;  % nF × 3
a32 = v2 - v3;  % nF × 3

% Compute edge lengths with epsilon for numerical stability
eps0 = 1e-14;

len_a12 = sqrt(sum(a12.^2, 2)) + eps0;  % nF × 1
len_a13 = sqrt(sum(a13.^2, 2)) + eps0;
len_a21 = sqrt(sum(a21.^2, 2)) + eps0;
len_a23 = sqrt(sum(a23.^2, 2)) + eps0;
len_a31 = sqrt(sum(a31.^2, 2)) + eps0;
len_a32 = sqrt(sum(a32.^2, 2)) + eps0;

% Compute cosines from dot products
c1 = sum(a12.*a13, 2) ./ (len_a12 .* len_a13);  % nF × 1
c2 = sum(a21.*a23, 2) ./ (len_a21 .* len_a23);
c3 = sum(a31.*a32, 2) ./ (len_a31 .* len_a32);

% Clamp to [-1, 1] to avoid numerical issues with acos
c1 = max(-1, min(1, c1));
c2 = max(-1, min(1, c2));
c3 = max(-1, min(1, c3));

% Compute corner angles
ang1 = acos(c1);  % nF × 1, angle at vertex i1
ang2 = acos(c2);  % nF × 1, angle at vertex i2
ang3 = acos(c3);  % nF × 1, angle at vertex i3

% Accumulate angles at each vertex
sumAngles = accumarray(i1, ang1, [nV 1], @sum, 0) + ...
            accumarray(i2, ang2, [nV 1], @sum, 0) + ...
            accumarray(i3, ang3, [nV 1], @sum, 0);

% Compute angle defect (assumes closed surface, no boundary)
% For sphere: K = 2π - sum(angles)
K = 2*pi - sumAngles;  % nV × 1

% Convert precision if requested
if options.precision == "single"
    K = single(K);
end

% Build header
header = struct();
header.method = "angleDefect";
header.precision = char(options.precision);
header.formula = "K = 2π - Σ(angles)";
header.assumption = "closed_surface";

end
