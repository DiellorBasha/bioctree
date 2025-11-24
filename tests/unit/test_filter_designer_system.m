% Test script for BctFilterDesigner system with Filter and FilterDesigner classes
% This demonstrates the new architecture with proper Joint domain integration

clearvars;
close all;

%% Step 1: Create BCT object with domains
fprintf('Step 1: Creating BCT object...\n');
B = bct.bct();

% Load or create a simple mesh (using icosphere for demo)
[vertices, faces] = icosphere(3);  % 642 vertices
B.Manifold = bct.Manifold(vertices, faces);
fprintf('  Mesh: %d vertices\n', size(vertices, 1));

%% Step 2: Compute eigenbasis (fills Lambda with actual eigenvalues)
fprintf('\nStep 2: Computing eigenbasis...\n');
k = 50;  % Number of eigenmodes
B = B.computeEigenbasis(k);
fprintf('  Computed %d eigenmodes\n', k);
fprintf('  Lambda.lambda range: [%.4f, %.4f]\n', min(B.Lambda.lambda), max(B.Lambda.lambda));
fprintf('  Lambda.axis (wavenumber) range: [%.4f, %.4f] rad/mm\n', ...
    min(B.Lambda.axis), max(B.Lambda.axis));

%% Step 3: Create Time domain (Omega is auto-created as dual)
fprintf('\nStep 3: Creating Time domain...\n');
fs = 100;  % Sampling rate (Hz)
T = 2;     % Duration (seconds)
t = 0:1/fs:T-1/fs;
B.Time = bct.Time(t, fs);
fprintf('  Time: %d samples at %d Hz\n', length(t), fs);
fprintf('  Omega.axis range: [%.2f, %.2f] rad/s\n', ...
    min(B.Omega.axis), max(B.Omega.axis));
fprintf('  Frequency range: [%.2f, %.2f] Hz\n', ...
    min(B.Omega.axis)/(2*pi), max(B.Omega.axis)/(2*pi));

%% Step 4: Create Joint domain (Lambda × Omega)
fprintf('\nStep 4: Creating Joint domain...\n');
B = B.createJoint('Lambda', 'Omega');
dims = B.Joint.N;
fprintf('  Joint domain: %s\n', B.Joint.Domain);
fprintf('  Grid size: [%d × %d]\n', sz(1), sz(2));
fprintf('  Total points: %d\n', prod(sz));

%% Step 5: Initialize FilterDesigner
fprintf('\nStep 5: Creating FilterDesigner...\n');
designer = bct.filters.FilterDesigner(B);
fprintf('  FilterDesigner ready\n');

%% Step 6: Create default Joint filter (Gabor kernel)
fprintf('\nStep 6: Creating default Gabor filter on Joint domain...\n');

% Default parameters (similar to app initialization)
k0 = mean(B.Lambda.axis);  % Center wavenumber
sigma_k = (max(B.Lambda.axis) - min(B.Lambda.axis)) / 10;  % 10% of range

omega0 = 0;  % Center frequency (DC)
sigma_o = (max(B.Omega.axis) - min(B.Omega.axis)) / 20;  % 5% of range

filt = designer.joint('gabor', ...
    'center_x', k0, 'sigma_x', sigma_k, ...
    'center_y', omega0, 'sigma_y', sigma_o, ...
    'label', 'Default Joint Filter');

fprintf('  Filter created: %s\n', filt.Label);
fprintf('  Kernel: %s\n', filt.KernelName);
fprintf('  Domain: %s\n', filt.Domain.Domain);
fprintf('  Parameters:\n');
fprintf('    center_x (k0) = %.4f rad/mm\n', filt.Parameters.center_x);
fprintf('    sigma_x (σ_k) = %.4f rad/mm\n', filt.Parameters.sigma_x);
fprintf('    center_y (ω0) = %.2f rad/s (%.2f Hz)\n', ...
    filt.Parameters.center_y, filt.Parameters.center_y/(2*pi));
fprintf('    sigma_y (σ_ω) = %.2f rad/s (%.2f Hz)\n', ...
    filt.Parameters.sigma_y, filt.Parameters.sigma_y/(2*pi));

%% Step 7: Evaluate filter on Joint domain
fprintf('\nStep 7: Evaluating filter...\n');
H = filt.evaluate();
fprintf('  Filter response size: [%d × %d]\n', size(H, 1), size(H, 2));
fprintf('  Response range: [%.6f, %.6f]\n', min(H(:)), max(H(:)));

%% Step 8: Visualize filter response
fprintf('\nStep 8: Visualizing filter response...\n');

figure('Position', [100 100 1200 400]);

