%% Demo: bct.brush.design.brush - Unified Brush Design System
% This script demonstrates the brush design system similar to filter design

clear; close all;

%% 1. Setup
fprintf('=== Setup: Create BCT Object ===\n');

% Create mesh
[V, F] = icosphere(3);
V = double(V);
F = double(F);

% Create BCT object
B = bct.bct();
B.Manifold = bct.Manifold(V, F);
B.Lambda = B.Manifold.dual('numModes', 100);
B.Time = bct.Time(0:0.01:1, 100);  % 1 second at 100 Hz

fprintf('Manifold: %d vertices\n', B.Manifold.N);
fprintf('Lambda: %d modes\n', B.Lambda.K);
fprintf('Time: %d steps\n\n', B.Time.N);

%% 2. Patch Brushes

fprintf('=== Test 1: Patch Brushes ===\n');

% Patch - Spectral with Gaussian kernel
params1 = struct();
params1.source = 100;
params1.kernel = 'gaussian';
params1.sigma = 15;
params1.bandwidth = 50;

w1 = bct.brush.design.brush('patch', 'spectral', B.Manifold, params1);
fprintf('Spectral patch: [%d × %d], non-zero: %.1f%%\n', ...
    size(w1, 1), size(w1, 2), 100*nnz(w1)/numel(w1));

% Patch - Gaussian
params2 = struct();
params2.source = 200;
params2.radius = 0.3;
params2.sigma = 0.1;

w2 = bct.brush.design.brush('patch', 'gaussian', B.Manifold, params2);
fprintf('Gaussian patch: [%d × %d], non-zero: %.1f%%\n', ...
    size(w2, 1), size(w2, 2), 100*nnz(w2)/numel(w2));

% Patch - Nearest
params3 = struct();
params3.source = 300;
params3.radius = 0.2;

w3 = bct.brush.design.brush('patch', 'nearest', B.Manifold, params3);
fprintf('Nearest patch: [%d × %d], non-zero: %.1f%%\n\n', ...
    size(w3, 1), size(w3, 2), 100*nnz(w3)/numel(w3));

%% 3. Trajectory Brushes

fprintf('=== Test 2: Trajectory Brushes ===\n');

% Trajectory - Spectral
params4 = struct();
params4.source = 100;
params4.target = 500;
params4.kernel = 'heat';
params4.kernel_params = struct('tau', 0.15);

w4 = bct.brush.design.brush('trajectory', 'spectral', B.Manifold, params4);
fprintf('Spectral trajectory: [%d × %d], non-zero: %.1f%%\n', ...
    size(w4, 1), size(w4, 2), 100*nnz(w4)/numel(w4));

% Trajectory - Gaussian
params5 = struct();
params5.source = 100;
params5.target = 500;
params5.sigma = 8;

w5 = bct.brush.design.brush('trajectory', 'gaussian', B.Manifold, params5);
fprintf('Gaussian trajectory: [%d × %d], non-zero: %.1f%%\n', ...
    size(w5, 1), size(w5, 2), 100*nnz(w5)/numel(w5));

% Trajectory - Geodesic
params6 = struct();
params6.source = 100;
params6.target = 500;
params6.width = 0;

w6 = bct.brush.design.brush('trajectory', 'geodesic', B.Manifold, params6);
fprintf('Geodesic trajectory: [%d × %d], vertices on path: %d\n\n', ...
    size(w6, 1), size(w6, 2), nnz(w6));

%% 4. Time (Spatiotemporal) Brushes

fprintf('=== Test 3: Time (Spatiotemporal) Brushes ===\n');

% Time - Heat diffusion
params7 = struct();
params7.source = 100;
params7.target = 500;
params7.tau_range = [0.02, 0.4];
params7.tau_profile = 'exponential';

w7 = bct.brush.design.brush('time', 'heat', B.Manifold, params7, B.Time);
fprintf('Heat diffusion: [%d × %d], sparsity: %.1f%%\n', ...
    size(w7, 1), size(w7, 2), 100*nnz(w7)/numel(w7));

% Time - Spectral with moving source
[path, ~] = B.Manifold.Graph.shortestPath(100, 500);
arrival_frac = 0.6;

params8 = struct();
params8.source = @(t, T) path(min(round((t/T)/arrival_frac * length(path)), length(path)));
params8.kernel = 'gaussian';
params8.sigma = 15;
params8.bandwidth = 50;

w8 = bct.brush.design.brush('time', 'spectral', B.Manifold, params8, B.Time);
fprintf('Moving spectral: [%d × %d], sparsity: %.1f%%\n', ...
    size(w8, 1), size(w8, 2), 100*nnz(w8)/numel(w8));

% Time - Spectral with time-varying tau
params9 = struct();
params9.source = 200;
params9.kernel = 'heat';
params9.tau = @(t, T) 0.05 + 0.25*(t/T);  % Increase over time

