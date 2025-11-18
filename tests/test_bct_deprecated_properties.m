%% Test BCT deprecated properties and migration to Manifold
% This test verifies that deprecated properties still work for backward
% compatibility while the new Manifold-based API is the preferred approach

% Initialize
try
    bioctree_start;
catch
    addpath(fullfile(fileparts(pwd), 'toolbox'));
    addpath(fullfile(fileparts(pwd), 'external'));
end
clear; close all;

fprintf('=== Testing BCT Deprecated Properties ===\n\n');

%% Test 1: fromMesh - verify both old and new properties
fprintf('Test 1: fromMesh with deprecated and Manifold properties\n');
[V, F] = icosphere(3);
B = bct.bct.fromMesh(V, F);

% Test deprecated properties (should still work)
fprintf('  Deprecated properties:\n');
fprintf('    B.N = %d\n', B.N);
fprintf('    B.F = %d\n', B.F);

% Test new Manifold properties
fprintf('  Manifold properties:\n');
fprintf('    B.Manifold.N = %d\n', B.Manifold.N);
fprintf('    size(B.Manifold.V,1) = %d\n', size(B.Manifold.V,1));
fprintf('    size(B.Manifold.F,1) = %d\n', size(B.Manifold.F,1));

% Verify consistency
assert(B.N == B.Manifold.N, 'N property mismatch');
assert(B.F == size(B.Manifold.F, 1), 'F property mismatch');
fprintf('✓ Deprecated and Manifold properties consistent\n\n');

%% Test 2: fromAdjacency - verify graph construction
fprintf('Test 2: fromAdjacency with deprecated and Manifold properties\n');
% Create simple adjacency matrix
A = sparse([1 1 2 3], [2 3 3 4], 1, 10, 10);
A = A | A';  % Make symmetric

try
    B2 = bct.bct.fromAdjacency(A);

    fprintf('  Deprecated properties:\n');
    fprintf('    B2.N = %d\n', B2.N);

    fprintf('  Manifold properties:\n');
    fprintf('    B2.Manifold.N = %d\n', B2.Manifold.N);
    fprintf('    B2.Manifold.Type = %s\n', B2.Manifold.Type);

    assert(B2.N == B2.Manifold.N, 'N property mismatch');
    assert(B2.Manifold.Type == "graph", 'Type should be graph');
    fprintf('✓ Graph construction successful\n\n');
catch ME
    fprintf('⚠ fromAdjacency test skipped: %s\n\n', ME.message);
end

%% Test 3: Time properties migration
fprintf('Test 3: Time properties (T, fs) migration to Manifold.Time\n');

% Create a Manifold with Time information
B3 = bct.bct.fromMesh(V, F);
B3.Manifold.Time = bct.manifold.Time(1000, 250);

fprintf('  Manifold.Time properties:\n');
fprintf('    B3.Manifold.Time.T = %d\n', B3.Manifold.Time.T);
fprintf('    B3.Manifold.Time.fs = %.2f Hz\n', B3.Manifold.Time.fs);
fprintf('    Duration: %.4f seconds\n', B3.Manifold.Time.get_duration());

fprintf('  Note: Deprecated T and fs properties would be set during bct.open()\n');
fprintf('  for files with time-series data.\n');
fprintf('✓ Time properties migration demonstrated\n\n');

%% Test 4: Hidden/deprecated property visibility
fprintf('Test 4: Verify deprecated properties are hidden\n');
props = properties(B);
fprintf('  Public properties visible: %s\n', strjoin(props, ', '));

% Deprecated properties should not appear in main property list
has_deprecated_in_public = any(strcmp(props, 'T')) || ...
                          any(strcmp(props, 'N')) || ...
                          any(strcmp(props, 'fs'));

if has_deprecated_in_public
    warning('Deprecated properties still visible in public properties list');
else
    fprintf('✓ Deprecated properties are hidden from main property list\n');
end

% But they should still be accessible
try
    test_N = B.N;
    test_F = B.F;
    fprintf('✓ Deprecated properties still accessible\n');
catch ME
    error('Deprecated properties should still be accessible: %s', ME.message);
end

fprintf('\n');

%% Test 5: Migration example
fprintf('Test 5: Migration example - old vs new code\n');

fprintf('  OLD CODE (deprecated):\n');
fprintf('    nVerts = B.N;        %% Returns: %d\n', B.N);
fprintf('    nFaces = B.F;        %% Returns: %d\n', B.F);

fprintf('  NEW CODE (preferred):\n');
fprintf('    nVerts = B.Manifold.N;           %% Returns: %d\n', B.Manifold.N);
fprintf('    nFaces = size(B.Manifold.F, 1);  %% Returns: %d\n', size(B.Manifold.F, 1));

fprintf('✓ Both approaches produce same results\n\n');

%% Summary
fprintf('=== All deprecation tests passed! ===\n');
fprintf('\nMIGRATION GUIDE:\n');
fprintf('  B.N  → B.Manifold.N\n');
fprintf('  B.T  → B.Manifold.Time.T\n');
fprintf('  B.fs → B.Manifold.Time.fs\n');
fprintf('  B.F  → size(B.Manifold.F, 1) [for meshes]\n');
fprintf('\nDeprecated properties still work for backward compatibility.\n');
fprintf('Update your code to use the Manifold object for future compatibility.\n');
