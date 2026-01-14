function isFlags = computeIsFlags(isUpdates)
%COMPUTEISFLAGS Merge isUpdate structs into canonical h.is flags
%
% Syntax:
%   isFlags = bct.manifold.health.internal.computeIsFlags(isUpdates)
%
% Inputs:
%   isUpdates - Cell array of isUpdate structures from checks
%
% Outputs:
%   isFlags - Merged structure with canonical boolean flags:
%     .facesValid
%     .facesNondegenerate
%     .hasDuplicateFaces
%     .hasDuplicateDirectedEdges
%     .edgeManifold
%     .hasBoundary
%     .oriented
%     .vertexManifold
%     .outward
%
% Description:
%   Combines isUpdate structures from multiple checks into a single
%   canonical h.is structure. Handles NaN values for unevaluated checks.
%
%   Default values are NaN to indicate not evaluated. As checks run,
%   they override these defaults with true/false.
%
% Examples:
%   isUpdate1 = struct('facesValid', true);
%   isUpdate2 = struct('edgeManifold', false);
%   isFlags = bct.manifold.health.internal.computeIsFlags({isUpdate1, isUpdate2});
%   % Result: isFlags.facesValid = true, isFlags.edgeManifold = false
%
% See also: bct.manifold.health.check

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Initialize with NaN for all canonical flags
isFlags = struct( ...
    'facesValid', NaN, ...
    'facesNondegenerate', NaN, ...
    'hasDuplicateFaces', NaN, ...
    'hasDuplicateDirectedEdges', NaN, ...
    'edgeManifold', NaN, ...
    'hasBoundary', NaN, ...
    'oriented', NaN, ...
    'vertexManifold', NaN, ...
    'outward', NaN ...
);

% Merge all isUpdate structures
for i = 1:length(isUpdates)
    if ~isempty(isUpdates{i}) && isstruct(isUpdates{i})
        fields = fieldnames(isUpdates{i});
        for j = 1:length(fields)
            fn = fields{j};
            isFlags.(fn) = isUpdates{i}.(fn);
        end
    end
end

end
