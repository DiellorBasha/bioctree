function [tf, boundaryEdgeIdx, boundaryVertexIdx] = boundaryEdges(mesh, cache, ~)
%BOUNDARYEDGES Detect boundary edges (multiplicity == 1)
%
% Syntax:
%   [tf, boundaryEdgeIdx, boundaryVertexIdx] = ...
%       bct.manifold.health.measure.boundaryEdges(mesh, cache, options)
%
% Inputs:
%   mesh    - Normalized mesh structure with .E field
%   cache   - Cache structure with .multiplicity field
%   options - Options structure (unused)
%
% Outputs:
%   tf                - true if mesh has boundary edges, false otherwise
%   boundaryEdgeIdx   - Indices into canonical E for boundary edges
%   boundaryVertexIdx - Unique vertex indices on boundary
%
% Description:
%   Identifies edges that appear in only one face (multiplicity == 1).
%   These are boundary edges indicating the mesh is not closed.
%
%   All edge indices are indices into mesh.E (canonical edge list from
%   M.Edges when input is bct.Manifold).
%
% See also: bct.manifold.health.measure.edgeMultiplicity,
%           bct.manifold.health.check.boundaryEdges

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Require cache with multiplicity
if ~isfield(cache, 'multiplicity') || isempty(cache.multiplicity)
    error('bct:manifold:health:MissingCache', ...
        'boundaryEdges requires cache.multiplicity from buildEdgeIncidence');
end

multiplicity = cache.multiplicity;
E = mesh.E;

% Find boundary edges (multiplicity == 1)
boundaryEdgeIdx = find(multiplicity == 1);

tf = ~isempty(boundaryEdgeIdx);

% Extract boundary vertices
if tf
    boundaryVertexIdx = unique(E(boundaryEdgeIdx, :));
else
    boundaryVertexIdx = [];
end

end
