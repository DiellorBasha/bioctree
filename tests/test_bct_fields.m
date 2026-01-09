%% Test bct.fields package
%
% Comprehensive test suite for Field struct system

%% Setup
% Ensure we're in the bioctree root
if ~exist('bct_start.m', 'file')
    cd('..');
end
run('bct_start.m');

% Add icosphere to path if needed
if ~exist('icosphere', 'file')
    addpath(fullfile(pwd, 'external'));
end

% Create test manifold (icosphere)
[V, F] = icosphere(3);
M = bct.Manifold(V, F);

fprintf('Test manifold: %d vertices, %d faces\n', M.numVertices(), M.numFaces());

%% Test 1: Schema
fprintf('\n=== Test 1: Schema ===\n');
%% Test 1: Schema
fprintf('\n=== Test 1: Schema ===\n');

schema = bct.fields.schema();
assert(strcmp(schema.version, "bct.field@1"), 'Schema version mismatch');
assert(length(schema.supports) == 6, 'Schema should have 6 supports');
assert(length(schema.valueTypes) == 5, 'Schema should have 5 valueTypes');
assert(ismember("vertex", schema.supports), 'vertex must be in supports');
assert(ismember("scalar", schema.valueTypes), 'scalar must be in valueTypes');

fprintf('✓ Schema validation passed\n');

%% Test 2: Size of Support
fprintf('\n=== Test 2: Size of Support ===\n');

nv = bct.fields.sizeOfSupport("vertex", M);
assert(nv == M.numVertices(), 'vertex count mismatch');

nf = bct.fields.sizeOfSupport("face", M);
assert(nf == M.numFaces(), 'face count mismatch');

ne = bct.fields.sizeOfSupport("edge", M);
assert(ne == M.numEdges(), 'edge count mismatch');

nhe = bct.fields.sizeOfSupport("halfedge", M);
assert(nhe == 3 * M.numFaces(), 'halfedge count mismatch');

ndf = bct.fields.sizeOfSupport("dualFace", M);
assert(ndf == M.numVertices(), 'dualFace count mismatch');

ndv = bct.fields.sizeOfSupport("dualVertex", M);
assert(ndv == M.numFaces(), 'dualVertex count mismatch');

fprintf('✓ All support sizes correct\n');

%% Test 3: Static Scalar Vertex Field
fprintf('\n=== Test 3: Static Scalar Vertex Field ===\n');

nv = M.numVertices();
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'scalar', ...
                   'value', rand(nv, 1), ...
                   'meshId', M.ID);

assert(strcmp(F.support, 'vertex'), 'support mismatch');
assert(strcmp(F.valueType, 'scalar'), 'valueType mismatch');
assert(isequal(size(F.value), [nv, 1]), 'value size mismatch');
assert(strcmp(F.meshId, M.ID), 'meshId mismatch');
assert(~bct.fields.isTimeVarying(F), 'should not be time-varying');
assert(~isfield(F, 'time'), 'should not have time field');

% Validate with Manifold
bct.fields.validate(F, M);

fprintf('✓ Static scalar vertex field OK\n');

%% Test 4: Time-Varying Scalar Field
fprintf('\n=== Test 4: Time-Varying Scalar Field ===\n');

nv = M.numVertices();
T = 50;
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'scalar', ...
                   'value', rand(nv, T), ...
                   'time', struct('t0', 0, 'dt', 0.01, 'unit', 's'));

assert(isequal(size(F.value), [nv, T]), 'value size mismatch');
assert(bct.fields.isTimeVarying(F), 'should be time-varying');
assert(isfield(F, 'time'), 'should have time field');
assert(F.time.t0 == 0.0, 't0 mismatch');
assert(F.time.dt == 0.01, 'dt mismatch');
assert(strcmp(F.time.unit, 's'), 'time unit mismatch');
assert(length(F.time.samples) == T, 'samples length mismatch');

fprintf('✓ Time-varying scalar field OK\n');

