function h = check(meshOrManifold, options)
%CHECK Modular mesh health aggregator with canonical edge indexing
%
% Syntax:
%   h = bct.manifold.health.check(meshOrManifold)
%   h = bct.manifold.health.check(M, Name, Value)
%
% Primary entry point for mesh health validation using modular measure/check architecture.
% All edge-indexed outputs refer to canonical edge list (M.Edges when input is bct.Manifold).
%
% Inputs:
%   meshOrManifold - bct.Manifold (preferred), F, {V,F}, or (V,F)
%
% Name-Value Parameters:
%   Level             - "quick" | "standard" (default) | "full"
%                       * quick: topology (faces, degeneracy, manifoldness, boundary)
%                       * standard: quick + orientation + directed duplicates
%                       * full: standard + vertex manifoldness + outward orientation
%   RequireManifold   - logical, error on non-manifold edges (default: true)
%   RequireOriented   - logical, error on orientation inconsistency (default: true)
%   RequireClosed     - logical, error on boundary edges (default: false)
%   FailOnWarnings    - logical, set ok=false for warnings (default: false)
%   Verbose           - logical, store canonical E and index sets in h.data (default: false)
%   UseSurfaceMesh    - logical, use surfaceMesh for vertex manifoldness (default: true)
%
% Outputs:
%   h - Report structure with fields:
%     .ok          - logical, overall pass/fail
%     .severity    - "ok" | "warn" | "error"
%     .scope       - "bct.manifold.health"
%     .level       - check level performed
%     .summary     - string array of high-level messages
%     .issues      - struct array of detected issues
%     .is          - canonical boolean flags (NEW):
%                    .facesValid, .facesNondegenerate, .hasDuplicateFaces,
%                    .hasDuplicateDirectedEdges, .edgeManifold, .hasBoundary,
%                    .oriented, .vertexManifold, .outward
%     .stats       - mesh statistics (nV, nF, nE, nBoundaryEdges, etc.)
%     .statsByCheck- detailed stats grouped by check (avoids collisions)
%     .timing      - performance timers
%     .data        - optional cached data (canonical E, index sets if Verbose)
%
% Description:
%   Performs comprehensive mesh health validation using modular architecture:
%   
%   1. Normalizes input, prioritizing bct.Manifold
%   2. Establishes canonical edge list E from M.Edges (or derives from F)
%   3. Runs gating checks (facesValid, degenerateFaces)
%   4. Builds edge incidence cache (ic, multiplicity, dE)
%   5. Runs checks per Level using modular +measure/+check architecture
%   6. Populates h.is flags and aggregates issues
%
%   All edge-based outputs (boundary, non-manifold, inconsistent) are
%   indices into canonical E (M.Edges when input is bct.Manifold).
%
% Examples:
%   % Quick DEC gating check
%   h = bct.manifold.health.check(M, 'Level', 'quick');
%   assert(h.is.facesValid && h.is.edgeManifold && h.is.oriented);
%   
%   % Standard check with boundary allowed
%   h = bct.manifold.health.check(M, 'RequireClosed', false);
%   if h.is.hasBoundary
%       fprintf('Mesh has %d boundary edges\n', h.stats.nBoundaryEdges);
%   end
%   
%   % Full check with debug data
%   h = bct.manifold.health.check(M, 'Level', 'full', 'Verbose', true);
%   % h.data contains canonical E and all index sets
%
% See also: bct.manifold.health.measure, bct.manifold.health.check,
%           bct.manifold.health.internal.buildEdgeIncidence

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

arguments
    meshOrManifold
    options.Level (1,1) string {mustBeMember(options.Level, ...
        ["quick", "standard", "full"])} = "standard"
    options.RequireManifold (1,1) logical = true
    options.RequireOriented (1,1) logical = true
    options.RequireClosed (1,1) logical = false
    options.FailOnWarnings (1,1) logical = false
    options.Verbose (1,1) logical = false
    options.UseSurfaceMesh (1,1) logical = true
end

% Start timing
tStart = tic;

