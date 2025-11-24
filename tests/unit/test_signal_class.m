%% Test bct.Signal class
% Tests the Signal class for representing data on manifolds

clear all;
close all;

% Add toolbox to path
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));
addpath(fullfile(root, 'external'));

fprintf('=== Testing bct.Signal Class ===\n\n');

%% Setup: Create a manifold
[V, F] = icosphere(2);  % Small icosphere for testing
M = bct.manifold.Manifold(V, F);
fprintf('Created manifold with N=%d vertices\n', M.N);

% Add time dimension
M.Time = bct.manifold.Time(100, 250);
fprintf('Added time dimension: T=%d at fs=%.2f Hz\n\n', M.Time.T, M.Time.fs);

%% Test 1: Scalar static signal [N×1]
fprintf('Test 1: Scalar static signal [N×1]\n');
data1 = randn(M.N, 1);
s1 = bct.Signal(M, data1, 'scalar_static');

assert(s1.N == M.N, 'N mismatch');
assert(s1.T == 0, 'Should be static');
assert(s1.IsStatic, 'Should be static');
assert(~s1.IsDynamic, 'Should not be dynamic');
assert(~s1.IsVector, 'Should be scalar');
assert(strcmp(s1.Label, 'scalar_static'), 'Label mismatch');

if s1.IsVector
    sig_type = 'vector';
else
    sig_type = 'scalar';
end
if s1.IsStatic
    temp_type = 'static';
else
    temp_type = 'dynamic';
end

fprintf('  Signal type: %s\n', sig_type);
fprintf('  Temporal: %s\n', temp_type);
fprintf('  Dimensions: [%s]\n', num2str(size(s1.Data)));
fprintf('✓ Scalar static signal created successfully\n\n');

%% Test 2: Scalar dynamic signal [N×T]
fprintf('Test 2: Scalar dynamic signal [N×T]\n');
data2 = randn(M.N, M.Time.T);
s2 = bct.Signal(M, data2, 'scalar_dynamic');

assert(s2.N == M.N, 'N mismatch');
assert(s2.T == M.Time.T, 'T mismatch');
assert(~s2.IsStatic, 'Should not be static');
assert(s2.IsDynamic, 'Should be dynamic');
assert(~s2.IsVector, 'Should be scalar');

fprintf('  Signal type: %s\n', ternary(s2.IsVector, 'vector', 'scalar'));
fprintf('  Temporal: %s\n', ternary(s2.IsStatic, 'static', 'dynamic'));
fprintf('  Dimensions: [%s]\n', num2str(size(s2.Data)));
fprintf('✓ Scalar dynamic signal created successfully\n\n');

%% Test 3: Vector static signal [N×3]
fprintf('Test 3: Vector static signal [N×3]\n');
data3 = randn(M.N, 3);
s3 = bct.Signal(M, data3, 'vector_static');

assert(s3.N == M.N, 'N mismatch');
assert(s3.T == 0, 'Should be static');
assert(s3.IsStatic, 'Should be static');
assert(~s3.IsDynamic, 'Should not be dynamic');
assert(s3.IsVector, 'Should be vector');

fprintf('  Signal type: %s\n', ternary(s3.IsVector, 'vector', 'scalar'));
fprintf('  Temporal: %s\n', ternary(s3.IsStatic, 'static', 'dynamic'));
fprintf('  Dimensions: [%s]\n', num2str(size(s3.Data)));
fprintf('✓ Vector static signal created successfully\n\n');

%% Test 4: Vector dynamic signal [N×T×3]
fprintf('Test 4: Vector dynamic signal [N×T×3]\n');
data4 = randn(M.N, M.Time.T, 3);
s4 = bct.Signal(M, data4, 'vector_dynamic');

assert(s4.N == M.N, 'N mismatch');
assert(s4.T == M.Time.T, 'T mismatch');
assert(~s4.IsStatic, 'Should not be static');
assert(s4.IsDynamic, 'Should be dynamic');
assert(s4.IsVector, 'Should be vector');

fprintf('  Signal type: %s\n', ternary(s4.IsVector, 'vector', 'scalar'));
fprintf('  Temporal: %s\n', ternary(s4.IsStatic, 'static', 'dynamic'));
fprintf('  Dimensions: [%s]\n', num2str(size(s4.Data)));
fprintf('✓ Vector dynamic signal created successfully\n\n');