%% Test 5: Static Vector3 Field
fprintf('\n=== Test 5: Static Vector3 Field ===\n');

nv = M.numVertices();
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'vector3', ...
                   'value', rand(nv, 3));

assert(strcmp(F.valueType, 'vector3'), 'valueType mismatch');
assert(isequal(size(F.value), [nv, 3]), 'value size mismatch');
assert(~bct.fields.isTimeVarying(F), 'should not be time-varying');

fprintf('✓ Static vector3 field OK\n');

%% Test 6: Time-Varying Vector3 Field
fprintf('\n=== Test 6: Time-Varying Vector3 Field ===\n');

nf = M.numFaces();
T = 30;
F = bct.fields.make('support', 'face', ...
                   'valueType', 'vector3', ...
                   'value', rand(nf, 3, T));

assert(isequal(size(F.value), [nf, 3, T]), 'value size mismatch');
assert(bct.fields.isTimeVarying(F), 'should be time-varying');
assert(isfield(F, 'time'), 'should have time field');
assert(length(F.time.samples) == T, 'samples length mismatch');

fprintf('✓ Time-varying vector3 field OK\n');

%% Test 7: Static Tangent2 Field
fprintf('\n=== Test 7: Static Tangent2 Field ===\n');

nv = M.numVertices();
tangents = rand(nv, 2);
frames = rand(nv, 2, 3);

F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'tangent2', ...
                   'value', tangents, ...
                   'frame', frames);

assert(strcmp(F.valueType, 'tangent2'), 'valueType mismatch');
assert(isequal(size(F.value), [nv, 2]), 'value size mismatch');
assert(isequal(size(F.frame), [nv, 2, 3]), 'frame size mismatch');
assert(~bct.fields.isTimeVarying(F), 'should not be time-varying');

fprintf('✓ Static tangent2 field OK\n');

%% Test 8: Time-Varying Tangent2 Field
fprintf('\n=== Test 8: Time-Varying Tangent2 Field ===\n');

nv = M.numVertices();
T = 20;
tangents = rand(nv, 2, T);
frames = rand(nv, 2, 3, T);

F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'tangent2', ...
                   'value', tangents, ...
                   'frame', frames);

assert(isequal(size(F.value), [nv, 2, T]), 'value size mismatch');
assert(isequal(size(F.frame), [nv, 2, 3, T]), 'frame size mismatch');
assert(bct.fields.isTimeVarying(F), 'should be time-varying');

fprintf('✓ Time-varying tangent2 field OK\n');

%% Test 9: Tangent2 Missing Frame Error
fprintf('\n=== Test 9: Tangent2 Missing Frame Error ===\n');

nv = M.numVertices();
try
    F = bct.fields.make('support', 'vertex', ...
                       'valueType', 'tangent2', ...
                       'value', rand(nv, 2));
    error('Should have thrown error for missing frame');
catch ME
    assert(strcmp(ME.identifier, 'bct:Field:MissingFrame'), 'Wrong error ID');
    fprintf('✓ Correctly caught missing frame error\n');
end

%% Test 10: Complex Scalar Field
fprintf('\n=== Test 10: Complex Scalar Field ===\n');

nv = M.numVertices();
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'complexScalar', ...
                   'value', complex(rand(nv, 1), rand(nv, 1)));

assert(strcmp(F.valueType, 'complexScalar'), 'valueType mismatch');
assert(~isreal(F.value), 'value should be complex');

fprintf('✓ Complex scalar field OK\n');

%% Test 11: Complex Vector3 Field
fprintf('\n=== Test 11: Complex Vector3 Field ===\n');

nf = M.numFaces();
T = 10;
F = bct.fields.make('support', 'face', ...
                   'valueType', 'complexVector3', ...
                   'value', complex(rand(nf, 3, T), rand(nf, 3, T)));

