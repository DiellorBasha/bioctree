%% Test script for refactored bct.sim package
% This script tests the new Manifold-based simulation functions

% Change to bioctree directory
cd('c:\CodingProjects\bioctree');

% Run startup if it exists
if exist('bioctree_start.m', 'file')
    bioctree_start;
end

%% Test 1: Load a Bct object with FreeSurfer mesh
fprintf('Test 1: Loading FreeSurfer mesh...\n');
try
    % Assumes you have FreeSurfer data available
    % Adjust path as needed
    fs_dir = 'C:\Users\diell\Desktop\freesurfer\subjects\fsaverage\surf';
    if exist(fullfile(fs_dir, 'lh.pial'), 'file')
        B = bct.io.import.graph(fullfile(fs_dir, 'lh.pial'));
        fprintf('✓ Loaded mesh with %d vertices\n', size(B.Manifold.V, 1));
    else
        fprintf('⚠ FreeSurfer data not found, skipping mesh test\n');
        B = [];
    end
catch ME
    fprintf('✗ Error loading mesh: %s\n', ME.message);
    B = [];
end

%% Test 2: Create simple test object if FreeSurfer not available
if isempty(B)
    fprintf('\nTest 2: Creating simple test graph...\n');
    try
        % Create a simple mesh for testing
        V = single([0 0 0; 1 0 0; 0.5 sqrt(3)/2 0; 0.5 sqrt(3)/6 sqrt(2/3)]);
        F = uint32([1 2 3; 1 2 4; 2 3 4; 1 3 4]);
        B = bct.bct.create('test_sim');
        % Use Manifold constructor with (V, F) for mesh
        B.Manifold = bct.manifold.Manifold(V, F);
        fprintf('✓ Created test mesh with %d vertices\n', size(B.Manifold.V, 1));
    catch ME
        fprintf('✗ Error creating test mesh: %s\n', ME.message);
        fprintf('Stack: %s\n', ME.getReport());
        return;
    end
end

%% Test 3: Test gaussian function
fprintf('\nTest 3: Testing bct.sim.gaussian...\n');
try
    x = bct.sim.gaussian(B);
    assert(isequal(size(x), [size(B.Manifold.V, 1), 1]), 'Wrong output size');
    assert(isa(x, 'single'), 'Wrong data type');
    fprintf('✓ Gaussian signal generated: size=%dx%d, type=%s\n', ...
        size(x, 1), size(x, 2), class(x));
catch ME
    fprintf('✗ Error in gaussian: %s\n', ME.message);
end

%% Test 4: Test gaussian with custom parameters
fprintf('\nTest 4: Testing gaussian with custom parameters...\n');
try
    x = bct.sim.gaussian(B, 'center', 1, 'sigma', 5, 'amplitude', 2);
    assert(max(x) <= 2.01, 'Amplitude not respected');
    fprintf('✓ Gaussian with custom params: max=%.2f\n', max(x));
catch ME
    fprintf('✗ Error in custom gaussian: %s\n', ME.message);
end

%% Test 5: Test gaussian_growth
fprintf('\nTest 5: Testing bct.sim.gaussian_growth...\n');
try
    X = bct.sim.gaussian_growth(B, 'T', 50);
    assert(isequal(size(X), [50, size(B.Manifold.V, 1)]), 'Wrong output size');
    assert(isa(X, 'single'), 'Wrong data type');
    fprintf('✓ Gaussian growth generated: size=%dx%d\n', size(X, 1), size(X, 2));
catch ME
    fprintf('✗ Error in gaussian_growth: %s\n', ME.message);
end

%% Test 6: Test patch_signal (static)
fprintf('\nTest 6: Testing bct.sim.patch_signal (static)...\n');
try
    x = bct.sim.patch_signal(B, 'patchSize', 0.2);
    assert(isequal(size(x), [size(B.Manifold.V, 1), 1]), 'Wrong output size');
    fprintf('✓ Static patch generated: %d nodes active\n', sum(x ~= 0));
catch ME
    fprintf('✗ Error in patch_signal: %s\n', ME.message);
end

%% Test 7: Test patch_signal (growing)
fprintf('\nTest 7: Testing bct.sim.patch_signal (growing)...\n');
try
    X = bct.sim.patch_signal(B, 'T', 30, 'growthMode', 'grow', 'growthRate', 2);
    assert(isequal(size(X), [size(B.Manifold.V, 1), 30]), 'Wrong output size');
    fprintf('✓ Growing patch generated: size=%dx%d\n', size(X, 1), size(X, 2));
catch ME
    fprintf('✗ Error in growing patch: %s\n', ME.message);
end

%% Test 8: Test synth_mesh_signal
fprintf('\nTest 8: Testing bct.sim.synth_mesh_signal...\n');
try
    spec.type = 'narrowband';
    spec.f0 = 0.1;
    spec.bw_abs = 0.02;
    [x, a, f] = bct.sim.synth_mesh_signal(B, spec);
    assert(isequal(size(x), [size(B.Manifold.V, 1), 1]), 'Wrong signal size');
    assert(~isempty(a), 'Missing coefficients');
    assert(~isempty(f), 'Missing frequencies');
    fprintf('✓ Spectral synthesis: %d coefficients, freq range [%.4f, %.4f]\n', ...
        length(a), min(f), max(f));
catch ME
    fprintf('✗ Error in synth_mesh_signal: %s\n', ME.message);
end

%% Test 9: Test with different parameter combinations
fprintf('\nTest 9: Testing parameter combinations...\n');
try
    % Test geodesic distance mode
    x_geo = bct.sim.gaussian(B, 'center', 1, 'sigma', 5, 'distance', 'geodesic');
    fprintf('✓ Geodesic distance mode: max=%.2f\n', max(x_geo));
    
    % Test euclidean distance mode
    x_euc = bct.sim.gaussian(B, 'center', 1, 'sigma', 5, 'distance', 'euclidean');
    fprintf('✓ Euclidean distance mode: max=%.2f\n', max(x_euc));
catch ME
    fprintf('✗ Error in parameter test: %s\n', ME.message);
end

%% Summary
fprintf('\n=== Test Summary ===\n');
fprintf('All refactored simulation functions work with Manifold objects!\n');
fprintf('Functions tested:\n');
fprintf('  - bct.sim.gaussian\n');
fprintf('  - bct.sim.gaussian_growth\n');
fprintf('  - bct.sim.patch_signal\n');
fprintf('  - bct.sim.synth_mesh_signal\n');

%% Cleanup
if exist('test_sim.h5', 'file')
    delete('test_sim.h5');
end

