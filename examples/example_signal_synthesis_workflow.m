% Example: Modern Signal Synthesis Workflow
% 
% Demonstrates the new architecture for signal synthesis using:
%   1. Domain transforms (owned by Domain classes)
%   2. Filter evaluation (owned by Filter class)
%   3. Signal creation and filtering (owned by Signal class)
%   4. Workflow orchestration (BCT class)
%
% This replaces the old deprecated Synthesize/Generate methods with a
% cleaner separation of concerns following signal processing principles.

clearvars;
close all;

fprintf('===== Modern Signal Synthesis Workflow =====\n\n');

%% Step 1: Create BCT object with domains
fprintf('Step 1: Setting up BCT object with domains...\n');

% Create mesh (icosphere for demonstration)
[V, F] = icosphere(3);  % 642 vertices
B = bct.bct();
B.Manifold = bct.Manifold(V, F);

% Compute eigenbasis (fills Lambda with eigenvalues and eigenvectors)
k = 100;
B = B.computeEigenbasis(k);

% Create Time domain (Omega is automatically created as dual)
fs = 100;  % Hz
T_duration = 2;  % seconds
t = 0:1/fs:T_duration-1/fs;
B.Time = bct.Time(t, fs);

fprintf('  Manifold: %d vertices\n', B.Manifold.N);
fprintf('  Lambda: %d eigenmodes (k range: [%.4f, %.4f] rad/mm)\n', ...
    length(B.Lambda.lambda), min(B.Lambda.axis), max(B.Lambda.axis));
fprintf('  Time: %d samples at %d Hz\n', B.Time.N, B.Time.fs);
fprintf('  Omega: frequency range [%.2f, %.2f] Hz\n\n', ...
    min(B.Omega.axis)/(2*pi), max(B.Omega.axis)/(2*pi));

%% Step 2: Create impulse (delta) signal
fprintf('Step 2: Creating Kronecker delta (impulse) signal...\n');

% In signal processing, a filter is fully characterized by its impulse response
% Create spatial impulse at vertex 100
v0 = 100;
delta = bct.Signal.createDelta(B.Manifold, v0);

fprintf('  Created delta signal at vertex %d\n', v0);
fprintf('  Signal dimensions: [%d × %d]\n', size(delta.Data, 1), size(delta.Data, 2));
fprintf('  Sum of signal: %.1f (should be 1 for delta)\n', sum(delta.Data));
fprintf('  Label: %s\n\n', delta.Label);

%% Step 3: Create spatial filter (Lambda domain)
fprintf('Step 3: Creating spatial filter on Lambda domain...\n');

% Initialize FilterDesigner
designer = bct.filters.FilterDesigner(B);

% Create heat (lowpass) filter in wavenumber space
tau = 0.05;  % Diffusion parameter (smaller = more lowpass)
filt_spatial = designer.spatial('heat_wavenumber', 'tau', tau, ...
    'label', 'Spatial Lowpass');

fprintf('  Filter type: %s\n', filt_spatial.KernelName);
fprintf('  Filter domain: %s\n', filt_spatial.Domain.name);
fprintf('  Parameters: tau = %.3f\n', tau);

% Evaluate filter on Lambda domain
H_spatial = filt_spatial.evaluate();
fprintf('  Filter response range: [%.4f, %.4f]\n', min(H_spatial), max(H_spatial));
fprintf('  Filter evaluated on %d eigenvalues\n\n', length(H_spatial));

%% Step 4: Apply filter using domain transforms
fprintf('Step 4: Applying filter using domain transforms...\n');
fprintf('  Workflow: Manifold -> Lambda (filter) -> Manifold\n');

% Method 1: Using Signal.applyFilter (recommended)
fprintf('\n  Method 1: Using Signal.applyFilter()\n');
filtered_sig1 = delta.applyFilter(filt_spatial, B.Manifold, B.Lambda);

fprintf('    - Forward transform (Manifold -> Lambda)\n');
fprintf('    - Multiply by filter response\n');
fprintf('    - Inverse transform (Lambda -> Manifold)\n');
fprintf('    Result dimensions: [%d × %d]\n', size(filtered_sig1.Data));
fprintf('    Result label: %s\n', filtered_sig1.Label);

