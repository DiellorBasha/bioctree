%% Example: Creating Signals with Gaussian and Mexican Hat Filters
% Demonstrates how to create manifold signals using different filter types

clear; close all;

%% Load mesh
fprintf('Loading mesh...\n');
B = bct.io.import.mesh('test-data\freesurfer\fsaverage\surf\lh.pial');

%% Example 1: Gaussian Bandpass Filter (Wavenumber-based)
fprintf('\n=== Example 1: Gaussian Bandpass ===\n');

% Create filter object
filt_gaussian = bct.filters.Filter('Manifold');
filt_gaussian.Manifold = B.Manifold;

% Design Gaussian filter centered at k0 with bandwidth sigma_k
k0 = 8;          % Center wavenumber (rad/mm) - medium spatial frequency
sigma_k = 3.5;   % Bandwidth in wavenumber space (rad/mm)

[filt_gaussian.g, params_gauss] = bct.filters.design.manifold.gaussian(...
    B.Manifold, 'k0', k0, 'sigma_k', sigma_k);
filt_gaussian.lambda_band = params_gauss.lambda_band;
filt_gaussian.KernelType = "gaussian";

fprintf('  Center wavenumber: k0 = %.2f rad/mm\n', k0);
fprintf('  Bandwidth: sigma_k = %.2f rad/mm\n', sigma_k);
fprintf('  Wavenumber band: [%.2f, %.2f] rad/mm\n', ...
    params_gauss.k_band(1), params_gauss.k_band(2));
fprintf('  Eigenvalue band: [%.2f, %.2f]\n', ...
    params_gauss.lambda_band(1), params_gauss.lambda_band(2));

% Add filter and synthesize signal
B.addFilter(filt_gaussian);
B.Synthesize(1);  % Synthesize spectral coefficients
sig_gaussian = B.Generate('label', 'gaussian_signal', 'rms', 1.0);

fprintf('  Signal generated: %d vertices\n', length(sig_gaussian.Data));

%% Example 2: Mexican Hat Wavelet Filter
fprintf('\n=== Example 2: Mexican Hat Wavelet ===\n');

% Create filter object
filt_mexh = bct.filters.Filter('Manifold');
filt_mexh.Manifold = B.Manifold;

% Design Mexican hat filter centered at lambda0 with spectral width sx
lambda0 = 600;   % Center eigenvalue
sx = 0.08;       % Spectral width (smaller = narrower bandpass)

filt_mexh.g = bct.filters.design.manifold.mexh(B.Manifold, ...
    'lambda0', lambda0, 'sx', sx);
filt_mexh.KernelType = "mexh";

% Estimate lambda_band for this filter (approximate)
lambda_max = B.Manifold.Resolution.lambda_max;
% Mexican hat has effective support around ±3*sx from lambda0
half_width = 3 * sx * lambda_max;
filt_mexh.lambda_band = [max(0, lambda0 - half_width), lambda0 + half_width];

fprintf('  Center eigenvalue: lambda0 = %.2f\n', lambda0);
fprintf('  Spectral width: sx = %.3f\n', sx);
fprintf('  Estimated lambda_band: [%.2f, %.2f]\n', ...
    filt_mexh.lambda_band(1), filt_mexh.lambda_band(2));

% Add filter and synthesize signal
B.addFilter(filt_mexh);
B.Synthesize(2);  % Synthesize using filter #2
sig_mexh = B.Generate('label', 'mexh_signal', 'rms', 1.0);

fprintf('  Signal generated: %d vertices\n', length(sig_mexh.Data));

%% Visualize both signals
fprintf('\n=== Visualizing Signals ===\n');

figure('Position', [100 100 1400 600]);

% Gaussian signal
subplot(2,3,1);
B.Manifold.plot('data', sig_gaussian.Data, 'shading', 'interp');
colormap(jet); colorbar;
title(sprintf('Gaussian Signal (k_0=%.1f rad/mm)', k0));
axis equal tight off;
view([-90 0]);

