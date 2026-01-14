function [tf, invalidIdx] = facesValid(mesh, ~, ~)
%FACESVALID Check if face connectivity is valid
%
% Syntax:
%   [tf, invalidIdx] = bct.manifold.health.measure.facesValid(mesh, cache, options)
%
% Inputs:
%   mesh    - Normalized mesh structure
%   cache   - Cache structure (unused)
%   options - Options structure (unused)
%
% Outputs:
%   tf         - true if all faces are valid, false otherwise
%   invalidIdx - Indices of invalid faces
%
% Description:
%   Checks if all face indices are within valid vertex range [1, nV].
%   Invalid faces have indices < 1 or > nV.
%
%   This is a gating check that must pass before other topology checks.
%
% See also: bct.manifold.health.check.faces

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

F = mesh.F;
nV = mesh.nV;
nF = mesh.nF;

% Empty mesh is valid
if nF == 0
    tf = true;
    invalidIdx = [];
    return;
end

% Check bounds
minIdx = min(F(:));
maxIdx = max(F(:));

if minIdx < 1 || maxIdx > nV
    % Find invalid faces
    invalidMask = any(F < 1 | F > nV, 2);
    invalidIdx = find(invalidMask);
    tf = false;
else
    tf = true;
    invalidIdx = [];
end

end
