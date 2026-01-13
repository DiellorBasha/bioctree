function [header, dualEdgeLengths] = dualEdgeLengths(meshOrManifold, options)
%DUALEDGELENGTHS Compute circumcentric dual edge lengths.
%
%   [header, L] = bct.manifold.geometry.dualEdgeLengths(meshOrManifold)
%   [header, L] = bct.manifold.geometry.dualEdgeLengths(__, Name, Value)
%
% Inputs
%   meshOrManifold : bct.Manifold object or {V, F} cell array
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
%   dualEdgeLengths : [nE × 1] length of dual edge per primal edge
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
%   [header, L] = bct.manifold.geometry.dualEdgeLengths(M);
%   meanDualLength = mean(L);
%
% See also: bct.manifold.geometry.faceCircumcenters, bct.manifold.geometry.dualVertexAreas

arguments
    meshOrManifold
    options.boundaryPolicy (1,1) string {mustBeMember(options.boundaryPolicy, ...
        ["error"])} = "error"
    options.circumcenterMethod (1,1) string {mustBeMember(options.circumcenterMethod, ...
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
    error('bct:manifold:geometry:dualEdgeLengths:NoVertices', ...
        'Vertices required to compute dual edge lengths');
end

if nF == 0
    dualEdgeLengths = zeros(0, 1, options.precision);
    header = struct( ...
        'boundaryPolicy', options.boundaryPolicy, ...
        'circumcenterMethod', options.circumcenterMethod, ...
        'precision', options.precision, ...
        'numberOfBoundaryEdges', 0);
    return;
end

% Get halfedge connectivity
if isa(meshOrManifold, 'bct.Manifold')
    he = meshOrManifold.halfedge();
else
    he = bct.manifold.topology.halfedge(V, F);
end

% Check for boundary edges
nBoundary = sum(he.isBoundary);

if nBoundary > 0 && options.boundaryPolicy == "error"
    error('bct:manifold:geometry:dualEdgeLengths:BoundaryNotSupported', ...
        ['Mesh has %d boundary edges. Circumcentric dual edge lengths require ', ...
         'a closed manifold. Set boundaryPolicy to a supported value when available.'], ...
        nBoundary);
end

% Compute face circumcenters
[~, faceCircumcenters] = bct.manifold.geometry.faceCircumcenters(meshOrManifold, ...
    'method', options.circumcenterMethod, ...
    'precision', 'double');  % Keep double for intermediate computation

% Compute dual edge lengths
nE = size(he.E, 1);
dualEdgeLengths = zeros(nE, 1);

% For each edge, get the two incident faces via halfedge structure
% halfedge h has face he.face(h)
% twin halfedge has face he.face(he.twin(h))
% Edge i corresponds to halfedges in the first nE entries of halfedge array

for i = 1:nE
    % Find a halfedge for this edge
    % Edges are indexed in the stacked order, but we need to map to halfedge ID
    % The halfedge structure has he.edge mapping halfedge -> edge ID
    % We need the reverse: find halfedges with he.edge == i
    
    halfedgesForEdge = find(he.edge == i);
    
    if length(halfedgesForEdge) == 2
        % Interior edge - two incident faces
        h1 = halfedgesForEdge(1);
        h2 = halfedgesForEdge(2);
        
        face1 = he.face(h1);
        face2 = he.face(h2);
        
        % Compute dual edge length
        c1 = faceCircumcenters(face1, :);
        c2 = faceCircumcenters(face2, :);
        
        dualEdgeLengths(i) = norm(c2 - c1);
        
    elseif length(halfedgesForEdge) == 1
        % Boundary edge - should have been caught earlier
        % Set to NaN for now (should not reach here with error policy)
        dualEdgeLengths(i) = nan;
    else
        % Non-manifold or error
        error('bct:manifold:geometry:dualEdgeLengths:InvalidTopology', ...
            'Edge %d has unexpected number of halfedges: %d', i, length(halfedgesForEdge));
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
