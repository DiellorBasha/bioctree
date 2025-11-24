%% Demo: Signal Generation via Mask Filters
%
% This script demonstrates the new Signal.fromMask() approach for signal generation
% using the Filter/Kernel system, replacing the old createDelta() method.
%
% Key Concepts:
%   1. Signal.fromMask(filter) - Generate signal by evaluating filter on domain
%   2. Normalization options - 'none', 'energy', 'peak'
%   3. Dynamic mask updates - Change filter parameters and regenerate signal
%   4. Integration with KernelEditors - Interactive signal design
%
% Workflow:
%   Step 1: Create Filter (mask) on domain with kernel
%   Step 2: Evaluate kernel on domain axis → generates signal data
%   Step 3: Optional normalization (unit energy, unit peak)
%   Step 4: Create Signal object with mask reference

clear; close all;

%% Setup: Create BCT instance with domains

% Load test mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

% Compute eigendecomposition
fprintf('Computing eigendecomposition...\n');
B.Lambda = B.Manifold.dual('numModes', 100);

% Create temporal domains
B.Time = bct.Time(0:0.001:1, 1000);  % 1 second, 1000 Hz
B.Omega = B.Time.dual;

fprintf('\nDomains ready:\n');
fprintf('  Manifold: %d vertices\n', B.Manifold.N);
fprintf('  Lambda: %d modes\n', B.Lambda.N);
fprintf('  Time: %d samples (fs=%.0f Hz)\n', B.Time.N, B.Time.fs);
fprintf('  Omega: %d frequencies\n', B.Omega.N);

%% Example 1: Delta Impulse Signal (Discrete Domain)

fprintf('\n=== Example 1: Delta Impulse on Time Domain ===\n');

% OLD APPROACH (deprecated):
% sig_old = bct.Signal.createDelta(B.Time, 500);

% NEW APPROACH: Create delta filter, then signal from mask
mask_delta = bct.filters.Filter(B.Time, 'delta', ...
    'x0', B.Time.axis(500), 'label', 'Time_Delta_0.5s');

% Generate signal from mask (no normalization)
sig_delta = bct.Signal.fromMask(mask_delta, 'normalize', 'none');

% Generate signal with unit energy normalization
sig_delta_norm = bct.Signal.fromMask(mask_delta, 'normalize', 'energy');

fprintf('  Delta at t=%.3f s\n', B.Time.axis(500));
fprintf('  Raw delta: sum = %.2f, norm = %.4f\n', sum(sig_delta.Data), norm(sig_delta.Data));
fprintf('  Unit energy: sum = %.4f, norm = %.4f\n', sum(sig_delta_norm.Data), norm(sig_delta_norm.Data));

% Visualize
figure('Name', 'Delta Impulse Signals', 'Position', [100 100 1200 400]);

subplot(1,2,1);
stem(B.Time.axis, sig_delta.Data, 'b', 'LineWidth', 1.5);
grid on; xlabel('Time (s)'); ylabel('Amplitude');
title('Delta Impulse (Raw)');
xlim([0.4 0.6]);

subplot(1,2,2);
stem(B.Time.axis, sig_delta_norm.Data, 'r', 'LineWidth', 1.5);
grid on; xlabel('Time (s)'); ylabel('Amplitude');
title('Delta Impulse (Unit Energy)');
xlim([0.4 0.6]);

%% Example 2: Gaussian Bump on Lambda Domain

fprintf('\n=== Example 2: Gaussian on Lambda Domain ===\n');

% Create Gaussian mask on Lambda
mask_gauss = bct.filters.Filter(B.Lambda, 'gaussian', ...
    'center', 50, 'sigma', 10, 'label', 'Lambda_Gaussian');

% Generate signals with different normalizations
sig_gauss_none = bct.Signal.fromMask(mask_gauss, 'normalize', 'none');
sig_gauss_energy = bct.Signal.fromMask(mask_gauss, 'normalize', 'energy');
sig_gauss_peak = bct.Signal.fromMask(mask_gauss, 'normalize', 'peak');

fprintf('  Gaussian centered at λ=%.0f, σ=%.0f\n', ...
    mask_gauss.center, mask_gauss.sigma);
fprintf('  No norm:     max=%.4f, energy=%.4f\n', ...
    max(sig_gauss_none.Data), norm(sig_gauss_none.Data));
