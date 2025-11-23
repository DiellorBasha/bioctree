%% Signal Synthesis with Kronecker Delta - Complete Workflow
% 
% This example demonstrates the new signal synthesis architecture using
% impulse (Kronecker delta) signals and filter transforms.
%
% Key Concepts:
% - Kronecker delta: δ(v) = 1 at v=v0, 0 elsewhere (impulse signal)
% - Filter impulse response: output when delta signal is filtered
% - Transform-based filtering: forward → filter → inverse
%
% Architecture:
% 1. Domains own transforms (MFT, FFT, IMFT, IFFT)
% 2. Filters define kernels (pure evaluation)
% 3. Signals create data and coordinate filtering
% 4. BCT orchestrates high-level workflow

clear; close all; clc;

%% Step 1: Import mesh and create BCT object
fprintf('=== Step 1: Import Mesh ===\n');
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);
fprintf('✓ Mesh imported: %d vertices, %d faces\n', B.Manifold.N, size(B.Manifold.Faces, 1));

%% Step 2: Compute eigenbasis (spectral decomposition)
fprintf('\n=== Step 2: Compute Eigenbasis ===\n');
B = B.computeEigenbasis(100);
fprintf('✓ Computed %d eigenmodes\n', length(B.Lambda.lambda));
fprintf('  Eigenvalue range: [%.4f, %.4f]\n', min(B.Lambda.lambda), max(B.Lambda.lambda));

