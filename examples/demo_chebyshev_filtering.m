%% Demo: Fast Spatial Filtering via Chebyshev Polynomial Approximation
%
% This script demonstrates the applyChebyshevFilter method which provides
% fast 1D spatial filtering on the Manifold domain using Chebyshev polynomial
% approximation. This avoids computing the full eigendecomposition.
%
% Key Concepts:
%   1. Chebyshev approximation - Fast polynomial approximation of filter kernels
%   2. Graph signal processing - Filtering via graph structure (not full eigenbasis)
%   3. Computational efficiency - O(K*M) vs O(N^2) for eigendecomposition
%   4. GSPBox integration - Uses external/gspbox/filters/gsp_filter_analysis
%
% Workflow:
%   Step 1: Create Filter on Lambda domain (spatial kernel)
%   Step 2: Create Signal on Manifold domain (vertex data)
%   Step 3: Apply Chebyshev filtering: B.applyChebyshevFilter(filter, signal)
%   Step 4: Result is filtered signal in Manifold domain

clear; close all;

%% Setup: Create BCT instance with mesh

% Load test mesh (fsaverage right hemisphere)
data = load('data/mesh/fsaverage_rh_pial.mat');

% Initialize BCT from mesh
B = bct.bct.fromMesh(data.V, data.F);

fprintf('Mesh loaded:\n');
fprintf('  Vertices: %d\n', B.Manifold.N);
fprintf('  Faces: %d\n', size(B.Manifold.Faces, 1));

%% Example 1: Delta Impulse with Heat Diffusion (Chebyshev)

fprintf('\n=== Example 1: Heat Diffusion via Chebyshev Approximation ===\n');

% Create delta impulse signal at vertex 5000
mask_delta = bct.filters.Filter(B.Manifold, 'delta', 'x0', 5000);
sig_impulse = bct.Signal.fromMask(mask_delta, 'normalize', 'energy');

fprintf('  Created impulse signal at vertex %d\n', 5000);

% Create heat diffusion filter on Lambda domain
filt_heat = bct.filters.Filter(B.Lambda, 'heat', 'tau', 0.05, 'label', 'Heat_Diffusion');

fprintf('  Created heat filter: tau=%.3f\n', filt_heat.Parameters.tau);

% Apply Chebyshev filtering (FAST - no eigendecomposition needed)
tic;
sig_heat_cheby = B.applyChebyshevFilter(filt_heat, sig_impulse, 'order', 30);
time_cheby = toc;

fprintf('  Chebyshev filtering completed in %.4f seconds\n', time_cheby);
fprintf('  Output signal: %d vertices, energy=%.4f\n', ...
    length(sig_heat_cheby.Data), norm(sig_heat_cheby.Data));

% Visualize
figure('Name', 'Heat Diffusion - Impulse Response', 'Position', [100 100 1200 400]);

subplot(1,3,1);
% Plot impulse (just mark the vertex)
scatter3(B.Manifold.Vertices(5000,1), B.Manifold.Vertices(5000,2), ...
    B.Manifold.Vertices(5000,3), 100, 'r', 'filled');
hold on;
trimesh(B.Manifold.Faces, B.Manifold.Vertices(:,1), B.Manifold.Vertices(:,2), ...
    B.Manifold.Vertices(:,3), 'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none', ...
    'FaceAlpha', 0.3);
hold off;
axis equal; view(3); camlight; lighting gouraud;
title('Input: Delta Impulse at Vertex 5000');

subplot(1,3,2);
% Plot filtered signal
trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), B.Manifold.Vertices(:,2), ...
    B.Manifold.Vertices(:,3), sig_heat_cheby.Data, 'EdgeColor', 'none');
axis equal; view(3); camlight; lighting gouraud; colorbar;
title(sprintf('Heat Diffusion (Chebyshev, order=%d)', 30));

subplot(1,3,3);
% Plot histogram of values
histogram(sig_heat_cheby.Data, 50);
grid on; xlabel('Signal Value'); ylabel('Count');
title('Distribution of Filtered Values');

%% Example 2: Gaussian Lowpass Filtering

fprintf('\n=== Example 2: Gaussian Lowpass Filter ===\n');

% Create random signal on Manifold
sig_random = bct.Signal(B.Manifold, randn(B.Manifold.N, 1), 'Random_Noise');

fprintf('  Created random noise signal\n');

