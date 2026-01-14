function [tf, duplicateIdx] = duplicateDirectedEdges(~, cache, ~)
%DUPLICATEDIRECTEDEDGES Check for duplicate directed edges in face list
%
% Syntax:
%   [tf, duplicateIdx] = bct.manifold.health.measure.duplicateDirectedEdges(mesh, cache, options)
%
% Inputs:
%   mesh    - Normalized mesh structure (unused)
%   cache   - Cache structure with .dE field
%   options - Options structure (unused)
%
% Outputs:
%   tf           - true if no duplicate directed edges, false otherwise
%   duplicateIdx - Indices into dE space (1..3*nF) for duplicate instances
%
% Description:
%   Detects directed edges that appear more than once in the face list.
%   Unlike undirected edge multiplicity, this checks for identical directed
%   edges [u v] appearing multiple times.
%
%   This typically indicates duplicate faces or other topology errors.
%
%   Output indices are in the directed edge space (1..3*nF), not canonical E.
%   To map back to faces: face = mod(idx-1, nF) + 1, slot = floor((idx-1)/nF) + 1
%
% See also: bct.manifold.health.check.duplicateDirectedEdges

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Require cache with dE
if ~isfield(cache, 'dE') || isempty(cache.dE)
    error('bct:manifold:health:MissingCache', ...
        'duplicateDirectedEdges requires cache.dE');
end

dE = cache.dE;

% Find duplicates in directed edge list
[~, ia, ~] = unique(dE, 'rows', 'stable');

% Duplicates are rows not in ia
allIdx = (1:size(dE,1))';
duplicateIdx = setdiff(allIdx, ia);

tf = isempty(duplicateIdx);

end