% Subplot 1: 2D heatmap
subplot(1, 3, 1);
imagesc(B.Lambda.axis, B.Omega.axis/(2*pi), H);
axis xy;
xlabel('Wavenumber k (rad/mm)');
ylabel('Frequency (Hz)');
title(sprintf('Filter Response: %s', filt.Label));
colorbar;
colormap turbo;
hold on;
plot(filt.Parameters.center_x, filt.Parameters.center_y/(2*pi), ...
    'r+', 'MarkerSize', 15, 'LineWidth', 2);
legend('Center (k0, f0)', 'Location', 'best');

% Subplot 2: Surface view
subplot(1, 3, 2);
surf(B.Joint.A_grid, B.Joint.B_grid/(2*pi), H, 'EdgeColor', 'none');
xlabel('Wavenumber k (rad/mm)');
ylabel('Frequency (Hz)');
zlabel('Magnitude');
title('3D Surface View');
colormap turbo;
shading interp;
view(45, 30);

% Subplot 3: Cross-sections
subplot(1, 3, 3);
hold on;

% Lambda cross-section at omega = omega0
[~, omega_idx] = min(abs(B.Omega.axis - filt.Parameters.center_y));
plot(B.Lambda.axis, H(:, omega_idx), 'b-', 'LineWidth', 2, 'DisplayName', 'Lambda cut (at ω0)');

% Omega cross-section at k = k0
[~, k_idx] = min(abs(B.Lambda.axis - filt.Parameters.center_x));
plot(B.Omega.axis/(2*pi), H(k_idx, :), 'r-', 'LineWidth', 2, 'DisplayName', 'Omega cut (at k0)');

xlabel('Axis value');
ylabel('Magnitude');
title('Cross-sections through Center');
legend('Location', 'best');
grid on;

%% Step 9: Test parameter updates (simulating slider changes)
fprintf('\nStep 9: Testing parameter updates...\n');

% Change center wavenumber (like k0Slider)
new_k0 = k0 * 1.5;
filt.setParameter('center_x', new_k0);
fprintf('  Updated center_x: %.4f -> %.4f rad/mm\n', k0, new_k0);

% Change frequency (like omegaSlider)
new_omega0 = 20 * 2*pi;  % 20 Hz
filt.setParameter('center_y', new_omega0);
fprintf('  Updated center_y: %.2f -> %.2f rad/s (%.2f Hz)\n', ...
    omega0, new_omega0, new_omega0/(2*pi));

% Re-evaluate with new parameters
H_new = filt.evaluate();
fprintf('  Re-evaluated filter with new parameters\n');

% Visualize updated filter
figure('Position', [100 600 800 300]);

subplot(1, 2, 1);
imagesc(B.Lambda.axis, B.Omega.axis/(2*pi), H);
axis xy;
xlabel('Wavenumber k (rad/mm)');
ylabel('Frequency (Hz)');
title('Original Filter');
colorbar;
colormap turbo;
hold on;
plot(k0, omega0/(2*pi), 'r+', 'MarkerSize', 15, 'LineWidth', 2);

subplot(1, 2, 2);
imagesc(B.Lambda.axis, B.Omega.axis/(2*pi), H_new);
axis xy;
xlabel('Wavenumber k (rad/mm)');
ylabel('Frequency (Hz)');
title('Updated Filter (after slider changes)');
colorbar;
colormap turbo;
hold on;
plot(new_k0, new_omega0/(2*pi), 'r+', 'MarkerSize', 15, 'LineWidth', 2);

%% Step 10: Summary
fprintf('\n=== SUMMARY ===\n');
fprintf('Successfully demonstrated:\n');
fprintf('  ✓ BCT object with Manifold, Lambda, Time, Omega, Joint domains\n');
fprintf('  ✓ FilterDesigner initialization\n');
fprintf('  ✓ Joint filter creation with Gabor kernel\n');
fprintf('  ✓ Filter evaluation on Joint grid\n');
fprintf('  ✓ Parameter updates (simulating app sliders)\n');
fprintf('  ✓ Visualization of filter response\n');
fprintf('\nThe BctFilterDesigner app uses this same architecture!\n');

%% Step 11: Save BCT object to workspace for app testing
fprintf('\nStep 11: Saving BCT object to base workspace...\n');
assignin('base', 'B_test', B);
fprintf('  Saved as ''B_test'' in workspace\n');
fprintf('  You can now:\n');
fprintf('    1. Run BctFilterDesigner app\n');
fprintf('    2. Click Scan to find B_test\n');
fprintf('    3. Load B_test\n');
fprintf('    4. Use sliders to adjust filter parameters\n');
fprintf('    5. Click Synthesize to see filter response\n');

fprintf('\nTest complete!\n');
