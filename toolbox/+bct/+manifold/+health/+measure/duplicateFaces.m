function [tf, duplicateIdx] = duplicateFaces(mesh, ~, ~)
%DUPLICATEFACES Check for duplicate faces
%
% Syntax:
%   [tf, duplicateIdx] = bct.manifold.health.measure.duplicateFaces(mesh, cache, options)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   cache   - Cache structure (unused)
%   options - Options structure (unused)
%
% Outputs:
%   tf           - true if no duplicate faces, false otherwise
%   duplicateIdx - Indices of duplicate face instances
%
% Description:
%   Detects faces that appear more than once in the face list.
%   Faces are considered duplicates if they have the same three vertices
%   in any cyclic permutation (e.g., [1 2 3], [2 3 1], [3 1 2]).
%
%   Returns indices of all duplicate instances (not just first occurrence).
%
% See also: bct.manifold.health.check.duplicateFaces

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

F = mesh.F;
nF = mesh.nF;

% Empty mesh has no duplicates
if nF == 0
    tf = true;
    duplicateIdx = [];
    return;
end

% Normalize faces to canonical form (cyclic rotation with minimum first)
% For each face, find the cyclic permutation that has the minimum vertex first
Fnorm = zeros(size(F));
for i = 1:nF
    face = F(i,:);
    [~, minIdx] = min(face);
    
    % Rotate to put minimum first
    if minIdx == 1
        Fnorm(i,:) = face;
    elseif minIdx == 2
        Fnorm(i,:) = [face(2) face(3) face(1)];
    else % minIdx == 3
        Fnorm(i,:) = [face(3) face(1) face(2)];
    end
end

% Find duplicates using unique
[~, ia, ic] = unique(Fnorm, 'rows', 'stable');

% Duplicates are faces not in ia (first occurrence)
allIdx = (1:nF)';
duplicateIdx = setdiff(allIdx, ia);

tf = isempty(duplicateIdx);

end
