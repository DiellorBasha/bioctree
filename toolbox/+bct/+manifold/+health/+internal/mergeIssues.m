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

% Vertically concatenate all issue arrays
mergedIssues = vertcat(validIssues{:});

end
