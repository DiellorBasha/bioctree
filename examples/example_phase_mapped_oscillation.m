%% Example: Phase-mapped oscillations on mesh
% Demonstrates how spatial patterns map to phase offsets in temporal oscillations

clear all;
close all;

% Add toolbox to path
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));
addpath(fullfile(root, 'external'));

fprintf('=== Phase-Mapped Oscillation Example ===\n\n');

%% Create mesh and BCT object
fprintf('Creating icosphere mesh...\n');
[V, F] = icosphere(3);  % 642 vertices
B = bct.bct.fromMesh(V, F);

% Set temporal dimension: 1 second at 100 Hz
B.Manifold.Time = bct.manifold.Time(100, 100);

fprintf('  Mesh: %d vertices\n', B.Manifold.N);
fprintf('  Time: %.1f sec at %.1f Hz (%d samples)\n\n', ...
    B.Manifold.Time.get_duration(), B.Manifold.Time.fs, B.Manifold.Time.T);

%% Generate phase-mapped oscillating signal
fprintf('Generating phase-mapped oscillating signal...\n');

% Spatial pattern: narrowband around spatial frequency 0.15
spec.type = 'narrowband';
spec.f0 = 0.15;
spec.bw_abs = 0.03;

% Temporal dynamics: 10 Hz oscillation
timespec.type = 'sinusoid';
timespec.freq = 10;  % Hz

[B, spatial_pattern, ~] = bct.sim.synth_mesh_signal_dynamic(B, spec, timespec, ...
    'k', 100, 'label', 'phase_mapped_10Hz');

fprintf('  ✓ Generated signal: %s\n\n', B.Signals(1).Label);

%% Analyze the signal
sig = B.Signals(1);
data = sig.Data;  % [N x T]

fprintf('Signal properties:\n');
fprintf('  Dimensions: [%d × %d]\n', sig.N, sig.T);
fprintf('  RMS: %.3f\n', sqrt(mean(data(:).^2)));
fprintf('  Range at t=0: [%.3f, %.3f]\n', min(data(:,1)), max(data(:,1)));

% Temporal properties
fprintf('\nTemporal properties:\n');

% Check frequency content of a single vertex
vertex_idx = 100;
vertex_trace = data(vertex_idx, :);

Y = fft(vertex_trace);
P = abs(Y/length(vertex_trace));
P = P(1:length(vertex_trace)/2+1);
P(2:end-1) = 2*P(2:end-1);
f = sig.Manifold.Time.fs*(0:(length(vertex_trace)/2))/length(vertex_trace);

[~, peak_idx] = max(P);
peak_freq = f(peak_idx);
fprintf('  Peak frequency: %.1f Hz (expected %.1f Hz)\n', peak_freq, timespec.freq);

%% Demonstrate phase relationships
fprintf('\nPhase relationships:\n');

% Sort vertices by spatial pattern value
[sorted_spatial, sort_idx] = sort(spatial_pattern);

% Get initial values (which encode phase)
initial_values = data(:, 1);

% Vertices with similar spatial values should have similar phases
fprintf('  Correlation (spatial pattern vs initial value): %.3f\n', ...
    corr(spatial_pattern, initial_values));

% Check phase coherence between nearby vertices in sorted order
mid_idx = round(length(sort_idx)/2);
v1 = sort_idx(mid_idx);
v2 = sort_idx(mid_idx + 1);

trace1 = data(v1, :);
trace2 = data(v2, :);

xcorr_near = max(xcorr(trace1, trace2, 0, 'normalized'));
fprintf('  Cross-correlation (similar spatial values): %.3f\n', xcorr_near);

% Check vertices with very different spatial values
v_low = sort_idx(1);
v_high = sort_idx(end);

trace_low = data(v_low, :);
trace_high = data(v_high, :);

xcorr_far = max(xcorr(trace_low, trace_high, 0, 'normalized'));
fprintf('  Cross-correlation (different spatial values): %.3f\n', xcorr_far);

%% Visualization
fprintf('\nCreating visualizations...\n');

figure('Position', [100 100 1400 900]);

