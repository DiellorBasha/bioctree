function [issues, isUpdate, statsUpdate, dataUpdate] = connectivity(mesh, options, cache)
%CONNECTIVITY Check manifold connectivity and detect disconnected components
%
% Syntax:
%   [issues, isUpdate, statsUpdate, dataUpdate] = ...
%       bct.manifold.health.check.connectivity(mesh, options, cache)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   options - Options structure (unused)
%   cache   - Cache structure (unused)
%
% Outputs:
%   issues      - Array of issue structures
%   isUpdate    - struct('connected', true/false)
%   statsUpdate - Connectivity statistics from measure
%   dataUpdate  - Component vertex indices (if Verbose)
%
% Description:
%   Checks if manifold is a single connected component.
%   
%   Uses MATLAB's graph connectivity analysis via graph() and conncomp().
%   
%   Severity:
%   - Single component: no issue
%   - Multiple components: warning (may be valid for some analyses)
%   - If components cannot be determined: info
%
% Examples:
%   % Disconnected mesh
%   h = M.health();
%   if ~h.is.connected
%       fprintf('Found %d components\n', h.statsByCheck.connectivity.numComponents);
%   end
%
% See also: bct.manifold.health.measure.connectivity, graph, conncomp

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Initialize
dataUpdate = struct();

% Run measure
[connectivityStats, isConnected, components] = ...
    bct.manifold.health.measure.connectivity(mesh, cache, []);

% Return stats
statsUpdate = connectivityStats;

% Build issues
if isnan(isConnected)
    % Could not determine connectivity
    issues = bct.manifold.health.internal.issue( ...
        'connectivityUnknown', 'info', ...
        'Connectivity could not be determined (requires adjacency or faces)', ...
        'mesh');
    
elseif ~isConnected
    % Multiple components detected
    numComponents = connectivityStats.numComponents;
    componentSizes = connectivityStats.componentSizes;
    
    % Sort sizes descending for reporting
    [sortedSizes, ~] = sort(componentSizes, 'descend');
    
    % Format size list (show first 5)
    if numComponents <= 5
        sizeStr = sprintf('%d ', sortedSizes);
    else
        sizeStr = sprintf('%d %d %d %d %d ... (and %d more)', ...
            sortedSizes(1), sortedSizes(2), sortedSizes(3), ...
            sortedSizes(4), sortedSizes(5), numComponents - 5);
    end
    
    message = sprintf(['Manifold has %d disconnected components. ' ...
                       'Component sizes (vertices): [%s]. ' ...
                       'Some operations may require connected manifold.'], ...
                      numComponents, strtrim(sizeStr));
    
    issues = bct.manifold.health.internal.issue( ...
        'disconnectedComponents', 'warn', ...
        message, ...
        'mesh', ...
        'data', struct('numComponents', numComponents, ...
                       'componentSizes', componentSizes));
    
    % Store component indices if verbose mode
    if isfield(options, 'Verbose') && options.Verbose
        dataUpdate.components = components;
    end
else
    % Single connected component - no issue
    issues = [];
end

% Update is flags
isUpdate = struct('connected', isConnected);

end