% Step 1: Normalize input
mesh = bct.manifold.health.internal.normalizeInput(meshOrManifold);

% Step 2: Establish canonical edges (uses M.Edges if available, else derives from F)
mesh = bct.manifold.health.internal.ensureCanonicalEdges(mesh);

% Step 3: Initialize report structure
h = struct();
h.ok = true;
h.severity = "ok";
h.scope = "bct.manifold.health";
h.level = options.Level;
h.summary = string.empty;
h.issues = struct([]);
h.is = struct();  % Will be populated by computeIsFlags
h.stats = struct('nV', mesh.nV, 'nF', mesh.nF, 'nE', mesh.nE);
h.statsByCheck = struct();
h.timing = struct();
h.data = struct();

% Initialize collections
allIssues = {};
allIsUpdates = {};
cache = struct();

% Step 4: Gating checks (must pass to build edge incidence)
tGating = tic;

% Check: faces valid
[issues, isUpdate, statsUpdate, dataUpdate] = bct.manifold.health.check.faces(mesh, options, cache);
allIssues{end+1} = issues;
allIsUpdates{end+1} = isUpdate;
h.statsByCheck.faces = statsUpdate;
if options.Verbose
    h.data.faces = dataUpdate;
end

% Check: degenerate faces
[issues, isUpdate, statsUpdate, dataUpdate] = bct.manifold.health.check.degenerateFaces(mesh, options, cache);
allIssues{end+1} = issues;
allIsUpdates{end+1} = isUpdate;
h.statsByCheck.degenerateFaces = statsUpdate;
if options.Verbose
    h.data.degenerateFaces = dataUpdate;
end

h.timing.gating = toc(tGating);

% Early exit if gating checks failed
if ~isUpdate.facesNondegenerate || ~h.is.facesValid
    h.issues = bct.manifold.health.internal.mergeIssues(allIssues{:});
    h.is = bct.manifold.health.internal.computeIsFlags(allIsUpdates);
    [h.ok, h.severity] = computeOverallStatus(h.issues, options.FailOnWarnings);
    h.summary = generateSummary(h);
    h.timing.total = toc(tStart);
    return;
end

% Step 5: Build canonical edge incidence cache
tCache = tic;
try
    [cache.ic, cache.multiplicity, cache.dE, cache.uE] = ...
        bct.manifold.health.internal.buildEdgeIncidence(mesh.F, mesh.E);
catch ME
    % Edge incidence build failed (should not happen if faces valid)
    h.issues = bct.manifold.health.internal.issue(...
        'edgeIncidenceFailed', 'error', ...
        sprintf('Edge incidence mapping failed: %s', ME.message), 'edges');
    h.is = bct.manifold.health.internal.computeIsFlags(allIsUpdates);
    [h.ok, h.severity] = computeOverallStatus(h.issues, options.FailOnWarnings);
    h.summary = generateSummary(h);
    h.timing.total = toc(tStart);
    return;
end
h.timing.cacheBuilding = toc(tCache);

% Store canonical E in data if verbose
if options.Verbose
    h.data.canonicalEdges = mesh.E;
end

% Step 6: Run checks based on Level
tChecks = tic;

% Always run (quick level and above)
runCheckAndCollect('duplicateFaces', mesh, options, cache);

% Multiplicity-based checks (quick level and above)
runCheckAndCollect('boundaryEdges', mesh, options, cache);
runCheckAndCollect('nonManifoldEdges', mesh, options, cache);

% Standard level and above
if ismember(options.Level, ["standard", "full"])
    runCheckAndCollect('oriented', mesh, options, cache);
    runCheckAndCollect('duplicateDirectedEdges', mesh, options, cache);
end

% Full level only
if options.Level == "full"
    % Vertex manifoldness (requires V and surfaceMesh)
    if mesh.hasV
        runCheckAndCollect('vertexManifold', mesh, options, cache);
    end
    
    % Outward orientation (requires V)
    if mesh.hasV
        runCheckAndCollect('outward', mesh, options, cache);
    end
end

h.timing.checks = toc(tChecks);

