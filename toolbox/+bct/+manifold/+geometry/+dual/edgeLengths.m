function [header, edgeLengths] = edgeLengths(meshInput, options)
%EDGELENGTHS Compute circumcentric dual edge lengths.
%
%   [header, L] = bct.manifold.geometry.dual.edgeLengths(M)
%   [header, L] = bct.manifold.geometry.dual.edgeLengths(V, F)
%   [header, L] = bct.manifold.geometry.dual.edgeLengths(__, Name, Value)
%
% Inputs
%   M : bct.Manifold object
%   OR
%   V, F : Vertices [NÃ—3] and Faces [nFÃ—3] (can be passed as {V, F} cell)
%
% Name-Value Parameters
%   boundaryPolicy      : 'error' (default)
%   circumcenterMethod  : 'native' (default) | 'triangulation'
%   precision           : 'double' (default) | 'single'
%
% Outputs
%   header : struct with fields
%     .boundaryPolicy      : boundary handling policy
%     .circumcenterMethod  : method used for circumcenters
%     .precision           : precision used
%     .numberOfBoundaryEdges : diagnostic count
%   edgeLengths : [nE × 1] length of dual edge per primal edge
%
% Dual Edge Definition
%   For each interior primal edge shared by two faces:
%     dual edge connects the two face circumcenters
%     length = ||circumcenter1 - circumcenter2||
%
% Boundary Policy (Iteration 1)
%   'error' : Throws error if boundary edges exist (default)
%   Future: 'midpoint', 'voronoi', etc.
%
% Prerequisites
%   - Closed manifold mesh (no boundary edges)
%   - Consistent orientation
%   - Non-degenerate faces
%
% Example
%   [header, L] = bct.manifold.geometry.dual.edgeLengths(M);
%   meanDualLength = mean(L);
%
% See also: bct.manifold.geometry.face.circumcenters, bct.manifold.geometry.dual.vertexAreas

arguments
    meshInput
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
nF = mesh.nF;

% Validate inputs
if ~mesh.hasV
    error('bct:manifold:geometry:dualEdgeLengths:NoVertices', ...
        'Vertices required to compute dual edge lengths');
end

if nF == 0
    header = struct( ...
        'boundaryPolicy', options.boundaryPolicy, ...
        'circumcenterMethod', options.circumcenterMethod, ...
        'precision', options.precision, ...
        'numberOfBoundaryEdges', 0);
    edgeLengths = zeros(0, 1, options.precision);
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
    error('bct:manifold:geometry:dual:edgeLengths:BoundaryNotSupported', ...
        ['Mesh has %d boundary edges. Circumcentric dual edge lengths require ', ...
         'a closed manifold. Set boundaryPolicy to a supported value when available.'], ...
        nBoundary);
end

% Compute face circumcenters
[~, faceCircumcenters] = bct.manifold.geometry.face.circumcenters(meshInput, ...
    'method', options.circumcenterMethod, ...
    'precision', 'double');  % Keep double for intermediate computation

% Compute dual edge lengths
nE = size(he.edgeList, 1);
dualEdgeLengths = zeros(nE, 1);

% Build reverse mapping from edge ID to halfedges (O(n) construction)
% For each halfedge, we know its edge ID from he.edge
% We store the first two halfedges per edge (should be exactly 2 for interior edges)
nH = length(he.edge);
edgeToHalfedge = zeros(nE, 2, 'uint32');  % [nE×2] first two halfedges per edge
edgeHalfedgeCount = zeros(nE, 1, 'uint8');  % Count of halfedges per edge

for h = 1:nH
    edgeID = he.edge(h);
    count = edgeHalfedgeCount(edgeID) + 1;
    if count <= 2
        edgeToHalfedge(edgeID, count) = h;
    end
    edgeHalfedgeCount(edgeID) = count;
end

% Compute dual edge lengths using the precomputed mapping
for i = 1:nE
    numHalfedges = edgeHalfedgeCount(i);
    
    if numHalfedges == 2
        % Interior edge - two incident faces
        h1 = edgeToHalfedge(i, 1);
        h2 = edgeToHalfedge(i, 2);
        
        face1 = he.face(h1);
        face2 = he.face(h2);
        
        % Compute dual edge length
        c1 = faceCircumcenters(face1, :);
        c2 = faceCircumcenters(face2, :);
        
        dualEdgeLengths(i) = norm(c2 - c1);
        
    elseif numHalfedges == 1
        % Boundary edge - should have been caught earlier
        % Set to NaN for now (should not reach here with error policy)
        dualEdgeLengths(i) = nan;
    else
        % Non-manifold or error
        error('bct:manifold:geometry:dualEdgeLengths:InvalidTopology', ...
            'Edge %d has unexpected number of halfedges: %d', i, numHalfedges);
    end
end

% Convert precision if requested
if options.precision == "single"
    dualEdgeLengths = single(dualEdgeLengths);
end

% Check for invalid dual edges
invalidMask = isnan(dualEdgeLengths) | isinf(dualEdgeLengths);
if any(invalidMask)
    invalidIdx = find(invalidMask);
    error('bct:manifold:geometry:dualEdgeLengths:InvalidDualEdges', ...
        '%d dual edges have invalid lengths (NaN or Inf). Sample indices: %s', ...
        length(invalidIdx), mat2str(invalidIdx(1:min(5, end))'));
end

% Build header
header = struct( ...
    'boundaryPolicy', options.boundaryPolicy, ...
    'circumcenterMethod', options.circumcenterMethod, ...
    'precision', options.precision, ...
    'numberOfBoundaryEdges', nBoundary ...
);

end
