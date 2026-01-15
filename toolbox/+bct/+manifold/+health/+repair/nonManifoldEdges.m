function [V_out, F_out] = nonManifoldEdges(V, F)
%NONMANIFOLDEDGES Remove faces incident to non-manifold edges
%
% Syntax:
%   [V_out, F_out] = bct.manifold.health.repair.nonManifoldEdges(V, F)
%
% Inputs:
%   V - [N×3] vertex coordinates
%   F - [M×3] face connectivity
%
% Outputs:
%   V_out - [N×3] vertex coordinates (may have unreferenced vertices after)
%   F_out - [M2×3] face connectivity (M2 ≤ M, faces incident to non-manifold edges removed)
%
% Description:
%   Removes faces incident to edges shared by 3 or more faces (non-manifold).
%   Uses surfaceMesh.removeDefects() internally.
%   
%   Note: May leave unreferenced vertices. Consider running
%   bct.manifold.health.repair(M, "unreferenced-vertices") afterward.
%
% Examples:
%   [V_clean, F_clean] = bct.manifold.health.repair.nonManifoldEdges(V, F);
%
% See also: surfaceMesh.removeDefects, bct.manifold.health.repair

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Create surfaceMesh and apply fix
mesh = surfaceMesh(V, F);
removeDefects(mesh, "nonmanifold-edges");  % Modifies in-place

% Extract repaired mesh
V_out = mesh.Vertices;
F_out = mesh.Faces;

end
