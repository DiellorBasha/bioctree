function [ic, multiplicity, dE, uE] = buildEdgeIncidence(F, E)
%BUILDEDGEINCIDENCE Build mapping from face-edge occurrences to canonical edges
%
% Syntax:
%   [ic, multiplicity] = bct.manifold.health.internal.buildEdgeIncidence(F, E)
%   [ic, multiplicity, dE, uE] = bct.manifold.health.internal.buildEdgeIncidence(F, E)
%
% Inputs:
%   F - [nF×3] Face connectivity
%   E - [nE×2] Canonical undirected edge list (from M.Edges or derived)
%
% Outputs:
%   ic           - [3*nF×1] Mapping from face-edge occurrences to canonical E indices
%   multiplicity - [nE×1] Face incidence count per canonical edge
%   dE           - [3*nF×2] Directed face-edge list (optional)
%   uE           - [3*nF×2] Undirected face-edge keys (optional)
%
% Description:
%   Creates a deterministic mapping from each of the 3*nF directed face-edge
%   occurrences to indices in the canonical edge list E.
%
%   Directed edges from faces:
%   - dE = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])]
%   
%   For each directed edge, compute undirected key by sorting:
%   - uE = sort(dE, 2)
%
%   Map each undirected key to its index in canonical E using efficient lookup.
%
%   The multiplicity array counts how many times each canonical edge appears
%   in the face list (should be 1 for boundary, 2 for manifold interior,
%   ≥3 for non-manifold).
%
% See also: bct.manifold.health.internal.ensureCanonicalEdges

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

nF = size(F, 1);
nE = size(E, 1);
nV = max(max(F));

% Build directed face-edge list
dE = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];  % [3*nF × 2]

% Compute undirected keys by sorting
uE = sort(dE, 2);  % [3*nF × 2]

% Build efficient edge key mapping using integer encoding
% Create unique keys for edges (u < v assumed in uE)
edgeKeys = uint64(uE(:,1)) * uint64(nV + 1) + uint64(uE(:,2));
canonicalKeys = uint64(E(:,1)) * uint64(nV + 1) + uint64(E(:,2));

% Build map from canonical keys to indices
keyMap = containers.Map(canonicalKeys, 1:nE);

% Map each face-edge occurrence to canonical index
ic = zeros(3*nF, 1);
for i = 1:length(edgeKeys)
    if keyMap.isKey(edgeKeys(i))
        ic(i) = keyMap(edgeKeys(i));
    else
        error('bct:manifold:health:EdgeInconsistency', ...
            'Face-edge at occurrence %d not found in canonical edge list E. This indicates E is not derived from F.', i);
    end
end

% Compute multiplicity (face incidence count per canonical edge)
multiplicity = accumarray(ic, 1, [nE 1]);

end
