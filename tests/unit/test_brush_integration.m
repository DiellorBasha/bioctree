%TEST_BRUSH_INTEGRATION  Integration test for brush registry/runtime system
%
%   This script verifies the new brush integration:
%   - bct.registry.brushes (authoritative definitions)
%   - bct.runtime.brushes (context-aware dispatch)
%   - Backward compatibility with bct.brush.apply()
%
% See: notes/BrushContract.md, notes/BRUSH_INTEGRATION_PLAN.md

%% Setup
fprintf('=== Brush Integration Test ===\n\n');

% Load test mesh
dataPath = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');
if ~isfile(dataPath)
    error('Test data not found: %s', dataPath);
end

data = load(dataPath);
M = bct.Manifold(data.V, data.F);
fprintf('✓ Loaded test manifold: %d vertices\n', M.numVertices);

%% Test 1: Registry Interface
fprintf('\n--- Test 1: Registry Interface ---\n');

% Get all definitions
defs = bct.registry.brushes();
fprintf('✓ Registry contains %d brush definitions\n', numel(defs));

% Get specific brush
spec = bct.registry.brushes('get', 'patch_gaussian');
fprintf('✓ Retrieved spec for %s\n', spec.Id);

% Validate a spec
[ok, msg] = bct.registry.brushes('validate', spec);
if ok
    fprintf('✓ Validation passed: %s\n', msg);
else
    error('Validation failed: %s', msg);
end

% List all brushes
ids = bct.registry.brushes('list');
fprintf('✓ Listed %d brush IDs\n', numel(ids));

%% Test 2: Runtime Interface
fprintf('\n--- Test 2: Runtime Interface ---\n');

% Get filtered dictionary (only brushes compatible with this manifold)
dict = bct.runtime.brushes('dictionary', M);
fprintf('✓ Runtime dictionary contains %d compatible brushes\n', numel(dict));

% Test resolution with context
context = struct(...
    'manifold', M, ...
    'params', struct('center', 1000, 'radius', 15));
resolvedSpec = bct.runtime.brushes('resolve', 'patch_gaussian', context);
fprintf('✓ Resolved patch_gaussian with context\n');

% List available brushes for this manifold
availableIds = bct.runtime.brushes('list', M);
fprintf('✓ %d brushes available for this manifold\n', numel(availableIds));

%% Test 3: Backward Compatibility (bct.brush.apply)
fprintf('\n--- Test 3: Backward Compatibility ---\n');

% Test patch_gaussian (uses runtime path)
params_gaussian = struct('center', 1000, 'radius', 20);
w_gaussian = bct.brush.apply('patch_gaussian', M, params_gaussian);
fprintf('✓ patch_gaussian via apply(): output size = %s\n', mat2str(size(w_gaussian)));

% Test patch_spectral (uses runtime path, requires eigenpairs)
params_spectral = struct('center', 5000, 'numModes', 100, 'bandwidth', 0.05);
w_spectral = bct.brush.apply('patch_spectral', M, params_spectral);
fprintf('✓ patch_spectral via apply(): output size = %s\n', mat2str(size(w_spectral)));

%% Test 4: Direct Evaluation
fprintf('\n--- Test 4: Direct Evaluation ---\n');

% Get default parameters resolved for manifold
spec_direct = bct.registry.brushes('get', 'patch_nearest');
defaultParams = spec_direct.DefaultParams(M);
fprintf('✓ Default params for patch_nearest: center=%d, k=%d\n', ...
    defaultParams.center, defaultParams.k);

% Evaluate directly
w_direct = spec_direct.Evaluate(M, defaultParams);
fprintf('✓ Direct evaluation: output size = %s\n', mat2str(size(w_direct)));

%% Test 5: Cache Management
fprintf('\n--- Test 5: Cache Management ---\n');

% Clear cache
bct.runtime.brushes('clear');
fprintf('✓ Cache cleared\n');

% Rebuild cache
dict2 = bct.runtime.brushes('dictionary', M);
fprintf('✓ Cache rebuilt: %d entries\n', numel(dict2));

%% Summary
fprintf('\n=== All Tests Passed ===\n');
fprintf('Registry: %d total brushes\n', numel(defs));
fprintf('Runtime:  %d compatible with test manifold\n', numel(availableIds));
fprintf('Backward compatibility maintained\n');
