%DEMO_JOINTSPECTRUM  Demonstrates joint spectrum visualization
%
% Shows:
%   1. Joint transform with fftshift (zero frequency centered)
%   2. Multiple visualization options (power, logpower, magnitude, phase)
%   3. Different frequency units (Hz, index, normalized)
%   4. Different spatial units (eigenvalue, wavenumber, wavelength)
%   5. Frequency range filtering

clearvars; clc;
bioctree_start;

%% Setup
fprintf('=== Joint Spectrum Visualization Demo ===\n\n');

% Load mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

% Create Time domain
T = 100;
fs = 100;  % 100 Hz sampling rate
B.Time = bct.Time(T, 'SampleRate', fs);

fprintf('Mesh: %d vertices\n', B.Manifold.N);
fprintf('Time: %d samples at %.1f Hz\n', B.Time.N, fs);
fprintf('Lambda modes: %d\n', length(B.Manifold.dual.lambda));

%% Create spatiotemporal signal with known frequency
fprintf('\nGenerating spatiotemporal signal with 10 Hz oscillation...\n');

% Create a spectral brush that oscillates at 10 Hz
% Use a single spatial mode (mode 50) with 10 Hz temporal oscillation
sig_st = bct.Signal.fromBrush(B.Manifold, 'Category', 'time', ...
    'Type', 'spectral', 'Time', B.Time, ...
    'Source', @(t, T) 50 * ones(size(t)), ...  % Fixed spatial mode
    'Kernel', 'heat', 'Tau', 0.05);

% Modulate with 10 Hz sine wave
t_axis = (0:T-1) / fs;
modulation = sin(2*pi*10*t_axis);  % 10 Hz
sig_st.Data = sig_st.Data .* modulation;

fprintf('Signal created with 10 Hz temporal modulation\n');

%% Apply joint transform
fprintf('\nApplying joint transform...\n');

sig_spectral = bct.operator.transform.joint(sig_st);

fprintf('Transform complete. Frequency axis is fftshifted (zero centered).\n');

%% Visualization 1: Different plot types
fprintf('\n=== Visualization 1: Different Plot Types ===\n');

figure('Name', 'Joint Spectrum - Plot Types', 'Position', [100 100 1200 800]);

subplot(2, 3, 1);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'power');
title('Power Spectrum');

subplot(2, 3, 2);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'logpower');
title('Log Power Spectrum');

subplot(2, 3, 3);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'magnitude');
title('Magnitude');

subplot(2, 3, 4);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'phase');
title('Phase');

subplot(2, 3, 5);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'real');
title('Real Part');

subplot(2, 3, 6);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'imag');
title('Imaginary Part');

sgtitle('Joint Spectrum: Different Representations');

%% Visualization 2: Different frequency units
fprintf('\n=== Visualization 2: Different Frequency Units ===\n');

figure('Name', 'Joint Spectrum - Frequency Units', 'Position', [150 150 1200 400]);

subplot(1, 3, 1);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'logpower', ...
    'FrequencyUnits', 'Hz');
title('Frequency in Hz (Default)');

subplot(1, 3, 2);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'logpower', ...
    'FrequencyUnits', 'index');
title('Frequency Index');

subplot(1, 3, 3);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'logpower', ...
    'FrequencyUnits', 'norm');
title('Normalized Frequency');

sgtitle('Joint Spectrum: Frequency Axis Options');

%% Visualization 3: Different spatial units
fprintf('\n=== Visualization 3: Different Spatial Units ===\n');

figure('Name', 'Joint Spectrum - Spatial Units', 'Position', [200 200 1200 800]);

subplot(2, 3, 1);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'logpower', ...
    'SpatialUnits', 'eigenvalue');
title('Eigenvalue \lambda');

subplot(2, 3, 2);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'logpower', ...
    'SpatialUnits', 'wavenumber');
title('Wavenumber k = \surd\lambda');

subplot(2, 3, 3);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'logpower', ...
    'SpatialUnits', 'wavelength');
title('Wavelength 2\pi/\surd\lambda');

