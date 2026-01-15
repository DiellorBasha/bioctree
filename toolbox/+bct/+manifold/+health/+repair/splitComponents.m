function components = splitComponents(M, options)
%SPLITCOMPONENTS Split disconnected manifold into separate manifolds
%
% Syntax:
%   components = bct.manifold.health.repair.splitComponents(M)
%   components = bct.manifold.health.repair.splitComponents(M, 'MinSize', n)
%
% Inputs:
%   M - bct.Manifold object (potentially disconnected)
%
% Name-Value Arguments:
%   MinSize - Minimum component size (vertices) to include (default: 1)
%
% Outputs:
%   components - Cell array of bct.Manifold objects (one per component)
%
% Description:
%   Automatically detects and splits all disconnected components.
%   
%   Uses connectivity analysis to identify components, then creates
%   separate Manifold objects for each component (with compacted indices).
%
%   Components are returned in descending order of size (largest first).
%
% Examples:
%   % Split all components
%   components = bct.manifold.health.repair.splitComponents(M);
%   fprintf('Found %d components\n', length(components));
%
%   % Keep only large components (>100 vertices)
%   components = bct.manifold.health.repair.splitComponents(M, 'MinSize', 100);
%
% See also: bct.manifold.health.repair.split, 
%           bct.manifold.health.check.connectivity

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

arguments
    M (1,1) bct.Manifold
    options.MinSize (1,1) double {mustBePositive, mustBeInteger} = 1
end

% Run connectivity check with Verbose to get component indices
h = M.health('Verbose', true);

% If already connected, return as-is
if h.is.connected
    components = {M};
    return;
end

% Extract component vertex indices
if ~isfield(h.data, 'connectivity') || ~isfield(h.data.connectivity, 'components')
    % This shouldn't happen with Verbose=true, but handle gracefully
    warning('bct:manifold:health:repair:splitComponents:NoComponentData', ...
        'Component data not available. Check may have failed.');
    components = {M};
    return;
end

componentIndices = h.data.connectivity.components;
componentSizes = cellfun(@length, componentIndices);

% Sort by size (descending)
[sortedSizes, sortOrder] = sort(componentSizes, 'descend');
componentIndices = componentIndices(sortOrder);

% Filter by minimum size
keep = sortedSizes >= options.MinSize;
componentIndices = componentIndices(keep);

if isempty(componentIndices)
    components = {};
    return;
end

% Extract vertices and faces
V = M.Vertices;
F = M.Faces;

% Split each component
nComponents = length(componentIndices);
components = cell(nComponents, 1);

for i = 1:nComponents
    vertexIdx = componentIndices{i};
    
    % Build membership mask
    isMember = false(size(V, 1), 1);
    isMember(vertexIdx) = true;
    
    % Extract faces (all 3 vertices belong)
    facesMask = all(isMember(F), 2);
    F_comp = F(facesMask, :);
    
    % Compact vertices
    if ~isempty(F_comp)
        usedVertices = unique(F_comp(:));
        vertexMap = zeros(size(V, 1), 1);
        vertexMap(usedVertices) = 1:length(usedVertices);
        
        V_comp = V(usedVertices, :);
        F_comp = vertexMap(F_comp);
        
        components{i} = bct.Manifold(V_comp, F_comp);
    else
        % Empty component (shouldn't happen with valid connectivity)
        components{i} = bct.Manifold(zeros(0, 3), zeros(0, 3));
    end
end

end
