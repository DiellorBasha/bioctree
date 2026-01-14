function [tf, degenerateIdx] = degenerateFaces(mesh, ~, ~)
%DEGENERATEFACES Check for degenerate faces (repeated vertex indices)
%
% Syntax:
%   [tf, degenerateIdx] = bct.manifold.health.measure.degenerateFaces(mesh, cache, options)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   cache   - Cache structure (unused)
%   options - Options structure (unused)
%
% Outputs:
%   tf            - true if no degenerate faces, false otherwise
%   degenerateIdx - Indices of degenerate faces
%
% Description:
%   Detects faces with repeated vertex indices (e.g., [1 1 2] or [1 2 1]).
%   Such faces are degenerate and invalid for DEC operators.
%
%   A face is degenerate if any two of its three vertex indices are identical.
%
% See also: bct.manifold.health.check.degenerateFaces

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

F = mesh.F;
nF = mesh.nF;

% Empty mesh has no degenerate faces
if nF == 0
    tf = true;
    degenerateIdx = [];
    return;
end

% Check for repeated indices within each face
% A face [a b c] is degenerate if a==b or b==c or c==a
degenerateMask = (F(:,1) == F(:,2)) | (F(:,2) == F(:,3)) | (F(:,3) == F(:,1));

degenerateIdx = find(degenerateMask);
tf = isempty(degenerateIdx);

end
