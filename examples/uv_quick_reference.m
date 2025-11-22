% UV Parametrization Quick Reference

%% Basic Usage
% Import FreeSurfer surface with automatic UV loading
path = 'test-data/freesurfer/fsaverage/surf/lh.pial';
B = bct.io.import.mesh(path);

% Check if UV is available (UV is optional)
if B.Manifold.checkUV(false)  % false = warn but don't error
    UV = B.Manifold.UV;  % [N×2] matrix
    fprintf('UV parametrization available: [%d × 2]\n', size(UV, 1));
else
    fprintf('UV parametrization not available (sphere.reg not found)\n');
end

%% Check if UV exists
if B.Manifold.checkUV(false)  % Returns true/false, warns if missing
    fprintf('UV parametrization loaded: [%d × 2]\n', size(B.Manifold.UV, 1));
    fprintf('U range: [%.3f, %.3f]\n', min(B.Manifold.UV(:,1)), max(B.Manifold.UV(:,1)));
    fprintf('V range: [%.3f, %.3f]\n', min(B.Manifold.UV(:,2)), max(B.Manifold.UV(:,2)));
else
    fprintf('No UV parametrization (sphere.reg not found)\n');
    return;  % Skip UV-dependent code
end

%% Visualize in UV space
if B.Manifold.checkUV(false)
    % Generate a signal
    spec.type = 'narrowband';
    spec.f0 = 0.1;
    B = bct.sim.synth_mesh_signal(B, spec);
    signal_data = B.Signals(1).Data;
    
    % Plot in UV space
    figure;
    trisurf(B.Manifold.F, B.Manifold.UV(:,1), B.Manifold.UV(:,2), ...
        zeros(B.Manifold.N, 1), signal_data, 'EdgeColor', 'none');
    view(2);
    axis equal tight;
    xlabel('U');
    ylabel('V');
    title('Signal in UV Parametric Space');
    colorbar;
end

%% Manual UV computation (if needed)
% Load sphere.reg manually
sphere_path = 'test-data/freesurfer/fsaverage/surf/lh.sphere.reg';
sphere_raw = bct.io.in.readFreeSurferSurf(sphere_path);
UV = bct.io.import.computeUVFromSphere(sphere_raw.V);

% Assign to existing BCT object
B.Manifold.UV = UV;

%% Find corresponding sphere.reg
surf_path = 'test-data/freesurfer/fsaverage/surf/lh.pial';
sphere_reg_path = bct.io.import.findSphereReg(surf_path);

if ~isempty(sphere_reg_path)
    fprintf('Found: %s\n', sphere_reg_path);
else
    fprintf('No sphere.reg found\n');
end

%% UV Coordinate System
% U: Azimuthal coordinate [0, 1]
%    - Wraps around the sphere horizontally
%    - theta = atan2(y, x) mapped to [0, 1]
%
% V: Polar coordinate [0, 1]
%    - Goes from north pole (0) to south pole (1)
%    - phi = acos(z) mapped to [0, 1]

%% Applications

% 1. Texture mapping (with UV check)
if B.Manifold.checkUV(false)
    texture_value = interp2(texture_image, B.Manifold.UV(:,1), B.Manifold.UV(:,2));
end

% 2. Feature extraction in UV space (with UV check)
if B.Manifold.checkUV(false)
    UV_features = extract_features_from_UV(B.Manifold.UV);
end

% 3. 2D visualization of 3D signals (with UV check)
if B.Manifold.checkUV(false)
    scatter(B.Manifold.UV(:,1), B.Manifold.UV(:,2), 30, signal_data, 'filled');
end

% 4. Cross-subject comparison (with UV check)
if B.Manifold.checkUV(false)
    signal_in_uv = griddata(B.Manifold.UV(:,1), B.Manifold.UV(:,2), signal_data, ...
        uv_grid_x, uv_grid_y);
end

%% Error-throwing mode for UV-dependent functions
% Use checkUV(true) when UV is required (not optional)
try
    B.Manifold.checkUV(true);  % Throws error if UV missing
    % Proceed with UV-dependent operation
    plot_uv_texture(B.Manifold.UV, texture_data);
catch ME
    fprintf('Cannot proceed: %s\n', ME.message);
end

