%DEMO_JOINT_TRANSFORM  Demonstrates joint Manifold-Time Fourier Transform
%
% Shows:
%   1. Create spatiotemporal signal (Manifold × Time)
%   2. Apply joint transform to Lambda × Omega
%   3. Visualize in both domains
%   4. Apply inverse transform to verify

clearvars; clc;
bioctree_start;

%% Setup
fprintf('=== Joint Transform Demo ===\n\n');

% Load mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

% Create Time domain
T = 100;
B.Time = bct.Time(T, 'SampleRate', 100);

fprintf('Mesh: %d vertices\n', B.Manifold.N);
fprintf('Time: %d samples\n', B.Time.N);
fprintf('Lambda modes: %d\n', length(B.Manifold.dual.lambda));

%% Create spatiotemporal signal
fprintf('\nGenerating spatiotemporal signal...\n');

% Create moving spectral heat brush
sig_st = bct.Signal.fromBrush(B.Manifold, 'Category', 'time', ...
    'Type', 'spectral', 'Time', B.Time, ...
    'Source', @(t, T) 1000 + round(500 * sin(2*pi*t/T)), ...
    'Kernel', 'heat', 'Tau', 0.15);

fprintf('Signal shape: [%d × %d] (Manifold × Time)\n', ...
    size(sig_st.Data, 1), size(sig_st.Data, 2));

% Visualize snapshots
figure('Name', 'Spatiotemporal Signal - Snapshots');
for i = 1:4
    t_idx = round(i * T / 4);
    subplot(2, 2, i);
    
    trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), ...
        B.Manifold.Vertices(:,2), B.Manifold.Vertices(:,3), ...
        sig_st.Data(:, t_idx), 'EdgeColor', 'none');
    
    shading interp; colormap(jet); colorbar;
    axis equal tight off; view([0 90]);
    title(sprintf('t = %d', t_idx));
end
sgtitle('Spatiotemporal Signal: Manifold × Time');

%% Apply joint transform
fprintf('\nApplying joint transform (Manifold-Time → Lambda-Omega)...\n');

sig_spectral = bct.operator.transform.joint(sig_st);

fprintf('Spectral shape: [%d × %d] (Lambda × Omega)\n', ...
    size(sig_spectral.Data, 1), size(sig_spectral.Data, 2));

% Compute power in spectral domain
P_spectral = abs(sig_spectral.Data).^2;

% Visualize spectral-frequency representation using jointspectrum
figure('Name', 'Joint Spectral Domain');

subplot(2, 2, 1);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'logpower', ...
    'FrequencyUnits', 'Hz', 'SpatialUnits', 'eigenvalue');

subplot(2, 2, 2);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'power', ...
    'FrequencyUnits', 'Hz', 'SpatialUnits', 'wavenumber');

% Compute power in spectral domain
P_spectral = abs(sig_spectral.Data).^2;

subplot(2, 2, 3);
% Marginal over space (temporal spectrum)
P_temporal = sum(P_spectral, 1);
% Get frequency axis (fftshifted)
Nt = size(P_spectral, 2);
fs = sig_spectral.Domain.B.dual.SampleRate;
if mod(Nt, 2) == 0
    freq_indices = (-Nt/2):(Nt/2-1);
else
    freq_indices = (-(Nt-1)/2):((Nt-1)/2);
end
freq_axis = freq_indices * (fs / Nt);
plot(freq_axis, P_temporal, 'r-', 'LineWidth', 2);
grid on;
xlabel('Frequency (Hz)');
ylabel('Total Power');
title('Marginal: Temporal Spectrum');
xlim([min(freq_axis), max(freq_axis)]);

subplot(2, 2, 4);
% Marginal over frequency (spatial spectrum)
P_spatial = sum(P_spectral, 2);
lambda = sig_spectral.Domain.A.lambda;
semilogy(lambda, P_spatial, 'b-', 'LineWidth', 2);
grid on;
xlabel('Eigenvalue \lambda');
ylabel('Total Power');
title('Marginal: Spatial Spectrum');

