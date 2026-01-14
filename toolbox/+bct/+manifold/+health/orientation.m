function R = orientation(meshOrManifold, options)
%ORIENTATION Check orientation consistency and global outward direction (DEPRECATED)
%
%   R = bct.manifold.health.orientation(meshOrManifold, options)
%
% DEPRECATED: This function is superseded by the modular health check architecture.
% Use bct.manifold.health.check() instead, which provides the same functionality
% with improved modularity and canonical edge indexing.
%
% Migration:
%   OLD: R = bct.manifold.health.orientation(M, 'RequireConsistent', true);
%   NEW: h = bct.manifold.health.check(M, 'Level', 'standard', 'RequireOriented', true);
%
% The new check() function returns h.is.oriented flag and h.stats with equivalent data.
%
% Checks performed:
%   1. Orientation consistency across interior edges (combinatorial)
%   2. Global outward vs inward orientation (geometric, requires V)
%
% Orientation Consistency:
%   For each interior edge shared by two faces, checks that the faces
%   traverse the edge in opposite directions (consistent orientation).
%
% Global Outward Orientation:
%   For closed manifolds, determines if face normals point outward (positive
%   signed volume) or inward (negative signed volume). "Outward" is defined
%   as the orientation yielding positive signed enclosed volume computed via
%   sum(dot(a, cross(b, c)))/6 over all faces.
%
% Inputs
%   meshOrManifold : bct.Manifold, F, {V,F}, or (V,F)
%
% Name-Value Parameters
%   Level             : "quick" | "standard" | "full" (default: "standard")
%   RequireConsistent : logical, error on inconsistent edges (default: true)
%   CheckOutward      : logical, perform outwardness test (default: true)
%   RequireOutward    : logical, error on inward orientation (default: false)
%   OutwardMethod     : "volume" | "raycast" | "auto" (default: "auto")
%   VolumeTol         : double, volume threshold for ambiguity (default: 1e-12)
%   MaxIssuesPerClass : int, max indices to store (default: 50)
%   Verbose           : logical, store additional data (default: false)
%
% Output
%   R : Report struct with fields:
%     .stats.nInteriorEdges : count of edges with multiplicity 2
%     .stats.nInconsistentInteriorEdges : count of inconsistent edges
%     .stats.signedVolume : signed enclosed volume (if computed)
%     .stats.outwardStatus : "outward" | "inward" | "unknown"
%
% Example
%   % Check consistency only (F alone)
%   R = bct.manifold.health.orientation(F);
%   
%   % Check consistency and outwardness
%   R = bct.manifold.health.orientation({V,F}, 'RequireOutward', true);
%
% See also: bct.manifold.health.check, bct.manifold.health.topology

arguments
    meshOrManifold
    options.Level (1,1) string {mustBeMember(options.Level, ...
        ["quick", "standard", "full"])} = "standard"
    options.RequireConsistent (1,1) logical = true
    options.CheckOutward (1,1) logical = true
    options.RequireOutward (1,1) logical = false
    options.OutwardMethod (1,1) string {mustBeMember(options.OutwardMethod, ...
        ["volume", "raycast", "auto"])} = "auto"
    options.VolumeTol (1,1) double = 1e-12
    options.MaxIssuesPerClass (1,1) {mustBeInteger, mustBePositive} = 50
    options.Verbose (1,1) logical = false
end

% Normalize input
mesh = bct.manifold.health.internal.normalizeInput(meshOrManifold);
F = mesh.F;
V = mesh.V;
nF = mesh.nF;
hasV = mesh.hasV;

% Issue deprecation warning
warning('bct:manifold:health:orientation:Deprecated', ...
    ['bct.manifold.health.orientation() is deprecated. ', ...
     'Use bct.manifold.health.check() with the new modular architecture instead.']);

% Initialize report
stats = struct('nF', nF);
R = bct.manifold.health.internal.newReport("bct.manifold.health.orientation", options.Level, stats);

% Early return if no faces
if nF == 0
    R.summary = "Empty mesh (no faces)";
    stats.outwardStatus = "unknown";
    return;
end

%% Component A: Orientation consistency (combinatorial)

% Build directed face-edge list in canonical stacking order
dE = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];  % 3*nF x 2

% Compute undirected edge keys
uE = sort(dE, 2);  % undirected representation

% Group by undirected edge
[Euniq, ~, ic] = unique(uE, 'rows');  % canonical undirected edges
counts = accumarray(ic, 1);

nEdges = size(Euniq, 1);
R.stats.nUndirectedEdges = nEdges;

% Classify edges by multiplicity
boundaryEdges = (counts == 1);
interiorEdges = (counts == 2);
nonManifoldEdges = (counts >= 3);

nInterior = sum(interiorEdges);
nBoundary = sum(boundaryEdges);
nNonManifold = sum(nonManifoldEdges);

R.stats.nInteriorEdges = nInterior;
R.stats.nBoundaryEdges = nBoundary;
R.stats.nNonManifoldEdges = nNonManifold;

% Check consistency of interior edges
% For each interior edge, compare the two directed occurrences
[icSorted, perm] = sort(ic);
dESorted = dE(perm, :);

% Find inconsistent interior edges
inconsistentEdges = [];
inconsistentFacePairs = [];

