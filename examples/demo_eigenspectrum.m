%DEMO_EIGENSPECTRUM  Demonstrates eigenspectrum visualization
%
% Shows different ways to visualize the Manifold Fourier Transform:
%   1. Power spectrum vs eigenvalue
%   2. Index-based spectrum
%   3. Log-log spectrum (power law analysis)
%   4. Energy-normalized spectrum
%   5. Band-aggregated spectrum
%   6. Top mode visualization

clearvars; clc;
bioctree_start;

%% Setup
fprintf('=== Eigenspectrum Visualization Demo ===\n\n');

% Load mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

fprintf('Mesh: %d vertices, %d eigenmodes\n', B.Manifold.N, ...
    length(B.Manifold.dual.lambda));

%% Create Test Signal - Spectral Heat Brush
fprintf('\nGenerating test signal (spectral heat brush)...\n');

sig = bct.Signal.fromBrush(B.Manifold, 'Category', 'patch', ...
    'Type', 'spectral', 'Source', 1000, 'Kernel', 'heat', 'Tau', 0.2);

% Plot spatial pattern
fig_spatial = figure('Name', 'Spatial Pattern');
B.Manifold.plot('data', sig.Data, 'shading', 'interp');
colormap(jet); colorbar;
title('Test Signal: Heat Kernel (tau=0.2)');
axis equal tight off; view([0 90]);

%% 1. Basic Power Spectrum
fprintf('\n--- Example 1: Power Spectrum ---\n');

bct.show.eigenspectrum(sig);
fprintf('Standard power spectrum: |x̂(λ)|² vs eigenvalue\n');

pause(1);

%% 2. Index-Based Spectrum (Log Scale)
fprintf('\n--- Example 2: Index Spectrum (Log Scale) ---\n');

bct.show.eigenspectrum(sig, 'Type', 'index', 'Scale', 'log');
fprintf('Log-scale plot vs mode index (clearer for non-uniform eigenvalues)\n');

pause(1);

%% 3. Log-Log Spectrum (Power Law Analysis)
fprintf('\n--- Example 3: Log-Log Spectrum ---\n');

bct.show.eigenspectrum(sig, 'Type', 'loglog');
fprintf('Reveals power law scaling: P ∝ λ^α\n');

pause(1);

%% 4. Energy-Normalized Spectrum with Threshold
fprintf('\n--- Example 4: Normalized Energy Spectrum ---\n');

bct.show.eigenspectrum(sig, 'Type', 'normalized', ...
    'ShowThreshold', true, 'ThresholdValue', 90);
fprintf('Shows fraction of total energy per mode\n');
fprintf('Threshold marks 90%% cumulative energy\n');

pause(1);

%% 5. Band-Aggregated Spectrum
fprintf('\n--- Example 5: Band-Aggregated Spectrum ---\n');

bct.show.eigenspectrum(sig, 'Type', 'bands', 'NumBands', 25);
fprintf('Aggregates power into frequency bands (like EEG bands)\n');

pause(1);

%% 6. All Plots Together
fprintf('\n--- Example 6: All Spectrum Types ---\n');

bct.show.eigenspectrum(sig, 'Type', 'all', 'NumBands', 20);
fprintf('Comprehensive view of all spectrum types\n');

pause(1);

%% 7. Top Eigenmodes Visualization
fprintf('\n--- Example 7: Top Eigenmodes ---\n');

bct.show.eigenspectrum(sig, 'TopModes', 6);
fprintf('Shows spatial patterns of dominant modes\n');
fprintf('Links spectral content back to geometry\n');

pause(1);

%% Compare Different Signals
fprintf('\n--- Example 8: Comparing Different Signals ---\n');

% Create three signals with different spatial scales
sig_sharp = bct.Signal.fromBrush(B.Manifold, 'Category', 'patch', ...
    'Type', 'spectral', 'Source', 1000, 'Kernel', 'heat', 'Tau', 0.05);

sig_medium = bct.Signal.fromBrush(B.Manifold, 'Category', 'patch', ...
    'Type', 'spectral', 'Source', 1000, 'Kernel', 'heat', 'Tau', 0.2);

sig_smooth = bct.Signal.fromBrush(B.Manifold, 'Category', 'patch', ...
    'Type', 'spectral', 'Source', 1000, 'Kernel', 'heat', 'Tau', 0.6);

% Compute spectra
sig_sharp_spectral = sig_sharp.mft();
sig_medium_spectral = sig_medium.mft();
sig_smooth_spectral = sig_smooth.mft();

lambda = sig_sharp_spectral.Domain.lambda;
P_sharp = abs(sig_sharp_spectral.Data).^2;
P_medium = abs(sig_medium_spectral.Data).^2;
P_smooth = abs(sig_smooth_spectral.Data).^2;

% Plot comparison
figure('Name', 'Spectrum Comparison');

subplot(2,2,1:2);
semilogy(lambda, P_sharp, 'b-', 'LineWidth', 2, 'DisplayName', 'Sharp (τ=0.05)');
hold on;
semilogy(lambda, P_medium, 'g-', 'LineWidth', 2, 'DisplayName', 'Medium (τ=0.2)');
semilogy(lambda, P_smooth, 'r-', 'LineWidth', 2, 'DisplayName', 'Smooth (τ=0.6)');
grid on;
xlabel('Eigenvalue λ');
ylabel('Power |x̂(λ)|²');
title('Spectrum Comparison: Different Spatial Scales');
legend('Location', 'best');

