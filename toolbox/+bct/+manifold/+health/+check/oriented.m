function [issues, isUpdate, statsUpdate, dataUpdate] = oriented(mesh, options, cache)
%ORIENTED Check local orientation consistency
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.oriented(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure with optional:
%             .RequireOriented - true to upgrade to error (default: true)
%   cache   - Cache structure with .dE, .ic, .multiplicity fields
%
% Outputs:
%   issues      - Array of issue structures
%   isUpdate    - struct('oriented', true/false)
%   statsUpdate - Statistics from measure
%   dataUpdate  - Optional debug data
%
% Description:
%   Checks for consistent local orientation across interior edges.
%   
%   Policy:
%   - Default severity: error (RequireOriented=true for DEC)
%   - If RequireOriented=false: warn
%
% See also: bct.manifold.health.measure.oriented

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Parse options
if isfield(options, 'RequireOriented')
    requireOriented = options.RequireOriented;
else
    requireOriented = true;  % Default: require oriented for DEC
end

% Run measure
[tf, badInteriorEdgeIdx, badFacePairs] = bct.manifold.health.measure.oriented(mesh, cache, []);

% Build issue if found
if ~tf
    % Determine severity
    if requireOriented
        severity = 'error';
    else
        severity = 'warn';
    end
    
    issues = bct.manifold.health.internal.issue( ...
        'orientationInconsistent', severity, ...
        sprintf('%d interior edges have inconsistent orientation', ...
            length(badInteriorEdgeIdx)), ...
        'edges', ...
        'count', length(badInteriorEdgeIdx), ...
        'indices', badInteriorEdgeIdx, ...
        'data', struct('badFacePairs', badFacePairs));
else
    issues = struct([]);
end

% Update flags
isUpdate = struct('oriented', tf);

% Stats
statsUpdate = struct(...
    'nInconsistentEdges', length(badInteriorEdgeIdx), ...
    'nInconsistentFacePairs', size(badFacePairs, 1));

% Data for debugging (canonical E indices)
dataUpdate = struct(...
    'badInteriorEdgeIdx', badInteriorEdgeIdx, ...
    'badFacePairs', badFacePairs);

end
