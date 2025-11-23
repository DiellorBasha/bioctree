%% Test Joint Non-Separable Transform
% This script demonstrates the non-separable joint transform using a
% custom basis matrix. Non-separable transforms are useful for modeling
% coupled spatiotemporal phenomena that cannot be captured by separable
% (Kronecker product) bases.
%
% Tests:
% 1. Create Joint domain with default separable transform
% 2. Create custom non-separable basis (random orthonormal for demo)
% 3. Switch to non-separable transform
% 4. Test forward/inverse transforms
% 5. Verify perfect reconstruction

clear; clc;

%% Step 1: Create BCT with Joint domain
fprintf('Step 1: Create BCT with Joint Manifold×Time domain\n');
fprintf('---------------------------------------------------\n');

B = bct;

% Create small manifold for demonstration
B.Manifold = bct.Manifold(icosphere(2));  % Smaller for demo
N = B.Manifold.N;
fprintf('  Manifold: N = %d vertices\n', N);

% Create time domain
B.Time = bct.Time(64, 100);  % 64 samples at 100 Hz
T = B.Time.N;
fprintf('  Time: T = %d samples\n', T);

% Joint domain created automatically
fprintf('  Joint Manifold×Time: [%d × %d]\n', B.Joint.size());
fprintf('  Default transform type: %s\n', B.Joint.transformType);
fprintf('  Default transform class: %s\n', class(B.Joint.transform));

%% Step 2: Create custom non-separable basis
fprintf('\nStep 2: Create custom non-separable basis matrix\n');
fprintf('-------------------------------------------------\n');

% For demonstration, create a random orthonormal basis
% In practice, this could be wave packets, Gabor atoms, etc.
rng(42);  % For reproducibility

% Input/output sizes
sizeIn = [N, T];
N_modes = N;      % Number of spatial modes
T_modes = T;      % Number of temporal modes
sizeOut = [N_modes, T_modes];

% Total dimensions
dim_in = prod(sizeIn);    % N*T
dim_out = prod(sizeOut);  % N_modes*T_modes

fprintf('  Input dimensions: [%d × %d] = %d\n', N, T, dim_in);
fprintf('  Output dimensions: [%d × %d] = %d\n', N_modes, T_modes, dim_out);

% Create random orthonormal basis using QR decomposition
fprintf('  Creating random orthonormal basis...\n');
[Phi, ~] = qr(randn(dim_in, dim_out), 0);
Phi = Phi';  % Transpose to get [dim_out × dim_in]

fprintf('  Basis matrix Φ: [%d × %d]\n', size(Phi, 1), size(Phi, 2));

