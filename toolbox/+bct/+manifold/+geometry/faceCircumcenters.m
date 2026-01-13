function [header, faceCircumcenters] = faceCircumcenters(meshOrManifold, options)
%FACECIRCUMCENTERS Compute circumcenter of each triangular face.
%
%   [header, C] = bct.manifold.geometry.faceCircumcenters(meshOrManifold)
%   [header, C] = bct.manifold.geometry.faceCircumcenters(__, 'method', m)
%
% Inputs
%   meshOrManifold : bct.Manifold object or {V, F} cell array
%
% Name-Value Parameters
%   method    : 'native' (default) | 'triangulation'
%   precision : 'double' (default) | 'single'
%
% Outputs
%   header : struct with fields
%     .method    : method used
%     .precision : precision used
%   faceCircumcenters : [nF × 3] 3D coordinates of circumcenter per face
%
% Methods
%   'native' : Stable vectorized circumcenter formula
%   'triangulation' : Uses MATLAB's triangulation.circumcenter
%
% Algorithm (native)
%   For triangle with vertices a, b, c:
%     1. Translate to origin: b' = b-a, c' = c-a
%     2. Compute circumcenter in local frame
%     3. Translate back to global frame
%
% Example
%   [header, C] = bct.manifold.geometry.faceCircumcenters(M);
%   plot3(C(:,1), C(:,2), C(:,3), 'r.');
%
% See also: bct.manifold.geometry, bct.manifold.geometry.faceAreas

arguments
    meshOrManifold
    options.method (1,1) string {mustBeMember(options.method, ...
        ["native", "triangulation"])} = "native"
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
    error('bct:manifold:geometry:faceCircumcenters:NoVertices', ...
        'Vertices required to compute face circumcenters');
end

if nF == 0
    faceCircumcenters = zeros(0, 3, options.precision);
    header = struct('method', options.method, 'precision', options.precision);
    return;
end

% Compute circumcenters using selected method
if options.method == "native"
    faceCircumcenters = computeCircumcentersNative(V, F);
else  % "triangulation"
    faceCircumcenters = computeCircumcentersTriangulation(V, F);
end

% Convert precision if requested
if options.precision == "single"
    faceCircumcenters = single(faceCircumcenters);
end

% Check for invalid circumcenters
invalidMask = any(isnan(faceCircumcenters) | isinf(faceCircumcenters), 2);
if any(invalidMask)
    invalidIdx = find(invalidMask);
    error('bct:manifold:geometry:faceCircumcenters:InvalidCircumcenters', ...
        '%d faces have invalid circumcenters (NaN or Inf). Sample indices: %s', ...
        length(invalidIdx), mat2str(invalidIdx(1:min(5, end))'));
end

% Build header
header = struct( ...
    'method', options.method, ...
    'precision', options.precision ...
);

end

%% Helper functions

function C = computeCircumcentersNative(V, F)
%COMPUTECIRCUMCENTERSNATIVE Compute circumcenters using stable vector formula.
%
% For each triangle (a, b, c):
%   1. Translate to origin: b' = b-a, c' = c-a
%   2. Compute: u = b' × c', v = u × b', w = u × c'
%   3. alpha = ||c'||^2 * dot(b', u) / (2 * ||u||^2)
%   4. beta  = ||b'||^2 * dot(c', u) / (2 * ||u||^2)
%   5. circumcenter = a + alpha * b' + beta * c'

nF = size(F, 1);
C = zeros(nF, 3);

% Get vertex coordinates
a = V(F(:,1), :);  % nF × 3
b = V(F(:,2), :);  % nF × 3
c = V(F(:,3), :);  % nF × 3

% Translate to origin
bp = b - a;  % nF × 3
cp = c - a;  % nF × 3

% Compute cross product u = b' × c'
u = cross(bp, cp, 2);  % nF × 3

% Compute squared norms
bp_norm2 = sum(bp.^2, 2);  % nF × 1
cp_norm2 = sum(cp.^2, 2);  % nF × 1
u_norm2 = sum(u.^2, 2);    % nF × 1

% Compute dot products
bp_dot_u = sum(bp .* u, 2);  % nF × 1
cp_dot_u = sum(cp .* u, 2);  % nF × 1

% Compute barycentric-like coordinates
alpha = cp_norm2 .* bp_dot_u ./ (2 * u_norm2);  % nF × 1
beta  = bp_norm2 .* cp_dot_u ./ (2 * u_norm2);  % nF × 1

% Circumcenter in global frame
C = a + alpha .* bp + beta .* cp;  % nF × 3

end

function C = computeCircumcentersTriangulation(V, F)
%COMPUTECIRCUMCENTERSTRIANGULATION Use MATLAB's triangulation object.

try
    TR = triangulation(F, V);
    C = TR.circumcenter();
catch ME
    error('bct:manifold:geometry:faceCircumcenters:TriangulationFailed', ...
        'Failed to compute circumcenters using triangulation: %s', ME.message);
end

end