% Panel 1: Spatial pattern (determines phase offsets)
subplot(3, 3, 1);
trisurf(F, V(:,1), V(:,2), V(:,3), spatial_pattern, 'EdgeColor', 'none');
axis equal off;
view(3);
colorbar;
title('Spatial Pattern (determines phase)');
colormap(gca, 'parula');

% Panel 2: Initial values (t=0)
subplot(3, 3, 2);
trisurf(F, V(:,1), V(:,2), V(:,3), data(:,1), 'EdgeColor', 'none');
axis equal off;
view(3);
colorbar;
title('Initial Values (t=0)');
colormap(gca, 'parula');

% Panel 3: Mid-time snapshot (t=0.5s)
subplot(3, 3, 3);
t_mid = round(sig.T / 2);
trisurf(F, V(:,1), V(:,2), V(:,3), data(:,t_mid), 'EdgeColor', 'none');
axis equal off;
view(3);
colorbar;
title(sprintf('At t=%.2f sec', (t_mid-1)/sig.Manifold.Time.fs));
colormap(gca, 'parula');

% Panel 4-6: Three vertex traces with different spatial values
time_vec = sig.Manifold.Time.get_time_vector();

% Low spatial value vertex
subplot(3, 3, 4);
plot(time_vec, data(v_low, :), 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Vertex %d (low spatial value)', v_low));
grid on;

% Medium spatial value vertex
v_mid = sort_idx(mid_idx);
subplot(3, 3, 5);
plot(time_vec, data(v_mid, :), 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Vertex %d (medium spatial value)', v_mid));
grid on;

% High spatial value vertex
subplot(3, 3, 6);
plot(time_vec, data(v_high, :), 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Vertex %d (high spatial value)', v_high));
grid on;

% Panel 7: Overlay of traces showing phase shifts
subplot(3, 3, 7);
hold on;
plot(time_vec, data(v_low, :), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Low');
plot(time_vec, data(v_mid, :), 'g-', 'LineWidth', 1.5, 'DisplayName', 'Medium');
plot(time_vec, data(v_high, :), 'r-', 'LineWidth', 1.5, 'DisplayName', 'High');
hold off;
xlabel('Time (s)');
ylabel('Amplitude');
title('Phase Shifts (overlay)');
legend('Location', 'best');
grid on;
xlim([0 0.3]);  % Show first 3 cycles

% Panel 8: Power spectrum
subplot(3, 3, 8);
plot(f, P, 'LineWidth', 1.5);
xlabel('Frequency (Hz)');
ylabel('Power');
title('Frequency Spectrum (single vertex)');
grid on;
xlim([0 30]);

% Panel 9: Spatial-phase relationship
subplot(3, 3, 9);
scatter(spatial_pattern, initial_values, 20, spatial_pattern, 'filled');
xlabel('Spatial Pattern Value');
ylabel('Initial Value (phase proxy)');
title('Spatial → Phase Mapping');
grid on;
colorbar;

sgtitle(sprintf('Phase-Mapped Oscillation: %.1f Hz on %d vertices', ...
    timespec.freq, B.Manifold.N), 'FontSize', 14, 'FontWeight', 'bold');

fprintf('  ✓ Figure created\n\n');

%% Summary
fprintf('=== Summary ===\n\n');
fprintf('Key Concept:\n');
fprintf('  Each vertex oscillates at %.1f Hz, but starts at a different phase\n', timespec.freq);
fprintf('  determined by its spatial pattern value.\n\n');

fprintf('Algorithm:\n');
fprintf('  1. Generate spatial pattern from graph spectrum\n');
fprintf('  2. Map spatial values to phase offsets: φ[n] ∈ [0, 2π]\n');
fprintf('  3. Each vertex oscillates: X[n,t] = A[n] * sin(ωt + φ[n])\n\n');

fprintf('Result:\n');
fprintf('  • Vertices with similar spatial values oscillate in sync\n');
fprintf('  • Creates spatially coherent, traveling wave-like patterns\n');
fprintf('  • All vertices share the same frequency (%.1f Hz)\n', timespec.freq);
fprintf('  • Phase diversity creates rich spatiotemporal dynamics\n\n');
