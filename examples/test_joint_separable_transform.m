%% Test Joint Separable Transform
% This script tests the JointSeparable transform that composes 1D spatial
% and temporal transforms into a separable 2D transform.
%
% Tests:
% 1. Create Joint Manifold×Time domain with automatic transform
% 2. Create test spatiotemporal signal
% 3. Apply forward transform (space-time → spectral-frequency)
% 4. Apply inverse transform (verify reconstruction)
% 5. Test transform metadata

clear; clc;

%% Step 1: Create BCT object with all domains
fprintf('Step 1: Create BCT with Manifold and Time\n');
fprintf('------------------------------------------\n');

B = bct;

% Create icosphere manifold (automatically creates Lambda)
B.Manifold = bct.Manifold(icosphere(3));
fprintf('  Manifold: N = %d vertices\n', B.Manifold.N);

% Verify Lambda was created
assert(~isempty(B.Lambda), 'Lambda should be auto-created');
fprintf('  Lambda: N = %d modes\n', B.Lambda.N);

% Create time domain (automatically creates Omega and Joint domains)
B.Time = bct.Time(128, 100);  % 128 samples at 100 Hz
fprintf('  Time: T = %d samples at %.0f Hz\n', B.Time.N, B.Time.fs);

% Verify Omega was created
assert(~isempty(B.Omega), 'Omega should be auto-created');
fprintf('  Omega: T = %d frequencies\n', B.Omega.N);

% Verify Joint domains were created
assert(~isempty(B.Joint), 'Joint Manifold×Time should be auto-created');
fprintf('  Joint Manifold×Time: [%d × %d]\n', B.Joint.size());

%% Step 2: Verify transforms exist on constituent domains
fprintf('\nStep 2: Verify constituent domain transforms\n');
fprintf('---------------------------------------------\n');

assert(~isempty(B.Manifold.transform), 'Manifold should have transform');
fprintf('  Manifold.transform: %s\n', class(B.Manifold.transform));

assert(~isempty(B.Time.transform), 'Time should have transform');
fprintf('  Time.transform: %s\n', class(B.Time.transform));

%% Step 3: Verify Joint transform was created
fprintf('\nStep 3: Verify Joint domain has separable transform\n');
fprintf('----------------------------------------------------\n');

assert(~isempty(B.Joint.transform), 'Joint should have transform');
fprintf('  Joint.transform: %s\n', class(B.Joint.transform));

% Check it's the right type
assert(isa(B.Joint.transform, 'bct.factory.transforms.JointSeparable'), ...
    'Joint transform should be JointSeparable');

% Check metadata
fprintf('  Transform type: %s\n', B.Joint.transform.metadata.type);
fprintf('  Spatial transform: %s\n', B.Joint.transform.metadata.spatialType);
fprintf('  Temporal transform: %s\n', B.Joint.transform.metadata.timeType);

%% Step 4: Verify dual Joint also has transform
fprintf('\nStep 4: Verify dual Joint (Lambda×Omega) has transform\n');
fprintf('-------------------------------------------------------\n');

assert(~isempty(B.Joint.dual), 'Joint should have dual');
fprintf('  Joint.dual: %s\n', B.Joint.dual.Domain);

assert(~isempty(B.Joint.dual.transform), 'Dual Joint should have transform');
fprintf('  Dual Joint.transform: %s\n', class(B.Joint.dual.transform));

%% Step 5: Create test spatiotemporal signal
fprintf('\nStep 5: Create test spatiotemporal signal\n');
fprintf('------------------------------------------\n');

% Create a simple test signal: spatial mode + temporal oscillation
N = B.Manifold.N;
T = B.Time.N;

% Get a spatial mode (e.g., mode 5)
spatial_mode = zeros(N, 1);
spatial_mode(5) = 1;
X_spatial = B.Manifold.transform.inverse(spatial_mode);  % Convert to vertex space

% Create temporal oscillation (e.g., 10 Hz)
t_axis = B.Time.axis;
temporal_signal = sin(2*pi*10 * t_axis);  % 10 Hz sine wave

% Create separable spatiotemporal signal
X_spacetime = X_spatial * temporal_signal';  % [N×T] outer product

fprintf('  Signal dimensions: [%d × %d]\n', size(X_spacetime, 1), size(X_spacetime, 2));
fprintf('  Signal energy: %.6f\n', norm(X_spacetime(:)));

%% Step 6: Apply forward Joint transform
fprintf('\nStep 6: Apply forward Joint transform\n');
fprintf('--------------------------------------\n');

% Transform space-time → spectral-frequency
X_hat = B.Joint.transform.forward(X_spacetime);