% Create Gaussian lowpass filter centered at lambda=0
filt_gauss = bct.filters.Filter(B.Lambda, 'gaussian', ...
    'center', 0, 'sigma', 20, 'label', 'Gaussian_Lowpass');

fprintf('  Created Gaussian filter: center=%.0f, sigma=%.0f\n', ...
    filt_gauss.center, filt_gauss.sigma);

% Apply Chebyshev filtering
tic;
sig_smoothed = B.applyChebyshevFilter(filt_gauss, sig_random, 'order', 40);
time_smooth = toc;

fprintf('  Filtering completed in %.4f seconds\n', time_smooth);

% Visualize
figure('Name', 'Gaussian Lowpass Smoothing', 'Position', [100 150 1200 400]);

subplot(1,2,1);
trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), B.Manifold.Vertices(:,2), ...
    B.Manifold.Vertices(:,3), sig_random.Data, 'EdgeColor', 'none');
axis equal; view(3); camlight; lighting gouraud; colorbar;
title('Input: Random Noise');
clim([-3 3]);

subplot(1,2,2);
trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), B.Manifold.Vertices(:,2), ...
    B.Manifold.Vertices(:,3), sig_smoothed.Data, 'EdgeColor', 'none');
axis equal; view(3); camlight; lighting gouraud; colorbar;
title('Output: Smoothed (Gaussian Lowpass)');
clim([-3 3]);

%% Example 3: Comparison of Polynomial Orders

fprintf('\n=== Example 3: Effect of Chebyshev Order ===\n');

% Create impulse
mask_imp = bct.filters.Filter(B.Manifold, 'delta', 'x0', 1000);
sig_imp = bct.Signal.fromMask(mask_imp);

% Create filter
filt_heat2 = bct.filters.Filter(B.Lambda, 'heat', 'tau', 0.03);

% Test different orders
orders = [10, 20, 40, 80];
results = cell(length(orders), 1);
times = zeros(length(orders), 1);

fprintf('  Testing Chebyshev orders: [%s]\n', num2str(orders));

for i = 1:length(orders)
    tic;
    results{i} = B.applyChebyshevFilter(filt_heat2, sig_imp, 'order', orders(i));
    times(i) = toc;
    fprintf('    Order %2d: %.4f seconds, energy=%.4f\n', ...
        orders(i), times(i), norm(results{i}.Data));
end

% Visualize
figure('Name', 'Effect of Chebyshev Order', 'Position', [100 200 1400 800]);

for i = 1:length(orders)
    subplot(2, length(orders), i);
    trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), B.Manifold.Vertices(:,2), ...
        B.Manifold.Vertices(:,3), results{i}.Data, 'EdgeColor', 'none');
    axis equal; view(3); camlight; lighting gouraud;
    title(sprintf('Order=%d', orders(i)));
    
    subplot(2, length(orders), length(orders)+i);
    histogram(results{i}.Data, 50);
    grid on; xlabel('Value'); ylabel('Count');
    title(sprintf('Time: %.4fs', times(i)));
end

%% Example 4: Multiple Filters (Bandpass Analysis)

fprintf('\n=== Example 4: Multi-band Filtering ===\n');

% Create signal
sig_test = bct.Signal(B.Manifold, randn(B.Manifold.N, 1), 'Test_Signal');

% Define spectral bands (eigenvalue ranges)
bands = struct(...
    'Very_Low', struct('low', 0, 'high', 10), ...
    'Low', struct('low', 10, 'high', 30), ...
    'Mid', struct('low', 30, 'high', 60), ...
    'High', struct('low', 60, 'high', 100));

band_names = fieldnames(bands);
filtered_bands = struct();

fprintf('  Filtering signal into %d spectral bands...\n', length(band_names));

for i = 1:length(band_names)
    name = band_names{i};
    range = bands.(name);
    
    % Create bandpass filter
    filt = bct.filters.Filter(B.Lambda, 'bandpass', ...
        'low', range.low, 'high', range.high, 'label', name);
    
    % Apply Chebyshev filtering
    filtered_bands.(name) = B.applyChebyshevFilter(filt, sig_test, 'order', 30);
    
    fprintf('    %s: λ ∈ [%.0f, %.0f], energy=%.4f\n', ...
        name, range.low, range.high, norm(filtered_bands.(name).Data));
end

% Visualize bands
figure('Name', 'Multi-band Filtering', 'Position', [100 250 1400 700]);