%% Test 5: Dimension validation errors
fprintf('Test 5: Dimension validation\n');

% Wrong N
try
    bad_data = randn(M.N + 5, 1);
    s_bad = bct.Signal(M, bad_data);
    error('Should have thrown dimension mismatch error');
catch ME
    if contains(ME.identifier, 'Signal:DimensionMismatch')
        fprintf('✓ Correctly rejected wrong N\n');
    else
        rethrow(ME);
    end
end

% Wrong T for dynamic
try
    bad_data = randn(M.N, M.Time.T + 10);
    s_bad = bct.Signal(M, bad_data);
    error('Should have thrown dimension mismatch error');
catch ME
    if contains(ME.identifier, 'Signal:DimensionMismatch')
        fprintf('✓ Correctly rejected wrong T\n');
    else
        rethrow(ME);
    end
end

% Dynamic signal without Time in Manifold
M_static = bct.manifold.Manifold(V, F);
try
    bad_data = randn(M_static.N, 50);
    s_bad = bct.Signal(M_static, bad_data);
    error('Should have thrown error for dynamic signal without Time');
catch ME
    if contains(ME.identifier, 'Signal:DimensionMismatch')
        fprintf('✓ Correctly rejected dynamic signal without Manifold.Time\n');
    else
        rethrow(ME);
    end
end

fprintf('\n');

%% Test 6: Spatial snapshot extraction
fprintf('Test 6: Spatial snapshot extraction\n');

% From scalar dynamic
snap_scalar = s2.get_spatial_snapshot(50);
assert(isequal(size(snap_scalar), [M.N, 1]), 'Snapshot size mismatch');
assert(all(snap_scalar == s2.Data(:, 50)), 'Snapshot data mismatch');
fprintf('✓ Scalar snapshot extraction correct\n');

% From vector dynamic
snap_vector = s4.get_spatial_snapshot(50);
assert(isequal(size(snap_vector), [M.N, 3]), 'Vector snapshot size mismatch');
fprintf('✓ Vector snapshot extraction correct\n');

% From static (should return full data)
snap_static = s1.get_spatial_snapshot();
assert(isequal(snap_static, s1.Data), 'Static snapshot mismatch');
fprintf('✓ Static signal snapshot correct\n\n');

%% Test 7: Temporal trace extraction
fprintf('Test 7: Temporal trace extraction\n');

node_idx = 5;

% From scalar dynamic
trace_scalar = s2.get_temporal_trace(node_idx);
assert(isequal(size(trace_scalar), [M.Time.T, 1]), 'Scalar trace size mismatch');
assert(all(trace_scalar == s2.Data(node_idx, :)'), 'Scalar trace data mismatch');
fprintf('✓ Scalar temporal trace extraction correct\n');

% From vector dynamic
trace_vector = s4.get_temporal_trace(node_idx);
assert(isequal(size(trace_vector), [M.Time.T, 3]), 'Vector trace size mismatch');
fprintf('✓ Vector temporal trace extraction correct\n');

% From static (should error)
try
    trace_bad = s1.get_temporal_trace(node_idx);
    error('Should have thrown error for static signal');
catch ME
    if contains(ME.identifier, 'Signal:NoTimeDimension')
        fprintf('✓ Correctly rejected temporal trace on static signal\n');
    else
        rethrow(ME);
    end
end

fprintf('\n');

%% Test 8: Summary and display
fprintf('Test 8: Summary and display methods\n');
fprintf('--- Scalar static summary ---\n');
disp(s1);
fprintf('\n--- Scalar dynamic summary ---\n');
disp(s2);
fprintf('\n--- Vector static summary ---\n');
disp(s3);
fprintf('\n--- Vector dynamic summary ---\n');
disp(s4);

fprintf('✓ Display methods work\n\n');

%% Summary
fprintf('=== All Signal class tests passed! ===\n');
fprintf('\nSignal Types Supported:\n');
fprintf('  Scalar static:  [N×1]   - One value per vertex\n');
fprintf('  Scalar dynamic: [N×T]   - Time-varying scalar at each vertex\n');
fprintf('  Vector static:  [N×3]   - 3D vector at each vertex\n');
fprintf('  Vector dynamic: [N×T×3] - Time-varying 3D vector at each vertex\n');

function result = ternary(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end

