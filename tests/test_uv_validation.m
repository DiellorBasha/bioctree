%% Test UV Validation and Optional UV Handling
% Tests that Manifold.UV can safely be empty and validation works

clear all;
close all;

% Add toolbox to path
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));
addpath(fullfile(root, 'external'));

fprintf('=== Testing UV Validation ===\n\n');

%% Test 1: Create manifold without UV (should be empty by default)
fprintf('Test 1: Manifold without UV parametrization...\n');

[V, F] = icosphere(2);
B = bct.bct.fromMesh(V, F);

fprintf('  Manifold created: %d vertices\n', B.Manifold.N);
fprintf('  UV is empty: %s\n', string(isempty(B.Manifold.UV)));

assert(isempty(B.Manifold.UV), 'UV should be empty by default');
fprintf('  ✓ UV empty by default\n\n');

%% Test 2: Test checkUV method (no error mode)
fprintf('Test 2: checkUV with warning (no error)...\n');

lastwarn('');  % Clear last warning
hasUV = B.Manifold.checkUV(false);

fprintf('  hasUV returned: %s\n', string(hasUV));
[warnMsg, warnId] = lastwarn;

assert(~hasUV, 'Should return false when UV is empty');
assert(~isempty(warnMsg), 'Should produce a warning');
assert(strcmp(warnId, 'bct:Manifold:NoUV'), 'Should have correct warning ID');
fprintf('  ✓ Warning generated: %s\n', warnId);
fprintf('  ✓ hasUV = false\n\n');

%% Test 3: Test checkUV with error mode
fprintf('Test 3: checkUV with error mode...\n');

try
    B.Manifold.checkUV(true);
    fprintf('  ✗ Should have thrown error\n');
    error('Test failed: expected error');
catch ME
    assert(strcmp(ME.identifier, 'bct:Manifold:NoUV'), 'Should throw NoUV error');
    fprintf('  ✓ Error thrown with ID: %s\n', ME.identifier);
    fprintf('  ✓ Message: %s\n', ME.message(1:min(60, length(ME.message))));
end

fprintf('\n');

%% Test 4: Manifold with UV present
fprintf('Test 4: Manifold with UV parametrization...\n');

% Manually add UV (simulate loaded from sphere.reg)
B.Manifold.UV = rand(B.Manifold.N, 2);

lastwarn('');
hasUV = B.Manifold.checkUV(false);

[warnMsg, ~] = lastwarn;

fprintf('  UV dimensions: [%d × %d]\n', size(B.Manifold.UV, 1), size(B.Manifold.UV, 2));
fprintf('  hasUV returned: %s\n', string(hasUV));
fprintf('  Warning generated: %s\n', string(~isempty(warnMsg)));

assert(hasUV, 'Should return true when UV exists');
assert(isempty(warnMsg), 'Should not produce warning when UV exists');
fprintf('  ✓ hasUV = true\n');
fprintf('  ✓ No warning when UV present\n\n');

%% Test 5: Error mode with UV present (should not throw)
fprintf('Test 5: checkUV error mode with UV present...\n');

try
    hasUV = B.Manifold.checkUV(true);
    fprintf('  ✓ No error thrown\n');
    fprintf('  ✓ hasUV = %s\n', string(hasUV));
    assert(hasUV, 'Should return true');
catch ME
    fprintf('  ✗ Unexpected error: %s\n', ME.identifier);
    error('Test failed: should not error when UV present');
end

fprintf('\n');

%% Test 6: UV can be set to empty
fprintf('Test 6: UV can be set to empty...\n');

B.Manifold.UV = [];

fprintf('  Set UV to []\n');
fprintf('  UV is empty: %s\n', string(isempty(B.Manifold.UV)));

lastwarn('');
hasUV = B.Manifold.checkUV(false);

[warnMsg, ~] = lastwarn;