subplot(2, 3, 4);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'logpower', ...
    'SpatialUnits', 'halfwavelength');
title('Half Wavelength \pi/\surd\lambda');

subplot(2, 3, 5);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'logpower', ...
    'SpatialUnits', 'index');
title('Eigenmode Index');

% Add marginal plots
subplot(2, 3, 6);
P_spectral = abs(sig_spectral.Data).^2;
P_temporal = sum(P_spectral, 1);
% Get frequency axis (fftshifted)
Nt = size(P_spectral, 2);
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
title('Temporal Marginal');
xlim([min(freq_axis), max(freq_axis)]);
% Mark 10 Hz
hold on;
xline(10, 'g--', '10 Hz', 'LineWidth', 2);
xline(-10, 'g--', '-10 Hz', 'LineWidth', 2);

sgtitle('Joint Spectrum: Spatial Axis Options');

%% Visualization 4: Frequency range filtering
fprintf('\n=== Visualization 4: Frequency Range Filtering ===\n');

figure('Name', 'Joint Spectrum - Frequency Ranges', 'Position', [250 250 1200 400]);

subplot(1, 3, 1);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'power', ...
    'FrequencyRange', [-50 50]);
title('Full Range: [-50, 50] Hz');

subplot(1, 3, 2);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'power', ...
    'FrequencyRange', [-20 20]);
title('Zoomed: [-20, 20] Hz');

subplot(1, 3, 3);
bct.show.jointspectrum(sig_spectral, 'PlotType', 'power', ...
    'FrequencyRange', [0 25]);
title('Positive Only: [0, 25] Hz');

sgtitle('Joint Spectrum: Frequency Range Options');

%% Verify 10 Hz peak
fprintf('\n=== Verification: Finding 10 Hz Peak ===\n');

P_spectral = abs(sig_spectral.Data).^2;
P_temporal = sum(P_spectral, 1);

% Find peak frequency
[peak_power, peak_idx] = max(P_temporal);
peak_freq = freq_axis(peak_idx);

fprintf('Peak frequency: %.2f Hz (expected: ±10 Hz)\n', abs(peak_freq));
fprintf('Peak power: %.2e\n', peak_power);

% Check if there's also a peak at -10 Hz (there should be)
[~, neg_10Hz_idx] = min(abs(freq_axis + 10));
[~, pos_10Hz_idx] = min(abs(freq_axis - 10));

fprintf('Power at -10 Hz: %.2e\n', P_temporal(neg_10Hz_idx));
fprintf('Power at +10 Hz: %.2e\n', P_temporal(pos_10Hz_idx));

%% Spatial distribution at 10 Hz
fprintf('\n=== Spatial Distribution at 10 Hz ===\n');

figure('Name', 'Spatial Distribution at 10 Hz');

% Extract column corresponding to +10 Hz
power_at_10Hz = P_spectral(:, pos_10Hz_idx);
lambda = sig_spectral.Domain.A.lambda;

subplot(1, 2, 1);
semilogy(lambda, power_at_10Hz, 'b-', 'LineWidth', 2);
grid on;
xlabel('Eigenvalue \lambda');
ylabel('Power');
title('Spatial Power Distribution at +10 Hz');
xlim([0 max(lambda)]);

subplot(1, 2, 2);
plot(1:length(lambda), power_at_10Hz, 'b-', 'LineWidth', 2);
grid on;
xlabel('Eigenmode Index');
ylabel('Power');
title('Spatial Power Distribution at +10 Hz');

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('Joint spectrum visualization features:\n');
fprintf('  • Plot types: power, logpower, magnitude, phase, real, imag\n');
fprintf('  • Frequency units: Hz (default), index, normalized\n');
fprintf('  • Spatial units: eigenvalue, wavenumber, wavelength, halfwavelength, index\n');
fprintf('  • Frequency range filtering available\n');
fprintf('  • Zero frequency centered (fftshift applied)\n');
fprintf('  • Negative frequencies on left, positive on right\n');

fprintf('\nDemo complete!\n');
