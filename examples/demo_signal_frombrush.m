%% Demo: Signal.fromBrush - Brush-based Signal Generation
% This script demonstrates the new Signal.fromBrush wrapper system

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

fprintf('=== Test 1: Patch - Spectral Gaussian ===\n');
sig1 = bct.Signal.fromBrush(B.Manifold, ...
    'Category', 'patch', ...
    'Type', 'spectral', ...
    'Source', 100, ...
    'Kernel', 'gaussian', ...
    'Sigma', 15, ...
    'Bandwidth', 50, ...
    'Label', 'patch_gaussian');

fprintf('Created: %s\n', sig1.Metadata.Label);
fprintf('  Size: [%d × %d]\n', size(sig1.Data, 1), size(sig1.Data, 2));
fprintf('  Domain: %s\n', class(sig1.Domain));
fprintf('  Generator: %s\n\n', sig1.Metadata.generator);

fprintf('=== Test 2: Patch - Spectral Heat ===\n');
sig2 = bct.Signal.fromBrush(B.Manifold, ...
    'Category', 'patch', ...
    'Type', 'spectral', ...
    'Source', 200, ...
    'Kernel', 'heat', ...
    'Tau', 0.2, ...
    'Label', 'patch_heat');

fprintf('Created: %s\n', sig2.Metadata.Label);
fprintf('  Size: [%d × %d]\n', size(sig2.Data, 1), size(sig2.Data, 2));
fprintf('  Non-zero: %.1f%%\n\n', 100*nnz(sig2.Data)/numel(sig2.Data));

%% 3. Trajectory Brushes

fprintf('=== Test 3: Trajectory - Spectral ===\n');
sig3 = bct.Signal.fromBrush(B.Manifold, ...
    'Category', 'trajectory', ...
    'Type', 'spectral', ...
    'Source', 100, ...
    'Target', 500, ...
    'Kernel', 'heat', ...
    'KernelParams', struct('tau', 0.15), ...
    'Label', 'trajectory_spectral');

fprintf('Created: %s\n', sig3.Metadata.Label);
fprintf('  Size: [%d × %d]\n', size(sig3.Data, 1), size(sig3.Data, 2));
fprintf('  Parameters: source=%d, target=%d\n\n', ...
    sig3.Metadata.brush_params.source, sig3.Metadata.brush_params.target);

fprintf('=== Test 4: Trajectory - Gaussian ===\n');
sig4 = bct.Signal.fromBrush(B.Manifold, ...
    'Category', 'trajectory', ...
    'Type', 'gaussian', ...
    'Source', 50, ...
    'Target', 600, ...
    'Sigma', 5);

fprintf('Created: %s\n', sig4.Metadata.Label);
fprintf('  Size: [%d × %d]\n', size(sig4.Data, 1), size(sig4.Data, 2));
fprintf('  Max value: %.3f\n\n', max(sig4.Data));

%% 4. Spatiotemporal (Time) Brushes

fprintf('=== Test 5: Time - Heat Diffusion ===\n');
sig5 = bct.Signal.fromBrush(B.Manifold, ...
    'Category', 'time', ...
    'Type', 'heat', ...
    'Time', B.Time, ...
    'Source', 100, ...
    'Target', 500, ...
    'TauRange', [0.02, 0.4], ...
    'TauProfile', 'exponential', ...
    'Label', 'time_heat_diffusion');

fprintf('Created: %s\n', sig5.Metadata.Label);
fprintf('  Size: [%d × %d] (spatiotemporal)\n', size(sig5.Data, 1), size(sig5.Data, 2));
fprintf('  Domain: %s, Time: %s\n', class(sig5.Domain), class(sig5.Time));
fprintf('  Sparsity: %.1f%% non-zero\n\n', 100*nnz(sig5.Data)/numel(sig5.Data));

fprintf('=== Test 6: Time - Spectral Moving Source ===\n');

