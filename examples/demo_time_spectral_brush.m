%% Test Script for Spatiotemporal Spectral Patch Brush
% This script demonstrates the bct.brush.time.spectral brush

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

% 1.5 seconds at 60 Hz = 90 time steps
fs = 60;  % Hz
duration = 1.5;  % seconds
t_vec = 0:(1/fs):(duration - 1/fs);
B.Time = bct.Time(t_vec, fs);

fprintf('Time domain: %d samples at %.0f Hz (%.1f seconds)\n', ...
    B.Time.N, B.Time.fs, duration);

%% 4. Test 1: Fixed source with varying tau (heat kernel)
fprintf('\n=== Test 1: Fixed Source, Varying Tau ===\n');

params1 = struct();
params1.source = 100;  % Fixed source
params1.kernel = 'heat';
params1.tau = @(t, T) 0.01 + 0.4*(t/T);  % Linear increase

tic;
w1 = bct.brush.time.spectral(B.Manifold, B.Time, params1);
t_elapsed = toc;
fprintf('Generated: [%d × %d] (%.3f seconds)\n', ...
    size(w1, 1), size(w1, 2), t_elapsed);
fprintf('Sparsity: %.1f%% non-zero\n', 100*nnz(w1)/numel(w1));

%% 5. Test 2: Moving source along path
fprintf('\n=== Test 2: Moving Source Along Geodesic Path ===\n');

% Create a path
[~, source_start] = max(V(:,1));
[~, source_end] = min(V(:,1));
[path, ~] = B.Manifold.Graph.shortestPath(source_start, source_end);

fprintf('Path length: %d vertices\n', length(path));

% Moving source function
params2 = struct();
params2.source = @(t, T) path(min(max(1, round(t/T * length(path))), length(path)));
params2.kernel = 'gaussian';
params2.sigma = 15;
params2.bandwidth = 50;

tic;
w2 = bct.brush.time.spectral(B.Manifold, B.Time, params2);
t_elapsed = toc;
fprintf('Generated: [%d × %d] (%.3f seconds)\n', ...
    size(w2, 1), size(w2, 2), t_elapsed);
fprintf('Sparsity: %.1f%% non-zero\n', 100*nnz(w2)/numel(w2));

%% 6. Test 3: Explicit source array with varying sigma
fprintf('\n=== Test 3: Explicit Sources, Varying Sigma ===\n');

% Create array of sources (random walk along path)
T = B.Time.N;
source_indices = zeros(T, 1);
current_idx = 1;
source_indices(1) = path(1);

for t = 2:T
    % Random walk along path
    step = randi([-2, 3]);  % Bias forward
    current_idx = min(max(1, current_idx + step), length(path));
    source_indices(t) = path(current_idx);
end

params3 = struct();
params3.source = source_indices;
params3.kernel = 'heat';
params3.tau = linspace(0.05, 0.25, T);  % Explicit array

tic;
w3 = bct.brush.time.spectral(B.Manifold, B.Time, params3);
t_elapsed = toc;
fprintf('Generated: [%d × %d] (%.3f seconds)\n', ...
    size(w3, 1), size(w3, 2), t_elapsed);
fprintf('Sparsity: %.1f%% non-zero\n', 100*nnz(w3)/numel(w3));

%% 7. Visualize Test 1: Fixed source, varying tau
fprintf('\n=== Visualization: Fixed Source (Test 1) ===\n');

time_indices = round(linspace(1, B.Time.N, 6));

figure('Position', [100 100 1800 600]);
for i = 1:6
    t_idx = time_indices(i);
    subplot(2, 6, i);
    B.Manifold.plot('data', full(w1(:, t_idx)), 'shading', 'interp');
    colormap(jet); colorbar;
    title(sprintf('Fixed: t=%.2fs', B.Time.axis(t_idx)));
    axis equal tight off;
    view([0 90]);
    caxis([0 1]);
end

% Show temporal evolution at a vertex
[~, max_vertex] = max(sum(w1, 2));
subplot(2, 6, 7:12);
plot(B.Time.axis, full(w1(max_vertex, :)), 'b-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Weight');
title(sprintf('Temporal Evolution at Vertex %d (Fixed Source)', max_vertex));
grid on;

