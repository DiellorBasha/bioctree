function [connectivityStats, isConnected, components] = connectivity(mesh, ~, ~)
%CONNECTIVITY Analyze manifold connectivity using graph components
%
% Syntax:
%   [connectivityStats, isConnected, components] = ...
%       bct.manifold.health.measure.connectivity(mesh, ~, ~)
%
% Inputs:
%   mesh - Normalized mesh structure with adjacency
%
% Outputs:
%   connectivityStats - Structure with:
%                       .numComponents - Number of connected components
%                       .componentSizes - Array of component sizes (vertex counts)
%                       .largestComponentSize - Size of largest component
%   isConnected       - true if single connected component
%   components        - Cell array of vertex indices for each component
%
% Description:
%   Uses MATLAB's graph connectivity analysis to detect disconnected
%   components in the manifold.
%
%   Creates graph from vertex adjacency matrix and applies conncomp()
%   to find connected components.
%
% See also: bct.manifold.health.check.connectivity, graph, conncomp

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Requires adjacency matrix
if ~isfield(mesh, 'adjacency') || isempty(mesh.adjacency)
    % Try to build from faces
    if mesh.hasV && ~isempty(mesh.F)
        % Build adjacency from edges
        E = mesh.E;
        if isempty(E)
            E = [mesh.F(:,[1,2]); mesh.F(:,[2,3]); mesh.F(:,[3,1])];
            E = unique(sort(E, 2), 'rows');
        end
        nV = mesh.nV;
        mesh.adjacency = sparse([E(:,1); E(:,2)], [E(:,2); E(:,1)], 1, nV, nV);
    else
        % Cannot compute connectivity
        connectivityStats = struct('numComponents', NaN, 'componentSizes', [], ...
            'largestComponentSize', NaN);
        isConnected = NaN;
        components = {};
        return;
    end
end

% Create graph from adjacency
gr = graph(mesh.adjacency);

% Find connected components
components = conncomp(gr, 'OutputForm', 'cell');

% Compute statistics
numComponents = length(components);
componentSizes = cellfun(@length, components);
[largestComponentSize, ~] = max(componentSizes);

connectivityStats.numComponents = numComponents;
connectivityStats.componentSizes = componentSizes;
connectivityStats.largestComponentSize = largestComponentSize;

% Single component = connected
isConnected = (numComponents == 1);

end
