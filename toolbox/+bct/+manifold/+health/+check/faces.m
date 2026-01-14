function [issues, isUpdate, statsUpdate, dataUpdate] = faces(mesh, options, ~)
%FACES Check face validity
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.faces(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure (unused for this check)
%   cache   - Cache structure (unused for this check)
%
% Outputs:
%   issues      - Array of issue structures
%   isUpdate    - struct('facesValid', true/false)
%   statsUpdate - Statistics from measure
%   dataUpdate  - Optional debug data
%
% Description:
%   Checks if all face indices are within valid vertex range.
%   This is a gating check that must pass before topology analysis.
%
% See also: bct.manifold.health.measure.facesValid

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Run measure
[tf, invalidIdx] = bct.manifold.health.measure.facesValid(mesh, [], []);

% Build issue if invalid
if ~tf
    issues = bct.manifold.health.internal.issue( ...
        'invalidFaces', 'error', ...
        sprintf('%d faces have invalid vertex indices', length(invalidIdx)), ...
        'faces', ...
        'count', length(invalidIdx), ...
        'indices', invalidIdx);
else
    issues = struct([]);
end

% Update flags
isUpdate = struct('facesValid', tf);

% Stats
statsUpdate = struct('nInvalidFaces', length(invalidIdx));

% Data for debugging
dataUpdate = struct('invalidFaceIdx', invalidIdx);

end
