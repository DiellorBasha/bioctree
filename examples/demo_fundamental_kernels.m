%% Demo: Fundamental Signal Processing Kernels
% 
% This script demonstrates all fundamental kernels in bct.filters.kernels:
%   - Gaussian (smoothing)
%   - Gabor (localized oscillations)
%   - Heat/Diffusion (thermal smoothing)
%   - Laplacian-of-Gaussian (edge detection)
%   - Bandpass (frequency bands)
%   - Low-pass (smoothing)
%   - High-pass (edge enhancement)
%   - Delta/Dirac (impulse responses)
%
% Each kernel is demonstrated on appropriate domains (Lambda, Omega, Time)
% showing their mathematical properties and signal processing applications.

clear; close all;

%% Setup: Create BCT instance with mesh and domains

% Load test mesh (fsaverage right hemisphere)
data = load('data/mesh/fsaverage_rh_pial.mat');

% Initialize BCT from mesh
B = bct.bct.fromMesh(data.V, data.F);

% Compute eigendecomposition
fprintf('Computing eigendecomposition...\n');
B.Lambda = B.Manifold.dual('numModes', 100);
fprintf('  Lambda domain: %d modes\n', B.Lambda.N);

% Create temporal domains
B.Time = bct.Time(0:0.001:1, 1000);  % 1 second, 1000 Hz sampling
B.Omega = B.Time.dual;

fprintf('\nDomains created:\n');
fprintf('  Manifold: %d vertices\n', B.Manifold.N);
fprintf('  Lambda: %d eigenvalues (%.2f to %.2f)\n', ...
  B.Lambda.N, min(B.Lambda.axis), max(B.Lambda.axis));
fprintf('  Time: %d samples (%.3f to %.3f s)\n', ...
  B.Time.N, min(B.Time.axis), max(B.Time.axis));
fprintf('  Omega: %d frequencies (%.2f to %.2f Hz)\n', ...
  B.Omega.N, min(B.Omega.axis), max(B.Omega.axis));

%% 1. GAUSSIAN KERNEL - Smoothing / Localization

fprintf('\n=== 1. GAUSSIAN KERNEL ===\n');

% Create Gaussian filter on Lambda domain
filt_gauss_lambda = bct.filters.Filter(B.Lambda, 'gaussian', ...
  'center', 50, 'sigma', 10, 'label', 'Spatial Gaussian');

% Create Gaussian filter on Omega domain
filt_gauss_omega = bct.filters.Filter(B.Omega, 'gaussian', ...
  'center', 20, 'sigma', 5, 'label', 'Temporal Gaussian');

% Evaluate responses
H_gauss_lambda = filt_gauss_lambda.evaluate();
H_gauss_omega = filt_gauss_omega.evaluate();

figure('Name', 'Gaussian Kernels', 'Position', [100 100 1200 400]);

subplot(1,2,1);
plot(B.Lambda.axis, H_gauss_lambda, 'b-', 'LineWidth', 2);
grid on; xlabel('\lambda (Eigenvalue)'); ylabel('H(\lambda)');
title('Gaussian on Lambda (Spatial Smoothing)');
legend(sprintf('center=%.0f, \\sigma=%.0f', filt_gauss_lambda.center, filt_gauss_lambda.sigma));

subplot(1,2,2);
plot(B.Omega.axis, H_gauss_omega, 'r-', 'LineWidth', 2);
grid on; xlabel('\omega (Hz)'); ylabel('H(\omega)');
title('Gaussian on Omega (Temporal Smoothing)');
legend(sprintf('center=%.0f Hz, \\sigma=%.0f Hz', filt_gauss_omega.center, filt_gauss_omega.sigma));

%% 2. LOW-PASS / HIGH-PASS / BANDPASS - Frequency Selection

fprintf('\n=== 2. IDEAL FILTERS (Low/High/Band-pass) ===\n');

% Low-pass filter on Lambda
filt_lowpass = bct.filters.Filter(B.Lambda, 'lowpass', ...
  'cutoff', 30, 'label', 'Spatial Low-pass');

% High-pass filter on Lambda  
filt_highpass = bct.filters.Filter(B.Lambda, 'highpass', ...
  'cutoff', 70, 'label', 'Spatial High-pass');

% Bandpass filter on Omega (alpha band 8-12 Hz)
filt_bandpass_ideal = bct.filters.Filter(B.Omega, 'bandpass', ...
  'low', 8, 'high', 12, 'taper', false, 'label', 'Alpha (ideal)');

% Bandpass with Hann tapering
filt_bandpass_hann = bct.filters.Filter(B.Omega, 'bandpass', ...
  'low', 8, 'high', 12, 'taper', true, 'label', 'Alpha (Hann)');