%% Apply inverse transform
fprintf('\nApplying inverse joint transform (Lambda-Omega → Manifold-Time)...\n');

sig_reconstructed = bct.operator.transform.ijoint(sig_spectral);

fprintf('Reconstructed shape: [%d × %d] (Manifold × Time)\n', ...
    size(sig_reconstructed.Data, 1), size(sig_reconstructed.Data, 2));

% Verify reconstruction
reconstruction_error = norm(sig_st.Data(:) - sig_reconstructed.Data(:)) / norm(sig_st.Data(:));
fprintf('\nReconstruction error: %.2e (relative)\n', reconstruction_error);

%% Compare original and reconstructed
figure('Name', 'Reconstruction Verification');

for i = 1:4
    t_idx = round(i * T / 4);
    
    % Original
    subplot(3, 4, i);
    trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), ...
        B.Manifold.Vertices(:,2), B.Manifold.Vertices(:,3), ...
        sig_st.Data(:, t_idx), 'EdgeColor', 'none');
    shading interp; colormap(jet); colorbar;
    axis equal tight off; view([0 90]);
    title(sprintf('Original t=%d', t_idx));
    
    % Reconstructed
    subplot(3, 4, 4 + i);
    trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), ...
        B.Manifold.Vertices(:,2), B.Manifold.Vertices(:,3), ...
        sig_reconstructed.Data(:, t_idx), 'EdgeColor', 'none');
    shading interp; colormap(jet); colorbar;
    axis equal tight off; view([0 90]);
    title(sprintf('Reconstructed t=%d', t_idx));
    
    % Difference
    subplot(3, 4, 8 + i);
    diff_data = sig_st.Data(:, t_idx) - sig_reconstructed.Data(:, t_idx);
    trisurf(B.Manifold.Faces, B.Manifold.Vertices(:,1), ...
        B.Manifold.Vertices(:,2), B.Manifold.Vertices(:,3), ...
        diff_data, 'EdgeColor', 'none');
    shading interp; colormap(jet); colorbar;
    axis equal tight off; view([0 90]);
    title(sprintf('Difference t=%d', t_idx));
end

sgtitle(sprintf('Reconstruction Verification (error = %.2e)', reconstruction_error));

%% Energy distribution
fprintf('\n=== Energy Distribution ===\n');

% Total energy
E_total = sum(P_spectral(:));
fprintf('Total energy: %.4e\n', E_total);

% Energy in low spatial frequencies (first 50 modes)
E_lowfreq = sum(P_spectral(1:50, :), 'all');
fprintf('Energy in first 50 modes: %.2f%%\n', 100 * E_lowfreq / E_total);

% Energy in low temporal frequencies (DC to 10 Hz)
fs = B.Time.SampleRate;
freq_axis = (0:T-1) * fs / T;
idx_10Hz = find(freq_axis <= 10, 1, 'last');
E_temporal_low = sum(P_spectral(:, 1:idx_10Hz), 'all');
fprintf('Energy below 10 Hz: %.2f%%\n', 100 * E_temporal_low / E_total);

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('Joint transform workflow:\n');
fprintf('  1. Manifold × Time [%d × %d] → MFT spatial\n', ...
    B.Manifold.N, B.Time.N);
fprintf('  2. Lambda × Time [%d × %d] → FFT temporal\n', ...
    length(lambda), B.Time.N);
fprintf('  3. Lambda × Omega [%d × %d] (spectral-frequency)\n', ...
    length(lambda), B.Time.N);
fprintf('\nInverse transform:\n');
fprintf('  1. Lambda × Omega [%d × %d] → IFFT temporal\n', ...
    length(lambda), B.Time.N);
fprintf('  2. Lambda × Time [%d × %d] → IMFT spatial\n', ...
    length(lambda), B.Time.N);
fprintf('  3. Manifold × Time [%d × %d] (reconstructed)\n', ...
    B.Manifold.N, B.Time.N);
fprintf('\nReconstruction accuracy: %.2e (relative error)\n', reconstruction_error);

fprintf('\nDemo complete!\n');
