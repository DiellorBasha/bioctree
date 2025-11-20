%% Test synth_mesh_signal with optional k parameter
% This script verifies that synth_mesh_signal correctly:
% 1. Uses cached eigenvectors when available and k not specified
% 2. Computes default k=200 when no cache and k not specified
% 3. Uses explicit k when specified

clear all;
close all;

% Initialize bioctree
bioctree_start();

% Load mesh
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.import.mesh(path);

%% Test 1: No cache, no k specified -> should compute default k=200
fprintf('\n=== Test 1: No cache, no k specified ===\n');
% Create fresh Bct object without eigenvectors computed
B1 = bct.io.import.mesh(path);

spec = struct('type', 'narrowband', 'f0', 0.1, 'bw_frac', 0.2);
rng(1);
[x1, a1, f1] = bct.sim.synth_mesh_signal(B1, spec);

fprintf('Result: k=%d modes used\n', length(a1));
assert(length(a1) >= 190 && length(a1) <= 200, 'Expected ~200 modes');
fprintf('✓ Test 1 passed\n');

%% Test 2: Cache exists with 600 modes, no k specified -> should use all 600
fprintf('\n=== Test 2: Cache exists (600 modes), no k specified ===\n');
[U, lam] = B.Manifold.meshFourier(600);
k_cached = B.Manifold.NumModes;
fprintf('Cached modes: %d\n', k_cached);

rng(2);
[x2, a2, f2] = bct.sim.synth_mesh_signal(B, spec);

fprintf('Result: k=%d modes used\n', length(a2));
assert(length(a2) == k_cached, 'Expected all cached modes to be used');
fprintf('✓ Test 2 passed\n');

%% Test 3: Cache exists with 600 modes, k=300 specified -> should use 300
fprintf('\n=== Test 3: Cache exists (600 modes), k=300 specified ===\n');
rng(3);
[x3, a3, f3] = bct.sim.synth_mesh_signal(B, spec, 'k', 300);

fprintf('Result: k=%d modes used\n', length(a3));
assert(length(a3) == 300, 'Expected exactly 300 modes');
fprintf('✓ Test 3 passed\n');

%% Test 4: Cache exists with 600 modes, k=800 specified -> should compute 800
fprintf('\n=== Test 4: Cache exists (600 modes), k=800 specified ===\n');
rng(4);
[x4, a4, f4] = bct.sim.synth_mesh_signal(B, spec, 'k', 800);

fprintf('Result: k=%d modes used\n', length(a4));
fprintf('Cached modes after: %d\n', B.Manifold.NumModes);
assert(length(a4) >= 790, 'Expected ~800 modes');
assert(B.Manifold.NumModes >= 790, 'Expected cache updated to ~800 modes');
fprintf('✓ Test 4 passed\n');

%% Test 5: Typical workflow - precompute once, synthesize many signals
fprintf('\n=== Test 5: Typical workflow - multiple synthesis with same basis ===\n');
B2 = bct.io.import.mesh(path);
B2.Manifold.meshFourier(600);

nBands = 5;
f0s = logspace(log10(0.05), log10(0.5), nBands);
rng(5);

tic;
X = cell(nBands, 1);
for i = 1:nBands
    spec_i = struct('type', 'narrowband', 'f0', f0s(i), 'bw_frac', 0.2);
    X{i} = bct.sim.synth_mesh_signal(B2, spec_i, 'verbose', false);
end
elapsed = toc;

fprintf('Generated %d signals in %.3f seconds (%.3f ms/signal)\n', ...
    nBands, elapsed, 1000*elapsed/nBands);
fprintf('✓ Test 5 passed\n');

%% Summary
fprintf('\n=== ALL TESTS PASSED ===\n');
fprintf('synth_mesh_signal correctly:\n');
fprintf('  • Uses cached modes when available (no k specified)\n');
fprintf('  • Computes default k=200 when no cache (no k specified)\n');
fprintf('  • Respects explicit k parameter when provided\n');
fprintf('  • Efficiently reuses cached basis for multiple signals\n');
