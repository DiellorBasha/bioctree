function [tf, badInteriorEdgeIdx, badFacePairs] = oriented(mesh, cache, ~)
%ORIENTED Check local orientation consistency across interior edges
%
% Syntax:
%   [tf, badInteriorEdgeIdx, badFacePairs] = ...
%       bct.manifold.health.measure.oriented(mesh, cache, options)
%
% Inputs:
%   mesh    - Normalized mesh structure with .F, .E fields
%   cache   - Cache structure with fields:
%             .dE - [3*nF×2] directed face-edge list
%             .ic - [3*nF×1] mapping to canonical E indices
%             .multiplicity - [nE×1] edge multiplicity
%   options - Options structure (unused)
%
% Outputs:
%   tf                  - true if oriented, false otherwise
%   badInteriorEdgeIdx  - Indices into canonical E for inconsistent edges
%   badFacePairs        - [k×2] face pairs with inconsistent orientation
%
% Description:
%   Checks if adjacent faces have consistent orientation across shared edges.
%   
%   For each interior edge (multiplicity == 2), the two incident faces should
%   traverse the edge in opposite directions. If both faces traverse in the
%   same direction, orientation is inconsistent.
%
%   Only interior edges are checked. Boundary edges (multiplicity == 1) and
%   non-manifold edges (multiplicity >= 3) are ignored.
%
%   All edge indices in badInteriorEdgeIdx are indices into mesh.E
%   (canonical edge list from M.Edges when input is bct.Manifold).
%
% See also: bct.manifold.health.check.oriented

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Require cache fields
if ~isfield(cache, 'dE') || ~isfield(cache, 'ic') || ~isfield(cache, 'multiplicity')
    error('bct:manifold:health:MissingCache', ...
        'oriented requires cache with dE, ic, and multiplicity');
end

dE = cache.dE;
ic = cache.ic;
multiplicity = cache.multiplicity;
nF = mesh.nF;

% Find interior edges (multiplicity == 2)
interiorEdgeIdx = find(multiplicity == 2);

if isempty(interiorEdgeIdx)
    % No interior edges to check
    tf = true;
    badInteriorEdgeIdx = [];
    badFacePairs = [];
    return;
end

% Check orientation consistency for each interior edge
badInteriorEdgeIdx = [];
badFacePairs = [];

for i = 1:length(interiorEdgeIdx)
    eIdx = interiorEdgeIdx(i);
    
    % Find the two directed face-edge occurrences for this canonical edge
    occurrenceIdx = find(ic == eIdx);
    
    if length(occurrenceIdx) ~= 2
        error('bct:manifold:health:InconsistentMultiplicity', ...
            'Interior edge %d has multiplicity 2 but found %d occurrences', ...
            eIdx, length(occurrenceIdx));
    end
    
    % Get the two directed edges
    dEdge1 = dE(occurrenceIdx(1), :);
    dEdge2 = dE(occurrenceIdx(2), :);
    
    % Check if they are identical (both same direction)
    % If consistent orientation, they should be opposite: [u v] and [v u]
    if isequal(dEdge1, dEdge2)
        % Inconsistent: same direction
        badInteriorEdgeIdx(end+1) = eIdx;
        
        % Identify the two faces
        face1 = mod(occurrenceIdx(1)-1, nF) + 1;
        face2 = mod(occurrenceIdx(2)-1, nF) + 1;
        badFacePairs(end+1, :) = [face1 face2];
    end
end

badInteriorEdgeIdx = badInteriorEdgeIdx(:);
tf = isempty(badInteriorEdgeIdx);

end
