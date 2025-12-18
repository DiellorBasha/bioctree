%% Test Script for Spatiotemporal Heat Brush
% This script demonstrates the bct.brush.time.heat brush

clear; close all;

%% 1. Load a test mesh
fprintf('=== Loading Test Mesh ===\n');

% Use icosphere for testing
[V, F] = icosphere(3);  % 642 vertices
V = double(V);
F = double(F);
fprintf('Mesh: %d vertices, %d faces\n', size(V, 1), size(F, 1));

%% 2. Create BCT object and compute eigenbasis
fprintf('\n=== Setting Up BCT Object ===\n');

B = bct.bct();
B.Manifold = bct.Manifold(V, F);

% Compute eigendecomposition
k = 100;
fprintf('Computing %d eigenmodes...\n', k);
B.Lambda = B.Manifold.dual('numModes', k);
fprintf('Eigenvalues range: [%.4f, %.4f]\n', ...
    B.Lambda.lambda(1), B.Lambda.lambda(end));

%% 3. Create Time domain
fprintf('\n=== Setting Up Time Domain ===\n');

% 2 seconds at 50 Hz = 100 time steps
fs = 50;  % Hz
duration = 2;  % seconds
t_vec = 0:(1/fs):(duration - 1/fs);
B.Time = bct.Time(t_vec, fs);

fprintf('Time domain: %d samples at %.0f Hz (%.1f seconds)\n', ...
    B.Time.N, B.Time.fs, duration);

%% 4. Select source and target vertices
fprintf('\n=== Selecting Path Vertices ===\n');

% Find vertices on opposite sides
[~, source] = max(V(:,1));
[~, target] = min(V(:,1));

fprintf('Source vertex: %d [%.2f, %.2f, %.2f]\n', ...
    source, V(source,1), V(source,2), V(source,3));
fprintf('Target vertex: %d [%.2f, %.2f, %.2f]\n', ...
    target, V(target,1), V(target,2), V(target,3));

%% 5. Test heat brush with different tau profiles

% Test 1: Linear tau profile
fprintf('\n=== Test 1: Linear Tau Profile ===\n');
params1 = struct();
params1.source = source;
params1.target = target;
params1.tau_range = [0.02, 0.4];
params1.tau_profile = 'linear';

tic;
w_linear = bct.brush.time.heat(B.Manifold, B.Time, params1);
t_elapsed = toc;
fprintf('Linear heat brush: [%d × %d] (%.3f seconds)\n', ...
    size(w_linear, 1), size(w_linear, 2), t_elapsed);
fprintf('Sparsity: %.1f%% non-zero\n', 100*nnz(w_linear)/numel(w_linear));

% Test 2: Exponential tau profile
fprintf('\n=== Test 2: Exponential Tau Profile ===\n');
params2 = struct();
params2.source = source;
params2.target = target;
params2.tau_range = [0.01, 0.5];
params2.tau_profile = 'exponential';

tic;
w_exponential = bct.brush.time.heat(B.Manifold, B.Time, params2);
t_elapsed = toc;
fprintf('Exponential heat brush: [%d × %d] (%.3f seconds)\n', ...
    size(w_exponential, 1), size(w_exponential, 2), t_elapsed);
fprintf('Sparsity: %.1f%% non-zero\n', 100*nnz(w_exponential)/numel(w_exponential));

% Test 3: Sigmoid tau profile
fprintf('\n=== Test 3: Sigmoid Tau Profile ===\n');
params3 = struct();
params3.source = source;
params3.target = target;
params3.tau_range = [0.02, 0.3];
params3.tau_profile = 'sigmoid';

tic;
w_sigmoid = bct.brush.time.heat(B.Manifold, B.Time, params3);
t_elapsed = toc;
fprintf('Sigmoid heat brush: [%d × %d] (%.3f seconds)\n', ...
    size(w_sigmoid, 1), size(w_sigmoid, 2), t_elapsed);
fprintf('Sparsity: %.1f%% non-zero\n', 100*nnz(w_sigmoid)/numel(w_sigmoid));