subplot(2,3,4);
histogram(sig_gaussian.Data, 50, 'Normalization', 'probability');
xlabel('Signal Amplitude');
ylabel('Probability');
title('Gaussian Signal Distribution');
grid on;

% Mexican hat signal
subplot(2,3,2);
B.Manifold.plot('data', sig_mexh.Data, 'shading', 'interp');
colormap(jet); colorbar;
title(sprintf('Mexican Hat Signal (\\lambda_0=%.0f)', lambda0));
axis equal tight off;
view([-90 0]);

subplot(2,3,5);
histogram(sig_mexh.Data, 50, 'Normalization', 'probability');
xlabel('Signal Amplitude');
ylabel('Probability');
title('Mexican Hat Signal Distribution');
grid on;

%% Compare filter responses
subplot(2,3,[3,6]);
lambda_vec = linspace(0, lambda_max, 1000);
k_vec = sqrt(lambda_vec);

% Evaluate filters
H_gaussian = filt_gaussian.g(lambda_vec);
H_mexh = filt_mexh.g(lambda_vec);

% Plot in wavenumber space
yyaxis left
plot(k_vec, H_gaussian, 'b-', 'LineWidth', 2);
ylabel('Gaussian H(k)', 'Color', 'b');
xlabel('Wavenumber k (rad/mm)');
hold on;
xline(k0, 'b--', 'k_0');
ylim([0 1.1]);

yyaxis right
plot(k_vec, H_mexh, 'r-', 'LineWidth', 2);
ylabel('Mexican Hat H(\lambda)', 'Color', 'r');
ylim([0 1.1]);

grid on;
title('Filter Responses');
legend({'Gaussian (k-space)', '', 'Mexican Hat (\lambda-space)'}, ...
    'Location', 'best');

%% Analyze spectral content
fprintf('\n=== Spectral Analysis ===\n');

% Get spectral coefficients from both signals
coeffs_gaussian = B.SpectralGrid(1).coeffs;
coeffs_mexh = B.SpectralGrid(2).coeffs;

lambda_band_gauss = B.SpectralGrid(1).lambda_band;
lambda_band_mexh = B.SpectralGrid(2).lambda_band;

fprintf('Gaussian filter:\n');
fprintf('  Number of modes: %d\n', length(coeffs_gaussian));
fprintf('  Eigenvalue range: [%.2f, %.2f]\n', ...
    lambda_band_gauss(1), lambda_band_gauss(2));
fprintf('  Coefficient power: %.4f\n', sum(abs(coeffs_gaussian).^2));

fprintf('\nMexican Hat filter:\n');
fprintf('  Number of modes: %d\n', length(coeffs_mexh));
fprintf('  Eigenvalue range: [%.2f, %.2f]\n', ...
    lambda_band_mexh(1), lambda_band_mexh(2));
fprintf('  Coefficient power: %.4f\n', sum(abs(coeffs_mexh).^2));

%% Statistical comparison
fprintf('\n=== Signal Statistics ===\n');

fprintf('Gaussian signal:\n');
fprintf('  Mean: %.4f\n', mean(sig_gaussian.Data));
fprintf('  Std: %.4f\n', std(sig_gaussian.Data));
fprintf('  RMS: %.4f\n', rms(sig_gaussian.Data));
fprintf('  Range: [%.4f, %.4f]\n', ...
    min(sig_gaussian.Data), max(sig_gaussian.Data));

fprintf('\nMexican Hat signal:\n');
fprintf('  Mean: %.4f\n', mean(sig_mexh.Data));
fprintf('  Std: %.4f\n', std(sig_mexh.Data));
fprintf('  RMS: %.4f\n', rms(sig_mexh.Data));
fprintf('  Range: [%.4f, %.4f]\n', ...
    min(sig_mexh.Data), max(sig_mexh.Data));

fprintf('\n=== Example Complete ===\n');