% Create path for moving source
[path, ~] = B.Manifold.Graph.shortestPath(100, 500);
arrival_frac = 0.5;  % Arrive halfway through

sig6 = bct.Signal.fromBrush(B.Manifold, ...
    'Category', 'time', ...
    'Type', 'spectral', ...
    'Time', B.Time, ...
    'Source', @(t, T) path(min(round((t/T)/arrival_frac * length(path)), length(path))), ...
    'Kernel', 'gaussian', ...
    'Sigma', 15, ...
    'Bandwidth', 50, ...
    'Label', 'time_spectral_moving');

fprintf('Created: %s\n', sig6.Metadata.Label);
fprintf('  Size: [%d × %d] (spatiotemporal)\n', size(sig6.Data, 1), size(sig6.Data, 2));
fprintf('  Moving source along path (%d vertices)\n', length(path));
fprintf('  Arrival fraction: %.1f%%\n\n', arrival_frac*100);

%% 5. Visualization

fprintf('=== Visualization ===\n');

% Visualize patch signals
figure('Position', [100 100 1400 500]);

subplot(1,3,1);
B.Manifold.plot('data', sig1.Data, 'shading', 'interp');
colormap(jet); colorbar;
title(sig1.Metadata.Label);
axis equal tight off;
view([0 90]);

subplot(1,3,2);
B.Manifold.plot('data', sig2.Data, 'shading', 'interp');
colormap(jet); colorbar;
title(sig2.Metadata.Label);
axis equal tight off;
view([0 90]);

subplot(1,3,3);
B.Manifold.plot('data', sig3.Data, 'shading', 'interp');
colormap(jet); colorbar;
title(sig3.Metadata.Label);
axis equal tight off;
view([0 90]);

sgtitle('Patch and Trajectory Signals');

% Visualize spatiotemporal signals
figure('Position', [100 100 1600 500]);

time_snapshots = [10, 30, 50, 70, 90];
for i = 1:5
    t = time_snapshots(i);
    
    subplot(2, 5, i);
    B.Manifold.plot('data', sig5.Data(:, t), 'shading', 'interp');
    colormap(jet); colorbar;
    title(sprintf('Heat: t=%.2fs', B.Time.axis(t)));
    axis equal tight off;
    view([0 90]);
    caxis([0 1]);
    
    subplot(2, 5, 5+i);
    B.Manifold.plot('data', sig6.Data(:, t), 'shading', 'interp');
    colormap(jet); colorbar;
    title(sprintf('Moving: t=%.2fs', B.Time.axis(t)));
    axis equal tight off;
    view([0 90]);
    caxis([0 1]);
end

sgtitle('Spatiotemporal Signals');

%% 6. Summary

fprintf('\n=== Summary ===\n');
fprintf('Created %d signals using Signal.fromBrush:\n', 6);
fprintf('  - 2 patch brushes (spectral gaussian, spectral heat)\n');
fprintf('  - 2 trajectory brushes (spectral, gaussian)\n');
fprintf('  - 2 spatiotemporal brushes (heat diffusion, moving spectral)\n\n');

fprintf('Key Features:\n');
fprintf('  ✓ Automatic domain handling (Manifold, Lambda, Time)\n');
fprintf('  ✓ Flexible parameter passing via Name-Value pairs\n');
fprintf('  ✓ Automatic metadata and label generation\n');
fprintf('  ✓ Support for all brush categories (patch, trajectory, time)\n');
fprintf('  ✓ Support for function handle parameters (e.g., moving sources)\n\n');

fprintf('Usage Pattern:\n');
fprintf('  sig = Signal.fromBrush(manifold, ...\n');
fprintf('      ''Category'', ''patch''/''trajectory''/''time'', ...\n');
fprintf('      ''Type'', ''spectral''/''gaussian''/''heat''/etc, ...\n');
fprintf('      ...brush-specific parameters..., ...\n');
fprintf('      ''Label'', ''optional_label'');\n');
