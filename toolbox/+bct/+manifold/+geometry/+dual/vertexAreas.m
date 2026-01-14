function [header, vertexAreas] = vertexAreas(meshInput, options)
%VERTEXAREAS Compute circumcentric dual cell area for each vertex.
%
%   [header, A] = bct.manifold.geometry.dual.vertexAreas(M)
%   [header, A] = bct.manifold.geometry.dual.vertexAreas(V, F)
%   [header, A] = bct.manifold.geometry.dual.vertexAreas(__, Name, Value)
%
% Inputs
%   M : bct.Manifold object
%   OR
%   V, F : Vertices [NÃ—3] and Faces [nFÃ—3] (can be passed as {V, F} cell)
%
% Name-Value Parameters
%   dualCellType        : 'circumcentric' (default)
%   boundaryPolicy      : 'error' (default)
%   circumcenterMethod  : 'native' (default) | 'triangulation'
%   precision           : 'double' (default) | 'single'
%
% Outputs
%   header : struct with fields
%     .dualCellType      : type of dual cell
%     .boundaryPolicy    : boundary handling policy
%     .circumcenterMethod : method for circumcenters
%     .precision         : precision used
%     .numberOfNonPositiveDualVertexAreas : diagnostic count
%   vertexAreas : [nV × 1] dual cell area per vertex
%
% Dual Cell Definition (Circumcentric)
%   For each vertex, the dual cell area is computed by summing contributions
%   from incident faces. Each face contributes the area of triangles formed
%   by: vertex, adjacent edge midpoint, face circumcenter.
%
% Non-Positive Areas
%   Circumcentric dual areas can be non-positive for non-Delaunay
%   triangulations. This function faithfully returns computed values and
%   reports the count of non-positive entries in the header.
%
% Boundary Policy (Iteration 1)
%   'error' : Throws error if boundary edges exist (default)
%   Future: 'midpoint', 'voronoi', 'mixed', etc.
%
% Prerequisites
%   - Closed manifold mesh (no boundary edges)
%   - Consistent orientation
%   - Non-degenerate faces
%
% Example
%   [header, A] = bct.manifold.geometry.dual.vertexAreas(M);
%   totalDualArea = sum(A);
%
% See also: bct.manifold.geometry.face.circumcenters, bct.manifold.geometry.dual.edgeLengths

arguments
    meshInput
    options.dualCellType (1,1) string {mustBeMember(options.dualCellType, ...
        ["circumcentric"])} = "circumcentric"
    options.boundaryPolicy (1,1) string {mustBeMember(options.boundaryPolicy, ...
        ["error"])} = "error"
    options.circumcenterMethod (1,1) string {mustBeMember(options.circumcenterMethod, ...
        ["native", "triangulation"])} = "native"
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
    error('bct:manifold:geometry:dualVertexAreas:NoVertices', ...
        'Vertices required to compute dual vertex areas');
end

if nF == 0
    vertexAreas = zeros(0, 1, options.precision);
    header = struct( ...
        'dualCellType', options.dualCellType, ...
        'boundaryPolicy', options.boundaryPolicy, ...
        'circumcenterMethod', options.circumcenterMethod, ...
        'precision', options.precision, ...
        'numberOfNonPositiveDualVertexAreas', 0);
    return;
end

% Get halfedge connectivity
if isa(meshInput, 'bct.Manifold')
    he = meshInput.halfedge();
else
    he = bct.manifold.topology.halfedge(V, F);
end

% Check for boundary edges
nBoundary = sum(he.isBoundary);

if nBoundary > 0 && options.boundaryPolicy == "error"
    error('bct:manifold:geometry:dual:vertexAreas:BoundaryNotSupported', ...
        ['Mesh has %d boundary edges. Circumcentric dual vertex areas require ', ...
         'a closed manifold. Set boundaryPolicy to a supported value when available.'], ...
        nBoundary);
end

% Compute face circumcenters
[~, faceCircumcenters] = bct.manifold.geometry.faceCircumcenters(meshOrManifold, ...
    'method', options.circumcenterMethod, ...
    'precision', 'double');  % Keep double for intermediate computation

% Initialize dual vertex area accumulator
dualVertexAreas = zeros(nV, 1);

% Face-based accumulation
% For each face (v1, v2, v3):
%   - Get face circumcenter C
%   - Compute edge midpoints: m12, m23, m31
%   - Form three triangles:
%     * T1: v1, m12, C, m31
%     * T2: v2, m23, C, m12
%     * T3: v3, m31, C, m23
%   - Add area of each triangle to corresponding vertex

for f = 1:nF
    % Get vertex indices
    v1_idx = F(f, 1);
    v2_idx = F(f, 2);
    v3_idx = F(f, 3);
    
    % Get vertex coordinates
    v1 = V(v1_idx, :);
    v2 = V(v2_idx, :);
    v3 = V(v3_idx, :);
    
    % Get face circumcenter
    C = faceCircumcenters(f, :);
    
    % Compute edge midpoints
    m12 = (v1 + v2) / 2;
    m23 = (v2 + v3) / 2;
    m31 = (v3 + v1) / 2;
    
    % Compute area contributions using triangle areas
    % Triangle area = 0.5 * ||cross(e1, e2)||
    
    % Contribution to v1: quadrilateral (v1, m12, C, m31)
    % Split into two triangles: (v1, m12, C) and (v1, C, m31)
    area_v1_1 = 0.5 * norm(cross(m12 - v1, C - v1));
    area_v1_2 = 0.5 * norm(cross(C - v1, m31 - v1));
    area_v1 = area_v1_1 + area_v1_2;
    
    % Contribution to v2: quadrilateral (v2, m23, C, m12)
    area_v2_1 = 0.5 * norm(cross(m23 - v2, C - v2));
    area_v2_2 = 0.5 * norm(cross(C - v2, m12 - v2));
    area_v2 = area_v2_1 + area_v2_2;
    
    % Contribution to v3: quadrilateral (v3, m31, C, m23)
    area_v3_1 = 0.5 * norm(cross(m31 - v3, C - v3));
    area_v3_2 = 0.5 * norm(cross(C - v3, m23 - v3));
    area_v3 = area_v3_1 + area_v3_2;
    
    % Accumulate to vertex dual areas
    dualVertexAreas(v1_idx) = dualVertexAreas(v1_idx) + area_v1;
    dualVertexAreas(v2_idx) = dualVertexAreas(v2_idx) + area_v2;
    dualVertexAreas(v3_idx) = dualVertexAreas(v3_idx) + area_v3;
end

% Convert precision if requested
if options.precision == "single"
    dualVertexAreas = single(dualVertexAreas);
end

% Count non-positive dual vertex areas (diagnostic)
nonPositiveMask = dualVertexAreas <= 0;
nNonPositive = sum(nonPositiveMask);

% Check for NaN or Inf
invalidMask = isnan(dualVertexAreas) | isinf(dualVertexAreas);
if any(invalidMask)
    invalidIdx = find(invalidMask);
    error('bct:manifold:geometry:dualVertexAreas:InvalidAreas', ...
        '%d vertices have invalid dual areas (NaN or Inf). Sample indices: %s', ...
        length(invalidIdx), mat2str(invalidIdx(1:min(5, end))'));
end

% Build header
header = struct( ...
    'dualCellType', options.dualCellType, ...
    'boundaryPolicy', options.boundaryPolicy, ...
    'circumcenterMethod', options.circumcenterMethod, ...
    'precision', options.precision, ...
    'numberOfNonPositiveDualVertexAreas', nNonPositive ...
);

end
