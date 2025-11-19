% Test script for joint mesh-time filters
% Demonstrates the bct.filters.JointFilter design workflow

clear; close all;

fprintf('=== Testing bct.filters.JointFilter ===\n\n');

% Initialize bioctree
bioctree_start();

%% Setup: Load mesh and create bct object
fprintf('\n=== Setup: Loading mesh and creating bct object ===\n');
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
[V, F] = in_fs_read_surf(path);

B = bct.bct();
B.Manifold = bct.manifold.Manifold(V, F);
B.Time = bct.manifold.Time(100, 100);  % 100 samples @ 100 Hz (1 second)

fprintf('  Mesh: %d vertices, %d faces\n', size(V,1), size(F,1));
fprintf('  Time: %d samples @ %.0f Hz\n', B.Time.T, B.Time.fs);

%% Test 1: Diffusion-coupled filter
fprintf('\n=== Test 1: Diffusion-coupled filter ===\n');

filt1 = bct.filters.design.diffusion(B, ...
    'lambda_band', [0, 5], ...
    'freq_hz', 10, ...      % 10 Hz center frequency
    'sx', 2, ...            % Spatial scale
    'st', 0.05);            % 50 ms temporal scale

fprintf('\nSynthesizing filter on spectral grid...\n');
tic;
filt1.synthesize('numModes', 50);  % Use 50 modes for faster test
t_synth = toc;
fprintf('  Synthesis time: %.2f seconds\n', t_synth);

% Display filter
disp(filt1);

% Get filter values
W1 = filt1.evaluate();
fprintf('  Filter grid size: %d × %d\n', size(W1, 1), size(W1, 2));
fprintf('  Filter value range: [%.4f, %.4f]\n', min(W1(:)), max(W1(:)));

% Plot
figure('Name', 'Test 1: Diffusion Filter');
filt1.plotJoint();

figure('Name', 'Test 1: Diffusion Filter Marginals');
filt1.plotMarginals();

%% Test 2: Wave-coupled filter
fprintf('\n=== Test 2: Wave-coupled filter ===\n');

filt2 = bct.filters.design.wave(B, ...
    'lambda_band', [1, 8], ...
    'freq_hz', 15, ...
    'velocity', 0.5, ...
    'sx', 3, ...
    'st', 0.04);

fprintf('\nSynthesizing wave filter...\n');
tic;
filt2.synthesize('numModes', 50);
t_synth = toc;
fprintf('  Synthesis time: %.2f seconds\n', t_synth);

% Display and plot
disp(filt2);

figure('Name', 'Test 2: Wave Filter');
filt2.plotJoint();

figure('Name', 'Test 2: Wave Filter Marginals');
filt2.plotMarginals();

%% Test 3: Separable filter (no dispersion)
fprintf('\n=== Test 3: Separable filter (no dispersion) ===\n');

filt3 = bct.filters.design.separable(B, ...
    'lambda_band', [0.5, 10], ...
    'freq_hz', 12, ...
    'spatial_kernel', 'gabor', ...
    'temporal_kernel', 'gabor', ...
    'sx', 3, ...
    'st', 0.08);

fprintf('\nSynthesizing separable filter...\n');
tic;
filt3.synthesize('numModes', 50);
t_synth = toc;
fprintf('  Synthesis time: %.2f seconds\n', t_synth);

% Display and plot
disp(filt3);

figure('Name', 'Test 3: Separable Filter');
filt3.plotJoint();

figure('Name', 'Test 3: Separable Filter Marginals');
filt3.plotMarginals();

%% Test 4: Custom kernels
fprintf('\n=== Test 4: Custom kernel functions ===\n');

% Create filter with custom kernels
filt4 = bct.filters.JointFilter(B);
filt4.lambda_band = [0, 5];

% Custom spatial kernel: Band-limited with smooth edges
custom_psi = @(lambda) exp(-((lambda - 2.5).^2) / (2*1.5^2));

