function [V_out, F_out] = unreferencedVertices(V, F)
%UNREFERENCEDVERTICES Remove vertices not referenced by any face
%
% Syntax:
%   [V_out, F_out] = bct.manifold.health.repair.unreferencedVertices(V, F)
%
% Inputs:
%   V - [N×3] vertex coordinates
%   F - [M×3] face connectivity
%
% Outputs:
%   V_out - [N2×3] vertex coordinates (N2 ≤ N, unreferenced vertices removed)
%   F_out - [M×3] face connectivity (re-indexed to match V_out)
%
% Description:
%   Removes vertices that are not referenced by any face and re-indexes
%   the face array accordingly. Uses surfaceMesh.removeDefects() internally.
%
% Examples:
%   [V_clean, F_clean] = bct.manifold.health.repair.unreferencedVertices(V, F);
%
% See also: surfaceMesh.removeDefects, bct.manifold.health.repair

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Create surfaceMesh and apply fix
mesh = surfaceMesh(V, F);
removeDefects(mesh, "unreferenced-vertices");  % Modifies in-place

% Extract repaired mesh
V_out = mesh.Vertices;
F_out = mesh.Faces;

end