for i = 1:length(band_names)
    name = band_names{i};
    
    subplot(2, length(band_names), i);
    trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), B.Manifold.Vertices(:,2), ...
        B.Manifold.Vertices(:,3), filtered_bands.(name).Data, 'EdgeColor', 'none');
    axis equal; view(3); camlight; lighting gouraud;
    title(name, 'Interpreter', 'none');
    
    subplot(2, length(band_names), length(band_names)+i);
    histogram(filtered_bands.(name).Data, 30);
    grid on; xlabel('Value'); ylabel('Count');
end

%% Example 5: Low-pass vs High-pass

fprintf('\n=== Example 5: Low-pass vs High-pass Filtering ===\n');

% Create signal
sig_mixed = bct.Signal(B.Manifold, randn(B.Manifold.N, 1), 'Mixed_Signal');

% Low-pass filter (retains smooth features)
filt_lp = bct.filters.Filter(B.Lambda, 'lowpass', 'cutoff', 30);
sig_lp = B.applyChebyshevFilter(filt_lp, sig_mixed, 'order', 30);

% High-pass filter (retains edges/details)
filt_hp = bct.filters.Filter(B.Lambda, 'highpass', 'cutoff', 30);
sig_hp = B.applyChebyshevFilter(filt_hp, sig_mixed, 'order', 30);

fprintf('  Low-pass energy: %.4f\n', norm(sig_lp.Data));
fprintf('  High-pass energy: %.4f\n', norm(sig_hp.Data));
fprintf('  Sum of energies: %.4f (vs original: %.4f)\n', ...
    norm(sig_lp.Data)^2 + norm(sig_hp.Data)^2, norm(sig_mixed.Data)^2);

% Visualize
figure('Name', 'Low-pass vs High-pass', 'Position', [100 300 1400 400]);

subplot(1,3,1);
trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), B.Manifold.Vertices(:,2), ...
    B.Manifold.Vertices(:,3), sig_mixed.Data, 'EdgeColor', 'none');
axis equal; view(3); camlight; lighting gouraud; colorbar;
title('Original Signal');

subplot(1,3,2);
trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), B.Manifold.Vertices(:,2), ...
    B.Manifold.Vertices(:,3), sig_lp.Data, 'EdgeColor', 'none');
axis equal; view(3); camlight; lighting gouraud; colorbar;
title('Low-pass (λ < 30): Smooth Features');

subplot(1,3,3);
trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), B.Manifold.Vertices(:,2), ...
    B.Manifold.Vertices(:,3), sig_hp.Data, 'EdgeColor', 'none');
axis equal; view(3); camlight; lighting gouraud; colorbar;
title('High-pass (λ > 30): Edges/Details');

%% Summary

fprintf('\n=== SUMMARY ===\n');
fprintf('Chebyshev Polynomial Filtering:\n');
fprintf('  Method: B.applyChebyshevFilter(filter, signal, ''order'', K)\n');
fprintf('\n');
fprintf('Requirements:\n');
fprintf('  ✓ Filter: 1D kernel on Lambda domain (spatial filtering)\n');
fprintf('  ✓ Signal: Data on Manifold domain (vertex values)\n');
fprintf('  ✓ GSPBox: Available in external/gspbox/\n');
fprintf('\n');
fprintf('Advantages:\n');
fprintf('  ✓ Fast: O(K*M) complexity (K=order, M=edges)\n');
fprintf('  ✓ No eigendecomposition needed (avoids O(N^3) cost)\n');
fprintf('  ✓ Works directly with graph structure\n');
fprintf('  ✓ Controllable accuracy via polynomial order\n');
fprintf('\n');
fprintf('Supported Kernels:\n');
fprintf('  • heat - Heat diffusion (tau parameter)\n');
fprintf('  • gaussian - Smooth lowpass (center, sigma)\n');
fprintf('  • lowpass - Ideal lowpass (cutoff)\n');
fprintf('  • highpass - Ideal highpass (cutoff)\n');
fprintf('  • bandpass - Band selection (low, high)\n');
fprintf('  • mexican_hat - Multi-scale analysis\n');
fprintf('  • laplacian_gaussian - Edge detection\n');
fprintf('\n');
fprintf('Parameters:\n');
fprintf('  order (default=30): Higher = more accurate, slower\n');
fprintf('  method: ''cheby'' (default), ''exact'', ''lanczos''\n');
fprintf('  verbose: 0 (quiet) or 1 (show warnings)\n');
fprintf('\n✓ Demo complete!\n');
