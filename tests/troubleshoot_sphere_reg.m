%% Troubleshoot sphere.reg UV Computation
% Investigate why UV parametrization results in imaginary numbers

clear all;
close all;

% Get script directory and navigate to project root
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(script_dir);
cd(project_root);

% Add toolbox to path
addpath(fullfile(project_root, 'toolbox'));

fprintf('=== Troubleshooting sphere.reg UV Computation ===\n\n');

%% Load sphere.reg file
sphere_path = fullfile(project_root, 'test-data', 'freesurfer', 'fsaverage', 'surf', 'lh.sphere.reg');

fprintf('Loading sphere.reg file...\n');
fprintf('  Path: %s\n', sphere_path);

if ~isfile(sphere_path)
    fprintf('  ERROR: File not found!\n');
    return;
end

sphere_raw = bct.io.in.readFreeSurferSurf(sphere_path);

fprintf('  ✓ Loaded successfully\n');
fprintf('  Vertices: %d\n', size(sphere_raw.V, 1));
fprintf('  Faces: %d\n\n', size(sphere_raw.F, 1));

%% Analyze sphere vertices
V_sphere = sphere_raw.V;

fprintf('Analyzing sphere vertex coordinates...\n');

% Check dimensions
fprintf('  Dimensions: [%d × %d]\n', size(V_sphere, 1), size(V_sphere, 2));

% Extract coordinates
x = V_sphere(:, 1);
y = V_sphere(:, 2);
z = V_sphere(:, 3);

fprintf('  X range: [%.4f, %.4f]\n', min(x), max(x));
fprintf('  Y range: [%.4f, %.4f]\n', min(y), max(y));
fprintf('  Z range: [%.4f, %.4f]\n\n', min(z), max(z));

% Check if on unit sphere
radius = sqrt(x.^2 + y.^2 + z.^2);
fprintf('Radius analysis:\n');
fprintf('  Min radius: %.6f\n', min(radius));
fprintf('  Max radius: %.6f\n', max(radius));
fprintf('  Mean radius: %.6f\n', mean(radius));
fprintf('  Std radius: %.6f\n\n', std(radius));

%% Check for problematic z values
fprintf('Checking Z coordinate issues...\n');

% Z should be in [-1, 1] for valid sphere coordinates
z_min = min(z);
z_max = max(z);
fprintf('  Z range: [%.6f, %.6f]\n', z_min, z_max);

% Check for values outside [-1, 1]
z_too_small = sum(z < -1);
z_too_large = sum(z > 1);

fprintf('  Vertices with z < -1: %d\n', z_too_small);
fprintf('  Vertices with z > 1: %d\n', z_too_large);

if z_too_large > 0
    fprintf('  WARNING: Z values > 1 will cause imaginary acos!\n');
    fprintf('  Max Z value: %.10f\n', z_max);
    fprintf('  Vertices affected: %d (%.2f%%)\n', z_too_large, 100*z_too_large/length(z));
end

if z_too_small > 0
    fprintf('  WARNING: Z values < -1 will cause imaginary acos!\n');
    fprintf('  Min Z value: %.10f\n', z_min);
    fprintf('  Vertices affected: %d (%.2f%%)\n', z_too_small, 100*z_too_small/length(z));
end

fprintf('\n');

%% Test spherical coordinate conversion
fprintf('Testing spherical coordinate conversion...\n');

% Original computation (from computeUVFromSphere)
fprintf('  Method 1: Direct acos(z)\n');
theta = atan2(y, x);
phi = acos(z);  % This will produce imaginary if |z| > 1

fprintf('    Theta range: [%.4f, %.4f]\n', min(theta), max(theta));
fprintf('    Phi complex?: %d\n', any(~isreal(phi)));
if any(~isreal(phi))
    fprintf('    Phi has imaginary parts!\n');
    fprintf('    Real part range: [%.4f, %.4f]\n', min(real(phi)), max(real(phi)));
    fprintf('    Imag part range: [%.4f, %.4f]\n', min(imag(phi)), max(imag(phi)));
end

% UV computation
u = (theta + pi) / (2 * pi);
v = phi / pi;

fprintf('    U complex?: %d\n', any(~isreal(u)));
fprintf('    V complex?: %d\n', any(~isreal(v)));

if any(~isreal(v))
    fprintf('    V has imaginary parts!\n');
    fprintf('    Real part range: [%.4f, %.4f]\n', min(real(v)), max(real(v)));
    fprintf('    Imag part range: [%.4f, %.4f]\n', min(imag(v)), max(imag(v)));
end

fprintf('\n');

%% Test clamping approach
fprintf('Method 2: Clamping z to [-1, 1] before acos\n');

z_clamped = z;
z_clamped(z > 1) = 1;
z_clamped(z < -1) = -1;

phi_clamped = acos(z_clamped);

fprintf('  Vertices clamped: %d\n', sum(z ~= z_clamped));
fprintf('  Phi complex?: %d\n', any(~isreal(phi_clamped)));
fprintf('  Phi range: [%.4f, %.4f]\n', min(phi_clamped), max(phi_clamped));

v_clamped = phi_clamped / pi;
fprintf('  V range: [%.4f, %.4f]\n', min(v_clamped), max(v_clamped));
fprintf('  V complex?: %d\n', any(~isreal(v_clamped)));

fprintf('\n');

%% Test normalization approach
fprintf('Method 3: Normalize vertices to unit sphere first\n');

% Normalize to unit sphere
V_norm = V_sphere ./ sqrt(sum(V_sphere.^2, 2));

z_norm = V_norm(:, 3);
fprintf('  Z_norm range: [%.10f, %.10f]\n', min(z_norm), max(z_norm));
fprintf('  Z_norm > 1: %d\n', sum(z_norm > 1));
fprintf('  Z_norm < -1: %d\n', sum(z_norm < -1));

