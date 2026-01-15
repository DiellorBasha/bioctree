function [issues, isUpdate, statsUpdate, dataUpdate] = outward(mesh, options, cache)
%OUTWARD Check outward orientation using signed volume
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.outward(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure with optional:
%             .RequireOutward - true to upgrade to warn (default: true)
%   cache   - Cache structure (unused)
%
% Outputs:
%   issues      - Array of issue structures
%   isUpdate    - struct('outward', true/false/NaN)
%   statsUpdate - Statistics from measure
%   dataUpdate  - Optional debug data
%
% Description:
%   Checks if mesh has outward orientation using signed volume.
%   
%   Checks global orientation convention using signed volume.
%   Returns NaN if cannot determine (e.g., no vertices, planar mesh).
%   
%   Policy:
%   - Default severity: error (RequireOutward=true)
%   - If RequireOutward=false: info
%
% See also: bct.manifold.health.measure.outwardVolume

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Parse options
if isfield(options, 'RequireOutward')
    requireOutward = options.RequireOutward;
else
    requireOutward = true;  % Default: error on inward orientation
end

% Run measure
[signedVolume, isOutward] = bct.manifold.health.measure.outwardVolume(mesh, cache, []);

% Build issue based on result
if isnan(isOutward)
    % Could not determine
    issues = bct.manifold.health.internal.issue( ...
        'outwardOrientationUnknown', 'info', ...
        'Outward orientation could not be determined', ...
        'mesh', ...
        'data', struct('signedVolume', signedVolume));
    
elseif ~isOutward
    % Inward orientation
    % Determine severity
    if requireOutward
        severity = 'error';
    else
        severity = 'info';
    end
    
    issues = bct.manifold.health.internal.issue( ...
        'inwardOrientation', severity, ...
        sprintf('Mesh has inward orientation (signed volume: %.6g)', signedVolume), ...
        'mesh', ...
        'data', struct('signedVolume', signedVolume));
else
    % Outward (expected)
    issues = struct([]);
end

% Update flags
isUpdate = struct('outward', isOutward);

% Stats
statsUpdate = struct('signedVolume', signedVolume);

% Data for debugging
dataUpdate = struct('signedVolume', signedVolume, 'isOutward', isOutward);

end