assert(strcmp(F.valueType, 'complexVector3'), 'valueType mismatch');
assert(~isreal(F.value), 'value should be complex');
assert(bct.fields.isTimeVarying(F), 'should be time-varying');

fprintf('✓ Complex vector3 field OK\n');

%% Test 12: Select Time - Single Sample
fprintf('\n=== Test 12: Select Time - Single Sample ===\n');

nv = M.numVertices();
T = 50;
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'scalar', ...
                   'value', rand(nv, T));

% Extract single time point -> becomes static
Fsnap = bct.fields.selectTime(F, 25);
assert(~bct.fields.isTimeVarying(Fsnap), 'should not be time-varying');
assert(isequal(size(Fsnap.value), [nv, 1]), 'value size mismatch');
assert(~isfield(Fsnap, 'time'), 'should not have time field');

fprintf('✓ Time selection (single) OK\n');

%% Test 13: Select Time - Range
fprintf('\n=== Test 13: Select Time - Range ===\n');

nv = M.numVertices();
T = 100;
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'scalar', ...
                   'value', rand(nv, T), ...
                   'time', struct('t0', 0, 'dt', 0.01, 'unit', 's'));

% Extract subset
Fsub = bct.fields.selectTime(F, 1:2:50);
assert(bct.fields.isTimeVarying(Fsub), 'should be time-varying');
assert(isequal(size(Fsub.value), [nv, 25]), 'value size mismatch');
assert(length(Fsub.time.samples) == 25, 'samples length mismatch');

fprintf('✓ Time selection (range) OK\n');

%% Test 14: withTime
fprintf('\n=== Test 14: withTime ===\n');

nv = M.numVertices();
T = 50;
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'scalar', ...
                   'value', rand(nv, T));

% Update time metadata
newTime = struct('t0', -0.5, 'dt', 0.001, 'unit', 'ms');
Fout = bct.fields.withTime(F, newTime);

assert(Fout.time.t0 == -0.5, 't0 mismatch');
assert(Fout.time.dt == 0.001, 'dt mismatch');
assert(strcmp(Fout.time.unit, 'ms'), 'time unit mismatch');

fprintf('✓ withTime OK\n');

%% Test 15: withMeta
fprintf('\n=== Test 15: withMeta ===\n');

nv = M.numVertices();
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'scalar', ...
                   'value', rand(nv, 1));

meta1 = struct('source', 'simulation', 'date', '2024-01-01');
F1 = bct.fields.withMeta(F, meta1);
assert(isfield(F1, 'metadata'), 'should have metadata');
assert(strcmp(F1.metadata.source, 'simulation'), 'metadata.source mismatch');

% Merge additional metadata
meta2 = struct('processed', true, 'filter', 'lowpass');
F2 = bct.fields.withMeta(F1, meta2);
assert(strcmp(F2.metadata.source, 'simulation'), 'metadata.source should persist');
assert(F2.metadata.processed == true, 'metadata.processed mismatch');

fprintf('✓ withMeta OK\n');

%% Test 16: cast
fprintf('\n=== Test 16: cast ===\n');

nv = M.numVertices();
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'scalar', ...
                   'value', rand(nv, 1));

Fsingle = bct.fields.cast(F, 'single');
assert(strcmp(class(Fsingle.value), 'single'), 'value class should be single');

Fdouble = bct.fields.cast(Fsingle, 'double');
assert(strcmp(class(Fdouble.value), 'double'), 'value class should be double');

fprintf('✓ cast OK\n');

%% Test 17: infer - Scalar
fprintf('\n=== Test 17: infer - Scalar ===\n');

nv = M.numVertices();
F = bct.fields.infer('vertex', rand(nv, 1));
assert(strcmp(F.valueType, 'scalar'), 'valueType should be scalar');

fprintf('✓ infer scalar OK\n');

%% Test 18: infer - Vector3
fprintf('\n=== Test 18: infer - Vector3 ===\n');

