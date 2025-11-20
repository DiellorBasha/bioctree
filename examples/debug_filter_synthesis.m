%% Debug Filter Synthesis - Diagnose why signals are mostly zero
%
% This script helps diagnose issues with Bct.Synthesize/Generate
%
% Author: BioCTree Project
% Date: 2025-11-19

clear; clc;

%% Setup
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.import.mesh(path);

fprintf('=== Mesh Info ===\n');
fprintf('Vertices: %d\n', B.Manifold.N);
fprintf('Lambda max: %.2e\n', B.Manifold.Resolution.lambda_max);

%% Design filter
lambda_band = [10000, 30000];
fprintf('\n=== Filter Design ===\n');
fprintf('Requested lambda band: [%.0f, %.0f]\n', lambda_band(1), lambda_band(2));

filt = B.designFilter(lambda_band, 'lambda', 'band', 'label', 'test');

% Check filter response on support
fprintf('Filter lambda_support range: [%.2e, %.2e]\n', ...
    min(filt.lambda_support), max(filt.lambda_support));
fprintf('Filter g_support range: [%.4f, %.4f]\n', ...
    min(filt.g_support), max(filt.g_support));
fprintf('Non-zero g_support: %d / %d\n', ...
    sum(filt.g_support > 0.01), length(filt.g_support));

%% Synthesize with diagnostics
fprintf('\n=== Synthesis ===\n');
numModes = 100;
B.Synthesize('test', 'numModes', numModes);

% Check what eigenvalues were actually used
lambda_vec = B.SpectralGrid.lambda_band;
fprintf('Actual eigenvalues used: %d modes\n', length(lambda_vec));
fprintf('Eigenvalue range: [%.2e, %.2e]\n', min(lambda_vec), max(lambda_vec));

% How many fall in requested band?
in_band = (lambda_vec >= lambda_band(1)) & (lambda_vec <= lambda_band(2));
fprintf('Modes in requested band: %d / %d (%.1f%%)\n', ...
    sum(in_band), length(lambda_vec), 100*sum(in_band)/length(lambda_vec));

% Check filter response at actual eigenvalues
g_vals = filt.getResponse(lambda_vec);
fprintf('\nFilter response at eigenvalues:\n');
fprintf('  g range: [%.4f, %.4f]\n', min(g_vals), max(g_vals));
fprintf('  Non-zero g: %d / %d\n', sum(g_vals > 0.01), length(g_vals));
fprintf('  Power sum: %.4f\n', sum(g_vals.^2));

% Check spectral coefficients
A_kl = B.SpectralCoefficients;
fprintf('\nSpectral coefficients:\n');
fprintf('  Size: %d × %d\n', size(A_kl, 1), size(A_kl, 2));
fprintf('  Range: [%.4f, %.4f]\n', min(abs(A_kl(:))), max(abs(A_kl(:))));
fprintf('  Non-zero: %d / %d\n', sum(abs(A_kl(:)) > 1e-10), numel(A_kl));

%% Generate signal
fprintf('\n=== Signal Generation ===\n');
sig = B.Generate();

fprintf('Signal range: [%.4f, %.4f]\n', min(sig.Data), max(sig.Data));
fprintf('Signal std: %.4f\n', std(sig.Data));
fprintf('Near-zero values: %d / %d (%.1f%%)\n', ...
    sum(abs(sig.Data) < 1e-6), length(sig.Data), ...
    100*sum(abs(sig.Data) < 1e-6)/length(sig.Data));

%% Compare with synth_mesh_signal approach
fprintf('\n=== Comparison: synth_mesh_signal approach ===\n');

% Use same eigenvalues but with narrowband spec
spec.type = 'bandpass';
spec.fmin = sqrt(lambda_band(1)) / (2*pi);
spec.fmax = sqrt(lambda_band(2)) / (2*pi);

B_ref = bct.sim.synth_mesh_signal(B, spec, 'k', numModes, 'label', 'reference');
sig_ref = B_ref.Signals{end};

fprintf('Reference signal range: [%.4f, %.4f]\n', min(sig_ref.Data), max(sig_ref.Data));
fprintf('Reference signal std: %.4f\n', std(sig_ref.Data));

%% Diagnosis
fprintf('\n=== DIAGNOSIS ===\n');
if sum(in_band) < 10
    fprintf('⚠ PROBLEM: Only %d modes in requested band!\n', sum(in_band));
    fprintf('   Most eigenvalues are OUTSIDE your filter band.\n');
    fprintf('   Solution: Use a wider lambda band or request fewer modes.\n');
end

if sum(g_vals > 0.01) < 10
    fprintf('⚠ PROBLEM: Filter response is near-zero for most modes!\n');
    fprintf('   Only %d/%d modes have significant filter response.\n', sum(g_vals > 0.01), length(g_vals));
    fprintf('   This creates a signal with very low power.\n');
end

fprintf('\n=== Recommended Fix ===\n');
fprintf('Option 1: Use a broader lambda band\n');
fprintf('  Try: [%.0f, %.0f] (10%% to 95%% of lambda_max)\n', ...
    0.1*B.Manifold.Resolution.lambda_max, 0.95*B.Manifold.Resolution.lambda_max);
fprintf('\nOption 2: Request fewer modes (only those in band)\n');
fprintf('  Estimate modes in band and request that number\n');