% Scan through sorted groups
edgeIdx = 1;
i = 1;
while i <= length(icSorted)
    currentEdge = icSorted(i);
    
    % Find run of same edge
    j = i;
    while j <= length(icSorted) && icSorted(j) == currentEdge
        j = j + 1;
    end
    runLength = j - i;
    
    % Check if this is an interior edge (multiplicity 2)
    if runLength == 2
        % Get the two directed edges
        dir1 = dESorted(i, :);
        dir2 = dESorted(i+1, :);
        
        % Check if they are identical (inconsistent orientation)
        if isequal(dir1, dir2)
            inconsistentEdges(end+1) = edgeIdx; %#ok<AGROW>
            
            % Map back to face indices
            origIdx1 = perm(i);
            origIdx2 = perm(i+1);
            face1 = mod(origIdx1 - 1, nF) + 1;
            face2 = mod(origIdx2 - 1, nF) + 1;
            inconsistentFacePairs(end+1, :) = [face1, face2]; %#ok<AGROW>
        end
    end
    
    i = j;
    edgeIdx = edgeIdx + 1;
end

nInconsistent = length(inconsistentEdges);
R.stats.nInconsistentInteriorEdges = nInconsistent;

% Issue: Inconsistent edge orientation
if nInconsistent > 0
    severity = ternary(options.RequireConsistent, "error", "warn");
    
    % Clip stored indices
    maxStore = min(nInconsistent, options.MaxIssuesPerClass);
    
    R = bct.manifold.health.internal.addIssue(R, ...
        "inconsistent_edge_orientation", severity, ...
        sprintf("%d interior edges have inconsistent face orientation", nInconsistent), ...
        'count', nInconsistent, ...
        'indices', struct( ...
            'edges', inconsistentEdges(1:maxStore)', ...
            'facePairs', inconsistentFacePairs(1:maxStore, :)), ...
        'details', struct('totalInconsistent', nInconsistent));
end

% Store edge list if verbose
if options.Verbose
    R.data.undirectedEdges = Euniq;
    R.data.edgeMultiplicity = counts;
end

%% Component B: Global outward orientation (geometric)

% Initialize outward status
outwardStatus = "unknown";
signedVolume = nan;

% Check prerequisites for outwardness test
canCheckOutward = options.CheckOutward && hasV && nBoundary == 0 && ...
                  nNonManifold == 0 && nInconsistent == 0;

if options.CheckOutward && ~canCheckOutward
    % Explain why we can't check
    reasons = string.empty;
    if ~hasV
        reasons(end+1) = "vertices not provided";
    end
    if nBoundary > 0
        reasons(end+1) = sprintf("%d boundary edges", nBoundary);
    end
    if nNonManifold > 0
        reasons(end+1) = sprintf("%d non-manifold edges", nNonManifold);
    end
    if nInconsistent > 0
        reasons(end+1) = sprintf("%d inconsistent edges", nInconsistent);
    end
    
    reasonStr = strjoin(reasons, ", ");
    R = bct.manifold.health.internal.addIssue(R, ...
        "outward_orientation_unknown", "warn", ...
        sprintf("Cannot determine outward orientation: %s", reasonStr), ...
        'details', struct('reason', reasonStr));
end

if canCheckOutward
    % Compute signed volume using vectorized formula
    % For each face with vertices a,b,c: Vf = dot(a, cross(b,c)) / 6
    
    % Get vertex coordinates for each face
    a = V(F(:,1), :);  % nF x 3
    b = V(F(:,2), :);  % nF x 3
    c = V(F(:,3), :);  % nF x 3
    
    % Compute cross product b × c
    bc = cross(b, c, 2);  % nF x 3
    
    % Compute dot product a · (b × c)
    abc = sum(a .* bc, 2);  % nF x 1
    
    % Sum and divide by 6
    signedVolume = sum(abc) / 6;
    
    % Compute tolerance based on mesh scale
    bbox = [min(V); max(V)];
    bboxSize = bbox(2,:) - bbox(1,:);
    meshScale = max(bboxSize);
    volumeTol = options.VolumeTol * meshScale^3;
    
    % Determine outward status
    if abs(signedVolume) < volumeTol
        outwardStatus = "unknown";
        R = bct.manifold.health.internal.addIssue(R, ...
            "outward_orientation_unknown", "warn", ...
            sprintf("Signed volume near zero (%.3e), cannot determine orientation", signedVolume), ...
            'details', struct('signedVolume', signedVolume, 'tolerance', volumeTol));
    elseif signedVolume > 0
        outwardStatus = "outward";
    else
        outwardStatus = "inward";
        
        % Issue: Inward orientation
        severity = ternary(options.RequireOutward, "error", "warn");
        R = bct.manifold.health.internal.addIssue(R, ...
            "inward_orientation", severity, ...
            sprintf("Mesh has inward orientation (signed volume: %.6e)", signedVolume), ...
            'details', struct( ...
                'signedVolume', signedVolume, ...
                'recommendation', "Flip all faces by swapping columns 2 and 3 of F"));
    end
end

% Store in stats
R.stats.signedVolume = signedVolume;
R.stats.outwardStatus = outwardStatus;

%% Summary

if R.ok
    if nInconsistent == 0 && outwardStatus == "outward"
        R.summary = sprintf("Consistent outward orientation: %d faces, %d interior edges", nF, nInterior);
    elseif nInconsistent == 0 && outwardStatus == "inward"
        R.summary = sprintf("Consistent but inward orientation: %d faces (flip recommended)", nF);
    elseif nInconsistent == 0
        R.summary = sprintf("Consistent orientation: %d faces, %d interior edges", nF, nInterior);
    end
elseif nInconsistent > 0
    R.summary = sprintf("Inconsistent orientation: %d/%d interior edges", nInconsistent, nInterior);
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