% Evaluate
H_lp = filt_lowpass.evaluate();
H_hp = filt_highpass.evaluate();
H_bp_ideal = filt_bandpass_ideal.evaluate();
H_bp_hann = filt_bandpass_hann.evaluate();

figure('Name', 'Ideal Filters', 'Position', [100 150 1200 800]);

subplot(2,2,1);
plot(B.Lambda.axis, H_lp, 'b-', 'LineWidth', 2);
grid on; xlabel('\lambda'); ylabel('H(\lambda)');
title(sprintf('Low-pass (cutoff = %.0f)', filt_lowpass.Parameters.cutoff));
ylim([-0.1 1.1]);

subplot(2,2,2);
plot(B.Lambda.axis, H_hp, 'r-', 'LineWidth', 2);
grid on; xlabel('\lambda'); ylabel('H(\lambda)');
title(sprintf('High-pass (cutoff = %.0f)', filt_highpass.Parameters.cutoff));
ylim([-0.1 1.1]);

subplot(2,2,3);
plot(B.Omega.axis, H_bp_ideal, 'g-', 'LineWidth', 2);
grid on; xlabel('\omega (Hz)'); ylabel('H(\omega)');
title('Bandpass - Ideal (Rectangular)');
xlim([0 30]); ylim([-0.1 1.1]);

subplot(2,2,4);
plot(B.Omega.axis, H_bp_hann, 'm-', 'LineWidth', 2);
grid on; xlabel('\omega (Hz)'); ylabel('H(\omega)');
title('Bandpass - Hann Tapered');
xlim([0 30]); ylim([-0.1 1.1]);

%% 3. LAPLACIAN-OF-GAUSSIAN - Edge Detection

fprintf('\n=== 3. LAPLACIAN-OF-GAUSSIAN (Edge Detection) ===\n');

% Create LoG filters at multiple scales
scales = [5, 10, 20];
colors = {'b', 'r', 'g'};

figure('Name', 'Laplacian-of-Gaussian', 'Position', [100 200 1200 400]);

subplot(1,2,1);
hold on;
for i = 1:length(scales)
  filt_log = bct.filters.Filter(B.Lambda, 'laplacian_gaussian', ...
    'center', 50, 'sigma', scales(i));
  H_log = filt_log.evaluate();
  plot(B.Lambda.axis, H_log, colors{i}, 'LineWidth', 2, ...
    'DisplayName', sprintf('\\sigma = %d', scales(i)));
end
hold off;
grid on; xlabel('\lambda'); ylabel('H(\lambda)');
title('LoG on Lambda (Multi-scale Edge Detection)');
legend('Location', 'best');

% Show zero-crossings (edges)
subplot(1,2,2);
filt_log = bct.filters.Filter(B.Lambda, 'laplacian_gaussian', ...
  'center', 50, 'sigma', 10);
H_log = filt_log.evaluate();
plot(B.Lambda.axis, H_log, 'b-', 'LineWidth', 2);
hold on;
plot(B.Lambda.axis, zeros(size(B.Lambda.axis)), 'k--', 'LineWidth', 1);
% Find and mark zero crossings
zero_crossings = find(diff(sign(H_log)) ~= 0);
if ~isempty(zero_crossings)
  plot(B.Lambda.axis(zero_crossings), zeros(size(zero_crossings)), ...
    'ro', 'MarkerSize', 10, 'LineWidth', 2);
end
hold off;
grid on; xlabel('\lambda'); ylabel('H(\lambda)');
title('LoG Zero-Crossings (Edge Locations)');
legend('LoG kernel', 'Zero line', 'Edges', 'Location', 'best');

%% 4. DELTA (Kronecker Delta) - Impulse Responses

fprintf('\n=== 4. DELTA KERNEL (Impulse Responses) ===\n');

% Discrete domain: vertex impulse
vertex_idx = 1:1000;
filt_delta_vertex = bct.filters.Filter(bct.Manifold([], []), 'delta', ...
  'x0', 500, 'label', 'Vertex Impulse');
% Note: For discrete domains, delta kernel works on indices directly

% Continuous domain: eigenvalue impulse
filt_delta_lambda = bct.filters.Filter(B.Lambda, 'delta', ...
  'x0', 50, 'tol', 2, 'label', 'Lambda Impulse');  % tol=2 to capture nearby modes

% Temporal impulse
filt_delta_time = bct.filters.Filter(B.Time, 'delta', ...
  'x0', 0.5, 'tol', 0.001, 'label', 'Time Impulse');

% Evaluate
H_delta_vertex = filt_delta_vertex.KernelFunction(vertex_idx, 500);
H_delta_lambda = filt_delta_lambda.evaluate();
H_delta_time = filt_delta_time.evaluate();

