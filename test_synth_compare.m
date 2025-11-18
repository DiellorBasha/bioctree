%% Test comparison between original and new synth_mesh_signal
% This script verifies that bct.sim.synth_mesh_signal exactly replicates
% the original synth_mesh_signal function

clear all;
close all;

% Initialize bioctree
bioctree_start();

% Load mesh
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.import.mesh(path);

% Compute Fourier basis
k = 600;
[U, lam, ~, M] = B.Manifold.meshFourier(k);
d = full(diag(M));

% Get actual number of modes (may be less than k due to DC filtering)
k_actual = size(U, 2);
fprintf('Requested k=%d, got k_actual=%d modes\n', k, k_actual);

% Compute frequency range
f_all = sqrt(lam)/(2*pi);
fmin = min(f_all(f_all>0));
fmax = max(f_all);

% Keep a little margin away from edges
lo = 1.15;
hi = 0.85;
f_lo = lo*fmin;
f_hi = hi*fmax;

% Test with narrowband
nBands = 5;
f0s = logspace(log10(f_lo), log10(f_hi), nBands);
bw_frac = 0.20;

% Test one band with SAME random seed
f0 = f0s(3);  % Middle band
spec = struct('type', 'narrowband', ...
              'f0', f0, ...
              'bw_frac', bw_frac);

%% Test 1: Original function
fprintf('\n=== Testing ORIGINAL synth_mesh_signal ===\n');
rng(42);  % Set seed
[x_orig, a_orig, f_orig] = synth_mesh_signal(U, lam, d, spec);

%% Test 2: New function
fprintf('\n=== Testing NEW bct.sim.synth_mesh_signal ===\n');
rng(42);  % Same seed
[x_new, a_new, f_new] = bct.sim.synth_mesh_signal(B, spec, 'k', k_actual, 'verbose', false);

%% Compare results
fprintf('\n=== COMPARISON ===\n');

% Check if frequencies match
freq_match = all(abs(f_orig - f_new) < 1e-10);
fprintf('Frequencies match: %d\n', freq_match);
if ~freq_match
    fprintf('  Max difference: %.2e\n', max(abs(f_orig - f_new)));
end

% Check if coefficients match
coeff_match = all(abs(a_orig - a_new) < 1e-6);
fprintf('Coefficients match: %d\n', coeff_match);
if ~coeff_match
    fprintf('  Max difference: %.2e\n', max(abs(a_orig - a_new)));
    fprintf('  Mean difference: %.2e\n', mean(abs(a_orig - a_new)));
end

% Check if signals match
signal_match = all(abs(x_orig - double(x_new)) < 1e-6);
fprintf('Signals match: %d\n', signal_match);
if ~signal_match
    fprintf('  Max difference: %.2e\n', max(abs(x_orig - double(x_new))));
    fprintf('  Mean difference: %.2e\n', mean(abs(x_orig - double(x_new))));
end

%% Plot power spectra
P_orig = a_orig.^2;
P_new = a_new.^2;

figure('Position', [100 100 1200 400]);

subplot(1,3,1);
[fs, idx] = sort(f_orig);
plot(fs, P_orig(idx), '.-', 'LineWidth', 1.5, 'DisplayName', 'Original');
hold on;
[fs, idx] = sort(f_new);
plot(fs, P_new(idx), 'o-', 'LineWidth', 1.5, 'DisplayName', 'New');
xlabel('Frequency (cycles/mm)');
ylabel('Power');
title('Power Spectra Comparison');
legend('Location', 'best');
grid on;

subplot(1,3,2);
[fs, idx] = sort(f_orig);
plot(fs, abs(P_orig(idx) - P_new(idx)), '.-', 'LineWidth', 1.5);
xlabel('Frequency (cycles/mm)');
ylabel('|P_{orig} - P_{new}|');
title('Absolute Power Difference');
grid on;

subplot(1,3,3);
histogram(x_orig - double(x_new), 50);
xlabel('x_{orig} - x_{new}');
ylabel('Count');
title('Signal Difference Distribution');
grid on;

%% Summary
if freq_match && coeff_match && signal_match
    fprintf('\n✓ SUCCESS: Functions produce identical results\n');
else
    fprintf('\n✗ FAILURE: Functions produce different results\n');
end

%% Test 3: Default behavior (uses cached modes)
fprintf('\n=== Testing DEFAULT behavior (no k specified) ===\n');
B2 = bct.io.import.mesh(path);
B2.Manifold.meshFourier(300);  % Cache 300 modes
fprintf('Cached %d modes in B2.Manifold\n', B2.Manifold.NumModes);

rng(99);
spec2 = struct('type', 'narrowband', 'f0', f0s(2), 'bw_frac', 0.15);
[x_default, a_default, f_default] = bct.sim.synth_mesh_signal(B2, spec2, 'verbose', true);

fprintf('✓ Generated signal using %d cached modes (no k specified)\n', length(a_default));

%% Test 4: Requesting fewer modes than cached
fprintf('\n=== Testing with k < cached modes ===\n');
rng(77);
[x_subset, a_subset, f_subset] = bct.sim.synth_mesh_signal(B2, spec2, 'k', 150, 'verbose', true);
fprintf('✓ Generated signal using %d modes (requested k=150, cached=%d)\n', ...
    length(a_subset), B2.Manifold.NumModes);

if length(a_subset) == 150
    fprintf('✓ Correctly used requested k=150\n');
else
    fprintf('✗ Expected 150 modes, got %d\n', length(a_subset));
end

%% Test 5: No cached modes (should compute default 200)
fprintf('\n=== Testing with no cached modes ===\n');
B3 = bct.io.import.mesh(path);
fprintf('B3.Manifold.NumModes = %d (no cache)\n', B3.Manifold.NumModes);

rng(55);
[x_nocache, a_nocache, f_nocache] = bct.sim.synth_mesh_signal(B3, spec2, 'verbose', true);
fprintf('✓ Generated signal with %d modes (auto-computed default)\n', length(a_nocache));
