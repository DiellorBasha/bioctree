function [issues, isUpdate, statsUpdate, dataUpdate] = outward(mesh, options, cache)
%OUTWARD Check outward orientation using signed volume
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.outward(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure (unused)
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
%   This is an optional convention check (not required for DEC).
%   Returns NaN if cannot determine (e.g., no vertices, planar mesh).
%   
%   Severity: info
%
% See also: bct.manifold.health.measure.outwardVolume

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

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
    issues = bct.manifold.health.internal.issue( ...
        'inwardOrientation', 'info', ...
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
