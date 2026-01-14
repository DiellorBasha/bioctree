function mesh = ensureCanonicalEdges(mesh)
%ENSURECANONICALEDGES Ensure mesh structure has canonical edge list
%
% Syntax:
%   mesh = bct.manifold.health.internal.ensureCanonicalEdges(mesh)
%
% Inputs:
%   mesh - Normalized mesh structure from normalizeInput
%
% Outputs:
%   mesh - Mesh structure with E and nE fields populated
%
% Description:
%   Establishes canonical undirected edge list:
%   - If mesh.isManifoldObj is true, uses M.Edges directly
%   - Otherwise, derives edges from F using bct.manifold.topology.edges
%
%   This ensures all edge-indexed outputs refer to the same canonical
%   edge index space throughout health checks.
%
% See also: bct.manifold.health.internal.normalizeInput

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

if mesh.isManifoldObj && ~isempty(mesh.M)
    % Use canonical edges from Manifold
    mesh.E = mesh.M.Edges;
    mesh.nE = size(mesh.E, 1);
else
    % Derive edges from faces using canonical extraction
    mesh.E = bct.manifold.topology.edges(mesh.F);
    mesh.nE = size(mesh.E, 1);
end

end
