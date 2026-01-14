function [tf, badVertexIdx] = surfaceMeshAdapter(V, F)
%SURFACEMESHADAPTER Fallback adapter for MATLAB's surfaceMesh API
%
% Syntax:
%   [tf, badVertexIdx] = bct.manifold.health.internal.surfaceMeshAdapter(V, F)
%
% Inputs:
%   V - [nV×3] Vertex coordinates
%   F - [nF×3] Face connectivity
%
% Outputs:
%   tf           - true if all vertices are manifold, false otherwise
%   badVertexIdx - Indices of non-manifold vertices (empty if not available)
%
% Description:
%   Wraps MATLAB's surfaceMesh API for vertex manifoldness checking.
%   Handles API variability across MATLAB versions and provides safe
%   fallback with error handling.
%
%   Limitations:
%   - surfaceMesh may not return indices of offending vertices
%   - Construction may fail for invalid meshes
%   - Should only be called after basic validation passes
%
%   This is a temporary fallback. Long-term plan is to implement
%   internal vertex manifoldness check that returns vertex indices.
%
% Examples:
%   try
%       [tf, badIdx] = bct.manifold.health.internal.surfaceMeshAdapter(V, F);
%       if ~tf
%           warning('Non-manifold vertices detected at indices: %s', mat2str(badIdx));
%       end
%   catch ME
%       warning('surfaceMesh fallback failed: %s', ME.message);
%   end
%
% See also: bct.manifold.health.measure.vertexManifold

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Initialize outputs
tf = false;
badVertexIdx = [];

try
    % Construct surfaceMesh
    sm = surfaceMesh(V, F);
    
    % Try to call isVertexManifold (method availability varies by version)
    if ismethod(sm, 'isVertexManifold')
        % Method syntax
        tf = sm.isVertexManifold();
    else
        % Function syntax
        tf = isVertexManifold(sm);
    end
    
    % Note: Standard surfaceMesh API does not return indices of
    % non-manifold vertices. This would require custom implementation.
    % For now, return empty badVertexIdx.
    
catch ME
    % Construction or call failed
    % Rethrow with context
    error('bct:manifold:health:SurfaceMeshFailed', ...
        'surfaceMesh adapter failed: %s', ME.message);
end

end
