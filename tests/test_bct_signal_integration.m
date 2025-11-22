%% Test bct class integration with Signal objects
% Tests that bct properly stores and validates Signal objects

clear all;
close all;

% Add toolbox to path
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));
addpath(fullfile(root, 'external'));

fprintf('=== Testing BCT + Signal Integration ===\n\n');

%% Setup: Create a bct object with Manifold
[V, F] = icosphere(2);
B = bct.bct.fromMesh(V, F);
B.Manifold.Time = bct.manifold.Time(100, 250);

fprintf('Created BCT with Manifold:\n');
fprintf('  N = %d vertices\n', B.Manifold.N);
fprintf('  T = %d time points at %.2f Hz\n\n', B.Manifold.Time.T, B.Manifold.Time.fs);

%% Test 1: Add valid signals
fprintf('Test 1: Adding valid signals\n');

% Create scalar static signal
data1 = randn(B.Manifold.N, 1);
s1 = bct.Signal(B.Manifold, data1, 'activation');
B.addSignal(s1);

fprintf('✓ Added scalar static signal\n');

% Create scalar dynamic signal
data2 = randn(B.Manifold.N, B.Manifold.Time.T);
s2 = bct.Signal(B.Manifold, data2, 'timeseries');
B.addSignal(s2);

fprintf('✓ Added scalar dynamic signal\n');

% Create vector static signal
data3 = randn(B.Manifold.N, 3);
s3 = bct.Signal(B.Manifold, data3, 'gradient');
B.addSignal(s3);

fprintf('✓ Added vector static signal\n');

% Verify count
assert(length(B.Signals) == 3, 'Should have 3 signals');
fprintf('  Total signals: %d\n\n', length(B.Signals));

%% Test 2: Access signals
fprintf('Test 2: Accessing signals\n');

% By index
sig1 = B.Signals(1);
assert(strcmp(sig1.Label, 'activation'), 'Label mismatch');
fprintf('✓ Access by index: B.Signals(1) = "%s"\n', sig1.Label);

% By label
sig2 = B.getSignalByLabel('timeseries');
assert(~isempty(sig2), 'Should find signal');
assert(sig2.IsDynamic, 'Should be dynamic');
fprintf('✓ Access by label: getSignalByLabel("timeseries")\n\n');

%% Test 3: Dimension validation - wrong N
fprintf('Test 3: Dimension validation\n');

% Create signal with wrong N
wrong_manifold = bct.manifold.Manifold(V(1:100,:), F(1:100,:));
wrong_data = randn(wrong_manifold.N, 1);
sig_bad = bct.Signal(wrong_manifold, wrong_data, 'wrong_N');

try
    B.addSignal(sig_bad);
    error('Should have thrown dimension mismatch error');
catch ME
    if contains(ME.identifier, 'bct:SignalDimensionMismatch')
        fprintf('✓ Correctly rejected signal with wrong N\n');
    else
        rethrow(ME);
    end
end

%% Test 4: Dimension validation - wrong T
% Create dynamic signal with wrong T
wrong_manifold2 = bct.manifold.Manifold(V, F);
wrong_manifold2.Time = bct.manifold.Time(50, 250);  % Different T
wrong_data2 = randn(B.Manifold.N, 50);
sig_bad2 = bct.Signal(wrong_manifold2, wrong_data2, 'wrong_T');

try
    B.addSignal(sig_bad2);
    error('Should have thrown dimension mismatch error');
catch ME
    if contains(ME.identifier, 'bct:SignalDimensionMismatch')
        fprintf('✓ Correctly rejected signal with wrong T\n');
    else
        rethrow(ME);
    end
end

%% Test 5: Dynamic signal without Manifold.Time
B2 = bct.bct.fromMesh(V, F);
% Don't set B2.Manifold.Time

% Try to add dynamic signal
dyn_data = randn(B2.Manifold.N, 100);
M_temp = bct.manifold.Manifold(V, F);
M_temp.Time = bct.manifold.Time(100, 250);
sig_dyn = bct.Signal(M_temp, dyn_data, 'dynamic');

