function [issues, isUpdate, statsUpdate, dataUpdate] = scale(mesh, ~, ~)
%SCALE Check mesh scale for inappropriate units
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.scale(mesh, ~, ~)
%
% Inputs:
%   mesh    - Normalized mesh structure with V, F
%
% Outputs:
%   issues      - Array of issue structures (warnings)
%   isUpdate    - struct('scaleAppropriate', true/false)
%   statsUpdate - Scale statistics from measure
%   dataUpdate  - Empty struct
%
% Description:
%   Checks if mesh scale suggests inappropriate units.
%   
%   For brain meshes, typical dimensions in SI meters:
%   - Vertex extent: 0.05 - 0.5 m
%   - Edge lengths: 0.001 - 0.05 m (1mm - 5cm)
%   - Face areas: 1e-6 - 1e-3 m²
%
%   Issues warning if:
%   - Dimensions too large (likely mm/cm instead of m)
%   - Dimensions too small (likely μm/nm instead of m)
%
%   Severity: warning (allows continued operation)
%
% Examples:
%   % Anatomical data in millimeters (will warn)
%   M = bct.Manifold(anat.Vertices, anat.Faces);
%   h = M.health();
%   % h.issues contains scaleInappropriate warning
%   
%   % Fix with rescale
%   M = M.rescale('From', 'mm');
%   h = M.health();  % No scale warning
%
% See also: bct.manifold.health.measure.scale, bct.manifold.metric.rescale

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Initialize
issues = [];
dataUpdate = struct();

% Requires vertices
if ~mesh.hasV
    isUpdate = struct('scaleAppropriate', true);
    statsUpdate = struct();
    return;
end

% Run measure
[scaleStats, needsRescaling] = bct.manifold.health.measure.scale(mesh, [], []);

% Return stats
statsUpdate = scaleStats;

% Build issue if needed
if needsRescaling
    % Determine likely culprit
    if scaleStats.vertexExtent_max > 10.0
        hint = 'Dimensions are extremely large. If data is in millimeters, use M.rescale(''From'', ''mm''). If centimeters, use M.rescale(''From'', ''cm'').';
    elseif scaleStats.vertexExtent_max < 0.001
        hint = 'Dimensions are extremely small. If data is in micrometers, use M.rescale(''From'', ''um'').';
    else
        hint = 'Dimensions are outside typical range. Verify units and use M.rescale() if needed.';
    end
    
    message = sprintf(['Mesh scale appears inappropriate for SI meters. ' ...
                       'Vertex extent: %.3e (max), Median edge length: %.3e. %s'], ...
                      scaleStats.vertexExtent_max, ...
                      scaleStats.edgeLength_median, ...
                      hint);
    
    issues = bct.manifold.health.internal.issue( ...
        'scaleInappropriate', 'warn', ...
        message, ...
        'mesh', ...
        'data', scaleStats);
end

% Update is flags
isUpdate = struct('scaleAppropriate', ~needsRescaling);

end
