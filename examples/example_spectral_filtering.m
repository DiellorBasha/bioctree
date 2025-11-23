%% Example: Spatial Filtering with Graph Spectral Transform
% This example demonstrates:
% 1. Create a delta (impulse) signal at a vertex on the Manifold
% 2. Transform to spectral domain (Lambda) using graph Fourier transform
% 3. Apply a Gaussian spectral filter in Lambda domain
% 4. Inverse transform back to Manifold to get localized filtered signal
%
% This is a fundamental operation in graph signal processing for spatial
% filtering and feature extraction on brain surfaces.

clear; clc;

%% Step 1: Load cortical surface mesh
fprintf('Step 1: Load cortical surface mesh\n');
fprintf('-----------------------------------\n');

% Import FreeSurfer surface
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);

fprintf('  Mesh loaded: %s\n', path);
fprintf('  Manifold: N = %d vertices\n', B.Manifold.N);
fprintf('  Lambda: N = %d spectral modes\n', B.Lambda.N);
fprintf('  Manifold transform: %s\n', class(B.Manifold.transform));

%% Step 2: Create delta signal at a vertex
fprintf('\nStep 2: Create delta (impulse) signal\n');
fprintf('--------------------------------------\n');

% Choose a vertex (e.g., near the middle of the mesh)
v0 = round(B.Manifold.N / 2);
fprintf('  Creating delta at vertex %d\n', v0);

% Create delta signal on Manifold
delta = bct.Signal.createDelta(B.Manifold, v0);

fprintf('  Signal label: %s\n', delta.Label);
fprintf('  Signal domain: %s\n', class(delta.Domain));
fprintf('  Signal dimensions: [%d × 1]\n', length(delta.Data));
fprintf('  Signal energy: %.6f (should be 1)\n', norm(delta.Data));

% Verify delta properties
assert(delta.Data(v0) == 1, 'Delta should be 1 at vertex v0');
assert(sum(delta.Data) == 1, 'Delta should have unit sum');

%% Step 3: Transform to spectral domain (Lambda)
fprintf('\nStep 3: Transform delta to spectral domain\n');
fprintf('-------------------------------------------\n');

% Apply forward transform: Manifold → Lambda
delta_spectral = B.Manifold.transform.forward(delta.Data);

fprintf('  Spectral coefficients dimensions: [%d × 1]\n', length(delta_spectral));
fprintf('  Spectral energy: %.6f\n', norm(delta_spectral));