w9 = bct.brush.design.brush('time', 'spectral', B.Manifold, params9, B.Time);
fprintf('Time-varying tau: [%d × %d], sparsity: %.1f%%\n\n', ...
    size(w9, 1), size(w9, 2), 100*nnz(w9)/numel(w9));

%% 5. Error Handling Demo

fprintf('=== Test 4: Error Handling ===\n');

try
    % Invalid category
    bct.brush.design.brush('invalid', 'spectral', B.Manifold, params1);
catch ME
    fprintf('✓ Caught invalid category: %s\n', ME.identifier);
end

try
    % Invalid brush type
    bct.brush.design.brush('patch', 'nonexistent', B.Manifold, params1);
catch ME
    fprintf('✓ Caught invalid brush type: %s\n', ME.identifier);
end

try
    % Missing time for time category
    bct.brush.design.brush('time', 'heat', B.Manifold, params7);
catch ME
    fprintf('✓ Caught missing time: %s\n\n', ME.identifier);
end

%% 6. Visualizations

fprintf('=== Visualizations ===\n');

% Patch brushes
figure('Position', [100 100 1400 500]);
subplot(1,3,1);
B.Manifold.plot('data', full(w1), 'shading', 'interp');
colormap(jet); colorbar;
title('Patch: Spectral Gaussian');
axis equal tight off; view([0 90]);

subplot(1,3,2);
B.Manifold.plot('data', full(w2), 'shading', 'interp');
colormap(jet); colorbar;
title('Patch: Gaussian');
axis equal tight off; view([0 90]);

subplot(1,3,3);
B.Manifold.plot('data', full(w3), 'shading', 'interp');
colormap(jet); colorbar;
title('Patch: Nearest');
axis equal tight off; view([0 90]);

sgtitle('Patch Brushes via Design System');

% Trajectory brushes
figure('Position', [100 100 1400 500]);
subplot(1,3,1);
B.Manifold.plot('data', full(w4), 'shading', 'interp');
colormap(jet); colorbar;
title('Trajectory: Spectral');
axis equal tight off; view([0 90]);

subplot(1,3,2);
B.Manifold.plot('data', full(w5), 'shading', 'interp');
colormap(jet); colorbar;
title('Trajectory: Gaussian');
axis equal tight off; view([0 90]);

subplot(1,3,3);
B.Manifold.plot('data', full(w6), 'shading', 'interp');
colormap(jet); colorbar;
title('Trajectory: Geodesic');
axis equal tight off; view([0 90]);

sgtitle('Trajectory Brushes via Design System');

% Time brushes
figure('Position', [100 100 1600 800]);
time_snapshots = [10, 30, 50, 70, 90];

for i = 1:5
    t = time_snapshots(i);
    
    subplot(3, 5, i);
    B.Manifold.plot('data', full(w7(:, t)), 'shading', 'interp');
    colormap(jet); colorbar;
    title(sprintf('Heat: t=%.2fs', B.Time.axis(t)));
    axis equal tight off; view([0 90]); caxis([0 1]);
    
    subplot(3, 5, 5+i);
    B.Manifold.plot('data', full(w8(:, t)), 'shading', 'interp');
    colormap(jet); colorbar;
    title(sprintf('Moving: t=%.2fs', B.Time.axis(t)));
    axis equal tight off; view([0 90]); caxis([0 1]);
    
    subplot(3, 5, 10+i);
    B.Manifold.plot('data', full(w9(:, t)), 'shading', 'interp');
    colormap(jet); colorbar;
    title(sprintf('Varying τ: t=%.2fs', B.Time.axis(t)));
    axis equal tight off; view([0 90]); caxis([0 1]);
end

sgtitle('Time (Spatiotemporal) Brushes via Design System');

%% 7. Summary

fprintf('\n=== Summary ===\n');
fprintf('Created %d brushes using bct.brush.design.brush:\n', 9);
fprintf('  - 3 patch brushes (spectral, gaussian, nearest)\n');
fprintf('  - 3 trajectory brushes (spectral, gaussian, geodesic)\n');
fprintf('  - 3 spatiotemporal brushes (heat, moving spectral, varying tau)\n\n');

fprintf('Key Features:\n');
fprintf('  ✓ Unified interface like bct.filter.design.kernel\n');
fprintf('  ✓ Registry-based brush lookup\n');
fprintf('  ✓ Automatic validation of inputs and outputs\n');
fprintf('  ✓ Clear error messages with available brush suggestions\n');
fprintf('  ✓ Support for all brush categories\n\n');

fprintf('Usage Pattern:\n');
fprintf('  w = bct.brush.design.brush(category, type, manifold, params);\n');
fprintf('  w = bct.brush.design.brush(''time'', type, manifold, params, time);\n');