% Method 2: Using BCT orchestration (alternative)
fprintf('\n  Method 2: Using B.synthesizeFilteredSignal()\n');
filtered_sig2 = B.synthesizeFilteredSignal(filt_spatial, delta);
fprintf('    Result dimensions: [%d × %d]\n', size(filtered_sig2.Data));

% Verify both methods give same result
fprintf('\n  Verification: max difference = %.2e (should be ~0)\n', ...
    max(abs(filtered_sig1.Data - filtered_sig2.Data)));

%% Step 5: Visualize impulse response
fprintf('\nStep 5: Visualizing impulse response...\n');

figure('Position', [100 100 1400 400]);

% Original impulse
subplot(1, 3, 1);
data1 = delta.Data;
scatter3(V(:,1), V(:,2), V(:,3), 30, data1, 'filled');
colormap(gca, 'hot');
colorbar;
title(sprintf('Original Impulse\n(vertex %d)', v0));
xlabel('X'); ylabel('Y'); zlabel('Z');
axis equal;
view(3);

% Spectral coefficients (Lambda domain)
subplot(1, 3, 2);
delta_spectral = B.Manifold.transform.forward(delta.Data);
stem(B.Lambda.axis, abs(delta_spectral), 'LineWidth', 1.5);
xlabel('Wavenumber k (rad/mm)');
ylabel('|Coefficient|');
title('Spectral Representation (Lambda)');
grid on;
hold on;
plot(B.Lambda.axis, H_spatial, 'r--', 'LineWidth', 2);
legend('Delta spectrum', 'Filter response', 'Location', 'best');

% Filtered impulse response
subplot(1, 3, 3);
data3 = filtered_sig1.Data;
scatter3(V(:,1), V(:,2), V(:,3), 30, data3, 'filled');
colormap(gca, 'hot');
colorbar;
title(sprintf('Filtered Response\n(tau = %.3f)', tau));
xlabel('X'); ylabel('Y'); zlabel('Z');
axis equal;
view(3);

%% Step 6: Create temporal filter (Omega domain)
fprintf('\nStep 6: Creating temporal filter on Omega domain...\n');

% Create Gaussian bandpass in frequency domain
center_freq = 10;  % Hz
bandwidth = 2;     % Hz
filt_temporal = designer.temporal('gaussian', ...
    'center', center_freq * 2*pi, ...  % Convert to rad/s
    'sigma', bandwidth * 2*pi, ...
    'label', sprintf('%d Hz Bandpass', center_freq));

fprintf('  Filter type: %s\n', filt_temporal.KernelName);
fprintf('  Center frequency: %d Hz\n', center_freq);
fprintf('  Bandwidth: %d Hz\n', bandwidth);

% Evaluate filter
H_temporal = filt_temporal.evaluate();

% Visualize temporal filter
figure('Position', [100 600 800 300]);
subplot(1, 2, 1);
plot(B.Omega.axis/(2*pi), H_temporal, 'LineWidth', 2);
xlabel('Frequency (Hz)');
ylabel('Filter Response');
title(sprintf('Temporal Filter: %d Hz Bandpass', center_freq));
grid on;
xlim([0 fs/2]);  % Show up to Nyquist

%% Step 7: Create spatiotemporal impulse
fprintf('\nStep 7: Creating spatiotemporal impulse...\n');

v0_st = 200;  % Vertex
t0_st = 50;   % Time index

delta_st = bct.Signal.createDelta(B.Manifold, v0_st, B.Time, t0_st);
fprintf('  Created delta at vertex %d, time index %d\n', v0_st, t0_st);
fprintf('  Signal dimensions: [%d × %d]\n', size(delta_st.Data));
fprintf('  Time point: %.3f s\n', B.Time.axis(t0_st));