% Energy should be preserved (Parseval's theorem)
energy_ratio = norm(delta_spectral) / norm(delta.Data);
fprintf('  Energy preservation ratio: %.6f (should be ≈1)\n', energy_ratio);

% Show spectral content
fprintf('  First 10 spectral coefficients:\n');
for k = 1:min(10, length(delta_spectral))
    fprintf('    Mode %d: %.6f\n', k, delta_spectral(k));
end

%% Step 4: Create Gaussian spectral filter
fprintf('\nStep 4: Create Gaussian spectral filter\n');
fprintf('----------------------------------------\n');

% Gaussian filter parameters
k0 = 50;      % Center mode (controls spatial frequency)
sigma = 20;   % Bandwidth (controls spatial scale)

fprintf('  Filter type: Gaussian\n');
fprintf('  Center mode k0 = %d\n', k0);
fprintf('  Bandwidth σ = %d\n', sigma);

% Create Gaussian filter in spectral domain
% H(k) = exp(-0.5 * ((k - k0) / sigma)^2)
k_axis = (1:B.Lambda.N)';
H = exp(-0.5 * ((k_axis - k0) / sigma).^2);

fprintf('  Filter peak value: %.6f at mode %d\n', max(H), k0);
fprintf('  Filter at DC (mode 1): %.6f\n', H(1));
fprintf('  Filter at Nyquist (mode %d): %.6f\n', B.Lambda.N, H(end));

%% Step 5: Apply filter in spectral domain
fprintf('\nStep 5: Apply spectral filter\n');
fprintf('------------------------------\n');

% Multiply spectral coefficients by filter
delta_spectral_filtered = delta_spectral .* H;

fprintf('  Filtered spectral energy: %.6f\n', norm(delta_spectral_filtered));
fprintf('  Energy reduction: %.2f%%\n', ...
    (1 - norm(delta_spectral_filtered)/norm(delta_spectral)) * 100);

%% Step 6: Inverse transform to Manifold
fprintf('\nStep 6: Inverse transform to Manifold\n');
fprintf('--------------------------------------\n');

% Apply inverse transform: Lambda → Manifold
signal_filtered = B.Manifold.transform.inverse(delta_spectral_filtered);

fprintf('  Filtered signal dimensions: [%d × 1]\n', length(signal_filtered));
fprintf('  Filtered signal energy: %.6f\n', norm(signal_filtered));

% Find peak in filtered signal
[max_val, max_idx] = max(abs(signal_filtered));
fprintf('  Peak magnitude: %.6f at vertex %d\n', max_val, max_idx);
fprintf('  Original delta was at vertex %d\n', v0);

% The filtered signal should be localized around the original vertex
% but smoothed by the spectral filter

%% Step 7: Visualize results (optional - requires plotting)
fprintf('\nStep 7: Visualize signals\n');
fprintf('-------------------------\n');

figure('Position', [100 100 1200 400]);

% Plot 1: Original delta signal
subplot(1, 3, 1);
plot(delta.Data);
title(sprintf('Original Delta at Vertex %d', v0));
xlabel('Vertex index');
ylabel('Amplitude');
grid on;

% Plot 2: Spectral filter
subplot(1, 3, 2);
plot(k_axis, H, 'LineWidth', 2);
hold on;
stem(1:length(delta_spectral), abs(delta_spectral), 'r.', 'MarkerSize', 8);
title('Spectral Domain: Filter + Delta Spectrum');
xlabel('Spectral mode k');
ylabel('Magnitude');
legend('Gaussian Filter H(k)', 'Delta Spectrum', 'Location', 'best');
grid on;

% Plot 3: Filtered signal on Manifold
subplot(1, 3, 3);
plot(signal_filtered);
title('Filtered Signal on Manifold');
xlabel('Vertex index');
ylabel('Amplitude');
grid on;

fprintf('  Plots created in Figure 1\n');

%% Step 8: Compare delta vs filtered signal
fprintf('\nStep 8: Analyze filtering effect\n');
fprintf('---------------------------------\n');

% Measure spatial spread
% Original delta: concentrated at one vertex
delta_spread = sum(abs(delta.Data) > 0.01);  % Vertices with >1% amplitude

% Filtered signal: spread over neighborhood
filtered_spread = sum(abs(signal_filtered) > 0.01 * max(abs(signal_filtered)));

fprintf('  Delta spread: %d vertices\n', delta_spread);
fprintf('  Filtered spread: %d vertices\n', filtered_spread);
fprintf('  Spread increase: %dx\n', filtered_spread / delta_spread);

% Energy concentration
delta_energy_top10 = sum(sort(abs(delta.Data), 'descend').^2 .* (1:10)');
filtered_energy_top10 = sum(sort(abs(signal_filtered), 'descend').^2 .* (1:10)');

fprintf('  Delta energy in top 10 vertices: %.2f%%\n', ...
    delta_energy_top10 / norm(delta.Data)^2 * 100);
fprintf('  Filtered energy in top 10 vertices: %.2f%%\n', ...
    filtered_energy_top10 / norm(signal_filtered)^2 * 100);

%% Step 9: Demonstrate with different filter bandwidths
fprintf('\nStep 9: Compare different filter bandwidths\n');
fprintf('--------------------------------------------\n');

sigmas = [10, 30, 50];  % Different bandwidths
figure('Position', [100 600 1200 400]);

for i = 1:length(sigmas)
    sig = sigmas(i);
    
    % Create filter
    H_i = exp(-0.5 * ((k_axis - k0) / sig).^2);
    
    % Apply filter
    delta_spec_filt = delta_spectral .* H_i;
    
    % Inverse transform
    sig_filt = B.Manifold.transform.inverse(delta_spec_filt);
    
    % Plot
    subplot(1, 3, i);
    plot(sig_filt);
    title(sprintf('Filtered Signal (σ = %d)', sig));
    xlabel('Vertex index');
    ylabel('Amplitude');
    grid on;
    
    % Measure spread
    spread = sum(abs(sig_filt) > 0.01 * max(abs(sig_filt)));
    fprintf('  σ = %2d: spread = %4d vertices, peak = %.4f\n', ...
        sig, spread, max(abs(sig_filt)));
end

fprintf('  Larger σ → wider spatial extent (more smoothing)\n');

%% Summary
fprintf('\n========================================\n');
fprintf('EXAMPLE COMPLETE!\n');
fprintf('========================================\n');
fprintf('Demonstrated:\n');
fprintf('  1. Delta signal creation on Manifold\n');
fprintf('  2. Forward transform to spectral domain (Lambda)\n');
fprintf('  3. Gaussian filtering in spectral domain\n');
fprintf('  4. Inverse transform back to Manifold\n');
fprintf('  5. Analysis of filtering effects\n');
fprintf('\n');
fprintf('Key concepts:\n');
fprintf('  - Spectral filtering = pointwise multiplication in Lambda\n');
fprintf('  - Low-pass filter (small k0) → spatial smoothing\n');
fprintf('  - Band-pass filter → feature extraction at specific scale\n');
fprintf('  - Filter bandwidth (σ) controls spatial extent\n');
fprintf('========================================\n');
