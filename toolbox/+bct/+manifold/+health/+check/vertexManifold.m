function [issues, isUpdate, statsUpdate, dataUpdate] = vertexManifold(mesh, options, cache)
%VERTEXMANIFOLD Check vertex manifoldness
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.vertexManifold(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure with optional:
%             .UseSurfaceMesh - true to use surfaceMesh fallback (default: true)
%   cache   - Cache structure (unused)
%
% Outputs:
%   issues      - Array of issue structures
%   isUpdate    - struct('vertexManifold', true/false/NaN)
%   statsUpdate - Statistics from measure
%   dataUpdate  - Optional debug data
%
% Description:
%   Checks if all vertices are locally manifold.
%   
%   Currently uses surfaceMesh fallback. Returns NaN if vertices not
%   available or check fails.
%
% See also: bct.manifold.health.measure.vertexManifold

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Run measure
[tf, badVertexIdx] = bct.manifold.health.measure.vertexManifold(mesh, cache, options);

% Build issue if found
if isnan(tf)
    % Could not determine
    issues = bct.manifold.health.internal.issue( ...
        'vertexManifoldUnknown', 'info', ...
        'Vertex manifoldness could not be determined', ...
        'vertices');
    
elseif ~tf
    % Non-manifold vertices detected
    if isempty(badVertexIdx)
        % Count unknown
        issues = bct.manifold.health.internal.issue( ...
            'nonManifoldVertices', 'warn', ...
            'Non-manifold vertices detected (count unknown)', ...
            'vertices');
    else
        issues = bct.manifold.health.internal.issue( ...
            'nonManifoldVertices', 'warn', ...
            sprintf('%d non-manifold vertices detected', length(badVertexIdx)), ...
            'vertices', ...
            'count', length(badVertexIdx), ...
            'indices', badVertexIdx);
    end
else
    issues = struct([]);
end

% Update flags
isUpdate = struct('vertexManifold', tf);

% Stats
if ~isnan(tf) && ~isempty(badVertexIdx)
    statsUpdate = struct('nNonManifoldVertices', length(badVertexIdx));
else
    statsUpdate = struct('nNonManifoldVertices', NaN);
end

% Data for debugging
dataUpdate = struct('badVertexIdx', badVertexIdx);

end