assert(~hasUV, 'Should return false after clearing UV');
assert(~isempty(warnMsg), 'Should warn after clearing UV');
fprintf('  ✓ UV can be set to empty\n');
fprintf('  ✓ checkUV properly detects absence\n\n');

%% Test 7: Test with FreeSurfer import (if data available)
fprintf('Test 7: Testing with FreeSurfer import...\n');

test_path = fullfile('test-data', 'freesurfer', 'fsaverage', 'surf', 'lh.pial');

if isfile(test_path)
    % Import mesh
    lastwarn('');
    B_fs = bct.io.import.mesh(test_path);
    
    fprintf('  Imported FreeSurfer mesh\n');
    fprintf('  Vertices: %d\n', B_fs.Manifold.N);
    fprintf('  UV is empty: %s\n', string(isempty(B_fs.Manifold.UV)));
    
    if ~isempty(B_fs.Manifold.UV)
        fprintf('  UV dimensions: [%d × %d]\n', size(B_fs.Manifold.UV, 1), size(B_fs.Manifold.UV, 2));
        
        % Test checkUV with UV present
        lastwarn('');
        hasUV = B_fs.Manifold.checkUV(false);
        [warnMsg, ~] = lastwarn;
        
        assert(hasUV, 'Should have UV');
        assert(isempty(warnMsg), 'Should not warn when UV present');
        fprintf('  ✓ UV loaded successfully\n');
        fprintf('  ✓ checkUV returns true\n');
    else
        fprintf('  Note: No .sphere.reg found (expected if file missing)\n');
        
        % Test checkUV without UV
        lastwarn('');
        hasUV = B_fs.Manifold.checkUV(false);
        [warnMsg, ~] = lastwarn;
        
        assert(~hasUV, 'Should not have UV');
        assert(~isempty(warnMsg), 'Should warn when UV absent');
        fprintf('  ✓ Import succeeded without UV\n');
        fprintf('  ✓ checkUV warns appropriately\n');
    end
else
    fprintf('  Skipped: Test data not found at %s\n', test_path);
end

fprintf('\n');

%% Test 8: UV dimension validation
fprintf('Test 8: UV dimension constraints...\n');

B_test = bct.bct.fromMesh(V, F);

% Valid UV: [N × 2]
B_test.Manifold.UV = rand(B_test.Manifold.N, 2);
fprintf('  Set UV to [%d × 2]: valid\n', B_test.Manifold.N);
assert(B_test.Manifold.checkUV(false), 'Valid UV should pass');

% Invalid UV dimensions should be caught by assignment
try
    B_test.Manifold.UV = rand(B_test.Manifold.N, 3);  % Wrong columns
    fprintf('  Warning: UV with 3 columns was accepted (should validate)\n');
catch
    fprintf('  ✓ Invalid UV dimensions rejected\n');
end

fprintf('\n');

%% Summary
fprintf('=== Summary ===\n\n');

fprintf('UV Parametrization Properties:\n');
fprintf('  • UV property defaults to empty []\n');
fprintf('  • Empty UV is valid and causes no errors during import\n');
fprintf('  • Functions needing UV should call checkUV()\n\n');

fprintf('checkUV() Method:\n');
fprintf('  • checkUV(false) - Returns true/false, warns if UV missing\n');
fprintf('  • checkUV(true)  - Returns true/false, errors if UV missing\n');
fprintf('  • Use checkUV(false) for optional UV features\n');
fprintf('  • Use checkUV(true) for UV-dependent operations\n\n');

fprintf('Usage Pattern:\n');
fprintf('  if manifold.checkUV(false)  %% Warns if missing\n');
fprintf('      %% Use UV-based functionality\n');
fprintf('      plot(manifold.UV(:,1), manifold.UV(:,2));\n');
fprintf('  else\n');
fprintf('      %% Fallback when UV not available\n');
fprintf('      fprintf(''UV not available\\n'');\n');
fprintf('  end\n\n');

fprintf('All UV validation tests passed! ✓\n\n');