% Plot spatial patterns
patterns = {sig_sharp.Data, sig_medium.Data, sig_smooth.Data};
titles = {'Sharp (τ=0.05)', 'Medium (τ=0.2)', 'Smooth (τ=0.6)'};

for i = 1:3
    subplot(2,3,3+i);
    trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), ...
        B.Manifold.V(:,3), patterns{i}, 'EdgeColor', 'none');
    shading interp; colormap(jet);
    axis equal tight off; view([0 90]);
    title(titles{i});
end

fprintf('\nKey observation:\n');
fprintf('  Sharp patterns (low τ) → broad spectrum (many modes)\n');
fprintf('  Smooth patterns (high τ) → narrow spectrum (few modes)\n');

%% Energy Distribution Analysis
fprintf('\n--- Example 9: Energy Distribution Analysis ---\n');

% Analyze where energy is concentrated
for i = 1:3
    specs = {P_sharp, P_medium, P_smooth};
    labels = {'Sharp', 'Medium', 'Smooth'};
    
    P_norm = specs{i} / sum(specs{i});
    cumulative = cumsum(P_norm);
    
    % Find 90% energy threshold
    idx_90 = find(cumulative >= 0.90, 1);
    
    fprintf('%s (τ=%.2f): 90%% energy in first %d modes (%.1f%%)\n', ...
        labels{i}, [0.05, 0.2, 0.6], idx_90, 100*idx_90/length(lambda));
end

%% Custom Styling Example
fprintf('\n--- Example 10: Custom Styling ---\n');

bct.show.eigenspectrum(sig, 'Type', 'power', 'Scale', 'log', ...
    'Color', [0.2 0.4 0.8], 'LineWidth', 2.5, 'MarkerSize', 10, ...
    'ShowThreshold', true, 'ThresholdValue', 95);

fprintf('Custom colors, line widths, and markers\n');

%% Bandpass Signal Example
fprintf('\n--- Example 11: Bandpass Signal ---\n');

% Create bandpass signal (Gaussian centered at eigenvalue 100)
sig_bandpass = bct.Signal.fromBrush(B.Manifold, 'Category', 'patch', ...
    'Type', 'spectral', 'Source', 1000, 'Kernel', 'gaussian', ...
    'Center', 100, 'Bandwidth', 30);

% Show spectrum
bct.show.eigenspectrum(sig_bandpass, 'Type', 'power', 'Scale', 'linear');
title('Bandpass Signal: Gaussian centered at λ=100');

% Show spatial pattern
figure('Name', 'Bandpass Spatial Pattern');
B.Manifold.plot('data', sig_bandpass.Data, 'shading', 'interp');
colormap(jet); colorbar;
title('Bandpass Signal (λ≈100)');
axis equal tight off; view([0 90]);

fprintf('Bandpass signal isolates specific spatial frequencies\n');

%% Summary Statistics
fprintf('\n=== Summary Statistics ===\n');

sig_spectral = sig.mft();
P = abs(sig_spectral.Data).^2;
P_norm = P / sum(P);

fprintf('Signal: %s\n', sig.Metadata.Label);
fprintf('Total modes: %d\n', length(P));
fprintf('Non-zero power modes: %d\n', sum(P > 1e-10));
fprintf('Peak power at mode: %d (λ=%.2f)\n', ...
    find(P == max(P)), lambda(P == max(P)));
fprintf('Energy concentration:\n');
fprintf('  50%% energy in first %d modes (%.1f%%)\n', ...
    find(cumsum(P_norm) >= 0.5, 1), 100*find(cumsum(P_norm) >= 0.5, 1)/length(P));
fprintf('  90%% energy in first %d modes (%.1f%%)\n', ...
    find(cumsum(P_norm) >= 0.9, 1), 100*find(cumsum(P_norm) >= 0.9, 1)/length(P));
fprintf('  99%% energy in first %d modes (%.1f%%)\n', ...
    find(cumsum(P_norm) >= 0.99, 1), 100*find(cumsum(P_norm) >= 0.99, 1)/length(P));

%% Interpretation Guide
fprintf('\n=== Interpretation Guide ===\n');
fprintf('1. Power Spectrum (|x̂|² vs λ):\n');
fprintf('   - Standard view analogous to Fourier spectrum\n');
fprintf('   - Shows energy at each spatial frequency\n\n');

fprintf('2. Index Spectrum (|x̂|² vs mode k):\n');
fprintf('   - Clearer for non-uniform eigenvalue spacing\n');
fprintf('   - Early modes = large-scale, later = fine detail\n\n');

fprintf('3. Log-Log Spectrum:\n');
fprintf('   - Reveals power law scaling: P ∝ λ^α\n');
fprintf('   - Useful for comparing conditions, detecting scale-free structure\n\n');

fprintf('4. Normalized Spectrum:\n');
fprintf('   - Shows fraction of total energy (Parseval/DEC-correct)\n');
fprintf('   - Cumulative curve shows energy accumulation\n\n');

fprintf('5. Band-Aggregated:\n');
fprintf('   - Bins frequencies like EEG bands\n');
fprintf('   - Easier to see broad trends\n\n');

fprintf('6. Top Modes:\n');
fprintf('   - Links spectrum back to spatial geometry\n');
fprintf('   - Shows what patterns carry the energy\n\n');

fprintf('Demo complete!\n');