% Step 7: Aggregate results
h.issues = bct.manifold.health.internal.mergeIssues(allIssues{:});
h.is = bct.manifold.health.internal.computeIsFlags(allIsUpdates);

% Step 8: Compute rollup stats
h.stats.nBoundaryEdges = 0;
h.stats.nInteriorEdges = 0;
h.stats.nNonManifoldEdges = 0;
h.stats.nInconsistentEdges = 0;

if isfield(h.statsByCheck, 'boundaryEdges')
    h.stats.nBoundaryEdges = h.statsByCheck.boundaryEdges.nBoundaryEdges;
end
if isfield(h.statsByCheck, 'nonManifoldEdges')
    h.stats.nNonManifoldEdges = h.statsByCheck.nonManifoldEdges.nNonManifoldEdges;
end
if isfield(h.statsByCheck, 'oriented')
    h.stats.nInconsistentEdges = h.statsByCheck.oriented.nInconsistentEdges;
end
h.stats.nInteriorEdges = mesh.nE - h.stats.nBoundaryEdges - h.stats.nNonManifoldEdges;

% Step 9: Compute overall status
[h.ok, h.severity] = computeOverallStatus(h.issues, options.FailOnWarnings);

% Step 10: Generate summary
h.summary = generateSummary(h);

% Step 11: Record total timing
h.timing.total = toc(tStart);

%% Nested helper function for check invocation
    function runCheckAndCollect(checkName, mesh, options, cache)
        % Run a check wrapper and collect results
        checkFn = str2func(sprintf('bct.manifold.health.check.%s', checkName));
        [issues, isUpdate, statsUpdate, dataUpdate] = checkFn(mesh, options, cache);
        
        allIssues{end+1} = issues;
        allIsUpdates{end+1} = isUpdate;
        h.statsByCheck.(checkName) = statsUpdate;
        
        if options.Verbose && ~isempty(fieldnames(dataUpdate))
            h.data.(checkName) = dataUpdate;
        end
    end

end

%% Helper functions

function [ok, severity] = computeOverallStatus(issues, failOnWarnings)
%COMPUTEOVERALLSTATUS Determine ok and severity from issues

if isempty(issues)
    ok = true;
    severity = "ok";
    return;
end

% Check for errors
hasError = any(arrayfun(@(iss) iss.severity == "error", issues));
hasWarn = any(arrayfun(@(iss) iss.severity == "warn", issues));

if hasError
    ok = false;
    severity = "error";
elseif hasWarn
    if failOnWarnings
        ok = false;
    else
        ok = true;
    end
    severity = "warn";
else
    ok = true;
    severity = "ok";
end

end

function summary = generateSummary(h)
%GENERATESUMMARY Create high-level summary from h.is flags and issues

lines = string.empty;

if h.ok && isempty(h.issues)
    lines(end+1) = sprintf("All checks passed (%s level)", h.level);
else
    % Report issues
    nErrors = sum(arrayfun(@(iss) iss.severity == "error", h.issues));
    nWarns = sum(arrayfun(@(iss) iss.severity == "warn", h.issues));
    
    if nErrors > 0
        lines(end+1) = sprintf("%d error(s) detected", nErrors);
    end
    if nWarns > 0
        lines(end+1) = sprintf("%d warning(s) detected", nWarns);
    end
    
    % Key failures
    if isfield(h.is, 'facesValid') && ~h.is.facesValid
        lines(end+1) = "Invalid face indices";
    end
    if isfield(h.is, 'edgeManifold') && ~h.is.edgeManifold
        lines(end+1) = sprintf("Non-manifold edges (%d)", h.stats.nNonManifoldEdges);
    end
    if isfield(h.is, 'oriented') && ~h.is.oriented
        lines(end+1) = sprintf("Inconsistent orientation (%d edges)", h.stats.nInconsistentEdges);
    end
    if isfield(h.is, 'hasBoundary') && h.is.hasBoundary
        lines(end+1) = sprintf("Boundary detected (%d edges)", h.stats.nBoundaryEdges);
    end
end

summary = lines;

end