sgtitle('Test 1: Fixed Source with Varying Tau');

%% 8. Visualize Test 2: Moving source
fprintf('\n=== Visualization: Moving Source (Test 2) ===\n');

figure('Position', [100 100 1800 600]);
for i = 1:6
    t_idx = time_indices(i);
    subplot(2, 6, i);
    B.Manifold.plot('data', full(w2(:, t_idx)), 'shading', 'interp');
    colormap(jet); colorbar;
    
    % Mark the source location at this time
    source_t = params2.source(t_idx, B.Time.N);
    hold on;
    plot3(V(source_t,1), V(source_t,2), V(source_t,3), ...
        'r*', 'MarkerSize', 15, 'LineWidth', 2);
    
    title(sprintf('Moving: t=%.2fs', B.Time.axis(t_idx)));
    axis equal tight off;
    view([0 90]);
    caxis([0 1]);
end

% Show source trajectory
subplot(2, 6, 7:12);
source_trajectory = zeros(B.Time.N, 1);
for t = 1:B.Time.N
    source_trajectory(t) = params2.source(t, B.Time.N);
end
plot(B.Time.axis, source_trajectory, 'r-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Source Vertex Index');
title('Source Position Over Time');
grid on;

sgtitle('Test 2: Moving Source Along Geodesic Path');

%% 9. Visualize Test 3: Random walk
fprintf('\n=== Visualization: Random Walk Sources (Test 3) ===\n');

figure('Position', [100 100 1800 600]);
for i = 1:6
    t_idx = time_indices(i);
    subplot(2, 6, i);
    B.Manifold.plot('data', full(w3(:, t_idx)), 'shading', 'interp');
    colormap(jet); colorbar;
    
    % Mark the source
    hold on;
    plot3(V(source_indices(t_idx),1), V(source_indices(t_idx),2), ...
        V(source_indices(t_idx),3), 'r*', 'MarkerSize', 15, 'LineWidth', 2);
    
    title(sprintf('Random: t=%.2fs', B.Time.axis(t_idx)));
    axis equal tight off;
    view([0 90]);
    caxis([0 1]);
end

% Show both source and tau evolution
subplot(2, 6, 7:9);
plot(B.Time.axis, source_indices, 'r-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Source Vertex');
title('Random Walk Source Position');
grid on;

subplot(2, 6, 10:12);
plot(B.Time.axis, params3.tau, 'b-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('Tau');
title('Diffusion Parameter (Tau)');
grid on;

sgtitle('Test 3: Random Walk with Varying Tau');

%% 10. Compare all three methods
fprintf('\n=== Comparison Summary ===\n');

fprintf('Test 1 (Fixed source):\n');
fprintf('  Max weight: %.3f\n', max(w1(:)));
fprintf('  Mean non-zero: %.3f\n', mean(nonzeros(w1)));
fprintf('  Active vertices: %.1f%%\n', 100*nnz(sum(w1,2)>0)/N);

fprintf('Test 2 (Moving source):\n');
fprintf('  Max weight: %.3f\n', max(w2(:)));
fprintf('  Mean non-zero: %.3f\n', mean(nonzeros(w2)));
fprintf('  Active vertices: %.1f%%\n', 100*nnz(sum(w2,2)>0)/N);

fprintf('Test 3 (Random walk):\n');
fprintf('  Max weight: %.3f\n', max(w3(:)));
fprintf('  Mean non-zero: %.3f\n', mean(nonzeros(w3)));
fprintf('  Active vertices: %.1f%%\n', 100*nnz(sum(w3,2)>0)/N);

fprintf('\n=== Test Complete ===\n');
fprintf('The spectral brush creates spatiotemporal patterns by:\n');
fprintf('  - Generating spectral patches at each time step\n');
fprintf('  - Supporting fixed, moving, or arbitrary source trajectories\n');
fprintf('  - Allowing time-varying kernel parameters\n');
