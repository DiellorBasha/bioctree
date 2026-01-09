%% Test Field-Native Operators
%
% Demonstrates Field-as-first-class-artifact architecture with
% gradient, divergence, and Laplacian operators

%% Setup
if ~exist('bct_start.m', 'file')
    cd('..');
end
run('bct_start.m');

% Add external dependencies
if ~exist('icosphere', 'file')
    addpath(fullfile(pwd, 'external'));
end

% Create test manifold
[V, F] = icosphere(3);
M = bct.Manifold(V, F);

fprintf('Test manifold: %d vertices, %d faces\n\n', M.numVertices(), M.numFaces());

%% Test 1: Create Runtime Context with Field-Native Operators
fprintf('=== Test 1: Runtime Context with Field Operators ===\n');

ctx = bct.runtime.context(M, 'DEC', true);
ops = bct.runtime.operators.dictionary(ctx);

% Check if Field-native operators are available
hasGradient = isKey(ops, 'gradient.dec.field');
hasDivergence = isKey(ops, 'divergence.dec.field');
hasLaplacian = isKey(ops, 'laplacian.dec.field');

fprintf('Field-native operators available:\n');
fprintf('  gradient.dec.field: %s\n', string(hasGradient));
fprintf('  divergence.dec.field: %s\n', string(hasDivergence));
fprintf('  laplacian.dec.field: %s\n\n', string(hasLaplacian));

assert(hasGradient, 'gradient.dec.field not found');
assert(hasDivergence, 'divergence.dec.field not found');
assert(hasLaplacian, 'laplacian.dec.field not found');

fprintf('✓ All Field-native operators loaded\n\n');

%% Test 2: Gradient Operator (vertex scalar → face vector3)
fprintf('=== Test 2: Gradient Operator (Field-Native) ===\n');

% Create input scalar field on vertices
nv = M.numVertices();
scalarData = sin(2*pi*V(:,1)) .* cos(2*pi*V(:,2));

Fin = bct.fields.make('support', 'vertex', ...
                      'valueType', 'scalar', ...
                      'value', scalarData, ...
                      'meshId', M.ID, ...
                      'metadata', struct('name', 'test_scalar'));

fprintf('Input Field:\n');
fprintf('  support: %s\n', Fin.support);
fprintf('  valueType: %s\n', Fin.valueType);
fprintf('  shape: [%s]\n', sprintf('%d×', size(Fin.value)));
fprintf('  meshId: %s\n', Fin.meshId);
fprintf('  time-varying: %s\n\n', string(bct.fields.isTimeVarying(Fin)));

% Apply gradient operator
gradOp = ops('gradient.dec.field');
Fgrad = gradOp.applyFcn(Fin);

fprintf('Output Field (gradient):\n');
fprintf('  support: %s\n', Fgrad.support);
fprintf('  valueType: %s\n', Fgrad.valueType);
fprintf('  shape: [%s]\n', sprintf('%d×', size(Fgrad.value)));
fprintf('  meshId: %s\n', Fgrad.meshId);
fprintf('  has metadata: %s\n', string(isfield(Fgrad, 'metadata')));

if isfield(Fgrad, 'metadata')
    fprintf('  operator: %s\n', Fgrad.metadata.operatorId);
    fprintf('  backend: %s\n', Fgrad.metadata.backend);
end

% Validate output
assert(strcmp(Fgrad.support, 'face'), 'Gradient output should have face support');
assert(strcmp(Fgrad.valueType, 'vector3'), 'Gradient output should be vector3');
assert(strcmp(Fgrad.meshId, M.ID), 'meshId should match');
assert(isfield(Fgrad, 'metadata'), 'Output should have metadata');
assert(strcmp(Fgrad.metadata.operatorId, 'gradient.dec.field'), 'Operator provenance missing');

fprintf('\n✓ Gradient operator Field-native test passed\n\n');

%% Test 3: Divergence Operator (face vector3 → vertex scalar)
fprintf('=== Test 3: Divergence Operator (Field-Native) ===\n');

% Use gradient output as divergence input
divOp = ops('divergence.dec.field');
Fdiv = divOp.applyFcn(Fgrad);

fprintf('Output Field (divergence):\n');
fprintf('  support: %s\n', Fdiv.support);
fprintf('  valueType: %s\n', Fdiv.valueType);
fprintf('  shape: [%s]\n', sprintf('%d×', size(Fdiv.value)));
fprintf('  operator: %s\n', Fdiv.metadata.operatorId);

% Validate output
assert(strcmp(Fdiv.support, 'vertex'), 'Divergence output should have vertex support');
assert(strcmp(Fdiv.valueType, 'scalar'), 'Divergence output should be scalar');
assert(strcmp(Fdiv.metadata.operatorId, 'divergence.dec.field'), 'Operator provenance missing');

fprintf('\n✓ Divergence operator Field-native test passed\n\n');

%% Test 4: Laplacian Operator (vertex scalar → vertex scalar)
fprintf('=== Test 4: Laplacian Operator (Field-Native) ===\n');

% Apply Laplacian to original scalar field
lapOp = ops('laplacian.dec.field');
Flap = lapOp.applyFcn(Fin);

fprintf('Output Field (Laplacian):\n');
fprintf('  support: %s\n', Flap.support);
fprintf('  valueType: %s\n', Flap.valueType);
fprintf('  shape: [%s]\n', sprintf('%d×', size(Flap.value)));
fprintf('  operator: %s\n', Flap.metadata.operatorId);

