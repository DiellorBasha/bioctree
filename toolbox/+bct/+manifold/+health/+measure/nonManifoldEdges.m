function [tf, nonManifoldEdgeIdx, maxMultiplicity] = nonManifoldEdges(mesh, cache, ~)
%NONMANIFOLDEDGES Detect non-manifold edges (multiplicity >= 3)
%
% Syntax:
%   [tf, nonManifoldEdgeIdx, maxMultiplicity] = ...
%       bct.manifold.health.measure.nonManifoldEdges(mesh, cache, options)
%
% Inputs:
%   mesh    - Normalized mesh structure with .E field
%   cache   - Cache structure with .multiplicity field
%   options - Options structure (unused)
%
% Outputs:
%   tf                 - true if edge-manifold (no non-manifold edges), false otherwise
%   nonManifoldEdgeIdx - Indices into canonical E for non-manifold edges
%   maxMultiplicity    - Maximum edge multiplicity found
%
% Description:
%   Identifies edges shared by three or more faces (multiplicity >= 3).
%   Such edges violate manifoldness and prevent DEC operator construction.
%
%   All edge indices are indices into mesh.E (canonical edge list from
%   M.Edges when input is bct.Manifold).
%
% See also: bct.manifold.health.measure.edgeMultiplicity,
%           bct.manifold.health.check.nonManifoldEdges

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Require cache with multiplicity
if ~isfield(cache, 'multiplicity') || isempty(cache.multiplicity)
    error('bct:manifold:health:MissingCache', ...
        'nonManifoldEdges requires cache.multiplicity from buildEdgeIncidence');
end

multiplicity = cache.multiplicity;

% Find non-manifold edges (multiplicity >= 3)
nonManifoldEdgeIdx = find(multiplicity >= 3);

tf = isempty(nonManifoldEdgeIdx);  % true if manifold

% Max multiplicity
if isempty(multiplicity)
    maxMultiplicity = 0;
else
    maxMultiplicity = max(multiplicity);
end

end