% Verify orthonormality
orthonormality_error = norm(Phi' * Phi - eye(dim_out), 'fro');
fprintf('  Orthonormality error: %.2e (should be ≈0)\n', orthonormality_error);

%% Step 3: Switch to non-separable transform
fprintf('\nStep 3: Set Joint to use non-separable transform\n');
fprintf('-------------------------------------------------\n');

B.Joint.setTransformType('NonSeparable', Phi, sizeOut);

fprintf('  Transform type: %s\n', B.Joint.transformType);
fprintf('  Transform class: %s\n', class(B.Joint.transform));
fprintf('  Transform metadata:\n');
disp(B.Joint.transform.metadata);

%% Step 4: Test forward transform
fprintf('\nStep 4: Test forward transform\n');
fprintf('-------------------------------\n');

% Create test signal (random spatiotemporal pattern)
X_test = randn(N, T);
fprintf('  Test signal dimensions: [%d × %d]\n', size(X_test, 1), size(X_test, 2));
fprintf('  Test signal energy: %.6f\n', norm(X_test(:)));

% Apply forward transform
X_hat = B.Joint.transform.forward(X_test);

fprintf('  Transformed signal dimensions: [%d × %d]\n', size(X_hat, 1), size(X_hat, 2));
fprintf('  Transformed signal energy: %.6f\n', norm(X_hat(:)));

% For orthonormal basis, energy is preserved
energy_ratio = norm(X_hat(:)) / norm(X_test(:));
fprintf('  Energy ratio: %.6f (should be ≈1 for orthonormal basis)\n', energy_ratio);

%% Step 5: Test inverse transform and reconstruction
fprintf('\nStep 5: Test inverse transform and reconstruction\n');
fprintf('--------------------------------------------------\n');

% Apply inverse transform
X_recon = B.Joint.transform.inverse(X_hat);

fprintf('  Reconstructed signal dimensions: [%d × %d]\n', ...
    size(X_recon, 1), size(X_recon, 2));

% Check reconstruction error
recon_error = norm(X_recon(:) - X_test(:)) / norm(X_test(:));
fprintf('  Relative reconstruction error: %.2e\n', recon_error);

% For orthonormal basis, reconstruction should be perfect
assert(recon_error < 1e-10, 'Reconstruction error should be negligible');
fprintf('  ✓ Perfect reconstruction verified!\n');

%% Step 6: Test with Signal object
fprintf('\nStep 6: Test with Signal object\n');
fprintf('--------------------------------\n');

% Create signal on Joint domain
sig = bct.Signal(B.Joint, X_test, 'Test Spatiotemporal Signal');

fprintf('  Signal label: %s\n', sig.Label);
fprintf('  Signal domain: %s\n', sig.Domain.Domain);
fprintf('  Signal dimensions: [%d × %d]\n', size(sig.Data, 1), size(sig.Data, 2));

% Transform signal data
sig_hat = B.Joint.transform.forward(sig.Data);
fprintf('  Transformed signal dimensions: [%d × %d]\n', size(sig_hat, 1), size(sig_hat, 2));

%% Step 7: Compare with separable transform
fprintf('\nStep 7: Compare separable vs non-separable\n');
fprintf('-------------------------------------------\n');

% Create another test signal
X_compare = randn(N, T);

% Save non-separable result
X_nonsep = B.Joint.transform.forward(X_compare);

% Switch back to separable
B.Joint.setTransformType('Separable');
fprintf('  Switched to transform type: %s\n', B.Joint.transformType);

% Get separable result
X_sep = B.Joint.transform.forward(X_compare);

% Compare results
fprintf('  Separable result dimensions: [%d × %d]\n', size(X_sep, 1), size(X_sep, 2));
fprintf('  Non-separable result dimensions: [%d × %d]\n', size(X_nonsep, 1), size(X_nonsep, 2));

% They will generally be different (unless Phi happens to be separable)
difference = norm(X_sep(:) - X_nonsep(:)) / norm(X_sep(:));
fprintf('  Relative difference: %.4f\n', difference);
fprintf('  Note: Non-zero difference expected - different transform types!\n');

%% Step 8: Verify transform properties
fprintf('\nStep 8: Verify non-separable transform properties\n');
fprintf('--------------------------------------------------\n');

% Switch back to non-separable for final tests
B.Joint.setTransformType('NonSeparable', Phi, sizeOut);

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
X_id = randn(N, T);
X_id_hat = B.Joint.transform.forward(X_id);
X_id_recon = B.Joint.transform.inverse(X_id_hat);

identity_error = norm(X_id_recon(:) - X_id(:)) / norm(X_id(:));
fprintf('  Identity error: %.2e (should be ≈0)\n', identity_error);
assert(identity_error < 1e-10, 'Transform should satisfy T^(-1)(T(x)) = x');

fprintf('  ✓ Linearity and identity verified!\n');

%% All tests passed!
fprintf('\n========================================\n');
fprintf('ALL TESTS PASSED!\n');
fprintf('Joint non-separable transform working correctly.\n');
fprintf('Transform type can be switched between Separable and NonSeparable.\n');
fprintf('========================================\n');
