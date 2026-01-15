function mergedIssues = mergeIssues(varargin)
%MERGEISSUES Merge multiple issue arrays into a single array
%
% Syntax:
%   mergedIssues = bct.manifold.health.internal.mergeIssues(issues1, issues2, ...)
%
% Inputs:
%   issues1, issues2, ... - Arrays of issue structures (can be empty)
%
% Outputs:
%   mergedIssues - Combined array of all non-empty issues
%
% Description:
%   Concatenates multiple issue arrays, filtering out empty inputs.
%   Used by aggregator to combine issues from multiple checks.
%
% Examples:
%   issues1 = check1(...);
%   issues2 = check2(...);
%   issues3 = check3(...);
%   allIssues = bct.manifold.health.internal.mergeIssues(issues1, issues2, issues3);
%
% See also: bct.manifold.health.internal.issue

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Filter out empty inputs
nonEmpty = cellfun(@(x) ~isempty(x), varargin);
validIssues = varargin(nonEmpty);

if isempty(validIssues)
    mergedIssues = struct([]);
    return;
end

% Collect all unique field names across all issue arrays
allFields = {};
for i = 1:length(validIssues)
    allFields = [allFields, fieldnames(validIssues{i})']; %#ok<AGROW>
end
allFields = unique(allFields);

% Normalize all issue structures to have the same fields
for i = 1:length(validIssues)
    for j = 1:length(validIssues{i})
        for k = 1:length(allFields)
            if ~isfield(validIssues{i}(j), allFields{k})
                % Add missing field with empty value
                validIssues{i}(j).(allFields{k}) = [];
            end
        end
        % Reorder fields to match
        validIssues{i}(j) = orderfields(validIssues{i}(j), allFields);
    end
end

% Vertically concatenate all issue arrays
mergedIssues = vertcat(validIssues{:});

end
