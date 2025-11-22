%% Example: UV Parametrization from FreeSurfer Spherical Registration
% Demonstrates automatic UV coordinate generation during mesh import

clear all;
close all;

% Add toolbox to path
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));

fprintf('=== UV Parametrization Example ===\n\n');

%% Load FreeSurfer mesh with automatic UV import
% When importing a FreeSurfer surface, the pipeline automatically:
% 1. Detects the corresponding .sphere.reg file
% 2. Loads spherical coordinates
% 3. Computes UV parametrization
% 4. Stores in B.Manifold.UV

path = 'test-data/freesurfer/fsaverage/surf/lh.pial';

if ~isfile(path)
    fprintf('Error: Test data not found at: %s\n', path);
    fprintf('Please ensure FreeSurfer test data is available.\n');
    return;
end

fprintf('Loading mesh: %s\n', path);
B = bct.io.import.mesh(path);

fprintf('  Mesh loaded: %d vertices, %d faces\n', B.Manifold.N, size(B.Manifold.F, 1));

%% Check UV parametrization
if ~B.Manifold.checkUV(false)
    fprintf('  UV parametrization not available\n');
    fprintf('  (sphere.reg file not found in the same directory)\n');
    fprintf('\n  Exiting example - UV required for visualization.\n');
    return;
end

fprintf('  ✓ UV parametrization loaded: [%d × 2]\n', size(B.Manifold.UV, 1));
fprintf('    U range: [%.3f, %.3f]\n', min(B.Manifold.UV(:,1)), max(B.Manifold.UV(:,1)));
fprintf('    V range: [%.3f, %.3f]\n\n', min(B.Manifold.UV(:,2)), max(B.Manifold.UV(:,2)));

%% Application: Generate signal and visualize in UV space
fprintf('Generating graph signal...\n');

% Generate a spatial pattern
spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;

B = bct.sim.synth_mesh_signal(B, spec, 'k', 100, 'label', 'spatial_pattern');
signal_data = B.Signals(1).Data;

fprintf('  Signal generated: [%d × 1]\n\n', length(signal_data));

%% Visualization
fprintf('Creating visualizations...\n');

figure('Position', [100 100 1400 600]);

% Panel 1: Signal on 3D mesh
subplot(2, 3, 1);
trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
    signal_data, 'EdgeColor', 'none');
axis equal off;
view(3);
colorbar;
title('Signal on 3D Mesh');
colormap(gca, 'parula');

% Panel 2: Signal projected to UV space (flattened)
subplot(2, 3, 2);
scatter(B.Manifold.UV(:,1), B.Manifold.UV(:,2), 30, signal_data, 'filled');
axis equal tight;
colorbar;
xlabel('U');
ylabel('V');
title('Signal in UV Space (scatter)');
grid on;
colormap(gca, 'parula');

% Panel 3: Signal in UV space with mesh topology
subplot(2, 3, 3);
trisurf(B.Manifold.F, B.Manifold.UV(:,1), B.Manifold.UV(:,2), ...
    zeros(size(B.Manifold.UV, 1), 1), signal_data, 'EdgeColor', 'none');
view(2);
axis equal tight;
colorbar;
xlabel('U');
ylabel('V');
title('Signal in UV Space (mesh)');
colormap(gca, 'parula');

% Panel 4: U coordinate visualization
subplot(2, 3, 4);
trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
    B.Manifold.UV(:,1), 'EdgeColor', 'none');
axis equal off;
view(3);
colorbar;
title('U Coordinate (azimuthal)');
colormap(gca, 'hsv');

% Panel 5: V coordinate visualization
subplot(2, 3, 5);
trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
    B.Manifold.UV(:,2), 'EdgeColor', 'none');
axis equal off;
view(3);
colorbar;
title('V Coordinate (polar)');
colormap(gca, 'parula');

% Panel 6: UV grid overlay
subplot(2, 3, 6);
trisurf(B.Manifold.F, B.Manifold.UV(:,1), B.Manifold.UV(:,2), ...
    zeros(size(B.Manifold.UV, 1), 1), 'EdgeColor', [0.7 0.7 0.7], ...
    'FaceAlpha', 0.3, 'FaceColor', 'w');
view(2);
axis equal tight;
xlabel('U');
ylabel('V');
title('UV Mesh Topology');
grid on;

sgtitle('UV Parametrization from FreeSurfer Spherical Registration', ...
    'FontSize', 14, 'FontWeight', 'bold');

fprintf('  ✓ Visualization complete\n\n');

%% Summary
fprintf('=== Usage Summary ===\n\n');

fprintf('Import with automatic UV:\n');
fprintf('  path = ''test-data/freesurfer/fsaverage/surf/lh.pial'';\n');
fprintf('  B = bct.io.import.mesh(path);\n');
fprintf('  \n');
fprintf('  %% Check if UV is available (optional)\n');
fprintf('  if B.Manifold.checkUV(false)\n');
fprintf('      UV = B.Manifold.UV;  %% [N × 2] UV coordinates\n');
fprintf('  end\n\n');

fprintf('UV coordinates are derived from .sphere.reg file:\n');
fprintf('  • Automatically detected and loaded during import\n');
fprintf('  • Computed using spherical coordinates:\n');
fprintf('      theta = atan2(y, x)      %% Azimuthal [-π, π]\n');
fprintf('      phi   = acos(z)          %% Polar [0, π]\n');
fprintf('      u = (theta + π) / (2π)   %% Normalized to [0, 1]\n');
fprintf('      v = phi / π              %% Normalized to [0, 1]\n\n');

fprintf('Applications:\n');
fprintf('  • Texture mapping\n');
fprintf('  • 2D visualization of surface signals\n');
fprintf('  • Feature extraction in parametric space\n');
fprintf('  • Cross-subject registration\n\n');