figure('Name', 'Delta (Impulse) Kernels', 'Position', [100 250 1200 800]);

subplot(3,1,1);
stem(vertex_idx, H_delta_vertex, 'b', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on; xlabel('Vertex Index'); ylabel('\delta(i - i_0)');
title('Discrete Delta: Vertex Impulse at i=500');
xlim([400 600]);

subplot(3,1,2);
stem(B.Lambda.axis, H_delta_lambda, 'r', 'LineWidth', 1.5, 'MarkerSize', 6);
grid on; xlabel('\lambda'); ylabel('\delta(\lambda - \lambda_0)');
title('Continuous Delta: Eigenvalue Impulse at \lambda=50');
xlim([30 70]);

subplot(3,1,3);
stem(B.Time.axis, H_delta_time, 'g', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on; xlabel('Time (s)'); ylabel('\delta(t - t_0)');
title('Temporal Delta: Impulse at t=0.5s');
xlim([0.4 0.6]);

%% 5. HEAT KERNEL - Diffusion Smoothing

fprintf('\n=== 5. HEAT KERNEL (Diffusion) ===\n');

% Heat kernels at different diffusion times
tau_values = [0.01, 0.05, 0.1];

figure('Name', 'Heat Kernel', 'Position', [100 300 800 400]);
hold on;
for i = 1:length(tau_values)
  filt_heat = bct.filters.Filter(B.Lambda, 'heat', ...
    'tau', tau_values(i), 'label', sprintf('Heat tau=%.2f', tau_values(i)));
  H_heat = filt_heat.evaluate();
  plot(B.Lambda.axis, H_heat, colors{i}, 'LineWidth', 2, ...
    'DisplayName', sprintf('\\tau = %.2f', tau_values(i)));
end
hold off;
grid on; xlabel('\lambda'); ylabel('H(\lambda) = e^{-\tau\lambda}');
title('Heat Kernel: Diffusion at Multiple Time Scales');
legend('Location', 'best');

%% 6. GABOR KERNEL - Localized Oscillations (Joint Domain)

fprintf('\n=== 6. GABOR KERNEL (Spatiotemporal) ===\n');

% Create joint domain
joint_LO = B.createJoint('Lambda', 'Omega');

% Gabor filter on Lambda-Omega
filt_gabor = bct.filters.Filter(joint_LO, 'gabor', ...
  'center_x', 50, 'center_y', 15, ...
  'sigma_x', 10, 'sigma_y', 3, ...
  'label', 'Spatiotemporal Gabor');

H_gabor = filt_gabor.evaluate();

figure('Name', 'Gabor Kernel (Joint Domain)', 'Position', [100 350 1000 400]);

subplot(1,2,1);
imagesc(B.Omega.axis, B.Lambda.axis, H_gabor);
axis xy; colorbar;
xlabel('\omega (Hz)'); ylabel('\lambda');
title('Gabor on Lambda-Omega');
clim([0 1]);

subplot(1,2,2);
contour(B.Omega.axis, B.Lambda.axis, H_gabor, 10, 'LineWidth', 1.5);
axis xy; grid on;
xlabel('\omega (Hz)'); ylabel('\lambda');
title('Gabor Contours (Localized Wave Packet)');

%% Summary Table

fprintf('\n=== SUMMARY: Fundamental Kernels ===\n');
fprintf('%-25s %-15s %-40s\n', 'Kernel', 'Domain', 'Application');
fprintf('%s\n', repmat('-', 1, 80));
fprintf('%-25s %-15s %-40s\n', 'gaussian', 'Any', 'Smoothing, localization');
fprintf('%-25s %-15s %-40s\n', 'lowpass', 'Lambda/Omega', 'Smoothing, low-freq retention');
fprintf('%-25s %-15s %-40s\n', 'highpass', 'Lambda/Omega', 'Edge enhancement, high-freq');
fprintf('%-25s %-15s %-40s\n', 'bandpass', 'Lambda/Omega', 'Frequency band selection');
fprintf('%-25s %-15s %-40s\n', 'laplacian_gaussian', 'Lambda/Omega', 'Edge/feature detection');
fprintf('%-25s %-15s %-40s\n', 'heat', 'Lambda', 'Diffusion smoothing');
fprintf('%-25s %-15s %-40s\n', 'delta', 'Any', 'Impulse response, testing');
fprintf('%-25s %-15s %-40s\n', 'gabor', 'Joint', 'Localized oscillations');
fprintf('%-25s %-15s %-40s\n', 'velocity_gabor', 'Lambda-Omega', 'Traveling waves');

fprintf('\n✓ All fundamental kernels demonstrated successfully!\n');