% Show time series at impulse vertex
subplot(1, 2, 2);
plot(B.Time.axis, delta_st.Data(v0_st, :), 'LineWidth', 2);
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Time series at vertex %d', v0_st));
grid on;
hold on;
plot(B.Time.axis(t0_st), 1, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
legend('Delta signal', 'Impulse time', 'Location', 'best');

%% Step 8: Create Joint filter (Lambda × Omega)
fprintf('\nStep 8: Creating joint spatiotemporal filter...\n');

% Ensure Joint domain exists
if isempty(B.Joint)
    B = B.createJoint('Lambda', 'Omega');
end

% Create Gabor filter (separable 2D Gaussian)
k0 = median(B.Lambda.axis);  % Center wavenumber
sigma_k = (max(B.Lambda.axis) - min(B.Lambda.axis)) / 10;
omega0 = 15 * 2*pi;  % 15 Hz center frequency
sigma_o = 3 * 2*pi;  % 3 Hz bandwidth

filt_joint = designer.joint('gabor', ...
    'center_x', k0, 'sigma_x', sigma_k, ...
    'center_y', omega0, 'sigma_y', sigma_o, ...
    'label', 'Spatiotemporal Gabor');

fprintf('  Filter: Gabor (2D Gaussian)\n');
fprintf('  Spatial: k0 = %.4f rad/mm, σ_k = %.4f\n', k0, sigma_k);
fprintf('  Temporal: f0 = %.1f Hz, σ_f = %.1f Hz\n', ...
    omega0/(2*pi), sigma_o/(2*pi));

% Evaluate joint filter
H_joint = filt_joint.evaluate();
fprintf('  Joint grid: [%d × %d]\n', size(H_joint, 1), size(H_joint, 2));

% Visualize joint filter
figure('Position', [100 200 800 600]);
imagesc(B.Lambda.axis, B.Omega.axis/(2*pi), H_joint);
axis xy;
xlabel('Wavenumber k (rad/mm)');
ylabel('Frequency (Hz)');
title('Joint Spatiotemporal Filter (Lambda × Omega)');
colormap turbo;
colorbar;
hold on;
plot(k0, omega0/(2*pi), 'r+', 'MarkerSize', 20, 'LineWidth', 3);
legend('Center (k0, f0)', 'Location', 'best');

%% Step 9: Summary of architecture
fprintf('\n===== Architecture Summary =====\n');
fprintf('\n1. Domain classes own transforms:\n');
fprintf('   - Manifold.transform: Manifold <-> Lambda (MFT/IMFT)\n');
fprintf('   - Lambda.transform: Lambda <-> Manifold (IMFT/MFT)\n');
fprintf('   - Time.transform: Time <-> Omega (FFT)\n');
fprintf('   - Omega.transform: Omega <-> Time (IFFT)\n');

fprintf('\n2. Filter classes define kernels:\n');
fprintf('   - Filter.evaluate() returns response on domain grid\n');
fprintf('   - No transforms, no signals - just kernel evaluation\n');
fprintf('   - Created via FilterDesigner.spatial/temporal/joint()\n');

fprintf('\n3. Signal classes hold data:\n');
fprintf('   - Signal.createDelta() creates impulse signals\n');
fprintf('   - Signal.applyFilter() applies filter using transforms\n');
fprintf('   - Validates dimensions against Manifold/Time\n');

fprintf('\n4. BCT orchestrates workflow:\n');
fprintf('   - B.createImpulse() - convenience wrapper\n');
fprintf('   - B.synthesizeFilteredSignal() - high-level synthesis\n');
fprintf('   - Manages domain relationships and initialization\n');

fprintf('\n===== Old vs New Workflow =====\n');
fprintf('\nOLD (deprecated):\n');
fprintf('  B.Synthesize(...)  - Complicated, monolithic\n');
fprintf('  B.Generate(...)    - Mixed responsibilities\n');

fprintf('\nNEW (recommended):\n');
fprintf('  delta = B.createImpulse(v0);\n');
fprintf('  filt = designer.spatial(''heat_wavenumber'', ''tau'', 0.1);\n');
fprintf('  response = delta.applyFilter(filt, B.Manifold, B.Lambda);\n');

fprintf('\nKey improvement: Clear separation of concerns!\n');
fprintf('  - Each class has ONE responsibility\n');
fprintf('  - Easier to test, debug, and extend\n');
fprintf('  - Follows signal processing conventions\n');

fprintf('\n===== Example Complete =====\n');