% Validate output
assert(strcmp(Flap.support, 'vertex'), 'Laplacian output should have vertex support');
assert(strcmp(Flap.valueType, 'scalar'), 'Laplacian output should be scalar');
assert(strcmp(Flap.metadata.operatorId, 'laplacian.dec.field'), 'Operator provenance missing');

fprintf('\n✓ Laplacian operator Field-native test passed\n\n');

%% Test 5: Operator Composition (gradient → divergence)
fprintf('=== Test 5: Operator Composition ===\n');

% Compose: Laplacian = div(grad(f))
% We already have div(grad(f)) in Fdiv
% Compare with direct Laplacian

maxDiff = max(abs(Fdiv.value - Flap.value));
relativeDiff = maxDiff / max(abs(Flap.value));

fprintf('Comparing div(grad(f)) vs Laplacian(f):\n');
fprintf('  Max absolute difference: %.6e\n', maxDiff);
fprintf('  Max relative difference: %.6e\n', relativeDiff);

% Should be numerically similar (within tolerance)
assert(relativeDiff < 0.1, 'div(grad) should approximate Laplacian');

fprintf('\n✓ Operator composition test passed\n\n');

%% Test 6: Time-Varying Field Support
fprintf('=== Test 6: Time-Varying Field Support ===\n');

% Create time-varying scalar field
T = 10;
timeVaryingData = zeros(nv, T);
for t = 1:T
    timeVaryingData(:, t) = sin(2*pi*V(:,1) + t/T*2*pi);
end

FtimeIn = bct.fields.make('support', 'vertex', ...
                          'valueType', 'scalar', ...
                          'value', timeVaryingData, ...
                          'time', struct('t0', 0, 'dt', 0.1, 'unit', 's'), ...
                          'meshId', M.ID);

fprintf('Time-varying input:\n');
fprintf('  shape: [%s]\n', sprintf('%d×', size(FtimeIn.value)));
fprintf('  time-varying: %s\n', string(bct.fields.isTimeVarying(FtimeIn)));
fprintf('  nSamples: %d\n\n', length(FtimeIn.time.samples));

% Apply gradient to time-varying field
FtimeGrad = gradOp.applyFcn(FtimeIn);

fprintf('Time-varying gradient output:\n');
fprintf('  shape: [%s]\n', sprintf('%d×', size(FtimeGrad.value)));
fprintf('  time-varying: %s\n', string(bct.fields.isTimeVarying(FtimeGrad)));
fprintf('  nSamples: %d\n', length(FtimeGrad.time.samples));

% Validate time preservation
assert(bct.fields.isTimeVarying(FtimeGrad), 'Output should be time-varying');
assert(length(FtimeGrad.time.samples) == T, 'Time samples should be preserved');
assert(FtimeGrad.time.dt == FtimeIn.time.dt, 'dt should be preserved');

fprintf('\n✓ Time-varying field support test passed\n\n');

%% Test 7: Error Handling - Wrong Support Type
fprintf('=== Test 7: Error Handling - Wrong Support Type ===\n');

% Try to apply gradient to face field (should error)
nf = M.numFaces();
badField = bct.fields.make('support', 'face', ...
                            'valueType', 'scalar', ...
                            'value', rand(nf, 1), ...
                            'meshId', M.ID);

try
    Fbad = gradOp.applyFcn(badField);
    error('Should have thrown error for wrong support type');
catch ME
    fprintf('Caught expected error:\n');
    fprintf('  ID: %s\n', ME.identifier);
    fprintf('  Message: %s\n', ME.message);
    assert(strcmp(ME.identifier, 'bct:runtime:SupportMismatch'), 'Wrong error ID');
    fprintf('\n✓ Error handling test passed\n\n');
end

%% Test 8: Error Handling - MeshId Mismatch
fprintf('=== Test 8: Error Handling - MeshId Mismatch ===\n');

% Create field with wrong meshId
wrongMeshField = bct.fields.make('support', 'vertex', ...
                                 'valueType', 'scalar', ...
                                 'value', rand(nv, 1), ...
                                 'meshId', 'wrong_mesh_id');

try
    Fwrong = gradOp.applyFcn(wrongMeshField);
    error('Should have thrown error for meshId mismatch');
catch ME
    fprintf('Caught expected error:\n');
    fprintf('  ID: %s\n', ME.identifier);
    fprintf('  Message: %s\n', ME.message);
    assert(strcmp(ME.identifier, 'bct:runtime:MismatchedMeshId'), 'Wrong error ID');
    fprintf('\n✓ MeshId mismatch handling test passed\n\n');
end

%% Summary
fprintf('====================================\n');
fprintf('✅ All 8 Field-native operator tests passed!\n');
fprintf('====================================\n\n');

fprintf('Field-as-first-class-artifact architecture verified:\n');
fprintf('  ✓ Field signatures in registry\n');
fprintf('  ✓ Runtime Field wrapping\n');
fprintf('  ✓ Input/output validation\n');
fprintf('  ✓ Provenance tracking\n');
fprintf('  ✓ Time preservation\n');
fprintf('  ✓ MeshId enforcement\n');
fprintf('  ✓ Support/valueType type safety\n');
fprintf('  ✓ Operator composition\n\n');