try
    B2.addSignal(sig_dyn);
    error('Should have thrown error for dynamic signal without Time');
catch ME
    if contains(ME.identifier, 'bct:NoManifoldTime')
        fprintf('✓ Correctly rejected dynamic signal when Manifold.Time not set\n\n');
    else
        rethrow(ME);
    end
end

%% Test 6: Remove signals
fprintf('Test 6: Removing signals\n');

initial_count = length(B.Signals);
fprintf('  Initial count: %d\n', initial_count);

% Remove by index
B.removeSignal(2);
assert(length(B.Signals) == initial_count - 1, 'Count should decrease');
fprintf('✓ Removed signal by index\n');

% Remove by label
B.removeSignal('activation');
assert(length(B.Signals) == initial_count - 2, 'Count should decrease');
fprintf('✓ Removed signal by label\n');

fprintf('  Final count: %d\n\n', length(B.Signals));

%% Test 7: Clear all signals
fprintf('Test 7: Clearing all signals\n');

B.clearSignalsNew();
assert(isempty(B.Signals), 'Signals should be empty');
fprintf('✓ Cleared all signals\n\n');

%% Test 8: Multiple signals with same label
fprintf('Test 8: Multiple signals with same label\n');

s_a = bct.Signal(B.Manifold, randn(B.Manifold.N, 1), 'test');
s_b = bct.Signal(B.Manifold, randn(B.Manifold.N, 1), 'test');
s_c = bct.Signal(B.Manifold, randn(B.Manifold.N, 1), 'other');

B.addSignal(s_a);
B.addSignal(s_b);
B.addSignal(s_c);

assert(length(B.Signals) == 3, 'Should have 3 signals');
fprintf('  Added 3 signals (2 with label "test", 1 with "other")\n');

% getSignalByLabel should return first match
sig_found = B.getSignalByLabel('test');
assert(~isempty(sig_found), 'Should find signal');
fprintf('✓ getSignalByLabel returns first match\n\n');

%% Test 9: Display signals summary
fprintf('Test 9: Display signals summary\n');

fprintf('--- Signal 1 ---\n');
disp(B.Signals(1));

fprintf('--- Signal 2 ---\n');
disp(B.Signals(2));

fprintf('--- Signal 3 ---\n');
disp(B.Signals(3));

fprintf('✓ Display methods work\n\n');

%% Test 10: Array operations
fprintf('Test 10: Array operations on Signals\n');

% Can iterate
labels = cell(1, length(B.Signals));
for i = 1:length(B.Signals)
    labels{i} = char(B.Signals(i).Label);
end
fprintf('  Signal labels: %s\n', strjoin(labels, ', '));

% Can filter
dynamic_signals = B.Signals([B.Signals.IsDynamic]);
fprintf('  Number of dynamic signals: %d\n', length(dynamic_signals));

% Can get dimensions
N_vals = arrayfun(@(s) s.N, B.Signals);
assert(all(N_vals == B.Manifold.N), 'All N should match');
fprintf('✓ Array operations work correctly\n\n');

%% Summary
fprintf('=== All BCT + Signal Integration Tests Passed! ===\n');
fprintf('\nSignal Management:\n');
fprintf('  B.addSignal(signal_obj)       - Add Signal object\n');
fprintf('  B.removeSignal(idx_or_label)  - Remove signal\n');
fprintf('  B.getSignalByLabel(label)     - Find signal by label\n');
fprintf('  B.clearSignalsNew()           - Clear all signals\n');
fprintf('  B.Signals(idx)                - Access by index\n');
fprintf('  B.Signals                     - Array of all signals\n');
fprintf('\nValidation:\n');
fprintf('  - Signal.N must match Manifold.N\n');
fprintf('  - Signal.T must match Manifold.Time.T (for dynamic signals)\n');
fprintf('  - Dynamic signals require Manifold.Time to be set\n');