%% 6. Visualize temporal evolution
fprintf('\n=== Visualization: Temporal Evolution ===\n');

% Select 6 time snapshots
time_indices = round(linspace(1, B.Time.N, 6));

figure('Position', [100 100 1800 900]);

% Linear profile snapshots
for i = 1:6
    t_idx = time_indices(i);
    subplot(3, 6, i);
    B.Manifold.plot('data', full(w_linear(:, t_idx)), 'shading', 'interp');
    colormap(jet); colorbar;
    title(sprintf('Linear: t=%.2fs', B.Time.axis(t_idx)));
    axis equal tight off;
    view([0 0]);
    caxis([0 1]);
end

% Exponential profile snapshots
for i = 1:6
    t_idx = time_indices(i);
    subplot(3, 6, 6+i);
    B.Manifold.plot('data', full(w_exponential(:, t_idx)), 'shading', 'interp');
    colormap(jet); colorbar;
    title(sprintf('Exp: t=%.2fs', B.Time.axis(t_idx)));
    axis equal tight off;
    view([0 0]);
    caxis([0 1]);
end

% Sigmoid profile snapshots
for i = 1:6
    t_idx = time_indices(i);
    subplot(3, 6, 12+i);
    B.Manifold.plot('data', full(w_sigmoid(:, t_idx)), 'shading', 'interp');
    colormap(jet); colorbar;
    title(sprintf('Sigmoid: t=%.2fs', B.Time.axis(t_idx)));
    axis equal tight off;
    view([0 0]);
    caxis([0 1]);
end

sgtitle('Spatiotemporal Heat Diffusion Along Trajectory');

%% 7. Analyze temporal profiles at specific vertices
fprintf('\n=== Temporal Profile Analysis ===\n');

% Pick a vertex near the middle of the path
[path_tmp, ~] = B.Manifold.Graph.shortestPath(source, target);
mid_vertex = path_tmp(round(length(path_tmp)/2));

fprintf('Analyzing vertex %d (middle of path)\n', mid_vertex);

figure('Position', [100 100 1400 500]);

subplot(1,3,1);
plot(B.Time.axis, full(w_linear(mid_vertex, :)), 'b-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Weight');
title('Linear Tau Profile');
grid on;

subplot(1,3,2);
plot(B.Time.axis, full(w_exponential(mid_vertex, :)), 'r-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Weight');
title('Exponential Tau Profile');
grid on;

subplot(1,3,3);
plot(B.Time.axis, full(w_sigmoid(mid_vertex, :)), 'g-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Weight');
title('Sigmoid Tau Profile');
grid on;

sgtitle(sprintf('Temporal Evolution at Vertex %d', mid_vertex));

%% 8. Summary statistics
fprintf('\n=== Summary Statistics ===\n');

fprintf('Linear profile:\n');
fprintf('  Max weight: %.3f\n', max(w_linear(:)));
fprintf('  Mean non-zero: %.3f\n', mean(nonzeros(w_linear)));
fprintf('  Peak time: %.2fs\n', B.Time.axis(find(max(w_linear(mid_vertex,:)))));

fprintf('Exponential profile:\n');
fprintf('  Max weight: %.3f\n', max(w_exponential(:)));
fprintf('  Mean non-zero: %.3f\n', mean(nonzeros(w_exponential)));
fprintf('  Peak time: %.2fs\n', B.Time.axis(find(max(w_exponential(mid_vertex,:)))));

fprintf('Sigmoid profile:\n');
fprintf('  Max weight: %.3f\n', max(w_sigmoid(:)));
fprintf('  Mean non-zero: %.3f\n', mean(nonzeros(w_sigmoid)));
fprintf('  Peak time: %.2fs\n', B.Time.axis(find(max(w_sigmoid(mid_vertex,:)))));

fprintf('\n=== Test Complete ===\n');
fprintf('The heat brush creates spatiotemporal patterns showing heat diffusion.\n');
fprintf('Different tau profiles control the temporal evolution of diffusion.\n');
