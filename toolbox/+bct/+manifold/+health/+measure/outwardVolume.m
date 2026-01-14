function [signedVolume, isOutward] = outwardVolume(mesh, ~, ~)
%OUTWARDVOLUME Check if mesh has outward orientation using signed volume
%
% Syntax:
%   [signedVolume, isOutward] = bct.manifold.health.measure.outwardVolume(mesh, cache, options)
%
% Inputs:
%   mesh    - Normalized mesh structure with .V, .F fields
%   cache   - Cache structure (unused)
%   options - Options structure (unused)
%
% Outputs:
%   signedVolume - Signed volume of mesh (positive if outward)
%   isOutward    - true if outward, false if inward, NaN if cannot determine
%
% Description:
%   Computes signed volume to determine global orientation.
%   
%   For closed meshes, positive signed volume indicates outward-facing
%   normals (right-hand rule), negative indicates inward.
%   
%   For open meshes, signed volume is less reliable but still provides
%   an orientation convention check.
%   
%   Requires V (vertex coordinates).
%
% See also: bct.manifold.health.check.outward

% Copyright (c) 2025 bioctree
% SPDX-License-Identifier: MIT

% Require vertices
if ~mesh.hasV
    signedVolume = NaN;
    isOutward = NaN;
    return;
end

V = mesh.V;
F = mesh.F;
nF = mesh.nF;

if nF == 0
    signedVolume = 0;
    isOutward = NaN;
    return;
end

% Compute signed volume using divergence theorem
% V = (1/6) * sum over faces of: dot(v1, cross(v2, v3))
signedVolume = 0;

for i = 1:nF
    v1 = V(F(i,1), :);
    v2 = V(F(i,2), :);
    v3 = V(F(i,3), :);
    
    % Signed volume contribution from this face
    signedVolume = signedVolume + dot(v1, cross(v2, v3));
end

signedVolume = signedVolume / 6.0;

% Determine orientation
if signedVolume > 0
    isOutward = true;
elseif signedVolume < 0
    isOutward = false;
else
    % Volume is exactly zero (degenerate or planar)
    isOutward = NaN;
end

end