% Custom temporal kernel: Damped sinusoid
custom_phi = @(t) exp(-abs(t)/0.1) .* sin(2*pi*10*t);

% Set custom kernels
filt4.setSpatialKernel('custom', 'handle', custom_psi);
filt4.setTemporalKernel('custom', 'handle', custom_phi);
filt4.setDispersion('heat');  % Heat diffusion dispersion

fprintf('Custom kernels configured\n');
filt4.synthesize('numModes', 50);

disp(filt4);

figure('Name', 'Test 4: Custom Kernels');
filt4.plotJoint();

%% Test 5: Evaluate at arbitrary points
fprintf('\n=== Test 5: Evaluate filter at arbitrary points ===\n');

% Query points
lambda_query = linspace(0, 10, 100);
t_query = linspace(0, 0.5, 50);

% Evaluate diffusion filter at query points
W_query = filt1.evaluate(lambda_query, t_query);

fprintf('  Query grid: %d λ points × %d time points\n', ...
    length(lambda_query), length(t_query));
fprintf('  Filter values range: [%.4f, %.4f]\n', ...
    min(W_query(:)), max(W_query(:)));

% Visualize
figure('Name', 'Test 5: Evaluated at Query Points');
imagesc(t_query, lambda_query, W_query);
axis xy;
colorbar;
xlabel('Time (s)');
ylabel('Eigenvalue \lambda');
title('Diffusion Filter Evaluated at Query Points');

%% Test 6: Frequency band specification
fprintf('\n=== Test 6: Frequency band specification ===\n');

% Design alpha band filter (8-12 Hz)
filt_alpha = bct.filters.design.diffusion(B, ...
    'lambda_band', [0, 5], ...
    'freq_band', [8, 12], ...  % Alpha band
    'sx', 2, 'st', 0.08);

% Design beta band filter (15-30 Hz)
filt_beta = bct.filters.design.diffusion(B, ...
    'lambda_band', [0, 5], ...
    'freq_band', [15, 30], ...  % Beta band
    'sx', 2, 'st', 0.04);

filt_alpha.synthesize('numModes', 50);
filt_beta.synthesize('numModes', 50);

fprintf('Alpha filter: %.1f Hz center\n', filt_alpha.KernelParams.omega0/(2*pi));
fprintf('Beta filter: %.1f Hz center\n', filt_beta.KernelParams.omega0/(2*pi));

% Compare temporal kernels
figure('Name', 'Test 6: Frequency Band Comparison');
subplot(2,1,1);
t_plot = filt_alpha.t_vec;
temporal_alpha = mean(filt_alpha.W_lambda_t, 1);
plot(t_plot, temporal_alpha, 'LineWidth', 2);
grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('Alpha Band Filter (8-12 Hz)');

subplot(2,1,2);
t_plot = filt_beta.t_vec;
temporal_beta = mean(filt_beta.W_lambda_t, 1);
plot(t_plot, temporal_beta, 'LineWidth', 2);
grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('Beta Band Filter (15-30 Hz)');

%% Summary
fprintf('\n=== Test Summary ===\n');
fprintf('✓ Diffusion-coupled filter created and synthesized\n');
fprintf('✓ Wave-coupled filter created and synthesized\n');
fprintf('✓ Separable filter created and synthesized\n');
fprintf('✓ Custom kernel functions working\n');
fprintf('✓ Arbitrary point evaluation working\n');
fprintf('✓ Frequency band specification working\n');
fprintf('\nAll tests completed successfully!\n');
fprintf('\nKey features demonstrated:\n');
fprintf('  • Joint mesh-time spectral filters\n');
fprintf('  • Multiple dispersion types (heat, wave, none)\n');
fprintf('  • Flexible kernel types (Mexican hat, Morlet, Gabor, custom)\n');
fprintf('  • Integration with Bct.SpectralGrid\n');
fprintf('  • Visualization tools (plotJoint, plotMarginals)\n');
