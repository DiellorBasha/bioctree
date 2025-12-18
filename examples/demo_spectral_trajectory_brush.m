%% Test Script for Spectral Trajectory Brush
% This script demonstrates the spectral trajectory brush

clear; close all;

%% 1. Load a test mesh
fprintf('=== Loading Test Mesh ===\n');

% Use icosphere for testing
[V, F] = icosphere(3);  % 642 vertices
% Ensure proper data types for Manifold constructor
V = double(V);
F = double(F);
fprintf('Mesh: %d vertices, %d faces\n', size(V, 1), size(F, 1));

%% 2. Create BCT object and compute eigenbasis
fprintf('\n=== Setting Up BCT Object ===\n');

B = bct.bct();
B.Manifold = bct.Manifold(V, F);

% Compute eigendecomposition
k = 100;  % Number of eigenmodes
fprintf('Computing %d eigenmodes...\n', k);
B.Lambda = B.Manifold.dual('numModes', k);
fprintf('Eigenvalues range: [%.4f, %.4f]\n', ...
    B.Lambda.lambda(1), B.Lambda.lambda(end));

%% 3. Select source and target vertices
fprintf('\n=== Selecting Path Vertices ===\n');

% Find vertices on opposite sides of the sphere
[~, source] = max(V(:,1));  % rightmost point
[~, target] = min(V(:,1));  % leftmost point

fprintf('Source vertex: %d [%.2f, %.2f, %.2f]\n', ...
    source, V(source,1), V(source,2), V(source,3));
fprintf('Target vertex: %d [%.2f, %.2f, %.2f]\n', ...
    target, V(target,1), V(target,2), V(target,3));

%% 4. Test different spectral filters

% Test 1: Heat kernel (low-pass filter)
fprintf('\n=== Test 1: Heat Kernel (Low-pass) ===\n');
params1 = struct();
params1.source = source;
params1.target = target;
params1.kernel = 'heat';
params1.kernel_params = struct('tau', 0.1);

w_heat = bct.brush.trajectory.spectral(B.Manifold, params1);
fprintf('Heat kernel brush: %d non-zero vertices (%.1f%% of mesh)\n', ...
    nnz(w_heat), 100*nnz(w_heat)/B.Manifold.N);
fprintf('Weight range: [%.4f, %.4f]\n', min(w_heat), max(w_heat));

% Test 2: Gaussian bandpass filter
fprintf('\n=== Test 2: Gaussian Bandpass ===\n');
params2 = struct();
params2.source = source;
params2.target = target;
params2.kernel = 'gaussian';
params2.kernel_params = struct('center', 50, 'sigma', 20);

w_gaussian = bct.brush.trajectory.spectral(B.Manifold, params2);
fprintf('Gaussian kernel brush: %d non-zero vertices (%.1f%% of mesh)\n', ...
    nnz(w_gaussian), 100*nnz(w_gaussian)/B.Manifold.N);
fprintf('Weight range: [%.4f, %.4f]\n', min(w_gaussian), max(w_gaussian));

% Test 3: Compare with geodesic brush
fprintf('\n=== Test 3: Geodesic Brush (for comparison) ===\n');
params_geo = struct();
params_geo.source = source;
params_geo.target = target;

w_geodesic = bct.brush.trajectory.geodesic(B.Manifold, params_geo);
fprintf('Geodesic brush: %d vertices on path\n', nnz(w_geodesic));

%% 5. Visualize results
fprintf('\n=== Visualization ===\n');

figure('Position', [100 100 1600 500]);

% Plot 1: Heat kernel
subplot(1,3,1);
B.Manifold.plot('data', full(w_heat), 'shading', 'interp');
colormap(jet); colorbar;
title('Spectral Brush: Heat Kernel (Low-pass)');
axis equal tight off;
view([0 0]);

% Plot 2: Gaussian bandpass
subplot(1,3,2);
B.Manifold.plot('data', full(w_gaussian), 'shading', 'interp');
colormap(jet); colorbar;
title('Spectral Brush: Gaussian Bandpass');
axis equal tight off;
view([0 0]);

% Plot 3: Geodesic (for comparison)
subplot(1,3,3);
B.Manifold.plot('data', full(w_geodesic), 'shading', 'interp');
colormap(jet); colorbar;
title('Geodesic Brush (comparison)');
axis equal tight off;
view([0 0]);

fprintf('\n=== Test Complete ===\n');
fprintf('The spectral brush creates smoothed trajectories using spectral filtering.\n');
fprintf('Different kernels produce different spatial smoothing characteristics.\n');
