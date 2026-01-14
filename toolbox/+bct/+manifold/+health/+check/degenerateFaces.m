function [issues, isUpdate, statsUpdate, dataUpdate] = degenerateFaces(mesh, options, ~)
%DEGENERATEFACES Check for degenerate faces
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.degenerateFaces(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure (unused for this check)
%   cache   - Cache structure (unused for this check)
%
% Outputs:
%   issues      - Array of issue structures
%   isUpdate    - struct('facesNondegenerate', true/false)
%   statsUpdate - Statistics from measure
%   dataUpdate  - Optional debug data
%
% Description:
%   Checks for faces with repeated vertex indices.
%   Degenerate faces are always errors for DEC operators.
%
% See also: bct.manifold.health.measure.degenerateFaces

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Run measure
[tf, degenerateIdx] = bct.manifold.health.measure.degenerateFaces(mesh, [], []);

% Build issue if found
if ~tf
    issues = bct.manifold.health.internal.issue( ...
        'degenerateFaces', 'error', ...
        sprintf('%d degenerate faces (repeated vertex indices)', length(degenerateIdx)), ...
        'faces', ...
        'count', length(degenerateIdx), ...
        'indices', degenerateIdx);
else
    issues = struct([]);
end

% Update flags
isUpdate = struct('facesNondegenerate', tf);

% Stats
statsUpdate = struct('nDegenerateFaces', length(degenerateIdx));

% Data for debugging
dataUpdate = struct('degenerateFaceIdx', degenerateIdx);

end
