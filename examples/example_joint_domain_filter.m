%% Example: Joint Domain Filter - Lambda×Omega Gabor Filter
% This example demonstrates:
% 1. Create Joint domain from Lambda (spectral) × Omega (frequency)
% 2. Design Gabor filter on joint domain using FilterDesigner
% 3. Verify automatic label generation: gabor_lambda-omega
% 4. Evaluate filter on joint grids
% 5. Visualize 2D joint kernel response
%
% This is fundamental for spatiotemporal filtering and time-frequency analysis.

clear; clc;

%% Step 1: Load cortical surface mesh and compute eigenbasis
fprintf('Step 1: Setup spatial domain (Lambda)\n');
fprintf('--------------------------------------\n');

% Import FreeSurfer surface
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);

fprintf('  Mesh loaded: %s\n', path);
fprintf('  Manifold: N = %d vertices\n', B.Manifold.N);

% Compute eigenbasis for spectral analysis (first 100 modes)
fprintf('  Computing eigenbasis (100 modes)...\n');
B = B.computeEigenbasis(100);

fprintf('  Lambda domain: N = %d spectral modes\n', B.Lambda.N);
fprintf('  Lambda axis range: [%.2f, %.2f]\n', ...
    min(B.Lambda.axis), max(B.Lambda.axis));

%% Step 2: Setup temporal domain (Time and Omega)
fprintf('\nStep 2: Setup temporal domain (Omega)\n');
fprintf('--------------------------------------\n');

% Create Time domain
t = linspace(0, 2, 128)';  % 2 seconds, 128 samples
fs = length(t) / (t(end) - t(1));  % Sampling frequency

B.Time = bct.Time(t, fs);
fprintf('  Time domain: N = %d samples\n', B.Time.N);
fprintf('  Sampling rate: %.1f Hz\n', fs);

% Omega is automatically created as dual of Time
B.Omega = B.Time.dual;
fprintf('  Omega domain: N = %d frequencies\n', B.Omega.N);
fprintf('  Frequency range: [%.2f, %.2f] rad/s\n', ...
    min(B.Omega.axis), max(B.Omega.axis));
fprintf('  Frequency range: [%.2f, %.2f] Hz\n', ...
    min(B.Omega.axis)/(2*pi), max(B.Omega.axis)/(2*pi));

%% Step 3: Create Joint domain (Lambda × Omega)
fprintf('\nStep 3: Create Joint domain\n');
fprintf('----------------------------\n');

B = B.createJoint('Lambda', 'Omega');

fprintf('  Joint domain created: %s\n', B.Joint.Domain);
fprintf('  Dimension A (Lambda): %d modes\n', B.Joint.size_A);
fprintf('  Dimension B (Omega): %d frequencies\n', B.Joint.size_B);
fprintf('  Joint grid size: [%d × %d]\n', size(B.Joint.A_grid, 1), size(B.Joint.A_grid, 2));

% Verify grids are initialized
assert(~isempty(B.Joint.A_grid), 'A_grid should be initialized');
assert(~isempty(B.Joint.B_grid), 'B_grid should be initialized');
fprintf('  ✓ Joint grids initialized\n');

%% Step 4: Design Gabor filter on Joint domain
fprintf('\nStep 4: Design Gabor filter on Joint domain\n');
fprintf('--------------------------------------------\n');

designer = bct.filters.FilterDesigner(B);

% Design 2D Gabor filter on Lambda×Omega
% Center at spectral mode 50, frequency 10 Hz
center_lambda = 50;
center_omega = 2*pi*10;  % 10 Hz in rad/s
sigma_lambda = 15;
sigma_omega = 2*pi*3;    % 3 Hz bandwidth

% Create filter WITHOUT custom label (test auto-generation)
gabor_filter = designer.create(B.Joint, 'gabor', ...
    'center_x', center_lambda, ...
    'center_y', center_omega, ...
    'sigma_x', sigma_lambda, ...
    'sigma_y', sigma_omega);

fprintf('  Filter type: %s\n', gabor_filter.KernelName);
fprintf('  Filter label: "%s" (auto-generated)\n', gabor_filter.Label);
fprintf('  Expected label: "gabor_lambda-omega"\n');

% Verify automatic label generation
expected_label = 'gabor_lambda-omega';
if strcmp(gabor_filter.Label, expected_label)
    fprintf('  ✓ Automatic label matches expected pattern\n');
else
    warning('Label mismatch! Got "%s", expected "%s"', ...
        gabor_filter.Label, expected_label);
end

fprintf('  Domain: %s\n', class(gabor_filter.Domain));
fprintf('  Center (λ, ω): (%.1f, %.1f rad/s) = (%.1f, %.1f Hz)\n', ...
    gabor_filter.Parameters.center_x, ...
    gabor_filter.Parameters.center_y, ...
    gabor_filter.Parameters.center_x, ...
    gabor_filter.Parameters.center_y/(2*pi));
fprintf('  Bandwidth (σ_λ, σ_ω): (%.1f, %.1f rad/s) = (%.1f, %.1f Hz)\n', ...
    gabor_filter.Parameters.sigma_x, ...
    gabor_filter.Parameters.sigma_y, ...
    gabor_filter.Parameters.sigma_x, ...
    gabor_filter.Parameters.sigma_y/(2*pi));

%% Step 5: Evaluate Gabor filter on Joint grids
fprintf('\nStep 5: Evaluate filter on Joint domain\n');
fprintf('----------------------------------------\n');

