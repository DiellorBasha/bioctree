function R = check(meshOrManifold, options)
%CHECK Comprehensive health check for mesh or Manifold.
%
%   R = bct.manifold.health.check(meshOrManifold, options)
%
% Primary entry point for mesh health validation. Detects structural issues,
% topological problems, and geometric degeneracies.
%
% Inputs
%   meshOrManifold : bct.Manifold, F, {V,F}, or (V,F)
%
% Name-Value Parameters
%   Level             : "quick" | "standard" | "full" (default: "standard")
%                       - quick: topology only (indices, degeneracy, manifoldness)
%                       - standard: quick + orientation + boundary + geometry
%                       - full: standard + self-intersection + quality metrics
%   Checks            : string array to override Level selection
%                       Valid: ["topology", "orientation", "boundary", "geometry"]
%   RequireManifold   : logical, error on non-manifold edges (default: true)
%   RequireOriented   : logical, error on orientation conflicts (default: true)
%   RequireClosed     : logical, error on boundary edges (default: false)
%   FailOnWarnings    : logical, set ok=false for warnings (default: false)
%   ToleranceArea     : double, area threshold for degeneracy (default: auto)
%   ToleranceEdge     : double, edge length threshold (default: 0)
%   MaxIssuesPerClass : int, max indices to store per issue (default: 50)
%   Verbose           : logical, store additional data (default: false)
%   ReturnEarlyOnError: logical, stop after first error (default: false)
%
% Output
%   R : Report struct with fields:
%     .ok       : logical, overall pass/fail
%     .severity : "ok" | "warn" | "error"
%     .scope    : "bct.manifold.health"
%     .level    : check level performed
%     .summary  : string array of high-level messages
%     .issues   : struct array of detected issues
%     .stats    : mesh statistics
%     .timing   : performance timers
%     .data     : optional cached data (if Verbose)
%
% Example
%   % Quick topology check for DEC
%   R = bct.manifold.health.check(M, 'Level', "quick");
%   assert(R.ok, 'Mesh failed health check');
%
%   % Standard check with boundary allowed
%   R = bct.manifold.health.check({V,F}, 'Level', "standard", ...
%       'RequireClosed', false);
%   disp(bct.manifold.health.report(R));
%
% See also: bct.manifold.health.topology, bct.manifold.health.report

arguments
    meshOrManifold
    options.Level (1,1) string {mustBeMember(options.Level, ...
        ["quick", "standard", "full"])} = "standard"
    options.Checks (1,:) string = string.empty
    options.RequireManifold (1,1) logical = true
    options.RequireOriented (1,1) logical = true
    options.RequireClosed (1,1) logical = false
    options.FailOnWarnings (1,1) logical = false
    options.ToleranceArea (1,1) double = nan
    options.ToleranceEdge (1,1) double = 0
    options.MaxIssuesPerClass (1,1) {mustBeInteger, mustBePositive} = 50
    options.Verbose (1,1) logical = false
    options.ReturnEarlyOnError (1,1) logical = false
end

% Start timing
tStart = tic;

% Normalize input
mesh = bct.manifold.health.internal.normalizeInput(meshOrManifold);

% Initialize master report
stats = struct('nV', mesh.nV, 'nF', mesh.nF);
R = bct.manifold.health.internal.newReport("bct.manifold.health", options.Level, stats);

% Determine which checks to run based on Level
if isempty(options.Checks)
    checks = selectChecks(options.Level);
else
    checks = options.Checks;
end

% Run each check in sequence
for i = 1:length(checks)
    checkName = checks(i);
    
    switch checkName
        case "topology"
            Ri = bct.manifold.health.topology(meshOrManifold, ...
                'RequireManifold', options.RequireManifold, ...
                'RequireClosed', options.RequireClosed, ...
                'MaxIssuesPerClass', options.MaxIssuesPerClass, ...
                'Verbose', options.Verbose);
            
        case "orientation"
            % Placeholder: not yet implemented
            Ri = placeholderReport("bct.manifold.health.orientation", options.Level);
            
        case "boundary"
            % Placeholder: not yet implemented
            Ri = placeholderReport("bct.manifold.health.boundary", options.Level);
            
        case "geometry"
            % Placeholder: not yet implemented (requires V)
            if mesh.hasV
                Ri = placeholderReport("bct.manifold.health.geometry", options.Level);
            else
                % Skip geometry checks if no vertices
                continue;
            end
            
        otherwise
            warning('bct:manifold:health:check:UnknownCheck', ...
                'Unknown check type: %s', checkName);
            continue;
    end
    
    % Merge report
    R = mergeReports(R, Ri);
    
    % Early return on error if requested
    if options.ReturnEarlyOnError && R.severity == "error"
        R.summary = [R.summary; sprintf("Stopped early after %s check", checkName)];
        break;
    end
end

% Apply FailOnWarnings policy
if options.FailOnWarnings && R.severity == "warn"
    R.ok = false;
end

% Record timing
R.timing.total = toc(tStart);

% Generate summary if not already set
if isempty(R.summary) && R.ok
    R.summary = sprintf("All checks passed (%s level)", options.Level);
end

end

%% Helper functions

function checks = selectChecks(level)
%SELECTCHECKS Determine check list based on level.

switch level
    case "quick"
        checks = ["topology"];
    case "standard"
        checks = ["topology", "orientation", "boundary", "geometry"];
    case "full"
        checks = ["topology", "orientation", "boundary", "geometry"];
    otherwise
        checks = ["topology"];
end

end

function R = placeholderReport(scope, level)
%PLACEHOLDERREPORT Create empty report for unimplemented checks.

R = bct.manifold.health.internal.newReport(scope, level, struct());
R.summary = sprintf("%s: not yet implemented", scope);

end

function Rmerged = mergeReports(R1, R2)
%MERGEREPORTS Combine two health check reports.

Rmerged = R1;

% Merge issues
if ~isempty(R2.issues)
    if isempty(Rmerged.issues)
        Rmerged.issues = R2.issues;
    else
        Rmerged.issues = [Rmerged.issues, R2.issues];
    end
end

% Update severity and ok
if R2.severity == "error"
    Rmerged.severity = "error";
    Rmerged.ok = false;
elseif R2.severity == "warn" && Rmerged.severity == "ok"
    Rmerged.severity = "warn";
end

% Merge summary
if ~isempty(R2.summary)
    Rmerged.summary = [Rmerged.summary; R2.summary];
end

% Merge stats (R2 overwrites R1)
fields = fieldnames(R2.stats);
for i = 1:length(fields)
    Rmerged.stats.(fields{i}) = R2.stats.(fields{i});
end

% Merge data (R2 overwrites R1)
fields = fieldnames(R2.data);
for i = 1:length(fields)
    Rmerged.data.(fields{i}) = R2.data.(fields{i});
end

% Merge timing
fields = fieldnames(R2.timing);
for i = 1:length(fields)
    Rmerged.timing.(fields{i}) = R2.timing.(fields{i});
end

end
