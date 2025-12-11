function UV = computeUVFromSphere(V_sphere)
%COMPUTEUVFROMSPHERE Compute UV parametrization from spherical coordinates
%
%   UV = computeUVFromSphere(V_sphere) converts spherical vertex coordinates
%   to UV parametrization suitable for texture mapping and visualization.
%
%   Algorithm:
%     Given vertices on a sphere (from FreeSurfer .sphere.reg file):
%       theta = atan2(y, x)      % Azimuthal angle [-π, π]
%       phi   = acos(z)          % Polar angle [0, π]
%       u = (theta + π) / (2π)   % Normalize to [0, 1]
%       v = phi / π              % Normalize to [0, 1]
%
%   Parameters:
%     V_sphere - N×3 vertex coordinates on sphere
%
%   Returns:
%     UV - N×2 matrix of UV coordinates in [0, 1] × [0, 1]
%
%   Example:
%     sphere_raw = bct.io.in.readFreeSurferSurf('lh.sphere.reg');
%     UV = bct.io.import.computeUVFromSphere(sphere_raw.V);
%
%   See also: bct.io.import.mesh, bct.io.import.findSphereReg

    % Validate input
    if size(V_sphere, 2) ~= 3
        error('bct:io:import:InvalidInput', ...
            'V_sphere must be N×3 matrix');
    end
    
    % Normalize vertices to unit sphere
    % FreeSurfer sphere.reg files store vertices on a sphere of radius ~100
    % We need radius = 1 for spherical coordinate conversion
    V_norm = V_sphere ./ sqrt(sum(V_sphere.^2, 2));
    
    % Extract coordinates
    x = V_norm(:, 1);
    y = V_norm(:, 2);
    z = V_norm(:, 3);
    
    % Clamp z to [-1, 1] for numerical stability
    % After normalization, z should be in [-1, 1], but numerical errors
    % can cause slight overflow (e.g., 1.0000000001)
    z = max(-1, min(1, z));
    
    % Compute spherical coordinates
    % theta: azimuthal angle [-π, π]
    % phi: polar angle [0, π]
    theta = atan2(y, x);
    phi = acos(z);
    
    % Normalize to [0, 1] range for UV coordinates
    u = (theta + pi) / (2 * pi);
    v = phi / pi;
    
    % Combine into UV matrix
    UV = [u, v];
end