%% Step 3: Set up time domain (auto-creates Omega dual)
fprintf('\n=== Step 3: Set Up Time Domain ===\n');
B.Time = bct.Time(linspace(0, 1, 50)', 50);  % 1 second, 50 Hz
fprintf('✓ Time domain created: %d samples @ %.1f Hz\n', B.Time.N, B.Time.fs);
fprintf('✓ Omega (frequency) domain auto-created: %d frequencies\n', length(B.Omega.axis));
fprintf('✓ Joint Manifold_Time domain auto-created: [%d×%d]\n', B.Joint.size());
fprintf('  Joint.dual = %s (automatic)\n', B.Joint.dual.Domain);

%% Step 4: Verify joint domain structure
fprintf('\n=== Step 4: Verify Joint Domain ===\n');
sz = B.Joint.size();
fprintf('Joint domain: %s [%d×%d]\n', B.Joint.Domain, sz(1), sz(2));
fprintf('  Dual domain: %s [%d×%d]\n', B.Joint.dual.Domain, B.Joint.dual.size());
fprintf('  (Manifold_Time ↔ Lambda_Omega dual relationship)\n');

%% Step 5: Create FilterDesigner
fprintf('\n=== Step 5: Initialize Filter Designer ===\n');
designer = bct.filters.FilterDesigner(B);
fprintf('✓ FilterDesigner initialized\n');

%% ========================================================================
%% PART A: SPATIAL FILTERING WITH KRONECKER DELTA
%% ========================================================================

%% Step 6: Create spatial Kronecker delta (impulse at vertex)
fprintf('\n=== Step 6: Create Spatial Kronecker Delta ===\n');

% Choose an impulse vertex near center of hemisphere
v0 = round(B.Manifold.N / 2);  % Middle vertex
fprintf('Creating delta at vertex %d\n', v0);

% Method 1: Using Signal class directly
delta_spatial = bct.Signal.createDelta(B.Manifold, v0);
fprintf('✓ Delta created using Signal.createDelta()\n');
fprintf('  Signal shape: [%d×%d]\n', size(delta_spatial.Data, 1), size(delta_spatial.Data, 2));
fprintf('  Sum of signal: %.1f (should be 1)\n', sum(delta_spatial.Data));
fprintf('  Value at v=%d: %.1f\n', v0, delta_spatial.Data(v0));

% Method 2: Using BCT wrapper (equivalent)
% delta_spatial = B.createImpulse(v0);

%% Step 7: Create spatial filter (heat diffusion on manifold)
fprintf('\n=== Step 7: Create Spatial Filter ===\n');

% Heat kernel: smooths signal on manifold surface
% tau controls diffusion time (larger = more smoothing)
tau = 0.05;
filt_spatial = designer.lambda('heat', 'tau', tau);

fprintf('✓ Heat diffusion filter created (tau=%.3f)\n', tau);
fprintf('  Filter domain: %s\n', filt_spatial.Domain);
fprintf('  Kernel function: %s\n', func2str(filt_spatial.KernelFunction));

% Evaluate filter response in spectral domain (Lambda)
H_spatial = filt_spatial.evaluate();
fprintf('  Filter response range: [%.4f, %.4f]\n', min(H_spatial), max(H_spatial));

%% Step 8: Apply spatial filter to delta signal
fprintf('\n=== Step 8: Apply Spatial Filter (Impulse Response) ===\n');

% Transform workflow: Manifold --(MFT)--> Lambda --(filter)--> Lambda --(IMFT)--> Manifold
fprintf('Transform workflow: Manifold → Lambda (filter) → Manifold\n');

% Method 1: Using Signal.applyFilter() with explicit domains
response_spatial = delta_spatial.applyFilter(filt_spatial, B.Manifold, B.Lambda);
fprintf('✓ Filter applied using Signal.applyFilter()\n');

% Method 2: Using BCT orchestration (equivalent, automatic domain selection)
% response_spatial = B.synthesizeFilteredSignal(filt_spatial, delta_spatial);

fprintf('  Response shape: [%d×%d]\n', size(response_spatial.Data, 1), size(response_spatial.Data, 2));
fprintf('  Response range: [%.4f, %.4f]\n', min(response_spatial.Data), max(response_spatial.Data));

%% Step 9: Visualize spatial impulse response
fprintf('\n=== Step 9: Visualize Spatial Filtering ===\n');

figure('Name', 'Spatial Filtering: Kronecker Delta', 'Position', [100 100 1400 500]);

% Panel 1: Original delta (impulse)
subplot(1, 3, 1);
B.Manifold.Vertices = B.Manifold.Vertices;  % Ensure vertices set
patch('Faces', B.Manifold.Faces, 'Vertices', B.Manifold.Vertices, ...
      'FaceVertexCData', delta_spatial.Data, ...
      'FaceColor', 'interp', 'EdgeColor', 'none');
axis equal; axis off; view(3);
colorbar; caxis([0 1]);
title(sprintf('Input: Kronecker Delta at v=%d', v0), 'FontSize', 12, 'FontWeight', 'bold');
camlight; lighting gouraud;

% Panel 2: Filter response in spectral domain
subplot(1, 3, 2);
k_vals = sqrt(B.Lambda.lambda);  % Wavenumber k = sqrt(λ)
plot(k_vals, H_spatial, 'LineWidth', 2);
grid on; xlabel('Wavenumber k (rad/mm)', 'FontSize', 11);
ylabel('Filter Response H(k)', 'FontSize', 11);
title(sprintf('Heat Kernel (τ=%.3f)', tau), 'FontSize', 12, 'FontWeight', 'bold');
ylim([0 1.05]);

% Panel 3: Filtered response (impulse response = smoothed delta)
subplot(1, 3, 3);
patch('Faces', B.Manifold.Faces, 'Vertices', B.Manifold.Vertices, ...
      'FaceVertexCData', response_spatial.Data, ...
      'FaceColor', 'interp', 'EdgeColor', 'none');
axis equal; axis off; view(3);
colorbar; caxis([0 max(response_spatial.Data)]);
title('Output: Impulse Response (Smoothed Delta)', 'FontSize', 12, 'FontWeight', 'bold');
camlight; lighting gouraud;

fprintf('✓ Spatial filtering visualization complete\n');

%% ========================================================================
%% PART B: TEMPORAL FILTERING WITH KRONECKER DELTA
%% ========================================================================

%% Step 10: Create temporal Kronecker delta
fprintf('\n=== Step 10: Create Temporal Kronecker Delta ===\n');

% For temporal filtering, we need a signal constant across space,
% with an impulse in time
t0 = 25;  % Middle time point
v_temporal = round(B.Manifold.N / 3);  % Choose a vertex for visualization

fprintf('Creating temporal delta at t=%d (vertex v=%d for viz)\n', t0, v_temporal);

% Create spatiotemporal delta: impulse at (v_temporal, t0)
delta_temporal = bct.Signal.createDelta(B.Manifold, v_temporal, B.Time, t0);

fprintf('✓ Spatiotemporal delta created\n');
fprintf('  Signal shape: [%d×%d] (vertices×time)\n', size(delta_temporal.Data, 1), size(delta_temporal.Data, 2));
fprintf('  Sum at vertex %d: %.1f\n', v_temporal, sum(delta_temporal.Data(v_temporal, :)));
fprintf('  Value at (v=%d, t=%d): %.1f\n', v_temporal, t0, delta_temporal.Data(v_temporal, t0));

%% Step 11: Create temporal filter (Gaussian bandpass)
fprintf('\n=== Step 11: Create Temporal Filter ===\n');

% Bandpass filter centered at 10 Hz (alpha band)
f_center = 10;  % Hz
f_bandwidth = 3;  % Hz

filt_temporal = designer.temporal('gaussian', ...
    'center', f_center * 2*pi, ...      % Convert to rad/s
    'sigma', f_bandwidth * 2*pi);

fprintf('✓ Gaussian bandpass filter created\n');
fprintf('  Center frequency: %.1f Hz\n', f_center);
fprintf('  Bandwidth: %.1f Hz\n', f_bandwidth);
fprintf('  Filter domain: %s\n', filt_temporal.Domain);

% Evaluate filter response in frequency domain (Omega)
H_temporal = filt_temporal.evaluate();
fprintf('  Filter response range: [%.4f, %.4f]\n', min(H_temporal), max(H_temporal));

%% Step 12: Apply temporal filter to delta signal
fprintf('\n=== Step 12: Apply Temporal Filter ===\n');

% Transform workflow: Time --(FFT)--> Omega --(filter)--> Omega --(IFFT)--> Time
fprintf('Transform workflow: Time → Omega (filter) → Time\n');

% Apply filter using Signal.applyFilter()
response_temporal = delta_temporal.applyFilter(filt_temporal, B.Time, B.Omega);

fprintf('✓ Filter applied\n');
fprintf('  Response shape: [%d×%d]\n', size(response_temporal.Data, 1), size(response_temporal.Data, 2));

% Extract time series at the impulse vertex
time_series_original = delta_temporal.Data(v_temporal, :);
time_series_filtered = response_temporal.Data(v_temporal, :);

fprintf('  Original signal range: [%.4f, %.4f]\n', min(time_series_original), max(time_series_original));
fprintf('  Filtered signal range: [%.4f, %.4f]\n', min(time_series_filtered), max(time_series_filtered));

%% Step 13: Visualize temporal impulse response
fprintf('\n=== Step 13: Visualize Temporal Filtering ===\n');

figure('Name', 'Temporal Filtering: Kronecker Delta', 'Position', [150 150 1400 500]);

% Panel 1: Original delta in time
subplot(1, 3, 1);
plot(B.Time.axis, time_series_original, 'k-', 'LineWidth', 2);
hold on;
stem(B.Time.axis(t0), 1, 'r', 'filled', 'LineWidth', 1.5);
grid on; xlabel('Time (s)', 'FontSize', 11);
ylabel('Amplitude', 'FontSize', 11);
title(sprintf('Input: Kronecker Delta at t=%d', t0), 'FontSize', 12, 'FontWeight', 'bold');
ylim([-0.2 1.2]);

% Panel 2: Filter response in frequency domain
subplot(1, 3, 2);
freq_axis = B.Omega.axis / (2*pi);  % Convert rad/s to Hz
plot(freq_axis, H_temporal, 'LineWidth', 2);
grid on; xlabel('Frequency (Hz)', 'FontSize', 11);
ylabel('Filter Response H(f)', 'FontSize', 11);
title(sprintf('Gaussian Bandpass (f₀=%.1f Hz)', f_center), 'FontSize', 12, 'FontWeight', 'bold');
xlim([0 B.Time.fs/2]); ylim([0 1.05]);

% Panel 3: Filtered response (impulse response = bandpass oscillation)
subplot(1, 3, 3);
plot(B.Time.axis, time_series_filtered, 'b-', 'LineWidth', 1.5);
grid on; xlabel('Time (s)', 'FontSize', 11);
ylabel('Amplitude', 'FontSize', 11);
title('Output: Impulse Response (10 Hz Oscillation)', 'FontSize', 12, 'FontWeight', 'bold');

fprintf('✓ Temporal filtering visualization complete\n');

%% ========================================================================
%% PART C: JOINT SPATIOTEMPORAL FILTERING
%% ========================================================================

%% Step 14: Create spatiotemporal Kronecker delta
fprintf('\n=== Step 14: Create Spatiotemporal Kronecker Delta ===\n');

% Impulse at specific vertex AND time point
v_joint = round(B.Manifold.N / 4);
t_joint = 20;

fprintf('Creating joint delta at (v=%d, t=%d)\n', v_joint, t_joint);

delta_joint = bct.Signal.createDelta(B.Manifold, v_joint, B.Time, t_joint);

fprintf('✓ Spatiotemporal delta created\n');
fprintf('  Signal shape: [%d×%d]\n', size(delta_joint.Data, 1), size(delta_joint.Data, 2));
fprintf('  Total sum: %.1f\n', sum(delta_joint.Data(:)));
fprintf('  Value at (v=%d, t=%d): %.1f\n', v_joint, t_joint, delta_joint.Data(v_joint, t_joint));

%% Step 15: Create joint spatiotemporal filter (2D Gabor)
fprintf('\n=== Step 15: Create Joint Filter (2D Gabor) ===\n');

% Gabor filter: selective for specific wavenumber AND frequency
% (traveling wave detector)
k0 = 0.2;      % Wavenumber center (rad/mm) - spatial frequency
dk = 0.05;     % Wavenumber bandwidth
f0 = 12;       % Frequency center (Hz) - temporal frequency
df = 4;        % Frequency bandwidth (Hz)

filt_joint = designer.joint('gabor', ...
    'center_x', k0, ...
    'sigma_x', dk, ...
    'center_y', f0 * 2*pi, ...
    'sigma_y', df * 2*pi);

fprintf('✓ Joint Gabor filter created\n');
fprintf('  Spatial center: k₀=%.2f rad/mm (λ=%.1f mm)\n', k0, 2*pi/k0);
fprintf('  Spatial bandwidth: Δk=%.3f\n', dk);
fprintf('  Temporal center: f₀=%.1f Hz\n', f0);
fprintf('  Temporal bandwidth: Δf=%.1f Hz\n', df);
fprintf('  Filter domain: %s\n', filt_joint.Domain);

% Evaluate filter on Joint grid
H_joint = filt_joint.evaluate();
fprintf('  Filter response shape: [%d×%d]\n', size(H_joint, 1), size(H_joint, 2));
fprintf('  Filter response range: [%.4f, %.4f]\n', min(H_joint(:)), max(H_joint(:)));

%% Step 16: Visualize joint filter (2D Gabor kernel)
fprintf('\n=== Step 16: Visualize Joint Filter ===\n');

figure('Name', 'Joint Filter: 2D Gabor (Lambda×Omega)', 'Position', [200 200 1200 500]);

% Panel 1: 2D Gabor in spectral-frequency space
subplot(1, 2, 1);
k_axis = sqrt(B.Lambda.lambda);  % Wavenumber axis
f_axis = B.Omega.axis / (2*pi);   % Frequency axis (Hz)

imagesc(f_axis, k_axis, H_joint);
axis xy; colorbar;
xlabel('Frequency (Hz)', 'FontSize', 11);
ylabel('Wavenumber k (rad/mm)', 'FontSize', 11);
title(sprintf('2D Gabor Filter (k₀=%.2f, f₀=%.1f Hz)', k0, f0), ...
      'FontSize', 12, 'FontWeight', 'bold');
hold on;
plot(f0, k0, 'r*', 'MarkerSize', 15, 'LineWidth', 2);  % Mark center

% Panel 2: Cross-sections
subplot(1, 2, 2);

% Spatial cross-section (at peak frequency)
[~, f_idx] = min(abs(f_axis - f0));
H_spatial_slice = H_joint(:, f_idx);

% Temporal cross-section (at peak wavenumber)
[~, k_idx] = min(abs(k_axis - k0));
H_temporal_slice = H_joint(k_idx, :);

yyaxis left;
plot(k_axis, H_spatial_slice, 'b-', 'LineWidth', 2);
ylabel('Spatial Response H(k)', 'FontSize', 11, 'Color', 'b');
xlabel('Wavenumber k (rad/mm) | Frequency f (Hz)', 'FontSize', 11);

yyaxis right;
plot(f_axis, H_temporal_slice, 'r-', 'LineWidth', 2);
ylabel('Temporal Response H(f)', 'FontSize', 11, 'Color', 'r');

grid on;
title('Filter Cross-Sections', 'FontSize', 12, 'FontWeight', 'bold');
legend({'Spatial (at f₀)', 'Temporal (at k₀)'}, 'Location', 'best');

fprintf('✓ Joint filter visualization complete\n');

%% Step 17: Note on joint filtering (2D transforms not yet implemented)
fprintf('\n=== Step 17: Joint Filtering Status ===\n');
fprintf('⚠ Full joint filtering requires 2D transforms (not yet implemented)\n');
fprintf('  Current limitation: Cannot apply Lambda×Omega filter directly\n');
fprintf('  Workaround: Apply spatial and temporal filters separately\n');
fprintf('\n');
fprintf('  Example separable workflow:\n');
fprintf('    1. Apply spatial filter: delta → spatial_filtered\n');
fprintf('    2. Apply temporal filter: spatial_filtered → final_result\n');
fprintf('\n');

% Demonstrate separable filtering
fprintf('Demonstrating separable filtering:\n');

% Step 1: Spatial filtering
response_step1 = delta_joint.applyFilter(filt_spatial, B.Manifold, B.Lambda);
fprintf('  ✓ Step 1: Spatial filtering complete\n');

% Step 2: Temporal filtering
response_final = response_step1.applyFilter(filt_temporal, B.Time, B.Omega);
fprintf('  ✓ Step 2: Temporal filtering complete\n');
fprintf('  Final response shape: [%d×%d]\n', size(response_final.Data, 1), size(response_final.Data, 2));

%% Summary
fprintf('\n');
fprintf('==================================================================\n');
fprintf('SUMMARY: Kronecker Delta Signal Synthesis\n');
fprintf('==================================================================\n');
fprintf('\n');
fprintf('Architecture Components:\n');
fprintf('  ✓ Domains own transforms (MFT, FFT, IMFT, IFFT)\n');
fprintf('  ✓ Filters define kernels (pure evaluation)\n');
fprintf('  ✓ Signals create data and coordinate filtering\n');
fprintf('  ✓ BCT orchestrates workflow\n');
fprintf('\n');
fprintf('Demonstrated Workflows:\n');
fprintf('  ✓ Spatial filtering: Manifold → Lambda (filter) → Manifold\n');
fprintf('  ✓ Temporal filtering: Time → Omega (filter) → Time\n');
fprintf('  ✓ Joint filter creation and visualization\n');
fprintf('  ✓ Separable spatiotemporal filtering\n');
fprintf('\n');
fprintf('Key Methods:\n');
fprintf('  Signal.createDelta(manifold, v0, [time, t0]) - Create impulse\n');
fprintf('  Signal.applyFilter(filter, src, dst) - Apply with transforms\n');
fprintf('  BCT.createImpulse(v0, [t0]) - Convenience wrapper\n');
fprintf('  BCT.synthesizeFilteredSignal(filter, signal) - Orchestration\n');
fprintf('\n');
fprintf('Next Steps:\n');
fprintf('  • Implement 2D transforms for full joint filtering\n');
fprintf('  • Add joint filtering to BctFilterDesigner UI\n');
fprintf('  • Create FilterBank for multiple filter application\n');
fprintf('\n');
fprintf('==================================================================\n');
fprintf('Workflow complete! See generated figures.\n');
fprintf('==================================================================\n');
