function [nBoundary, nInterior, nNonManifold, boundaryIdx, interiorIdx, nonManifoldIdx] = edgeMultiplicity(~, cache, ~)
%EDGEMULTIPLICITY Compute edge multiplicity statistics from canonical edges
%
% Syntax:
%   [nBoundary, nInterior, nNonManifold, boundaryIdx, interiorIdx, nonManifoldIdx] = ...
%       bct.manifold.health.measure.edgeMultiplicity(mesh, cache, options)
%
% Inputs:
%   mesh    - Normalized mesh structure (unused, uses cache)
%   cache   - Cache structure with fields:
%             .multiplicity - [nE×1] face incidence count per canonical edge
%   options - Options structure (unused)
%
% Outputs:
%   nBoundary       - Count of boundary edges (multiplicity == 1)
%   nInterior       - Count of interior edges (multiplicity == 2)
%   nNonManifold    - Count of non-manifold edges (multiplicity >= 3)
%   boundaryIdx     - Indices into canonical E for boundary edges
%   interiorIdx     - Indices into canonical E for interior edges
%   nonManifoldIdx  - Indices into canonical E for non-manifold edges
%
% Description:
%   Analyzes edge multiplicity from cached incidence data.
%   
%   Edge types:
%   - Boundary (multiplicity == 1): Edge appears in only one face
%   - Interior manifold (multiplicity == 2): Edge shared by exactly two faces
%   - Non-manifold (multiplicity >= 3): Edge shared by three or more faces
%
%   All index outputs are indices into the canonical edge list mesh.E
%   (which comes from M.Edges when input is bct.Manifold).
%
% See also: bct.manifold.health.measure.boundaryEdges,
%           bct.manifold.health.measure.nonManifoldEdges

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Require cache with multiplicity
if ~isfield(cache, 'multiplicity') || isempty(cache.multiplicity)
    error('bct:manifold:health:MissingCache', ...
        'edgeMultiplicity requires cache.multiplicity from buildEdgeIncidence');
end

multiplicity = cache.multiplicity;
nE = length(multiplicity);

% Classify edges by multiplicity
boundaryIdx = find(multiplicity == 1);
interiorIdx = find(multiplicity == 2);
nonManifoldIdx = find(multiplicity >= 3);

% Counts
nBoundary = length(boundaryIdx);
nInterior = length(interiorIdx);
nNonManifold = length(nonManifoldIdx);

end
