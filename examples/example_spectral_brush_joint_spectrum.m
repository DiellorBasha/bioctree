%EXAMPLE_SPECTRAL_BRUSH_JOINT_SPECTRUM
%   Quick example showing how to:
%   1. Create a signal using bct.brush.time.spectral
%   2. Compute the joint spectrum using bct.operator.transform.joint
%   3. Visualize using bct.show.jointspectrum

clearvars; clc;
bioctree_start;

%% Step 1: Setup BCT object with mesh and time domain
fprintf('=== Setting up mesh and time domain ===\n');

% Load mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

% Create time domain: 200 samples at 100 Hz = 2 seconds
B.Time = bct.Time(200, 'SampleRate', 100);

fprintf('Mesh: %d vertices, %d faces\n', B.Manifold.N, size(B.Manifold.Faces, 1));
fprintf('Time: %d samples at %.1f Hz (%.2f seconds)\n', ...
    B.Time.N, B.Time.SampleRate, B.Time.N / B.Time.SampleRate);

%% Step 2: Create spatiotemporal signal using spectral brush
fprintf('\n=== Creating spatiotemporal signal ===\n');

% Define brush parameters:
% - Moving source: oscillates between two vertices
% - Time-varying tau: heat diffusion increases over time
params = struct();
params.source = @(t, T) 1000 + round(500 * sin(2*pi*t/T));  % Oscillating source
params.kernel = 'heat';
params.tau = @(t, T) 0.05 + 0.15 * (t/T);  % Increasing diffusion: 0.05 → 0.20

% Create the brush weights [N×T]
w = bct.brush.time.spectral(B.Manifold, B.Time, params);

fprintf('Brush created: [%d × %d] (vertices × time)\n', size(w, 1), size(w, 2));
fprintf('Source oscillates: vertex 1000 ± 500\n');
fprintf('Tau increases: 0.05 → 0.20\n');

% Create Joint domain (Manifold × Time)
joint_domain = bct.Joint(B.Manifold, B.Time);

% Create Signal object on the Joint domain
sig_st = bct.Signal(w, joint_domain);
sig_st.Meta.Description = 'Oscillating spectral heat brush';

%% Step 3: Visualize spatiotemporal signal (snapshots)
fprintf('\n=== Visualizing spatiotemporal signal ===\n');

figure('Name', 'Spatiotemporal Signal - Snapshots', 'Position', [100 100 1200 800]);

time_indices = round(linspace(1, B.Time.N, 6));
for i = 1:6
    t_idx = time_indices(i);
    t_sec = (t_idx - 1) / B.Time.SampleRate;
    
    subplot(2, 3, i);
    trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), ...
        B.Manifold.Vertices(:,2), B.Manifold.Vertices(:,3), ...
        full(w(:, t_idx)), 'EdgeColor', 'none');
    
    shading interp; 
    colormap(jet); 
    colorbar;
    axis equal tight off; 
    view([0 90]);
    title(sprintf('t = %.2f s (sample %d)', t_sec, t_idx));
    caxis([0, max(w(:))]);  % Same color scale for all
end

sgtitle('Spatiotemporal Signal: Moving Spectral Heat Brush');

%% Step 4: Apply joint transform
fprintf('\n=== Computing joint transform ===\n');

sig_spectral = bct.operator.transform.joint(sig_st);

fprintf('Joint transform complete!\n');
fprintf('  Input:  Manifold × Time     [%d × %d]\n', ...
    size(sig_st.Data, 1), size(sig_st.Data, 2));
fprintf('  Output: Lambda × Omega      [%d × %d]\n', ...
    size(sig_spectral.Data, 1), size(sig_spectral.Data, 2));
fprintf('  Transform: MFT (spatial) + FFT (temporal) + fftshift\n');
fprintf('  Frequency axis: zero-centered (negative freq on left)\n');

%% Step 5: Visualize joint spectrum
fprintf('\n=== Visualizing joint spectrum ===\n');

% Create comprehensive visualization
figure('Name', 'Joint Spectrum Visualization', 'Position', [150 150 1400 900]);

% 5a: Log power spectrum (most informative)
subplot(2, 3, 1);
bct.show.jointspectrum(sig_spectral, ...
    'PlotType', 'logpower', ...
    'FrequencyUnits', 'Hz', ...
    'SpatialUnits', 'eigenvalue');
