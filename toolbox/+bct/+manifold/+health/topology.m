function R = topology(meshOrManifold, options)
%TOPOLOGY Check topological properties of a mesh.
%
%   R = bct.manifold.health.topology(meshOrManifold, options)
%
% Checks performed:
%   1. Face format and index validity
%   2. Repeated vertices within faces (degenerate triangles)
%   3. Edge multiplicity (manifoldness: boundary, interior, non-manifold)
%   4. Duplicate faces
%
% Inputs
%   meshOrManifold : bct.Manifold, F, {V,F}, or (V,F)
%   options        : Name-value arguments
%
% Name-Value Parameters
%   RequireManifold : logical, error on non-manifold edges (default: true)
%   RequireClosed   : logical, error on boundary edges (default: false)
%   MaxIssuesPerClass : int, max indices to store per issue (default: 50)
%   Verbose         : logical, store additional data (default: false)
%
% Output
%   R : Report struct (see bct.manifold.health.internal.newReport)
%     R.stats includes:
%       .nV, .nF, .nE
%       .nBoundaryEdges, .nInteriorEdges, .nNonManifoldEdges
%       .edgeMultiplicityHistogram (struct: .m1, .m2, .m3plus)
%
% See also: bct.manifold.health.check, bct.manifold.health.internal.newReport

arguments
    meshOrManifold
    options.RequireManifold (1,1) logical = true
    options.RequireClosed (1,1) logical = false
    options.MaxIssuesPerClass (1,1) {mustBeInteger, mustBePositive} = 50
    options.Verbose (1,1) logical = false
end

% Normalize input
mesh = bct.manifold.health.internal.normalizeInput(meshOrManifold);
F = mesh.F;
nV = mesh.nV;
nF = mesh.nF;

% Initialize report
stats = struct('nV', nV, 'nF', nF);
R = bct.manifold.health.internal.newReport("bct.manifold.health.topology", "quick", stats);

% Early return if no faces
if nF == 0
    R.summary = "Empty mesh (no faces)";
    return;
end

%% Check 1: Face format and index validity

% Check shape
if size(F, 2) ~= 3
    R = bct.manifold.health.internal.addIssue(R, ...
        "invalid_faces_shape", "error", ...
        sprintf("Faces must be M×3, got %d×%d", size(F,1), size(F,2)));
    return; % Cannot proceed
end

% Check for finite numeric indices
if ~all(isfinite(F(:)))
    badFaces = find(any(~isfinite(F), 2));
    R = bct.manifold.health.internal.addIssue(R, ...
        "invalid_faces_indices", "error", ...
        sprintf("%d faces contain NaN or Inf indices", length(badFaces)), ...
        'count', length(badFaces), ...
        'indices', struct('faces', badFaces(1:min(end, options.MaxIssuesPerClass))));
end

% Check for integer indices
if ~all(mod(F(:), 1) == 0)
    badFaces = find(any(mod(F, 1) ~= 0, 2));
    R = bct.manifold.health.internal.addIssue(R, ...
        "invalid_faces_indices", "error", ...
        sprintf("%d faces contain non-integer indices", length(badFaces)), ...
        'count', length(badFaces), ...
        'indices', struct('faces', badFaces(1:min(end, options.MaxIssuesPerClass))));
end

% Check index range if nV is known
if mesh.hasV && nV > 0
    outOfRange = (F < 1) | (F > nV);
    if any(outOfRange(:))
        badFaces = find(any(outOfRange, 2));
        R = bct.manifold.health.internal.addIssue(R, ...
            "invalid_faces_indices", "error", ...
            sprintf("%d faces have indices outside [1, %d]", length(badFaces), nV), ...
            'count', length(badFaces), ...
            'indices', struct('faces', badFaces(1:min(end, options.MaxIssuesPerClass))));
    end
end

% Early return on critical errors
if R.severity == "error"
    return;
end

%% Check 2: Repeated vertices in faces (degenerate)

repeatedMask = (F(:,1) == F(:,2)) | (F(:,2) == F(:,3)) | (F(:,3) == F(:,1));
if any(repeatedMask)
    badFaces = find(repeatedMask);
    R = bct.manifold.health.internal.addIssue(R, ...
        "degenerate_faces_repeated_vertices", "error", ...
        sprintf("%d faces have repeated vertices", length(badFaces)), ...
        'count', length(badFaces), ...
        'indices', struct('faces', badFaces(1:min(end, options.MaxIssuesPerClass))));
