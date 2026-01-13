function txt = report(R, options)
%REPORT Generate formatted report from health check results.
%
%   txt = bct.manifold.health.report(R, options)
%
% Inputs
%   R       : Report struct from bct.manifold.health.check
%   options : Name-value parameters
%
% Name-Value Parameters
%   Print   : logical, print to console (default: true)
%   MaxIssues : int, max issues to display per type (default: 10)
%   ShowIndices : logical, show sample indices (default: true)
%   Compact : logical, brief format (default: false)
%
% Output
%   txt : string, formatted report text
%
% Example
%   R = bct.manifold.health.check(M);
%   disp(bct.manifold.health.report(R));
%
% See also: bct.manifold.health.check

arguments
    R (1,1) struct
    options.Print (1,1) logical = true
    options.MaxIssues (1,1) {mustBeInteger, mustBePositive} = 10
    options.ShowIndices (1,1) logical = true
    options.Compact (1,1) logical = false
end

% Initialize output
lines = string.empty;

% Header
lines(end+1) = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
lines(end+1) = "  MESH HEALTH CHECK REPORT";
lines(end+1) = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";
lines(end+1) = "";

% Status
if R.ok
    statusIcon = "✓";
    statusText = "PASSED";
else
    statusIcon = "✗";
    statusText = "FAILED";
end

lines(end+1) = sprintf("  Status:   %s %s", statusIcon, statusText);
lines(end+1) = sprintf("  Severity: %s", upper(R.severity));
lines(end+1) = sprintf("  Scope:    %s", R.scope);
lines(end+1) = sprintf("  Level:    %s", R.level);

% Timing if available
if isfield(R.timing, 'total')
    lines(end+1) = sprintf("  Duration: %.3f ms", R.timing.total * 1000);
end

lines(end+1) = "";

% Statistics
if ~isempty(fieldnames(R.stats))
    lines(end+1) = "────────────────────────────────────────────────────────────────────────────────";
    lines(end+1) = "  Statistics";
    lines(end+1) = "────────────────────────────────────────────────────────────────────────────────";
    lines(end+1) = "";
    
    % Core stats
    if isfield(R.stats, 'nV')
        lines(end+1) = sprintf("    Vertices: %d", R.stats.nV);
    end
    if isfield(R.stats, 'nF')
        lines(end+1) = sprintf("    Faces:    %d", R.stats.nF);
    end
    if isfield(R.stats, 'nE')
        lines(end+1) = sprintf("    Edges:    %d", R.stats.nE);
    end
    
    % Edge multiplicity
    if isfield(R.stats, 'nBoundaryEdges')
        lines(end+1) = sprintf("      • Boundary:     %d", R.stats.nBoundaryEdges);
    end
    if isfield(R.stats, 'nInteriorEdges')
        lines(end+1) = sprintf("      • Interior:     %d", R.stats.nInteriorEdges);
    end
    if isfield(R.stats, 'nNonManifoldEdges')
        if R.stats.nNonManifoldEdges > 0
            lines(end+1) = sprintf("      • Non-manifold: %d  ⚠", R.stats.nNonManifoldEdges);
        else
            lines(end+1) = sprintf("      • Non-manifold: %d", R.stats.nNonManifoldEdges);
        end
    end
    
    lines(end+1) = "";
end

% Summary
if ~isempty(R.summary)
    lines(end+1) = "────────────────────────────────────────────────────────────────────────────────";
    lines(end+1) = "  Summary";
    lines(end+1) = "────────────────────────────────────────────────────────────────────────────────";
    lines(end+1) = "";
    
    for i = 1:length(R.summary)
        lines(end+1) = sprintf("    %s", R.summary(i));
    end
    lines(end+1) = "";
end

% Issues
if ~isempty(R.issues)
    lines(end+1) = "────────────────────────────────────────────────────────────────────────────────";
    lines(end+1) = sprintf("  Issues Found: %d", length(R.issues));
    lines(end+1) = "────────────────────────────────────────────────────────────────────────────────";
    lines(end+1) = "";
    
    % Group by severity
    errors = R.issues(strcmp({R.issues.severity}, "error"));
    warnings = R.issues(strcmp({R.issues.severity}, "warn"));
    
    % Display errors first
    if ~isempty(errors)
        lines(end+1) = sprintf("  ERRORS (%d):", length(errors));
        lines(end+1) = "";
        for i = 1:min(length(errors), options.MaxIssues)
            lines = [lines; formatIssue(errors(i), options)]; %#ok<AGROW>
        end
        if length(errors) > options.MaxIssues
            lines(end+1) = sprintf("    ... and %d more errors", length(errors) - options.MaxIssues);
            lines(end+1) = "";
        end
    end
    
    % Display warnings
    if ~isempty(warnings)
        lines(end+1) = sprintf("  WARNINGS (%d):", length(warnings));
        lines(end+1) = "";
        for i = 1:min(length(warnings), options.MaxIssues)
            lines = [lines; formatIssue(warnings(i), options)]; %#ok<AGROW>
        end
        if length(warnings) > options.MaxIssues
            lines(end+1) = sprintf("    ... and %d more warnings", length(warnings) - options.MaxIssues);
            lines(end+1) = "";
        end
    end
end

% Footer
lines(end+1) = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━";

% Join lines
txt = strjoin(lines, newline);

% Print if requested
if options.Print
    fprintf('%s\n', txt);
end

end

%% Helper functions

function lines = formatIssue(issue, options)
%FORMATISSUE Format a single issue for display.

lines = string.empty;

% Icon based on severity
if issue.severity == "error"
    icon = "✗";
else
    icon = "⚠";
end

% Main message
lines(end+1) = sprintf("    %s [%s] %s", icon, issue.id, issue.message);

% Count and details
if issue.count > 1
    lines(end+1) = sprintf("      Count: %d occurrences", issue.count);
end

if ~isempty(fieldnames(issue.details))
    detailStr = formatStruct(issue.details, "      ");
    lines = [lines; detailStr];
end

% Sample indices if requested and available
if options.ShowIndices && ~isempty(fieldnames(issue.indices))
    indexStr = formatIndices(issue.indices, options);
    if ~isempty(indexStr)
        lines = [lines; indexStr];
    end
end

lines(end+1) = "";

end

function lines = formatIndices(indices, options)
%FORMATINDICES Format index samples for display.

lines = string.empty;
fields = fieldnames(indices);

for i = 1:length(fields)
    fn = fields{i};
    vals = indices.(fn);
    
    if isempty(vals)
        continue;
    end
    
    % Show up to 10 indices
    nShow = min(10, length(vals));
    valStr = sprintf('%d ', vals(1:nShow));
    
    if length(vals) > nShow
        suffix = sprintf('... (%d total)', length(vals));
    else
        suffix = "";
    end
    
    lines(end+1) = sprintf("      Sample %s: %s%s", fn, valStr, suffix);
end

end

function lines = formatStruct(s, indent)
%FORMATSTRUCT Format struct fields for display.

lines = string.empty;
fields = fieldnames(s);

for i = 1:length(fields)
    fn = fields{i};
    val = s.(fn);
    
    if isnumeric(val) && isscalar(val)
        lines(end+1) = sprintf("%s%s: %g", indent, fn, val);
    elseif islogical(val) && isscalar(val)
        lines(end+1) = sprintf("%s%s: %s", indent, fn, string(val));
    elseif ischar(val) || isstring(val)
        lines(end+1) = sprintf("%s%s: %s", indent, fn, val);
    end
end

end
