function issueStruct = issue(id, severity, msg, location, varargin)
%ISSUE Create standardized issue structure for health checks
%
% Syntax:
%   issueStruct = bct.manifold.health.internal.issue(id, severity, msg, location)
%   issueStruct = bct.manifold.health.internal.issue(..., 'Field', value, ...)
%
% Inputs:
%   id       - String identifier for issue type (e.g., 'nonManifoldEdges')
%   severity - 'info' | 'warn' | 'error'
%   msg      - Human-readable message string
%   location - String describing where issue occurs (e.g., 'edges', 'faces')
%
% Optional Name-Value Parameters:
%   count    - Number of affected elements
%   indices  - Array of affected indices
%   data     - Additional diagnostic data
%
% Outputs:
%   issueStruct - Standardized structure with fields:
%     .id       - Issue identifier
%     .severity - Severity level
%     .location - Location string
%     .message  - Human-readable message
%     .count    - Number of affected elements (if provided)
%     .indices  - Affected indices (if provided)
%     .data     - Additional data (if provided)
%
% Description:
%   Creates a standardized issue structure used throughout the health
%   check system. All check wrappers should use this to create issues.
%
% Examples:
%   % Simple issue
%   iss = bct.manifold.health.internal.issue(...
%       'boundaryEdges', 'info', 'Mesh has boundary edges', 'edges', ...
%       'count', 42);
%
%   % Issue with indices
%   iss = bct.manifold.health.internal.issue(...
%       'nonManifoldEdges', 'error', 'Non-manifold edges detected', 'edges', ...
%       'count', 5, 'indices', [10, 23, 45, 67, 89]);
%
% See also: bct.manifold.health.internal.mergeIssues

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Parse optional parameters
p = inputParser;
p.addParameter('count', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('indices', [], @(x) isempty(x) || isnumeric(x));
p.addParameter('data', struct(), @isstruct);
p.parse(varargin{:});

% Build issue structure
issueStruct = struct();
issueStruct.id = string(id);
issueStruct.severity = string(severity);
issueStruct.location = string(location);
issueStruct.message = string(msg);

if ~isempty(p.Results.count)
    issueStruct.count = p.Results.count;
end

if ~isempty(p.Results.indices)
    issueStruct.indices = p.Results.indices;
end

if ~isempty(fieldnames(p.Results.data))
    issueStruct.data = p.Results.data;
end

end
