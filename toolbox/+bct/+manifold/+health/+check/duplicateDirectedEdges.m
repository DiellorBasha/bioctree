function [issues, isUpdate, statsUpdate, dataUpdate] = duplicateDirectedEdges(mesh, options, cache)
%DUPLICATEDIRECTEDEDGES Check for duplicate directed edges
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.duplicateDirectedEdges(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure (unused)
%   cache   - Cache structure with .dE field
%
% Outputs:
%   issues      - Array of issue structures
%   isUpdate    - struct('hasDuplicateDirectedEdges', true/false)
%   statsUpdate - Statistics from measure
%   dataUpdate  - Optional debug data
%
% Description:
%   Checks for duplicate directed edges in the face list.
%   Usually indicates duplicate faces or other topology errors.
%   
%   Severity: warn
%
% See also: bct.manifold.health.measure.duplicateDirectedEdges

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Run measure
[tf, duplicateIdx] = bct.manifold.health.measure.duplicateDirectedEdges(mesh, cache, []);

% Build issue if found
if ~tf
    issues = bct.manifold.health.internal.issue( ...
        'duplicateDirectedEdges', 'warn', ...
        sprintf('%d duplicate directed edge instances', length(duplicateIdx)), ...
        'edges', ...
        'count', length(duplicateIdx), ...
        'indices', duplicateIdx);
else
    issues = struct([]);
end

% Update flags
isUpdate = struct('hasDuplicateDirectedEdges', ~tf);

% Stats
statsUpdate = struct('nDuplicateDirectedEdges', length(duplicateIdx));

% Data for debugging (dE space indices, not canonical E)
dataUpdate = struct('duplicateDirectedEdgeIdx', duplicateIdx);

end
