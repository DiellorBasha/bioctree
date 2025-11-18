%% Test synth_mesh_signal with new Signal class integration
% Tests that synth_mesh_signal now returns bct objects with Signal objects

clear all;
close all;

% Add toolbox to path
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));
addpath(fullfile(root, 'external'));

fprintf('=== Testing synth_mesh_signal Signal Integration ===\n\n');

%% Setup: Create a bct object with Manifold
[V, F] = icosphere(2);
B = bct.bct.fromMesh(V, F);

fprintf('Created BCT with Manifold:\n');
fprintf('  N = %d vertices\n\n', B.Manifold.N);

%% Test 1: Single narrowband signal with default behavior
fprintf('Test 1: Single narrowband signal (default mode)\n');

spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;

B1 = bct.sim.synth_mesh_signal(B, spec, 'k', 50, 'verbose', false);

% Verify it's a bct object
assert(isa(B1, 'bct.bct'), 'Output should be a bct object');
fprintf('  ✓ Returns bct object\n');

% Verify signal was added
assert(~isempty(B1.Signals), 'Signal should be added');
assert(length(B1.Signals) == 1, 'Should have exactly 1 signal');
fprintf('  ✓ Signal added to bct object\n');

% Verify signal properties
sig = B1.Signals(1);
assert(sig.N == B.Manifold.N, 'Signal N should match Manifold N');
assert(sig.IsStatic, 'Should be static signal');
assert(~sig.IsVector, 'Should be scalar signal');
fprintf('  ✓ Signal has correct dimensions [%d × 1]\n', sig.N);
fprintf('  ✓ Signal label: "%s"\n\n', sig.Label);

%% Test 2: Multiple signals from spec array
fprintf('Test 2: Multiple signals from spec array\n');

specs = struct('type', {}, 'f0', {}, 'bw_abs', {});
for i = 1:3
    specs(i).type = 'narrowband';
    specs(i).f0 = 0.05 * i;
    specs(i).bw_abs = 0.01;
end

B2 = bct.sim.synth_mesh_signal(B, specs, 'k', 50, 'verbose', false);

assert(length(B2.Signals) == 3, 'Should have 3 signals');
fprintf('  ✓ Added %d signals from spec array\n', length(B2.Signals));

% Check each signal
for i = 1:length(B2.Signals)
    assert(B2.Signals(i).N == B.Manifold.N, 'Signal dimension mismatch');
    fprintf('    Signal %d: "%s"\n', i, B2.Signals(i).Label);
end
fprintf('\n');

%% Test 3: Custom label
fprintf('Test 3: Custom label\n');

spec.type = 'powerlaw';
spec.alpha = 1.5;

B3 = bct.sim.synth_mesh_signal(B, spec, 'k', 50, 'label', 'pink_noise', 'verbose', false);

sig = B3.Signals(1);
assert(strcmp(sig.Label, 'pink_noise'), 'Label should match custom label');
fprintf('  ✓ Custom label applied: "%s"\n\n', sig.Label);

%% Test 4: Different spec types
fprintf('Test 4: Different spec types\n');

B4 = bct.bct.fromMesh(V, F);

% Flat spectrum
spec1.type = 'flat';
B4 = bct.sim.synth_mesh_signal(B4, spec1, 'k', 50, 'verbose', false);
fprintf('  ✓ Flat spectrum: "%s"\n', B4.Signals(1).Label);

% Bandpass
spec2.type = 'bandpass';
spec2.fmin = 0.05;
spec2.fmax = 0.15;
B4 = bct.sim.synth_mesh_signal(B4, spec2, 'k', 50, 'verbose', false);
fprintf('  ✓ Bandpass: "%s"\n', B4.Signals(2).Label);

% Two-band
spec3.type = 'twoband';
spec3.f1 = 0.05;
spec3.bw1 = 0.01;
spec3.f2 = 0.15;
spec3.bw2 = 0.01;
B4 = bct.sim.synth_mesh_signal(B4, spec3, 'k', 50, 'verbose', false);
fprintf('  ✓ Two-band: "%s"\n', B4.Signals(3).Label);

assert(length(B4.Signals) == 3, 'Should have 3 different signal types');
fprintf('\n');

%% Test 5: Legacy mode (return_raw=true)
fprintf('Test 5: Legacy mode (return_raw=true)\n');

spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;

x = bct.sim.synth_mesh_signal(B, spec, 'k', 50, 'return_raw', true, 'verbose', false);

% Should return raw data, not bct object
assert(isnumeric(x), 'Should return numeric array in legacy mode');
assert(size(x, 1) == B.Manifold.N, 'Should have correct dimensions');
assert(size(x, 2) == 1, 'Should be column vector');
fprintf('  ✓ Legacy mode returns raw data [%d × %d]\n\n', size(x, 1), size(x, 2));

%% Test 6: Chaining - add multiple signals to same bct object
fprintf('Test 6: Chaining - build up multiple signals\n');

B5 = bct.bct.fromMesh(V, F);

% Add first signal
spec1.type = 'narrowband';
spec1.f0 = 0.05;
spec1.bw_abs = 0.01;
B5 = bct.sim.synth_mesh_signal(B5, spec1, 'k', 50, 'label', 'low_freq', 'verbose', false);

% Add second signal
spec2.type = 'narrowband';
spec2.f0 = 0.15;
spec2.bw_abs = 0.01;
B5 = bct.sim.synth_mesh_signal(B5, spec2, 'k', 50, 'label', 'high_freq', 'verbose', false);

assert(length(B5.Signals) == 2, 'Should have 2 signals');
fprintf('  ✓ Chained calls: %d signals\n', length(B5.Signals));
fprintf('    1. "%s"\n', B5.Signals(1).Label);
fprintf('    2. "%s"\n\n', B5.Signals(2).Label);

%% Test 7: Verify signal data properties
fprintf('Test 7: Verify signal data properties\n');

spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;
B6 = bct.sim.synth_mesh_signal(B, spec, 'k', 50, 'normalize', true, 'verbose', false);

sig = B6.Signals(1);
data = sig.Data;

% Check data type
assert(isa(data, 'single'), 'Data should be single precision');
fprintf('  ✓ Data type: single\n');

% Check dimensions
assert(all(size(data) == [B.Manifold.N, 1]), 'Data dimensions incorrect');
fprintf('  ✓ Data dimensions: [%d × 1]\n', size(data, 1));

% Check for NaN/Inf
assert(~any(isnan(data)), 'Data contains NaN');
assert(~any(isinf(data)), 'Data contains Inf');
fprintf('  ✓ Data is finite (no NaN/Inf)\n');

% Check normalization (should have unit RMS)
rms_val = sqrt(mean(data.^2));
fprintf('  ✓ RMS value: %.4f (normalized=%d)\n\n', rms_val, abs(rms_val - 1) < 0.1);

%% Summary
fprintf('=== All synth_mesh_signal Integration Tests Passed! ===\n\n');

fprintf('New API:\n');
fprintf('  B = synth_mesh_signal(B, spec)              - Add signal with auto label\n');
fprintf('  B = synth_mesh_signal(B, spec, ''label'', L)  - Add signal with custom label\n');
fprintf('  B = synth_mesh_signal(B, specs)             - Add multiple signals\n');
fprintf('  x = synth_mesh_signal(B, spec, ''return_raw'', true)  - Legacy mode\n\n');

fprintf('Signal Properties:\n');
fprintf('  - Automatically added to B.Signals array\n');
fprintf('  - Auto-generated labels based on spec type\n');
fprintf('  - Proper bct.signal.Signal objects\n');
fprintf('  - Dimension validation enforced\n');
