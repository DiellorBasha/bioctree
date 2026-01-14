function [issues, isUpdate, statsUpdate, dataUpdate] = duplicateFaces(mesh, options, ~)
%DUPLICATEFACES Check for duplicate faces
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.duplicateFaces(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure (unused for this check)
%   cache   - Cache structure (unused for this check)
%
% Outputs:
%   issues      - Array of issue structures
%   isUpdate    - struct('hasDuplicateFaces', true/false)
%   statsUpdate - Statistics from measure
%   dataUpdate  - Optional debug data
%
% Description:
%   Checks for duplicate faces in the face list.
%   Duplicates are typically warnings but may indicate topology errors.
%
% See also: bct.manifold.health.measure.duplicateFaces

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Run measure
[tf, duplicateIdx] = bct.manifold.health.measure.duplicateFaces(mesh, [], []);

% Build issue if found (warning level)
if ~tf
    issues = bct.manifold.health.internal.issue( ...
        'duplicateFaces', 'warn', ...
        sprintf('%d duplicate face instances', length(duplicateIdx)), ...
        'faces', ...
        'count', length(duplicateIdx), ...
        'indices', duplicateIdx);
else
    issues = struct([]);
end

% Update flags
isUpdate = struct('hasDuplicateFaces', ~tf);

% Stats
statsUpdate = struct('nDuplicateFaces', length(duplicateIdx));

% Data for debugging
dataUpdate = struct('duplicateFaceIdx', duplicateIdx);

end