phi_norm = acos(z_norm);
fprintf('  Phi complex?: %d\n', any(~isreal(phi_norm)));

if any(~isreal(phi_norm))
    % Even after normalization, numerical errors might occur
    z_norm_clamped = max(-1, min(1, z_norm));
    phi_norm = acos(z_norm_clamped);
    fprintf('  After numerical clamping:\n');
    fprintf('    Phi complex?: %d\n', any(~isreal(phi_norm)));
end

theta_norm = atan2(V_norm(:, 2), V_norm(:, 1));
u_norm = (theta_norm + pi) / (2 * pi);
v_norm = phi_norm / pi;

fprintf('  U range: [%.4f, %.4f]\n', min(u_norm), max(u_norm));
fprintf('  V range: [%.4f, %.4f]\n', min(v_norm), max(v_norm));
fprintf('  U complex?: %d\n', any(~isreal(u_norm)));
fprintf('  V complex?: %d\n', any(~isreal(v_norm)));

fprintf('\n');

%% Visualize problematic vertices
fprintf('Analyzing problematic vertices...\n');

% Find vertices with |z| > 1
problematic_idx = find(abs(z) > 1);
fprintf('  Total problematic vertices: %d (%.2f%%)\n', ...
    length(problematic_idx), 100*length(problematic_idx)/length(z));

if length(problematic_idx) > 0
    fprintf('  Showing first 10 problematic vertices:\n');
    for i = 1:min(10, length(problematic_idx))
        idx = problematic_idx(i);
        fprintf('    Vertex %d: [%.6f, %.6f, %.6f], radius=%.6f, z=%.6f\n', ...
            idx, x(idx), y(idx), z(idx), radius(idx), z(idx));
    end
end

fprintf('\n');

%% Statistical analysis of the issue
fprintf('Statistical Analysis:\n');

% How far are vertices from unit sphere?
radius_error = abs(radius - 100);  % Assuming sphere radius ~100
fprintf('  Radius deviation from 100:\n');
fprintf('    Mean: %.6f\n', mean(radius_error));
fprintf('    Max: %.6f\n', max(radius_error));

% How much do we need to clamp?
z_clamp_amount = abs(z - z_clamped);
if sum(z_clamp_amount) > 0
    fprintf('  Z clamping statistics:\n');
    fprintf('    Vertices needing clamp: %d\n', sum(z_clamp_amount > 0));
    fprintf('    Mean clamp amount: %.10f\n', mean(z_clamp_amount(z_clamp_amount > 0)));
    fprintf('    Max clamp amount: %.10f\n', max(z_clamp_amount));
end

fprintf('\n');

%% Recommended solution
fprintf('=== RECOMMENDED SOLUTION ===\n\n');

fprintf('The sphere.reg vertices are NOT on a unit sphere.\n');
fprintf('Actual sphere radius appears to be: %.2f\n', mean(radius));
fprintf('\n');

fprintf('Issue: acos() requires input in [-1, 1]\n');
fprintf('Current z range: [%.6f, %.6f]\n', min(z), max(z));
fprintf('After normalization: [%.10f, %.10f]\n', min(z_norm), max(z_norm));
fprintf('\n');

fprintf('Proposed fix in computeUVFromSphere:\n');
fprintf('  1. Normalize vertices to unit sphere: V_norm = V / ||V||\n');
fprintf('  2. Clamp z to [-1, 1] for numerical stability\n');
fprintf('  3. Then compute phi = acos(z_clamped)\n');
fprintf('\n');

fprintf('Code suggestion:\n');
fprintf('  V_norm = V_sphere ./ sqrt(sum(V_sphere.^2, 2));\n');
fprintf('  z = V_norm(:, 3);\n');
fprintf('  z = max(-1, min(1, z));  %% Clamp to [-1, 1]\n');
fprintf('  phi = acos(z);\n');
fprintf('\n');

%% Create visualization
figure('Position', [100 100 1400 800]);

% Plot 1: Sphere vertices
subplot(2, 3, 1);
scatter3(x, y, z, 1, radius, 'filled');
axis equal;
xlabel('X'); ylabel('Y'); zlabel('Z');
title('Sphere Vertices (colored by radius)');
colorbar;

% Plot 2: Z distribution
subplot(2, 3, 2);
histogram(z, 100);
hold on;
xline(-1, 'r--', 'LineWidth', 2);
xline(1, 'r--', 'LineWidth', 2);
xlabel('Z coordinate');
ylabel('Count');
title('Z Distribution (red lines = ±1)');
grid on;

% Plot 3: Radius distribution
subplot(2, 3, 3);
histogram(radius, 100);
xlabel('Radius');
ylabel('Count');
title(sprintf('Radius Distribution (mean=%.2f)', mean(radius)));
grid on;

% Plot 4: Original UV (with imaginary)
subplot(2, 3, 4);
scatter(real(u), real(v), 1, 'filled');
xlabel('U (real part)');
ylabel('V (real part)');
title('Original UV (real parts only)');
axis equal tight;
grid on;

% Plot 5: Clamped UV
subplot(2, 3, 5);
scatter(u_norm, v_norm, 1, 'filled');
xlabel('U');
ylabel('V');
title('Fixed UV (normalized + clamped)');
axis equal tight;
grid on;

% Plot 6: Difference
subplot(2, 3, 6);
scatter(real(u) - u_norm, real(v) - v_norm, 1, 'filled');
xlabel('ΔU');
ylabel('ΔV');
title('Difference (original - fixed)');
axis equal;
grid on;

sgtitle('sphere.reg UV Computation Analysis', 'FontSize', 14, 'FontWeight', 'bold');

fprintf('Visualization created.\n');

