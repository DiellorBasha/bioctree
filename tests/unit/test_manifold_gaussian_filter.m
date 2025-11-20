%% Test Manifold Gaussian Filter with Bct Class
% This script tests the complete workflow:
% 1. Load mesh
% 2. Design Gaussian manifold filter using bct.filters.design.manifold.gaussian
% 3. Synthesize spectral coefficients using Bct.Synthesize
% 4. Generate signal using Bct.Generate (inverse from spectral domain)

clear; close all;

%% 1. Load test mesh
fprintf('=== Loading Mesh ===\n');
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';

if ~exist(path, 'file')
    error('Test mesh not found: %s', path);
end

B = bct.io.import.mesh(path);
fprintf('Mesh loaded: %d vertices, %d faces\n', B.Manifold.N, size(B.Manifold.F, 1));

%% 2. Compute eigendecomposition
fprintf('\n=== Computing Eigendecomposition ===\n');

% Resolution is automatically created with lambda_max when mesh is loaded
% Just compute eigenmodes using meshFourier
numEigs = 200;
B.Manifold.meshFourier(numEigs);
fprintf('Computed %d eigenmodes\n', numEigs);
fprintf('Lambda range: [%.4f, %.4f]\n', ...
    B.Manifold.Eigenvalues(1), B.Manifold.Eigenvalues(end));

%% 3. Design Gaussian manifold filter
fprintf('\n=== Designing Gaussian Manifold Filter ===\n');

% Create Manifold filter
filt = bct.filters.Filter('Manifold');
filt.Manifold = B.Manifold;

% Design Gaussian filter centered at lambda0 with bandwidth sigma
lambda0 = 50;  % Center eigenvalue
sigma_lambda = 20;  % Bandwidth

% Get filter function from design package
filt.g = bct.filters.design.manifold.gaussian(B.Manifold, ...
    'lambda0', lambda0, ...
    'sigma', sigma_lambda);

% Set filter band (3-sigma rule for support)
filt.lambda_band = [max(0, lambda0 - 3*sigma_lambda), lambda0 + 3*sigma_lambda];
filt.KernelType = "gaussian";
filt.KernelParams.lambda0 = lambda0;
filt.KernelParams.sigma = sigma_lambda;
filt.KernelParams.label = "gaussian_test";

fprintf('Gaussian filter designed:\n');
fprintf('  Center: lambda0 = %.2f\n', lambda0);
fprintf('  Bandwidth: sigma = %.2f\n', sigma_lambda);
fprintf('  Support band: [%.2f, %.2f]\n', filt.lambda_band(1), filt.lambda_band(2));

% Plot filter response
figure('Name', 'Gaussian Filter Response');
filt.plotResponse();
title(sprintf('Gaussian Manifold Filter (λ₀=%.1f, σ=%.1f)', lambda0, sigma_lambda));

%% 4. Add filter to Bct Filterbank
fprintf('\n=== Adding Filter to Filterbank ===\n');
B.addFilter(filt);
B.listFilters();

%% 5. Synthesize spectral coefficients
fprintf('\n=== Synthesizing Spectral Coefficients ===\n');

% Determine number of modes in filter band
modes_in_band = sum(B.Manifold.Eigenvalues >= filt.lambda_band(1) & ...
                    B.Manifold.Eigenvalues <= filt.lambda_band(2));
fprintf('Modes in filter band: %d\n', modes_in_band);

% Synthesize using Bct.Synthesize
B.Synthesize(1);  % Use first (and only) filter in filterbank

% Check synthesized coefficients
fprintf('\n=== Spectral Coefficients ===\n');
fprintf('Coefficient matrix size: %s\n', mat2str(size(B.SpectralGrid.coeffs)));
fprintf('Number of spatial modes (K): %d\n', size(B.SpectralGrid.coeffs, 1));
fprintf('Lambda values used: %d eigenvalues\n', length(B.SpectralGrid.lambda_band));
fprintf('Coefficient power: %.4e\n', sum(abs(B.SpectralGrid.coeffs(:)).^2));

%% 6. Generate signal by inverse transform from spectral domain
fprintf('\n=== Generating Signal from Spectral Coefficients ===\n');

sig = B.Generate('label', 'gaussian_filtered_signal', 'add', true);

