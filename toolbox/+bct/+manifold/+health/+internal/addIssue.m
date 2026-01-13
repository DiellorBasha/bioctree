function R = addIssue(R, id, severity, message, varargin)
%ADDISSUE Add or update an issue in a health check report.
%
%   R = addIssue(R, id, severity, message, ...)
%
% Inputs
%   R        : Report struct (from newReport)
%   id       : string, stable identifier (e.g., "nonmanifold_edges")
%   severity : "warn" | "error"
%   message  : string, human-readable description
%
% Name-Value Parameters
%   count    : scalar, number of occurrences (default: 1)
%   indices  : struct with fields like 'faces', 'edges', 'verts'
%   details  : struct with additional metrics
%   maxStore : int, maximum indices to store (default: 50)
%
% Output
%   R : Updated report with issue added/updated
%
% Behavior
%   - If issue ID already exists, updates count and appends indices
%   - Clips stored indices to maxStore to prevent huge reports
%   - Updates R.ok and R.severity based on issue severity
%
% See also: bct.manifold.health.internal.newReport

arguments
    R (1,1) struct
    id (1,1) string
    severity (1,1) string {mustBeMember(severity, ["warn", "error"])}
    message (1,1) string
end

arguments (Repeating)
    varargin
end

% Parse name-value pairs
p = inputParser;
p.addParameter('count', 1, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('indices', struct(), @isstruct);
p.addParameter('details', struct(), @isstruct);
p.addParameter('maxStore', 50, @(x) isnumeric(x) && isscalar(x));
p.parse(varargin{:});

count = p.Results.count;
indices = p.Results.indices;
details = p.Results.details;
maxStore = p.Results.maxStore;

% Check if issue already exists
existingIdx = find(strcmp({R.issues.id}, id), 1);

if isempty(existingIdx)
    % Create new issue
    newIssue = struct( ...
        'id', id, ...
        'severity', severity, ...
        'message', message, ...
        'count', count, ...
        'indices', indices, ...
        'details', details ...
    );
    
    % Clip indices
    newIssue = clipIndices(newIssue, maxStore);
    
    % Append to issues array
    if isempty(R.issues)
        R.issues = newIssue;
    else
        R.issues(end+1) = newIssue;
    end
else
    % Update existing issue
    R.issues(existingIdx).count = R.issues(existingIdx).count + count;
    
    % Merge indices (append and clip)
    R.issues(existingIdx).indices = mergeIndices( ...
        R.issues(existingIdx).indices, indices, maxStore);
    
    % Update details if provided
    if ~isempty(fieldnames(details))
        R.issues(existingIdx).details = mergeStructs( ...
            R.issues(existingIdx).details, details);
    end
end

% Update report severity and ok flag
if severity == "error"
    R.severity = "error";
    R.ok = false;
elseif severity == "warn" && R.severity == "ok"
    R.severity = "warn";
    % Don't set ok=false for warnings by default
end

end

%% Helper functions

function issue = clipIndices(issue, maxStore)
%CLIPINDICES Limit stored indices to maxStore per field.

fields = fieldnames(issue.indices);
for i = 1:length(fields)
    fn = fields{i};
    val = issue.indices.(fn);
    if numel(val) > maxStore
        issue.indices.(fn) = val(1:maxStore);
        % Mark that we clipped
        if ~isfield(issue.details, 'clipped')
            issue.details.clipped = struct();
        end
        issue.details.clipped.(fn) = true;
    end
end

end

function merged = mergeIndices(idx1, idx2, maxStore)
%MERGEINDICES Concatenate index fields and clip to maxStore.

merged = idx1;
fields2 = fieldnames(idx2);

for i = 1:length(fields2)
    fn = fields2{i};
    if isfield(merged, fn)
        % Concatenate
        merged.(fn) = [merged.(fn); idx2.(fn)];
        % Clip
        if numel(merged.(fn)) > maxStore
            merged.(fn) = merged.(fn)(1:maxStore);
        end
    else
        % Add new field
        merged.(fn) = idx2.(fn);
        if numel(merged.(fn)) > maxStore
            merged.(fn) = merged.(fn)(1:maxStore);
        end
    end
end

end

function merged = mergeStructs(s1, s2)
%MERGESTRUCTS Merge two structs, s2 overwrites s1.

merged = s1;
fields2 = fieldnames(s2);
for i = 1:length(fields2)
    merged.(fields2{i}) = s2.(fields2{i});
end

end
