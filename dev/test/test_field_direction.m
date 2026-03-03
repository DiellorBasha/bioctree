%% TEST: Direction Field Generation from Singularities
% Test new bct.field.direction API with cached M.connection
%
% This test demonstrates the simplified workflow for generating direction
% fields from singularities. The new API handles all intermediate steps
% (connection, transport, propagation) automatically.

clear; clc;

%% Load manifold
M = bct.data.load('Id', 'fsaverage_rh_pial');
fprintf('Loaded manifold: %d vertices, %d faces\n', M.numVertices(), M.numFaces());

%% Test 1: Basic direction field from singularities
fprintf('\n=== TEST 1: Basic direction field ===\n');

% Canonical singularities (sphere: sum = 2)
singularityVertices = [6653; 978];
singularityWeights = [1.0; 1.0];

% Generate direction field (one-line!)
tic;
result = bct.field.direction(M, ...
    'singularities', singularityVertices, ...
    'weights', singularityWeights);
t1 = toc;

fprintf('Direction field computed in %.3f sec\n', t1);
fprintf('Direction angles range: [%.4f, %.4f] rad\n', ...
    min(result.directionAngles), max(result.directionAngles));
fprintf('Direction vectors norm: mean=%.6f, std=%.2e\n', ...
    result.attributes.meanNorm, result.attributes.stdNorm);

% Verify results
assert(size(result.directionVectors, 1) == M.numFaces(), 'Wrong number of direction vectors');
assert(size(result.directionVectors, 2) == 3, 'Direction vectors must be [nF×3]');
assert(size(result.orthogonalVectors, 1) == M.numFaces(), 'Wrong number of orthogonal vectors');
assert(size(result.orthogonalVectors, 2) == 3, 'Orthogonal vectors must be [nF×3]');

fprintf('✓ All basic tests passed\n');

%% Test 2: Caching works (second call should be faster)
fprintf('\n=== TEST 2: Connection caching ===\n');

% Second call with same parameters should use cache
tic;
result2 = bct.field.direction(M, ...
    'singularities', singularityVertices, ...
    'weights', singularityWeights);
t2 = toc;

fprintf('Second call: %.3f sec (%.1fx speedup from caching)\n', t2, t1/t2);

% Results should be identical
assert(isequal(result.directionAngles, result2.directionAngles), ...
    'Cached results differ from original');

fprintf('✓ Caching verified\n');

%% Test 3: Using pre-computed connection
fprintf('\n=== TEST 3: Using pre-computed connection ===\n');

% Compute connection once
conn = M.connection('trivial', ...
    'singularities', singularityVertices, ...
    'weights', singularityWeights);

% Verify connection contains transport
assert(isfield(conn, 'combinedTransport'), 'Connection missing combinedTransport');
assert(isfield(conn, 'geometricTransport'), 'Connection missing geometricTransport');
assert(isfield(conn, 'connectionTransport'), 'Connection missing connectionTransport');

fprintf('Connection fields: trivialConnection, combinedTransport, geometricTransport\n');
fprintf('Combined transport range: [%.4f, %.4f] rad\n', ...
    min(conn.combinedTransport.value), max(conn.combinedTransport.value));

% Generate direction field using connection
result3 = bct.field.direction(M, conn);

% Should match previous results
assert(isequal(result.directionAngles, result3.directionAngles), ...
    'Results differ when using pre-computed connection');

fprintf('✓ Pre-computed connection workflow verified\n');

%% Test 4: Custom seed face and angle
fprintf('\n=== TEST 4: Custom seed face and initial angle ===\n');

result4 = bct.field.direction(M, ...
    'singularities', singularityVertices, ...
    'weights', singularityWeights, ...
    'seedFace', 100, ...
    'seedValue', pi/4);  % Start at 45 degrees

fprintf('Seed face: %d, Seed angle: %.4f rad (%.1f deg)\n', ...
    100, pi/4, rad2deg(pi/4));
fprintf('Direction angles range: [%.4f, %.4f] rad\n', ...
    min(result4.directionAngles), max(result4.directionAngles));

% Verify seed value
assert(abs(result4.propagation.alpha_face(100) - pi/4) < 1e-10, ...
    'Seed face angle incorrect');

fprintf('✓ Custom seed parameters verified\n');

%% Test 5: Orthogonality check
fprintf('\n=== TEST 5: Orthogonality of direction and orthogonal fields ===\n');

% Compute dot product (should be zero for orthogonal vectors)
dotProducts = sum(result.directionVectors .* result.orthogonalVectors, 2);
maxDot = max(abs(dotProducts));
meanDot = mean(abs(dotProducts));

fprintf('Max dot product: %.2e (should be ~0)\n', maxDot);
fprintf('Mean dot product: %.2e\n', meanDot);

assert(maxDot < 1e-10, 'Direction and orthogonal vectors not orthogonal');

fprintf('✓ Orthogonality verified\n');

%% Test 6: Comparison with manual workflow
fprintf('\n=== TEST 6: Equivalence with manual workflow ===\n');

% Manual workflow (old way)
phi = M.connection('trivial', 'singularities', singularityVertices, ...
                   'weights', singularityWeights);
phi_values = phi.trivialConnection.value;

% Transport is now included in phi
combinedTransport = phi.combinedTransport.value;

% Propagate
manual_result = bct.manifold.query.dual(M, combinedTransport, ...
    'seedFace', 1, 'seedValue', 0, 'wrap', false);
alpha_manual = manual_result.alpha_face;

% Convert to vectors
geom = M.geometry();
tangent1 = geom.face.tangent1.value;
tangent2 = geom.face.tangent2.value;
dirVec_manual = cos(alpha_manual) .* tangent1 + sin(alpha_manual) .* tangent2;

% Compare
maxDiff = max(abs(result.directionVectors - dirVec_manual), [], 'all');
fprintf('Max difference from manual workflow: %.2e\n', maxDiff);

assert(maxDiff < 1e-10, 'bct.field.direction differs from manual workflow');

fprintf('✓ Equivalence with manual workflow verified\n');

%% Summary
fprintf('\n=== ALL TESTS PASSED ===\n');
fprintf('bct.field.direction API working correctly\n');
fprintf('Connection caching functional\n');
fprintf('Transport automatically included\n');