fprintf('\n=== Signal Properties ===\n');
fprintf('Signal class: %s\n', class(sig));
fprintf('Signal label: %s\n', sig.Label);
fprintf('Data size: %s\n', mat2str(size(sig.Data)));
fprintf('Data range: [%.4f, %.4f]\n', min(sig.Data(:)), max(sig.Data(:)));
fprintf('Data RMS: %.4f\n', sqrt(mean(sig.Data(:).^2)));

%% 7. Visualize the generated signal on the mesh
fprintf('\n=== Visualizing Signal ===\n');

figure('Name', 'Generated Signal on Mesh', 'Position', [100 100 1200 500]);

% Plot 1: Signal on mesh
subplot(1, 2, 1);
trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
    sig.Data, 'EdgeColor', 'none', 'FaceColor', 'interp');
axis equal; axis off;
view(-90, 0);  % Lateral view
colorbar;
title(sprintf('Generated Signal (λ₀=%.1f, σ=%.1f)', lambda0, sigma_lambda));
colormap('jet');
lighting gouraud;
camlight('headlight');

% Plot 2: Signal histogram
subplot(1, 2, 2);
histogram(sig.Data, 50, 'Normalization', 'pdf', 'FaceColor', [0.3 0.5 0.8]);
hold on;
% Overlay Gaussian fit
[mu, sigma] = normfit(sig.Data);
x_range = linspace(min(sig.Data), max(sig.Data), 100);
y_gaussian = normpdf(x_range, mu, sigma);
plot(x_range, y_gaussian, 'r-', 'LineWidth', 2);
hold off;
xlabel('Signal Amplitude');
ylabel('Probability Density');
title('Signal Distribution');
legend('Data', sprintf('Gaussian fit (μ=%.2e, σ=%.2f)', mu, sigma));
grid on;

%% 8. Analyze spectral content
fprintf('\n=== Spectral Analysis ===\n');

% Get the modes used
lambda_used = B.SpectralGrid.lambda_band;
coeffs = B.SpectralGrid.coeffs;

% Compute power per mode
power_per_mode = abs(coeffs).^2;

figure('Name', 'Spectral Analysis');

% Plot 1: Power spectrum
subplot(2, 1, 1);
stem(lambda_used, power_per_mode, 'b.', 'MarkerSize', 10);
hold on;
% Overlay theoretical Gaussian filter
lambda_theory = linspace(0, max(lambda_used)*1.2, 500);
H_theory = exp(-0.5 * ((lambda_theory - lambda0) / sigma_lambda).^2);
plot(lambda_theory, max(power_per_mode) * H_theory, 'r-', 'LineWidth', 2);
hold off;
xlabel('Eigenvalue λ');
ylabel('Power |A_k|^2');
title('Power Spectrum in Eigenvalue Domain');
legend('Synthesized', 'Theoretical Filter');
grid on;
xlim([0, max(lambda_used)*1.1]);

% Plot 2: Cumulative power
subplot(2, 1, 2);
[lambda_sorted, sort_idx] = sort(lambda_used);
power_sorted = power_per_mode(sort_idx);
cumulative_power = cumsum(power_sorted) / sum(power_sorted);
plot(lambda_sorted, cumulative_power * 100, 'b-', 'LineWidth', 2);
xlabel('Eigenvalue λ');
ylabel('Cumulative Power (%)');
title('Cumulative Power Distribution');
grid on;
xlim([0, max(lambda_used)*1.1]);
ylim([0, 105]);

%% 9. Summary
fprintf('\n=== Test Summary ===\n');
fprintf('✓ Mesh loaded successfully\n');
fprintf('✓ Eigendecomposition computed (%d modes)\n', numEigs);
fprintf('✓ Gaussian manifold filter designed (λ₀=%.1f, σ=%.1f)\n', lambda0, sigma_lambda);
fprintf('✓ Filter added to Filterbank\n');
fprintf('✓ Spectral coefficients synthesized (%d modes)\n', size(coeffs, 1));
fprintf('✓ Signal generated from spectral domain (%d vertices)\n', length(sig.Data));
fprintf('✓ Visualizations created\n');
fprintf('\nTest completed successfully!\n');
