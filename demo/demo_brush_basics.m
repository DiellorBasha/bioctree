%DEMO_BRUSH_BASICS  Introduction to BCT brush system
%
% This demo shows how to create spatial selections using the BCT brush system.
% Brushes are weighted selection tools that define regions of interest on 
% cortical meshes.
%
% Topics covered:
%   1. Loading a mesh and creating a Manifold
%   2. Using geometric brushes (nearest, gaussian)
%   3. Using spectral brushes (patch_spectral)
%   4. Visualizing brush selections
%   5. Discovering available brushes
%
% Uses the default fsaverage6 test mesh included with the toolbox.
%
% See also: bct.brush.apply, bct.registry.brushes, bct.runtime.brushes

%% Initialize workspace
clearvars; close all;

% Ensure bioctree is initialized
if ~exist('bct.Manifold', 'class')
    error('bioctree toolbox not initialized. Run bct_start first.');
end

fprintf('=== BCT Brush Basics Demo ===\n\n');

%% 1. Load Test Mesh
fprintf('[1/6] Loading cortical mesh...\n');

% Get the default mesh path from bct.data
mesh = bct.data.load();  % Load default mesh struct
M = bct.manifold.load(mesh);  % Create Manifold object

fprintf('  Loaded: %d vertices, %d faces\n', size(M.Vertices, 1), size(M.Faces, 1));

%% 2. Discover Available Brushes
fprintf('\n[2/6] Discovering available brushes...\n');

% List all registered brushes
allBrushes = bct.registry.brushes('list');
fprintf('  Total brushes: %d\n', numel(allBrushes));

% List only brushes compatible with this manifold
availableBrushes = bct.runtime.brushes('list', M);
fprintf('  Compatible with this mesh: %d\n', numel(availableBrushes));
fprintf('  Available: %s\n', strjoin(availableBrushes, ', '));

%% 3. Nearest Neighbors Brush (Simple Geometric)
fprintf('\n[3/6] Creating K-nearest neighbors selection...\n');

% Select center vertex (middle of mesh approximately)
centerIdx = round(size(M.Vertices, 1) / 2);

% Apply nearest neighbors brush
params_nearest = struct(...
    'center', centerIdx, ...
    'k', 200);  % Select 200 nearest neighbors

w_nearest = bct.brush.apply('patch_nearest', M, params_nearest);

fprintf('  Center vertex: %d\n', centerIdx);
fprintf('  Selected vertices: %d\n', sum(w_nearest > 0));
fprintf('  Max weight: %.2f\n', max(w_nearest));

% Visualize
figure('Name', 'Nearest Neighbors Brush', 'Position', [100 100 800 600]);
bct.show.mesh(M);
bct.show.signal(w_nearest);
title(sprintf('K-Nearest Neighbors (k=%d)', params_nearest.k));
colorbar;

%% 4. Gaussian Brush (Smooth Geometric)
fprintf('\n[4/6] Creating Gaussian-weighted selection...\n');

% Apply gaussian brush
params_gaussian = struct(...
    'center', centerIdx, ...
    'radius', 20);  % Geodesic radius in mm

w_gaussian = bct.brush.apply('patch_gaussian', M, params_gaussian);

fprintf('  Center vertex: %d\n', centerIdx);
fprintf('  Radius: %.1f mm\n', params_gaussian.radius);
fprintf('  Vertices with weight > 0.01: %d\n', sum(w_gaussian > 0.01));

% Visualize
figure('Name', 'Gaussian Brush', 'Position', [150 150 800 600]);
bct.show.mesh(M);
bct.show.signal(w_gaussian);
title(sprintf('Gaussian Brush (radius=%.1fmm)', params_gaussian.radius));
colorbar;

%% 5. Spectral Brush (Frequency-Based)
fprintf('\n[5/6] Creating spectral-filtered selection...\n');

% Spectral brushes use the Laplace-Beltrami eigenbasis
% This creates smooth, band-limited selections
params_spectral = struct(...
    'center', centerIdx, ...
    'numModes', 100, ...      % Number of eigenmodes to use
    'bandwidth', 0.05);       % Spectral bandwidth (smaller = smoother)

fprintf('  Computing eigenpairs (this may take a moment)...\n');
tic;
w_spectral = bct.brush.apply('patch_spectral', M, params_spectral);
t_spectral = toc;

fprintf('  Center vertex: %d\n', centerIdx);
fprintf('  Number of modes: %d\n', params_spectral.numModes);
fprintf('  Bandwidth: %.3f\n', params_spectral.bandwidth);
fprintf('  Computation time: %.2f seconds\n', t_spectral);
fprintf('  Vertices with weight > 0.01: %d\n', sum(w_spectral > 0.01));

% Visualize
figure('Name', 'Spectral Brush', 'Position', [200 200 800 600]);
bct.show.mesh(M);
bct.show.signal(w_spectral);
title(sprintf('Spectral Brush (modes=%d, bw=%.3f)', ...
    params_spectral.numModes, params_spectral.bandwidth));
colorbar;

%% 6. Compare All Three Brushes
fprintf('\n[6/6] Comparing brush types...\n');

figure('Name', 'Brush Comparison', 'Position', [250 250 1400 400]);

% Nearest neighbors
subplot(1, 3, 1);
bct.show.mesh(M);
bct.show.signal(w_nearest);
title('K-Nearest Neighbors');
colorbar;
view([90 0]);

% Gaussian
subplot(1, 3, 2);
bct.show.mesh(M);
bct.show.signal(w_gaussian);
title('Gaussian');
colorbar;
view([90 0]);

% Spectral
subplot(1, 3, 3);
bct.show.mesh(M);
bct.show.signal(w_spectral);
title('Spectral');
colorbar;
view([90 0]);

sgtitle('Brush Comparison: Same Center, Different Methods');

%% 7. Advanced: Parameter Exploration
fprintf('\n[BONUS] Exploring spectral bandwidth parameter...\n');

% Test different bandwidth values
bandwidths = [0.01, 0.03, 0.05, 0.1];
figure('Name', 'Spectral Bandwidth Effects', 'Position', [300 300 1400 800]);

for i = 1:length(bandwidths)
    params = struct(...
        'center', centerIdx, ...
        'numModes', 100, ...
        'bandwidth', bandwidths(i));
    
    w = bct.brush.apply('patch_spectral', M, params);
    
    subplot(2, 2, i);
    bct.show.mesh(M);
    bct.show.signal(w);
    title(sprintf('Bandwidth = %.3f', bandwidths(i)));
    colorbar;
    view([90 0]);
end

sgtitle('Effect of Spectral Bandwidth (smaller = smoother)');

%% Summary
fprintf('\n=== Demo Complete ===\n');
fprintf('Key Takeaways:\n');
fprintf('  • Use bct.brush.apply(brushId, manifold, params) to create selections\n');
fprintf('  • Nearest: Simple k-neighbor selection\n');
fprintf('  • Gaussian: Smooth geodesic distance-based selection\n');
fprintf('  • Spectral: Smooth, band-limited selection using eigenbasis\n');
fprintf('  • Spectral brushes respect mesh geometry and topology\n');
fprintf('  • Smaller bandwidth = smoother, more spread out selection\n');
fprintf('\nNext steps:\n');
fprintf('  • See docs/BRUSH_QUICK_REFERENCE.md for all brush types\n');
fprintf('  • Try trajectory brushes for path-based selections\n');
fprintf('  • Try time brushes for spatiotemporal patterns\n');
