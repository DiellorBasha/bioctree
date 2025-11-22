%% Example: Wavenumber-based Manifold Filters
% Demonstrates proper use of physical wavenumber k = sqrt(lambda)
% for stable, smooth spatial filtering

clear; close all;

%% Load mesh
B = bct.io.import.mesh('test-data\freesurfer\fsaverage\surf\lh.pial');

%% Example 1: Gaussian filter using WAVENUMBER
fprintf('=== Example 1: Gaussian in Wavenumber Space ===\n');

filt1 = bct.filters.Filter('Manifold');
filt1.Manifold = B.Manifold;

% Design using PHYSICAL WAVENUMBER (rad/mm)
k0 = 7;          % Center wavenumber (rad/mm)
sigma_k = 4.5;   % Bandwidth in wavenumber (rad/mm)

[filt1.g, params1] = bct.filters.design.manifold.gaussian(B.Manifold, ...
    'k0', k0, 'sigma_k', sigma_k);
filt1.lambda_band = params1.lambda_band;
filt1.KernelType = "gaussian_k";

fprintf('  k0 = %.2f rad/mm (λ₀ = %.2f)\n', k0, params1.lambda0);
fprintf('  sigma_k = %.2f rad/mm\n', sigma_k);
fprintf('  k_band = [%.2f, %.2f] rad/mm\n', params1.k_band(1), params1.k_band(2));
fprintf('  lambda_band = [%.2f, %.2f]\n\n', params1.lambda_band(1), params1.lambda_band(2));

B.addFilter(filt1);
B.Synthesize(1);
sig1 = B.Generate('label', 'gaussian_wavenumber');

%% Example 2: Heat filter (lowpass in wavenumber)
fprintf('=== Example 2: Heat Diffusion (Lowpass) ===\n');

filt2 = bct.filters.Filter('Manifold');
filt2.Manifold = B.Manifold;

tau = 0.1;  % Diffusion time
[filt2.g, params2] = bct.filters.design.manifold.heat(B.Manifold, 'tau', tau);
filt2.lambda_band = params2.lambda_band;
filt2.KernelType = "heat";

fprintf('  tau = %.2f\n', tau);
fprintf('  k_max = %.2f rad/mm\n', params2.k_max);
fprintf('  k_band = [%.2f, %.2f] rad/mm\n', params2.k_band(1), params2.k_band(2));
fprintf('  lambda_band = [%.2f, %.2f]\n\n', params2.lambda_band(1), params2.lambda_band(2));

B.addFilter(filt2);
B.Synthesize(2);
sig2 = B.Generate('label', 'heat_lowpass');

%% Example 3: OLD STYLE (deprecated, for comparison)
fprintf('=== Example 3: OLD lambda-based (deprecated) ===\n');

filt3 = bct.filters.Filter('Manifold');
filt3.Manifold = B.Manifold;

% Using deprecated lambda0/sigma parameters (will show warnings)
[filt3.g, params3] = bct.filters.design.manifold.gaussian(B.Manifold, ...
    'lambda0', 50, 'sigma', 20);
filt3.lambda_band = params3.lambda_band;
filt3.KernelType = "gaussian_lambda_old";

fprintf('  This uses deprecated parameters!\n');
fprintf('  Better to use k0=%.2f, sigma_k=%.2f instead\n\n', params3.k0, params3.sigma_k);

B.addFilter(filt3);
B.Synthesize(3);
sig3 = B.Generate('label', 'gaussian_lambda_deprecated');

%% Visualize all three
figure('Position', [100 100 1400 400]);

subplot(1,3,1);
trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
    sig1.Data, 'EdgeColor', 'none');
axis equal; axis off; view(-90, 0);
colorbar;
title(sprintf('Gaussian (k₀=%.1f rad/mm)', k0));

subplot(1,3,2);
trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
    sig2.Data, 'EdgeColor', 'none');
axis equal; axis off; view(-90, 0);
colorbar;
title(sprintf('Heat Lowpass (τ=%.2f)', tau));

subplot(1,3,3);
trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
    sig3.Data, 'EdgeColor', 'none');
axis equal; axis off; view(-90, 0);
colorbar;
title('Old λ-based (deprecated)');

%% Compare filter responses
figure('Position', [100 100 800 600]);

% Create test wavenumber and lambda vectors
k_test = linspace(0, params1.k_max, 500);
lambda_test = k_test.^2;

% Evaluate filters
H1 = filt1.getResponse(lambda_test);
H2 = filt2.getResponse(lambda_test);
H3 = filt3.getResponse(lambda_test);

subplot(2,1,1);
plot(k_test, abs(H1), 'b-', 'LineWidth', 2); hold on;
plot(k_test, abs(H2), 'r-', 'LineWidth', 2);
plot(k_test, abs(H3), 'g--', 'LineWidth', 2);
xlabel('Wavenumber k (rad/mm)');
ylabel('|H(k)|');
title('Filter Response in WAVENUMBER Space (Physical)');
legend('Gaussian', 'Heat', 'Old λ-based', 'Location', 'best');
grid on;

subplot(2,1,2);
plot(lambda_test, abs(H1), 'b-', 'LineWidth', 2); hold on;
plot(lambda_test, abs(H2), 'r-', 'LineWidth', 2);
plot(lambda_test, abs(H3), 'g--', 'LineWidth', 2);
xlabel('Eigenvalue λ');
ylabel('|H(λ)|');
title('Filter Response in EIGENVALUE Space');
legend('Gaussian (k-based)', 'Heat', 'Old λ-based', 'Location', 'best');
grid on;

fprintf('\n✓ All filters generated successfully!\n');
fprintf('Note: Wavenumber-based filters produce smoother, more stable signals.\n');

