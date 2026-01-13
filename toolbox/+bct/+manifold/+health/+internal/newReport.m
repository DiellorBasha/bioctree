function R = newReport(scope, level, stats)
%NEWREPORT Create empty health check report structure.
%
%   R = newReport(scope, level, stats)
%
% Inputs
%   scope : string, e.g. "bct.manifold.health.topology"
%   level : string, "quick" | "standard" | "full"
%   stats : struct with basic mesh statistics (nV, nF, etc.)
%
% Output
%   R : Report struct with canonical schema
%
% Schema
%   R.ok          : logical, overall pass/fail (updated as issues added)
%   R.severity    : "ok" | "warn" | "error"
%   R.scope       : string, identifies which check produced this report
%   R.level       : string, check level
%   R.summary     : string array, high-level messages
%   R.issues      : struct array of issues (see addIssue for schema)
%   R.stats       : struct with mesh statistics
%   R.timing      : struct with timers (if tracking performance)
%   R.data        : struct for optional cached artifacts
%
% See also: bct.manifold.health.internal.addIssue

arguments
    scope (1,1) string
    level (1,1) string {mustBeMember(level, ["quick", "standard", "full"])}
    stats (1,1) struct = struct()
end

R = struct( ...
    'ok', true, ...
    'severity', "ok", ...
    'scope', scope, ...
    'level', level, ...
    'summary', strings(0,1), ...
    'issues', struct('id', {}, 'severity', {}, 'message', {}, ...
                     'count', {}, 'indices', {}, 'details', {}), ...
    'stats', stats, ...
    'timing', struct(), ...
    'data', struct() ...
);

end