fprintf('  Unit energy: max=%.4f, energy=%.4f\n', ...
    max(sig_gauss_energy.Data), norm(sig_gauss_energy.Data));
fprintf('  Unit peak:   max=%.4f, energy=%.4f\n', ...
    max(sig_gauss_peak.Data), norm(sig_gauss_peak.Data));

figure('Name', 'Gaussian Signals on Lambda', 'Position', [100 150 1200 400]);

subplot(1,3,1);
plot(B.Lambda.axis, sig_gauss_none.Data, 'b-', 'LineWidth', 2);
grid on; xlabel('\lambda'); ylabel('Amplitude');
title('No Normalization');

subplot(1,3,2);
plot(B.Lambda.axis, sig_gauss_energy.Data, 'r-', 'LineWidth', 2);
grid on; xlabel('\lambda'); ylabel('Amplitude');
title('Unit Energy');

subplot(1,3,3);
plot(B.Lambda.axis, sig_gauss_peak.Data, 'g-', 'LineWidth', 2);
grid on; xlabel('\lambda'); ylabel('Amplitude');
title('Unit Peak');

%% Example 3: Dynamic Mask Updates

fprintf('\n=== Example 3: Dynamic Mask Updates ===\n');

% Create signal with Gaussian mask
mask_dynamic = bct.filters.Filter(B.Time, 'gaussian', ...
    'center', 0.3, 'sigma', 0.05, 'label', 'Dynamic_Gaussian');

sig_dynamic = bct.Signal.fromMask(mask_dynamic, 'normalize', 'energy');

fprintf('  Initial: center=%.2f, sigma=%.3f\n', ...
    mask_dynamic.center, mask_dynamic.sigma);

% Store initial data for comparison
data_initial = sig_dynamic.Data;

% Update mask parameters
mask_dynamic.center = 0.7;  % Move center
mask_dynamic.sigma = 0.02;  % Narrow the width

% Regenerate signal using setMask
sig_dynamic.setMask(mask_dynamic, 'normalize', 'energy', 'update_label', true);

fprintf('  Updated: center=%.2f, sigma=%.3f\n', ...
    mask_dynamic.center, mask_dynamic.sigma);

% Visualize before and after
figure('Name', 'Dynamic Mask Updates', 'Position', [100 200 1000 400]);

subplot(1,2,1);
plot(B.Time.axis, data_initial, 'b-', 'LineWidth', 2);
grid on; xlabel('Time (s)'); ylabel('Amplitude');
title('Initial: center=0.3, \sigma=0.05');
ylim([0 max(data_initial)*1.2]);

subplot(1,2,2);
plot(B.Time.axis, sig_dynamic.Data, 'r-', 'LineWidth', 2);
grid on; xlabel('Time (s)'); ylabel('Amplitude');
title('Updated: center=0.7, \sigma=0.02');
ylim([0 max(sig_dynamic.Data)*1.2]);

%% Example 4: Multiple Kernels Comparison

fprintf('\n=== Example 4: Multiple Kernels on Omega Domain ===\n');

% EEG frequency bands using different kernels
bands = struct(...
    'delta', [1 4], ...
    'theta', [4 8], ...
    'alpha', [8 12], ...
    'beta', [12 30]);

band_names = fieldnames(bands);

figure('Name', 'EEG Bands via Different Kernels', 'Position', [100 250 1400 800]);

for i = 1:length(band_names)
    name = band_names{i};
    freq_range = bands.(name);
    center_freq = mean(freq_range);
    bandwidth = diff(freq_range) / 2;
    
    % Approach 1: Bandpass filter (ideal)
    mask_bp = bct.filters.Filter(B.Omega, 'bandpass', ...
        'low', freq_range(1), 'high', freq_range(2), 'taper', false);
    sig_bp = bct.Signal.fromMask(mask_bp, 'normalize', 'peak');
    
    % Approach 2: Gaussian filter (smooth)
    mask_gauss = bct.filters.Filter(B.Omega, 'gaussian', ...
        'center', center_freq, 'sigma', bandwidth);
    sig_gauss = bct.Signal.fromMask(mask_gauss, 'normalize', 'peak');
    
    % Plot comparison
    subplot(length(band_names), 2, (i-1)*2 + 1);
    plot(B.Omega.axis, sig_bp.Data, 'b-', 'LineWidth', 2);
    grid on; xlabel('Frequency (Hz)'); ylabel('Amplitude');
    title(sprintf('%s Band - Ideal Bandpass [%d-%d Hz]', upper(name), freq_range(1), freq_range(2)));
    xlim([0 40]); ylim([0 1.1]);
    
    subplot(length(band_names), 2, (i-1)*2 + 2);
    plot(B.Omega.axis, sig_gauss.Data, 'r-', 'LineWidth', 2);
    grid on; xlabel('Frequency (Hz)'); ylabel('Amplitude');
    title(sprintf('%s Band - Gaussian (center=%d Hz, \\sigma=%.1f Hz)', ...
        upper(name), center_freq, bandwidth));
    xlim([0 40]); ylim([0 1.1]);