% Evaluate using Joint domain grids (automatic)
H_joint = gabor_filter.evaluate();

fprintf('  Filter response size: [%d × %d]\n', size(H_joint, 1), size(H_joint, 2));
fprintf('  Peak response: %.4f\n', max(H_joint(:)));
fprintf('  Response at origin: %.4f\n', H_joint(1, 1));

% Verify response shape matches joint grid
assert(isequal(size(H_joint), size(B.Joint.A_grid)), ...
    'Filter response size should match joint grid size');
fprintf('  ✓ Response dimensions match Joint grids\n');

% Find peak location
[max_val, max_idx] = max(H_joint(:));
[max_i, max_j] = ind2sub(size(H_joint), max_idx);
peak_lambda = B.Joint.A_grid(max_i, max_j);
peak_omega = B.Joint.B_grid(max_i, max_j);

fprintf('  Peak location: λ = %.1f, ω = %.1f rad/s (%.1f Hz)\n', ...
    peak_lambda, peak_omega, peak_omega/(2*pi));
fprintf('  Expected center: λ = %.1f, ω = %.1f rad/s (%.1f Hz)\n', ...
    center_lambda, center_omega, center_omega/(2*pi));

%% Step 6: Visualize 2D Gabor kernel
fprintf('\nStep 6: Visualize Gabor filter response\n');
fprintf('----------------------------------------\n');

figure('Position', [100 100 1200 500]);

% Plot 1: 2D heatmap of Gabor kernel
subplot(1, 2, 1);
imagesc(B.Omega.axis/(2*pi), B.Lambda.axis, H_joint);
axis xy;
colorbar;
xlabel('Frequency (Hz)');
ylabel('Spectral Mode (λ)');
title(sprintf('Gabor Filter: %s', gabor_filter.Label));
hold on;
plot(center_omega/(2*pi), center_lambda, 'r+', 'MarkerSize', 15, 'LineWidth', 2);
text(center_omega/(2*pi), center_lambda + 5, 'Center', ...
    'Color', 'red', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% Plot 2: Cross-sections through center
subplot(1, 2, 2);
hold on;

% Find indices closest to center
[~, idx_lambda] = min(abs(B.Lambda.axis - center_lambda));
[~, idx_omega] = min(abs(B.Omega.axis - center_omega));

% Lambda cross-section (fix omega at center)
yyaxis left;
plot(B.Lambda.axis, H_joint(:, idx_omega), 'b-', 'LineWidth', 2);
ylabel('Response (λ slice at ω₀)');
xlabel('Spectral Mode (λ)');

% Omega cross-section (fix lambda at center)
yyaxis right;
plot(B.Omega.axis/(2*pi), H_joint(idx_lambda, :), 'r-', 'LineWidth', 2);
ylabel('Response (ω slice at λ₀)');
xlabel('Frequency (Hz)');

title('Gabor Filter Cross-Sections');
legend({'λ-slice (ω=ω₀)', 'ω-slice (λ=λ₀)'}, 'Location', 'best');
grid on;

fprintf('  ✓ Visualization complete\n');

%% Step 7: Test alternative creation methods
fprintf('\nStep 7: Test alternative filter creation methods\n');
fprintf('-------------------------------------------------\n');

% Method 1: Using joint() shortcut
filt1 = designer.joint('gabor', ...
    'center_x', 30, 'center_y', 2*pi*5, ...
    'sigma_x', 10, 'sigma_y', 2*pi*2);
fprintf('  joint() method label: "%s"\n', filt1.Label);

% Method 2: Using joint() with custom label
filt2 = designer.joint('gabor', ...
    'center_x', 30, 'center_y', 2*pi*5, ...
    'sigma_x', 10, 'sigma_y', 2*pi*2, ...
    'label', 'my_custom_gabor');
fprintf('  Custom label: "%s"\n', filt2.Label);

% Method 3: Auto-create Joint domain on-the-fly
filt3 = designer.joint('separable', ...
    'domains', {'Lambda', 'Time'}, ...
    'kernel_x', @(x) exp(-0.5*((x-50)/10).^2), ...
    'kernel_y', @(t) exp(-0.5*((t-1)/0.2).^2));
fprintf('  Auto-created Joint label: "%s"\n', filt3.Label);

%% Summary
fprintf('\n========================================\n');
fprintf('EXAMPLE COMPLETE!\n');
fprintf('========================================\n');
fprintf('Demonstrated:\n');
fprintf('  1. Create Joint domain (Lambda × Omega)\n');
fprintf('  2. Design Gabor filter on joint domain\n');
fprintf('  3. Automatic label generation: kernel_domainA-domainB\n');
fprintf('  4. Filter evaluation on joint grids\n');
fprintf('  5. 2D visualization of joint kernel response\n');
fprintf('  6. Alternative filter creation methods\n');
fprintf('\n');
fprintf('Key concepts:\n');
fprintf('  - Joint domains combine two canonical domains\n');
fprintf('  - Joint grids (A_grid, B_grid) are automatically created\n');
fprintf('  - Automatic labels reflect domain structure: gabor_lambda-omega\n');
fprintf('  - Custom labels can override automatic naming\n');
fprintf('  - Filter.evaluate() uses Joint.A_grid and Joint.B_grid\n');
fprintf('  - 2D kernels (Gabor, separable) require Joint domains\n');
fprintf('========================================\n');
