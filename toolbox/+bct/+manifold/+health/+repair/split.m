function [M1, M2, stats] = split(M, component1Vertices, component2Vertices)
%SPLIT Split manifold into two components based on vertex membership
%
% Syntax:
%   [M1, M2, stats] = bct.manifold.health.repair.split(M, comp1, comp2)
%
% Inputs:
%   M                  - bct.Manifold object or (V, F) pair
%   component1Vertices - Vector of vertex indices for first component
%   component2Vertices - Vector of vertex indices for second component
%
% Outputs:
%   M1    - bct.Manifold for first component (compacted vertex indices)
%   M2    - bct.Manifold for second component (compacted vertex indices)
%   stats - Structure with:
%           .nVertices_input - Original vertex count
%           .nFaces_input    - Original face count
%           .nVertices_comp1 - Component 1 vertex count (after compaction)
%           .nVertices_comp2 - Component 2 vertex count (after compaction)
%           .nFaces_comp1    - Component 1 face count
%           .nFaces_comp2    - Component 2 face count
%           .nDiscarded      - Number of faces spanning both components
%
% Description:
%   Splits a manifold into two separate manifolds based on vertex membership.
%   
%   Algorithm:
%   1. Build membership masks for each component
%   2. Extract faces where all 3 vertices belong to same component
%   3. Compact each submesh by remapping vertex indices
%   4. Create new Manifold objects
%
%   Faces that span multiple components (bridge edges) are discarded.
%   Vertex indices in output manifolds are compacted (renumbered 1:nV).
%
% Examples:
%   % Split by connected components
%   h = M.health('Verbose', true);
%   if ~h.is.connected
%       comp = h.data.connectivity.components;
%       [M1, M2] = bct.manifold.health.repair.split(M, comp{1}, comp{2});
%   end
%
%   % Split hemispheres (if vertex indices known)
%   [MRH, MLH] = bct.manifold.health.repair.split(M, rhVertices, lhVertices);
%
% See also: bct.manifold.health.check.connectivity

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Parse input
if isa(M, 'bct.Manifold')
    V = M.Vertices;
    F = M.Faces;
else
    error('bct:manifold:health:repair:split:InvalidInput', ...
        'Input must be bct.Manifold object');
end

% Validate inputs
nV = size(V, 1);
nF = size(F, 1);

if isempty(component1Vertices) || isempty(component2Vertices)
    error('bct:manifold:health:repair:split:EmptyComponents', ...
        'Both component vertex sets must be non-empty');
end

% Ensure column vectors
component1Vertices = component1Vertices(:);
component2Vertices = component2Vertices(:);

% Validate indices
if any(component1Vertices < 1) || any(component1Vertices > nV)
    error('bct:manifold:health:repair:split:InvalidIndices', ...
        'Component 1 vertex indices out of range [1, %d]', nV);
end
if any(component2Vertices < 1) || any(component2Vertices > nV)
    error('bct:manifold:health:repair:split:InvalidIndices', ...
        'Component 2 vertex indices out of range [1, %d]', nV);
end

% Check for overlap
overlap = intersect(component1Vertices, component2Vertices);
if ~isempty(overlap)
    warning('bct:manifold:health:repair:split:OverlappingComponents', ...
        'Components share %d vertices - these will be duplicated', length(overlap));
end

% Build membership masks
isComp1 = false(nV, 1);
isComp2 = false(nV, 1);
isComp1(component1Vertices) = true;
isComp2(component2Vertices) = true;

% Extract faces for each component (strict: all 3 vertices belong)
facesComp1_mask = all(isComp1(F), 2);
facesComp2_mask = all(isComp2(F), 2);

F1 = F(facesComp1_mask, :);   % Component 1 faces (original indexing)
F2 = F(facesComp2_mask, :);   % Component 2 faces (original indexing)

nFaces1 = size(F1, 1);
nFaces2 = size(F2, 1);
nDiscarded = nF - nFaces1 - nFaces2;

% Compact component 1 mesh
if nFaces1 > 0
    usedComp1 = unique(F1(:));
    mapComp1 = zeros(nV, 1);
    mapComp1(usedComp1) = 1:length(usedComp1);
    
    V1 = V(usedComp1, :);
    F1_compacted = mapComp1(F1);
    
    M1 = bct.Manifold(V1, F1_compacted);
else
    % Empty component
    M1 = bct.Manifold(zeros(0, 3), zeros(0, 3));
end

% Compact component 2 mesh
if nFaces2 > 0
    usedComp2 = unique(F2(:));
    mapComp2 = zeros(nV, 1);
    mapComp2(usedComp2) = 1:length(usedComp2);
    
    V2 = V(usedComp2, :);
    F2_compacted = mapComp2(F2);
    
    M2 = bct.Manifold(V2, F2_compacted);
else
    % Empty component
    M2 = bct.Manifold(zeros(0, 3), zeros(0, 3));
end

% Build statistics
stats = struct();
stats.nVertices_input = nV;
stats.nFaces_input = nF;
stats.nVertices_comp1 = M1.numVertices;
stats.nVertices_comp2 = M2.numVertices;
stats.nFaces_comp1 = nFaces1;
stats.nFaces_comp2 = nFaces2;
stats.nDiscarded = nDiscarded;

end
