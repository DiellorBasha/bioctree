%TEST_FLATTENED_OPERATORS Test flattened operator structure
%
% Tests that:
% 1. M.operators() returns all operators at top level (no nested 'dec')
% 2. M.dec() returns only the 15 DEC operators
% 3. Individual DEC operator access triggers full DEC computation
% 4. All 15 DEC operators are present and accessible

% Load canonical test manifold
M = bct.data.load('Id', 'fsaverage_rh_pial');

fprintf('Testing flattened operator structure...\n\n');

%% Test 1: M.operators() returns flattened structure
fprintf('Test 1: M.operators() returns flattened structure\n');
ops = M.operators();

% Check that 'dec' field does NOT exist
if isfield(ops, 'dec')
    error('FAILED: ops.dec should not exist (structure should be flattened)');
end
fprintf('  ✓ No nested ops.dec field\n');

% Check that all DEC operators are at top level
decFields = {'d0', 'd1', 'dd0', 'dd1', 'hd0', 'hd1', 'hd2', ...
             'hdd0', 'hdd1', 'hdd2', 'flatPP', 'flatDP', 'flatDD', ...
             'sharpPD', 'sharpDD'};

for i = 1:numel(decFields)
    if ~isfield(ops, decFields{i})
        error('FAILED: ops.%s is missing', decFields{i});
    end
end
fprintf('  ✓ All 15 DEC operators present at top level\n');

% Check that FEM operators are present
if ~isfield(ops, 'mass') || ~isfield(ops, 'stiffness') || ~isfield(ops, 'laplacebeltrami')
    error('FAILED: FEM operators missing');
end
fprintf('  ✓ FEM operators present (mass, stiffness, laplacebeltrami)\n');

% Check that derived operators are present
if ~isfield(ops, 'gradient') || ~isfield(ops, 'divergence') || ~isfield(ops, 'curl')
    error('FAILED: Derived operators missing');
end
fprintf('  ✓ Derived operators present (gradient, divergence, curl)\n');

fprintf('\n');

%% Test 2: M.dec() returns only DEC operators
fprintf('Test 2: M.dec() returns only DEC operators\n');

% Clear cache to test fresh computation
M2 = bct.data.load('Id', 'fsaverage_rh_pial');
decOps = M2.dec();

% Check that all 15 DEC operators are returned
for i = 1:numel(decFields)
    if ~isfield(decOps, decFields{i})
        error('FAILED: decOps.%s is missing', decFields{i});
    end
end
fprintf('  ✓ M.dec() returns all 15 DEC operators\n');

% Check that only DEC operators are returned (no FEM operators)
if isfield(decOps, 'mass') || isfield(decOps, 'stiffness')
    error('FAILED: M.dec() should only return DEC operators');
end
fprintf('  ✓ M.dec() returns only DEC operators (no FEM operators)\n');

fprintf('\n');

%% Test 3: Individual operator access triggers full DEC computation
fprintf('Test 3: Individual operator access triggers full DEC computation\n');

% Create fresh manifold with empty cache
M3 = bct.data.load('Id', 'fsaverage_rh_pial');

% Request gradient (which depends on DEC operators)
[~, gradOp] = M3.gradient();
fprintf('  ✓ gradient() computed successfully\n');

% Check that all DEC operators were cached
cacheData = M3.Cache.operators.data;
missingFields = {};
for i = 1:numel(decFields)
    if ~isfield(cacheData, decFields{i})
        missingFields{end+1} = decFields{i};
    end
end

if ~isempty(missingFields)
    error('FAILED: DEC operators not fully cached: %s', strjoin(missingFields, ', '));
end
fprintf('  ✓ All DEC operators cached after gradient() call\n');

fprintf('\n');

%% Test 4: Verify operator dimensions
fprintf('Test 4: Verify operator dimensions\n');

nV = M.numVertices();
nE = M.numEdges();
nF = M.numFaces();

% Check d0: vertex → edge
assert(isequal(size(ops.d0), [nE, nV]), 'd0 has wrong dimensions');
fprintf('  ✓ d0: [%d × %d] (edge × vertex)\n', nE, nV);

% Check d1: edge → face
assert(isequal(size(ops.d1), [nF, nE]), 'd1 has wrong dimensions');
fprintf('  ✓ d1: [%d × %d] (face × edge)\n', nF, nE);

% Check dd0: edge → vertex
assert(isequal(size(ops.dd0), [nE, nF]), 'dd0 has wrong dimensions');
fprintf('  ✓ dd0: [%d × %d] (edge × face)\n', nE, nF);

% Check dd1: vertex → edge
assert(isequal(size(ops.dd1), [nV, nE]), 'dd1 has wrong dimensions');
fprintf('  ✓ dd1: [%d × %d] (vertex × edge)\n', nV, nE);

fprintf('\n');

%% Test 5: Verify operators are matrices (not structs)
fprintf('Test 5: Verify operators are matrices (not structs)\n');

for i = 1:numel(decFields)
    field = decFields{i};
    if ~isnumeric(ops.(field))
        error('FAILED: ops.%s is not a numeric matrix', field);
    end
end
fprintf('  ✓ All DEC operators are numeric matrices\n');

fprintf('\n');
fprintf('========================================\n');
fprintf('ALL TESTS PASSED ✓\n');
fprintf('Flattened operator structure working correctly.\n');
fprintf('========================================\n');
