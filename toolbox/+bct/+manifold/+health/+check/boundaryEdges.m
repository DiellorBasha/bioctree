function [issues, isUpdate, statsUpdate, dataUpdate] = boundaryEdges(mesh, options, cache)
%BOUNDARYEDGES Check for boundary edges
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.boundaryEdges(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure with optional:
%             .RequireClosed - true to upgrade boundary to error (default: false)
%   cache   - Cache structure with .multiplicity field
%
% Outputs:
%   issues      - Array of issue structures
%   isUpdate    - struct('hasBoundary', true/false)
%   statsUpdate - Statistics from measure
%   dataUpdate  - Optional debug data
%
% Description:
%   Checks for boundary edges (multiplicity == 1).
%   
%   Policy:
%   - Default severity: info (boundary is allowed)
%   - If RequireClosed=true: error
%
% See also: bct.manifold.health.measure.boundaryEdges

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Parse options
if isfield(options, 'RequireClosed')
    requireClosed = options.RequireClosed;
else
    requireClosed = false;
end

% Run measure
[tf, boundaryEdgeIdx, boundaryVertexIdx] = bct.manifold.health.measure.boundaryEdges(mesh, cache, []);

% Build issue if found
if tf
    % Determine severity
    if requireClosed
        severity = 'error';
    else
        severity = 'info';
    end
    
    issues = bct.manifold.health.internal.issue( ...
        'boundaryEdges', severity, ...
        sprintf('%d boundary edges detected', length(boundaryEdgeIdx)), ...
        'edges', ...
        'count', length(boundaryEdgeIdx), ...
        'indices', boundaryEdgeIdx, ...
        'data', struct('boundaryVertexIdx', boundaryVertexIdx));
else
    issues = struct([]);
end

% Update flags
isUpdate = struct('hasBoundary', tf);

% Stats
statsUpdate = struct(...
    'nBoundaryEdges', length(boundaryEdgeIdx), ...
    'nBoundaryVertices', length(boundaryVertexIdx));

% Data for debugging (canonical E indices)
dataUpdate = struct(...
    'boundaryEdgeIdx', boundaryEdgeIdx, ...
    'boundaryVertexIdx', boundaryVertexIdx);

end