end

%% Example 5: Integration with KernelEditor (Interactive)

fprintf('\n=== Example 5: Integration with KernelEditor ===\n');

% Create Time domain editor
editor_time = bct.ui.TimeWindowEditor(B.Time, ...
    bct.filters.Filter(B.Time, 'gaussian', 'center', 0.5, 'sigma', 0.1), ...
    0.5, 0.1);

% Create signal from editor's filter
sig_interactive = bct.Signal.fromMask(editor_time.Filter, 'normalize', 'energy');

fprintf('  Created signal from TimeWindowEditor\n');
fprintf('  Initial center: %.2f s, width: %.3f s\n', ...
    editor_time.Center, editor_time.Width);

% Simulate user interaction: shift forward
editor_time.shiftForward(2);  % Move forward by 2 steps
fprintf('  After shiftForward(2): center=%.2f s\n', editor_time.Center);

% Regenerate signal with updated filter
sig_interactive.setMask(editor_time.Filter, 'normalize', 'energy');

% Simulate user interaction: expand width
editor_time.expand(1.5);  % Increase width by 50%
fprintf('  After expand(1.5): width=%.3f s\n', editor_time.Width);

% Regenerate again
sig_interactive.setMask(editor_time.Filter, 'normalize', 'energy');

fprintf('  Signal dynamically updated via editor interactions\n');

%% Example 6: Low-pass / High-pass Signal Masks

fprintf('\n=== Example 6: Low-pass and High-pass Masks ===\n');

% Low-pass mask on Lambda
mask_lp = bct.filters.Filter(B.Lambda, 'lowpass', 'cutoff', 30);
sig_lp = bct.Signal.fromMask(mask_lp, 'normalize', 'peak');

% High-pass mask on Lambda
mask_hp = bct.filters.Filter(B.Lambda, 'highpass', 'cutoff', 70);
sig_hp = bct.Signal.fromMask(mask_hp, 'normalize', 'peak');

figure('Name', 'Low-pass and High-pass Masks', 'Position', [100 300 1000 400]);

subplot(1,2,1);
stem(B.Lambda.axis, sig_lp.Data, 'b', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on; xlabel('\lambda'); ylabel('Amplitude');
title('Low-pass Mask (cutoff=30)');

subplot(1,2,2);
stem(B.Lambda.axis, sig_hp.Data, 'r', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on; xlabel('\lambda'); ylabel('Amplitude');
title('High-pass Mask (cutoff=70)');

%% Summary

fprintf('\n=== SUMMARY ===\n');
fprintf('New Signal Generation Workflow:\n');
fprintf('  1. Create Filter (mask) on domain: mask = Filter(domain, kernel, params)\n');
fprintf('  2. Generate signal: sig = Signal.fromMask(mask, ''normalize'', mode)\n');
fprintf('  3. Update mask: mask.param = new_value\n');
fprintf('  4. Regenerate: sig.setMask(mask, ''normalize'', mode)\n');
fprintf('\n');
fprintf('Benefits:\n');
fprintf('  ✓ Unified interface via Filter/Kernel system\n');
fprintf('  ✓ Supports all kernels (delta, gaussian, heat, bandpass, etc.)\n');
fprintf('  ✓ Dynamic updates for interactive applications\n');
fprintf('  ✓ Integration with KernelEditor for GUI control\n');
fprintf('  ✓ Flexible normalization (none, energy, peak)\n');
fprintf('  ✓ Mask reference stored in Signal.Mask property\n');
fprintf('\n');
fprintf('Deprecated:\n');
fprintf('  ✗ Signal.createDelta() - replaced by delta kernel + fromMask()\n');
fprintf('\n✓ Demo complete!\n');