nf = M.numFaces();
F = bct.fields.infer('face', rand(nf, 3));
assert(strcmp(F.valueType, 'vector3'), 'valueType should be vector3');

fprintf('✓ infer vector3 OK\n');

%% Test 19: infer - Time-Varying Scalar
fprintf('\n=== Test 19: infer - Time-Varying Scalar ===\n');

nv = M.numVertices();
F = bct.fields.infer('vertex', rand(nv, 50));
assert(strcmp(F.valueType, 'scalar'), 'valueType should be scalar');
assert(bct.fields.isTimeVarying(F), 'should be time-varying');

fprintf('✓ infer time-varying scalar OK\n');

%% Test 20: infer - Tangent2
fprintf('\n=== Test 20: infer - Tangent2 ===\n');

nv = M.numVertices();
frames = rand(nv, 2, 3);
F = bct.fields.infer('vertex', rand(nv, 2), 'frame', frames);
assert(strcmp(F.valueType, 'tangent2'), 'valueType should be tangent2');

fprintf('✓ infer tangent2 OK\n');

%% Test 21: infer - Complex Scalar
fprintf('\n=== Test 21: infer - Complex Scalar ===\n');

nv = M.numVertices();
F = bct.fields.infer('vertex', complex(rand(nv, 1), rand(nv, 1)));
assert(strcmp(F.valueType, 'complexScalar'), 'valueType should be complexScalar');

fprintf('✓ infer complexScalar OK\n');

%% Test 22: toStruct / fromStruct
fprintf('\n=== Test 22: toStruct / fromStruct ===\n');

nv = M.numVertices();
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'scalar', ...
                   'value', rand(nv, 1), ...
                   'meshId', M.ID);

S = bct.fields.toStruct(F);
assert(isstruct(S), 'S should be struct');

F2 = bct.fields.fromStruct(S);
assert(strcmp(F2.support, F.support), 'support mismatch');
assert(strcmp(F2.valueType, F.valueType), 'valueType mismatch');
assert(strcmp(F2.meshId, F.meshId), 'meshId mismatch');

fprintf('✓ Serialization OK\n');

%% Test 23: Invalid Support Error
fprintf('\n=== Test 23: Invalid Support Error ===\n');

nv = M.numVertices();
try
    F = bct.fields.make('support', 'invalid', ...
                       'valueType', 'scalar', ...
                       'value', rand(nv, 1));
    error('Should have thrown error for invalid support');
catch ME
    assert(strcmp(ME.identifier, 'bct:Field:InvalidSupport'), 'Wrong error ID');
    fprintf('✓ Correctly caught invalid support error\n');
end

%% Test 24: Invalid ValueType Error
fprintf('\n=== Test 24: Invalid ValueType Error ===\n');

nv = M.numVertices();
try
    F = bct.fields.make('support', 'vertex', ...
                       'valueType', 'invalid', ...
                       'value', rand(nv, 1));
    error('Should have thrown error for invalid valueType');
catch ME
    assert(strcmp(ME.identifier, 'bct:Field:InvalidValueType'), 'Wrong error ID');
    fprintf('✓ Correctly caught invalid valueType error\n');
end

%% Test 25: Mismatched MeshId Error
fprintf('\n=== Test 25: Mismatched MeshId Error ===\n');

nv = M.numVertices();
F = bct.fields.make('support', 'vertex', ...
                   'valueType', 'scalar', ...
                   'value', rand(nv, 1), ...
                   'meshId', 'wrong_id');

try
    bct.fields.validate(F, M);
    error('Should have thrown error for mismatched meshId');
catch ME
    assert(strcmp(ME.identifier, 'bct:Field:MismatchedMeshId'), 'Wrong error ID');
    fprintf('✓ Correctly caught mismatched meshId error\n');
end

%% Summary
fprintf('\n====================================\n');
fprintf('✅ All 25 tests passed!\n');
fprintf('====================================\n');
fprintf('\nbct.fields package implementation complete.\n');