end

%% Check 3: Edge multiplicity (manifoldness)

% Build all directed edges, then convert to undirected
allEdges = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];
allEdgesSorted = sort(allEdges, 2);

% Get unique edges and their multiplicities
[E, ~, ic] = unique(allEdgesSorted, 'rows');
multiplicity = accumarray(ic, 1);

nE = size(E, 1);
R.stats.nE = nE;

% Classify edges by multiplicity
boundaryEdges = (multiplicity == 1);
interiorEdges = (multiplicity == 2);
nonManifoldEdges = (multiplicity >= 3);

nBoundary = sum(boundaryEdges);
nInterior = sum(interiorEdges);
nNonManifold = sum(nonManifoldEdges);

R.stats.nBoundaryEdges = nBoundary;
R.stats.nInteriorEdges = nInterior;
R.stats.nNonManifoldEdges = nNonManifold;
R.stats.edgeMultiplicityHistogram = struct( ...
    'm1', nBoundary, ...
    'm2', nInterior, ...
    'm3plus', nNonManifold ...
);

% Store edge list if verbose
if options.Verbose
    R.data.edges = E;
    R.data.multiplicity = multiplicity;
end

% Issue: Non-manifold edges
if nNonManifold > 0
    nonManifoldIdx = find(nonManifoldEdges);
    severity = ternary(options.RequireManifold, "error", "warn");
    maxMult = max(multiplicity(nonManifoldIdx));
    
    R = bct.manifold.health.internal.addIssue(R, ...
        "nonmanifold_edges", severity, ...
        sprintf("%d non-manifold edges (max multiplicity: %d)", nNonManifold, maxMult), ...
        'count', nNonManifold, ...
        'indices', struct('edges', nonManifoldIdx(1:min(end, options.MaxIssuesPerClass))), ...
        'details', struct('maxMultiplicity', maxMult));
end

% Issue: Boundary edges
if nBoundary > 0 && options.RequireClosed
    boundaryIdx = find(boundaryEdges);
    R = bct.manifold.health.internal.addIssue(R, ...
        "boundary_present", "error", ...
        sprintf("%d boundary edges (closed mesh required)", nBoundary), ...
        'count', nBoundary, ...
        'indices', struct('edges', boundaryIdx(1:min(end, options.MaxIssuesPerClass))));
elseif nBoundary > 0
    % Just informational
    R.summary = [R.summary; sprintf("Mesh has %d boundary edges", nBoundary)];
end

%% Check 4: Duplicate faces

% Sort vertices within each face to make order-invariant
Fsorted = sort(F, 2);
[~, uniqueIdx, ic] = unique(Fsorted, 'rows');
faceCounts = accumarray(ic, 1);

duplicateMask = faceCounts > 1;
if any(duplicateMask)
    nDuplicateGroups = sum(duplicateMask);
    nTotalDuplicates = sum(faceCounts(duplicateMask) - 1);
    
    % Find faces that are duplicates (not the first occurrence)
    duplicateFaces = setdiff((1:nF)', uniqueIdx);
    
    R = bct.manifold.health.internal.addIssue(R, ...
        "duplicate_faces", "error", ...
        sprintf("%d duplicate faces (%d groups)", nTotalDuplicates, nDuplicateGroups), ...
        'count', nTotalDuplicates, ...
        'indices', struct('faces', duplicateFaces(1:min(end, options.MaxIssuesPerClass))), ...
        'details', struct('groups', nDuplicateGroups));
end

%% Summary

if R.ok
    if nBoundary == 0
        R.summary = sprintf("Closed manifold: %d vertices, %d faces, %d edges", nV, nF, nE);
    else
        R.summary = sprintf("Manifold with boundary: %d vertices, %d faces, %d edges (%d boundary)", ...
            nV, nF, nE, nBoundary);
    end
end

end

%% Helper function

function result = ternary(condition, trueVal, falseVal)
%TERNARY Ternary conditional operator.
if condition
    result = trueVal;
else
    result = falseVal;
end
end
