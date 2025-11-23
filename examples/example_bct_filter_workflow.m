%% Complete BCT Filter Workflow Example
% Demonstrates creating a BCT object and building filters
% From mesh import to filter evaluation

clear; clc;
bioctree_start;

%% Step 1: Import mesh and create BCT object
fprintf('=== Step 1: Import Mesh ===\n');
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);
fprintf('✓ Mesh imported: %d vertices, %d faces\n', B.Manifold.N, size(B.Manifold.Faces, 1));

%% Step 2: Compute eigenbasis (spectral decomposition)
fprintf('\n=== Step 2: Compute Eigenbasis ===\n');
B = B.computeEigenbasis(100);
fprintf('✓ Computed %d eigenmodes\n', length(B.Lambda.lambda));
fprintf('  Eigenvalue range: [%.4f, %.4f]\n', min(B.Lambda.lambda), max(B.Lambda.lambda));

%% Step 3: Set up time domain (auto-creates Omega dual)
fprintf('\n=== Step 3: Set Up Time Domain ===\n');
B.Time = bct.Time(linspace(0, 1, 50)', 50);  % 1 second, 50 Hz
fprintf('✓ Time domain created: %d samples @ %.1f Hz\n', B.Time.N, B.Time.fs);
fprintf('✓ Omega (frequency) domain auto-created: %d frequencies\n', length(B.Omega.axis));

%% Step 4: Create joint spectral-frequency domain
fprintf('\n=== Step 4: Create Joint Domain ===\n');
B = B.createJoint('Lambda', 'Omega');
sz = B.Joint.size();
fprintf('✓ Joint domain created: Lambda×Omega [%d×%d]\n', sz(1), sz(2));

%% Step 5: Create filters using kernel functions
fprintf('\n=== Step 5: Create Filters ===\n');

% Temporal filter (operates on Omega/frequency domain)
fprintf('\n--- Temporal Filter (Low-pass) ---\n');
F_temporal = bct.filters.Filter(B.Omega, 'gaussian', 'center', 10, 'sigma', 2);
fprintf('✓ Temporal filter created\n');
fprintf('  Domain: Omega (frequency)\n');
fprintf('  Kernel: Gaussian (center=10 Hz, sigma=2)\n');

% Spatial filter (operates on Lambda/spectral domain)
% Lambda.axis returns WAVENUMBER k = sqrt(lambda) by default
fprintf('\n--- Spatial Filter (Gaussian in Wavenumber Space) ---\n');
F_spatial = bct.filters.Filter(B.Lambda, 'gaussian_wavenumber', 'k0', 5, 'sigma_k', 2);
fprintf('✓ Spatial filter created\n');
fprintf('  Domain: Lambda (spectral - wavenumber k = sqrt(λ))\n');
fprintf('  Kernel: Gaussian (k0=5 rad/mm, σ_k=2 rad/mm)\n');
fprintf('  Spatial wavelength at k0: %.2f mm\n', 2*pi/5);

% Joint spatiotemporal filter (operates on Lambda×Omega)
fprintf('\n--- Joint Spatiotemporal Filter (2D Gabor) ---\n');
% Gabor is a 2D Gaussian kernel - ideal for joint spectral-frequency localization
F_joint = bct.filters.Filter(B.Joint, 'gabor', ...
    'center_x', 50, 'center_y', 10, ...  % Center in Lambda×Omega space
    'sigma_x', 20, 'sigma_y', 5);         % Spread in each dimension
fprintf('✓ Joint filter created\n');
fprintf('  Domain: Lambda×Omega (spectral-frequency)\n');
fprintf('  Kernel: Gabor/2D Gaussian (center=[50,10], sigma=[20,5])\n');

%% Step 6: Evaluate filter responses
fprintf('\n=== Step 6: Evaluate Filter Responses ===\n');

% Temporal filter response
h_temporal = F_temporal.evaluate();
fprintf('✓ Temporal response: [%d×1]\n', length(h_temporal));

% Spatial filter response
h_spatial = F_spatial.evaluate();
fprintf('✓ Spatial response: [%d×1]\n', length(h_spatial));

% Joint filter response (2D)
h_joint = F_joint.evaluate();
fprintf('✓ Joint response: [%d×%d]\n', size(h_joint, 1), size(h_joint, 2));

%% Step 7: Visualize 2D Joint Kernel (Gabor)
fprintf('\n=== Step 7: Visualize 2D Joint Kernel ===\n');

% Get the kernel function directly
gabor_kernel = bct.filters.kernels.gabor();

% Create wavenumber and frequency grids for visualization
k_viz = linspace(0, 100, 200);      % Wavenumber axis (rad/mm)
omega_viz = linspace(0, 25, 200);   % Frequency axis (Hz)
[K_grid, Omega_grid] = meshgrid(k_viz, omega_viz);

% Evaluate 2D Gabor kernel on the grid
center_k = 50;      % Center wavenumber (rad/mm)
center_omega = 10;  % Center frequency (Hz)
sigma_k = 20;       % Wavenumber spread
sigma_omega = 5;    % Frequency spread

H_2D = gabor_kernel(K_grid, Omega_grid, center_k, center_omega, sigma_k, sigma_omega);

% Visualize 2D kernel
figure('Name', '2D Gabor Kernel (Lambda×Omega)', 'Position', [100, 100, 1400, 500]);

subplot(1, 3, 1);
imagesc(omega_viz, k_viz, H_2D);
axis xy;
colorbar;
xlabel('Frequency ω (Hz)');
ylabel('Wavenumber k (rad/mm)');
title('2D Gabor Kernel');
colormap('hot');

subplot(1, 3, 2);
surf(Omega_grid, K_grid, H_2D, 'EdgeColor', 'none');
xlabel('Frequency ω (Hz)');
ylabel('Wavenumber k (rad/mm)');
zlabel('Kernel Response');
title('2D Gabor Kernel (Surface)');
view(45, 30);
colormap('hot');
shading interp;

subplot(1, 3, 3);
contour(Omega_grid, K_grid, H_2D, 20);
xlabel('Frequency ω (Hz)');
ylabel('Wavenumber k (rad/mm)');
title('2D Gabor Kernel (Contours)');
grid on;
colorbar;

fprintf('✓ 2D joint kernel visualized\n');
fprintf('  Center: (k=%d rad/mm, ω=%d Hz)\n', center_k, center_omega);
fprintf('  Spread: (σ_k=%d rad/mm, σ_ω=%d Hz)\n', sigma_k, sigma_omega);
fprintf('  Spatial wavelength at k=%d: %.2f mm\n', center_k, 2*pi/center_k);

%% Step 8: Visualize filter responses
fprintf('\n=== Step 8: Visualize Filter Responses ===\n');

figure('Name', 'BCT Filter Workflow', 'Position', [100, 100, 1400, 400]);

% Plot temporal filter
subplot(1, 3, 1);
plot(B.Omega.axis, h_temporal, 'b-', 'LineWidth', 2);
grid on;
xlabel('Frequency (Hz)');
ylabel('Filter Response');
title('Temporal Filter (Gaussian Low-pass)');
ylim([0, 1.1*max(h_temporal)]);

% Plot spatial filter
subplot(1, 3, 2);
plot(B.Lambda.axis, h_spatial, 'r-', 'LineWidth', 2);
grid on;
xlabel('Wavenumber k (rad/mm)');
ylabel('Filter Response');
title('Spatial Filter (Gaussian in Wavenumber)');
ylim([0, 1.1*max(h_spatial)]);

% Plot joint filter (2D heatmap)
subplot(1, 3, 3);
imagesc(B.Omega.axis, B.Lambda.axis, h_joint);
axis xy;
colorbar;
xlabel('Frequency (Hz)');
ylabel('Eigenvalue λ');
title('Joint Spatiotemporal Filter');

fprintf('✓ Filter visualizations created\n');

%% Step 9: Apply filter to synthetic signal (optional)
fprintf('\n=== Step 9: Create and Filter a Signal ===\n');

% Create a synthetic spatiotemporal signal
signal_data = randn(B.Manifold.N, B.Time.N);
sig = bct.Signal(B.Manifold, signal_data, 'noisy_signal', B.Time);
fprintf('✓ Signal created: [%d×%d]\n', size(sig.Data, 1), size(sig.Data, 2));

% Add signal to BCT object
B.addSignal(sig);
fprintf('✓ Signal added to BCT object\n');
fprintf('  Total signals in B: %d\n', length(B.Signals));

%% Summary
fprintf('\n=== Workflow Complete! ===\n');
fprintf('Created BCT object with:\n');
fprintf('  • Manifold: %d vertices\n', B.Manifold.N);
fprintf('  • Lambda: %d eigenmodes\n', length(B.Lambda.lambda));
fprintf('  • Time: %d samples @ %.1f Hz\n', B.Time.N, B.Time.fs);
fprintf('  • Omega: %d frequencies\n', length(B.Omega.axis));
sz = B.Joint.size();
fprintf('  • Joint: Lambda×Omega [%d×%d]\n', sz(1), sz(2));
fprintf('  • Filters: 3 (temporal, spatial, joint)\n');
fprintf('  • Signals: %d\n', length(B.Signals));

%% Available Kernel Functions
fprintf('\n=== Available Kernel Functions ===\n');
fprintf('Located in: toolbox/+bct/+filters/+kernels/\n\n');
fprintf('TEMPORAL/FREQUENCY (Omega domain):\n');
fprintf('1. bct.filters.kernels.gaussian(center, sigma)  - Gaussian in frequency\n');
fprintf('2. bct.filters.kernels.bandpass(low, high)      - Bandpass filter\n');
fprintf('\nSPATIAL (Lambda domain - wavenumber-aware):\n');
fprintf('3. bct.filters.kernels.gaussian_wavenumber(k0, sigma_k)    - Gaussian bandpass\n');
fprintf('4. bct.filters.kernels.heat_wavenumber(tau)                - Heat diffusion lowpass\n');
fprintf('5. bct.filters.kernels.mexican_hat_wavenumber(k0, sigma_k) - Mexican hat wavelet\n');
fprintf('\nJOINT 2D (Lambda×Omega domain):\n');
fprintf('6. bct.filters.kernels.gabor(center_x, center_y, sigma_x, sigma_y) - 2D Gaussian\n');
fprintf('\nNote: Lambda.axis returns WAVENUMBER k=sqrt(λ) by default!\n');
fprintf('\nAll kernels are domain-agnostic pure functions!\n');

%% Filter Usage Patterns
fprintf('\n=== Common Filter Patterns ===\n');
fprintf('\n1. Temporal low-pass (remove high frequencies):\n');
fprintf('   F = bct.filters.Filter(B.Omega, ''gaussian'', ''center'', 10, ''sigma'', 2);\n');
fprintf('\n2. Temporal band-pass (isolate frequency band):\n');
fprintf('   F = bct.filters.Filter(B.Omega, ''bandpass'', ''low'', 5, ''high'', 15);\n');
fprintf('\n3. Spatial bandpass (mesh/wavenumber-aware):\n');
fprintf('   F = bct.filters.Filter(B.Lambda, ''gaussian_wavenumber'', ''k0'', 5, ''sigma_k'', 2);\n');
fprintf('   Note: k0 in rad/mm, wavelength = 2π/k0\n');
fprintf('\n4. Spatial smoothing (heat diffusion):\n');
fprintf('   F = bct.filters.Filter(B.Lambda, ''heat_wavenumber'', ''tau'', 0.1);\n');
fprintf('\n5. Spatial edge detection (Mexican hat wavelet):\n');
fprintf('   F = bct.filters.Filter(B.Lambda, ''mexican_hat_wavenumber'', ''k0'', 8, ''sigma_k'', 3);\n');
fprintf('\n6. Spatiotemporal filtering (2D joint domain):\n');
fprintf('   F = bct.filters.Filter(B.Joint, ''gabor'', ...\n');
fprintf('       ''center_x'', 50, ''center_y'', 10, ''sigma_x'', 20, ''sigma_y'', 5);\n');
fprintf('\n7. Update parameters dynamically:\n');
fprintf('   F.k0 = 7;        %% Change center wavenumber\n');
fprintf('   F.sigma_k = 3;   %% Change bandwidth\n');