title('Log Power: \Lambda × \Omega (eigenvalue vs Hz)');

% 5b: Power spectrum with wavenumber
subplot(2, 3, 2);
bct.show.jointspectrum(sig_spectral, ...
    'PlotType', 'power', ...
    'FrequencyUnits', 'Hz', ...
    'SpatialUnits', 'wavenumber');
title('Power: wavenumber vs Hz');

% 5c: Zoomed to low frequencies (±25 Hz)
subplot(2, 3, 3);
bct.show.jointspectrum(sig_spectral, ...
    'PlotType', 'logpower', ...
    'FrequencyUnits', 'Hz', ...
    'FrequencyRange', [-25, 25]);
title('Zoomed: ±25 Hz');

% 5d: Marginal - spatial spectrum
P_spectral = abs(sig_spectral.Data).^2;
P_spatial = sum(P_spectral, 2);  % Sum over frequency
lambda = sig_spectral.Domain.A.lambda;

subplot(2, 3, 4);
semilogy(lambda, P_spatial, 'b-', 'LineWidth', 2);
grid on;
xlabel('Eigenvalue \lambda');
ylabel('Total Power');
title('Marginal: Spatial Spectrum (summed over frequency)');
xlim([0, max(lambda)]);

% 5e: Marginal - temporal spectrum
P_temporal = sum(P_spectral, 1);  % Sum over space

% Frequency axis (after fftshift)
Nt = size(P_spectral, 2);
fs = B.Time.SampleRate;
if mod(Nt, 2) == 0
    freq_indices = (-Nt/2):(Nt/2-1);
else
    freq_indices = (-(Nt-1)/2):((Nt-1)/2);
end
freq_axis = freq_indices * (fs / Nt);

subplot(2, 3, 5);
plot(freq_axis, P_temporal, 'r-', 'LineWidth', 2);
grid on;
xlabel('Frequency (Hz)');
ylabel('Total Power');
title('Marginal: Temporal Spectrum (summed over space)');
xlim([min(freq_axis), max(freq_axis)]);

% 5f: Phase information
subplot(2, 3, 6);
bct.show.jointspectrum(sig_spectral, ...
    'PlotType', 'phase', ...
    'FrequencyUnits', 'Hz', ...
    'SpatialUnits', 'eigenvalue');
title('Phase: \Lambda × \Omega');

sgtitle('Joint Spectrum Analysis: Spectral Heat Brush');

%% Step 6: Verify reconstruction
fprintf('\n=== Verifying reconstruction ===\n');

sig_reconstructed = bct.operator.transform.ijoint(sig_spectral);

reconstruction_error = norm(sig_st.Data(:) - sig_reconstructed.Data(:)) / norm(sig_st.Data(:));
fprintf('Relative reconstruction error: %.2e\n', reconstruction_error);

if reconstruction_error < 1e-10
    fprintf('✓ Perfect reconstruction!\n');
else
    fprintf('⚠ Reconstruction error: %.2e\n', reconstruction_error);
end

%% Summary
fprintf('\n=== Summary: Complete Workflow ===\n');
fprintf('\n1. CREATE SIGNAL:\n');
fprintf('   params.source = @(t, T) 1000 + round(500 * sin(2*pi*t/T));\n');
fprintf('   params.kernel = ''heat'';\n');
fprintf('   params.tau = @(t, T) 0.05 + 0.15 * (t/T);\n');
fprintf('   w = bct.brush.time.spectral(B.Manifold, B.Time, params);\n');
fprintf('   joint_domain = bct.Joint(B.Manifold, B.Time);\n');
fprintf('   sig_st = bct.Signal(w, joint_domain);\n');

fprintf('\n2. COMPUTE JOINT SPECTRUM:\n');
fprintf('   sig_spectral = bct.operator.transform.joint(sig_st);\n');

fprintf('\n3. VISUALIZE:\n');
fprintf('   bct.show.jointspectrum(sig_spectral, ...\n');
fprintf('       ''PlotType'', ''logpower'', ...\n');
fprintf('       ''FrequencyUnits'', ''Hz'', ...\n');
fprintf('       ''SpatialUnits'', ''eigenvalue'');\n');

fprintf('\n4. RECONSTRUCT (optional):\n');
fprintf('   sig_reconstructed = bct.operator.transform.ijoint(sig_spectral);\n');

fprintf('\nDone!\n');
