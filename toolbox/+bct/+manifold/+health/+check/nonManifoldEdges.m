function [issues, isUpdate, statsUpdate, dataUpdate] = nonManifoldEdges(mesh, options, cache)
%NONMANIFOLDEDGES Check for non-manifold edges
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.nonManifoldEdges(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure with optional:
%             .RequireManifold - true to upgrade to error (default: true)
%   cache   - Cache structure with .multiplicity field
%
% Outputs:
%   issues      - Array of issue structures
%   isUpdate    - struct('edgeManifold', true/false)
%   statsUpdate - Statistics from measure
%   dataUpdate  - Optional debug data
%
% Description:
%   Checks for non-manifold edges (multiplicity >= 3).
%   
%   Policy:
%   - Default severity: error (RequireManifold=true by default for DEC)
%   - If RequireManifold=false: warn
%
% See also: bct.manifold.health.measure.nonManifoldEdges

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Parse options
if isfield(options, 'RequireManifold')
    requireManifold = options.RequireManifold;
else
    requireManifold = true;  % Default: require manifold for DEC
end

% Run measure
[tf, nonManifoldEdgeIdx, maxMultiplicity] = bct.manifold.health.measure.nonManifoldEdges(mesh, cache, []);

% Build issue if found
if ~tf
    % Determine severity
    if requireManifold
        severity = 'error';
    else
        severity = 'warn';
    end
    
    issues = bct.manifold.health.internal.issue( ...
        'nonManifoldEdges', severity, ...
        sprintf('%d non-manifold edges (max multiplicity: %d)', ...
            length(nonManifoldEdgeIdx), maxMultiplicity), ...
        'edges', ...
        'count', length(nonManifoldEdgeIdx), ...
        'indices', nonManifoldEdgeIdx, ...
        'data', struct('maxMultiplicity', maxMultiplicity));
else
    issues = struct([]);
end

% Update flags
isUpdate = struct('edgeManifold', tf);

% Stats
statsUpdate = struct(...
    'nNonManifoldEdges', length(nonManifoldEdgeIdx), ...
    'maxEdgeMultiplicity', maxMultiplicity);

% Data for debugging (canonical E indices)
dataUpdate = struct(...
    'nonManifoldEdgeIdx', nonManifoldEdgeIdx, ...
    'maxMultiplicity', maxMultiplicity);

end