fprintf('  Transformed signal dimensions: [%d × %d]\n', size(X_hat, 1), size(X_hat, 2));
fprintf('  Transformed signal energy: %.6f\n', norm(X_hat(:)));

% Energy should be preserved (Parseval's theorem)
energy_ratio = norm(X_hat(:)) / norm(X_spacetime(:));
fprintf('  Energy ratio (should be ≈1): %.6f\n', energy_ratio);

%% Step 7: Check concentration in spectral-frequency domain
fprintf('\nStep 7: Check spectral-frequency concentration\n');
fprintf('-----------------------------------------------\n');

% Find peak in spectral domain
[max_val, max_idx] = max(abs(X_hat(:)));
[k_max, f_max] = ind2sub(size(X_hat), max_idx);

fprintf('  Peak at spatial mode k=%d, frequency index f=%d\n', k_max, f_max);
fprintf('  Peak magnitude: %.6f\n', max_val);

% Should be concentrated near mode 5 in spatial, and 10 Hz in temporal
fprintf('  Expected: k≈5, f near 10 Hz\n');

% Find frequency corresponding to f_max
freq_Hz = B.Omega.axis(f_max) / (2*pi);  % Convert angular freq to Hz
fprintf('  Actual frequency at peak: %.2f Hz\n', freq_Hz);

%% Step 8: Apply inverse Joint transform
fprintf('\nStep 8: Apply inverse Joint transform and verify reconstruction\n');
fprintf('----------------------------------------------------------------\n');

% Transform back: spectral-frequency → space-time
X_reconstructed = B.Joint.transform.inverse(X_hat);

fprintf('  Reconstructed signal dimensions: [%d × %d]\n', ...
    size(X_reconstructed, 1), size(X_reconstructed, 2));

% Check reconstruction error
reconstruction_error = norm(X_reconstructed(:) - X_spacetime(:)) / norm(X_spacetime(:));
fprintf('  Relative reconstruction error: %.2e\n', reconstruction_error);

% Should be very small (numerical precision)
assert(reconstruction_error < 1e-10, ...
    'Reconstruction error should be negligible (< 1e-10)');

fprintf('  ✓ Perfect reconstruction verified!\n');

%% Step 9: Test with delta signal
fprintf('\nStep 9: Test transform with spatiotemporal delta\n');
fprintf('-------------------------------------------------\n');

% Create delta at vertex 50, time 60
delta = bct.Signal.createDelta(B.Joint, 50, 60);
fprintf('  Delta signal at (v=50, t=60)\n');

% Transform to spectral-frequency domain
delta_hat = B.Joint.transform.forward(delta.Data);

fprintf('  Transformed delta dimensions: [%d × %d]\n', size(delta_hat, 1), size(delta_hat, 2));
fprintf('  Transformed delta max: %.6f\n', max(abs(delta_hat(:))));

% Inverse transform
delta_recon = B.Joint.transform.inverse(delta_hat);

% Verify reconstruction
delta_error = norm(delta_recon(:) - delta.Data(:)) / norm(delta.Data(:));
fprintf('  Delta reconstruction error: %.2e\n', delta_error);

assert(delta_error < 1e-10, 'Delta reconstruction should be perfect');
fprintf('  ✓ Delta reconstruction verified!\n');

%% Step 10: Test transform properties
fprintf('\nStep 10: Verify transform properties\n');
fprintf('-------------------------------------\n');

% Test linearity: T(ax + by) = a*T(x) + b*T(y)
X1 = randn(N, T);
X2 = randn(N, T);
a = 2.5;
b = -1.3;

T_sum = B.Joint.transform.forward(a*X1 + b*X2);
sum_T = a*B.Joint.transform.forward(X1) + b*B.Joint.transform.forward(X2);

linearity_error = norm(T_sum(:) - sum_T(:)) / norm(T_sum(:));
fprintf('  Linearity error: %.2e (should be ≈0)\n', linearity_error);
assert(linearity_error < 1e-10, 'Transform should be linear');

% Test identity: T^(-1)(T(x)) = x
X_test = randn(N, T);
X_test_hat = B.Joint.transform.forward(X_test);
X_test_recon = B.Joint.transform.inverse(X_test_hat);

identity_error = norm(X_test_recon(:) - X_test(:)) / norm(X_test(:));
fprintf('  Identity error: %.2e (should be ≈0)\n', identity_error);
assert(identity_error < 1e-10, 'Transform should satisfy T^(-1)(T(x)) = x');

fprintf('  ✓ Linearity and identity verified!\n');

%% All tests passed!
fprintf('\n========================================\n');
fprintf('ALL TESTS PASSED!\n');
fprintf('JointSeparable transform working correctly.\n');
fprintf('========================================\n');
