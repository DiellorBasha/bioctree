function [tf, badVertexIdx] = vertexManifold(mesh, ~, options)
%VERTEXMANIFOLD Check if all vertices are manifold
%
% Syntax:
%   [tf, badVertexIdx] = bct.manifold.health.measure.vertexManifold(mesh, cache, options)
%
% Inputs:
%   mesh    - Normalized mesh structure with .V, .F fields
%   cache   - Cache structure (unused)
%   options - Options structure with optional:
%             .UseSurfaceMesh - true to use surfaceMesh fallback (default: true)
%
% Outputs:
%   tf           - true if all vertices are manifold, false otherwise (NaN if unknown)
%   badVertexIdx - Indices of non-manifold vertices (empty if not available)
%
% Description:
%   Checks if all vertices are locally manifold (disk-like neighborhood).
%   
%   Current implementation uses MATLAB's surfaceMesh API as fallback.
%   Limitations:
%   - surfaceMesh may not return indices of offending vertices
%   - Requires V (vertex coordinates)
%   
%   Future: Implement internal check based on edge-face incidence that
%   identifies non-manifold vertices and returns their indices.
%
% See also: bct.manifold.health.internal.surfaceMeshAdapter,
%           bct.manifold.health.check.vertexManifold

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Parse options
if nargin < 3 || ~isfield(options, 'UseSurfaceMesh')
    useSurfaceMesh = true;
else
    useSurfaceMesh = options.UseSurfaceMesh;
end

% Require vertices
if ~mesh.hasV
    % Cannot check without vertices
    tf = NaN;
    badVertexIdx = [];
    return;
end

V = mesh.V;
F = mesh.F;

% Use surfaceMesh fallback if enabled
if useSurfaceMesh
    try
        [tf, badVertexIdx] = bct.manifold.health.internal.surfaceMeshAdapter(V, F);
    catch ME
        % surfaceMesh failed
        warning('bct:manifold:health:SurfaceMeshFailed', ...
            'surfaceMesh adapter failed: %s. Returning NaN.', ME.message);
        tf = NaN;
        badVertexIdx = [];
    end
else
    % Internal implementation not yet available
    warning('bct:manifold:health:NotImplemented', ...
        'Internal vertex manifoldness check not yet implemented. Use UseSurfaceMesh=true.');
    tf = NaN;
    badVertexIdx = [];
end

end
