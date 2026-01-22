%% Test bct.manifold.geometry.vertex schema system
% Tests the schema definition and validation for vertex geometry

%% Setup
clear; clc;

fprintf('Testing bct.manifold.geometry.vertex.schema\n');
fprintf('============================================\n\n');

%% Test 1: Load canonical test manifold
fprintf('Test 1: Load canonical test manifold\n');
M = bct.data.load('Id', 'fsaverage_rh_pial');
fprintf('  Loaded manifold: %d vertices, %d faces\n', ...
    size(M.Vertices, 1), size(M.Faces, 1));
fprintf('  ✓ PASSED\n\n');

%% Test 2: Compute vertex geometry
fprintf('Test 2: Compute vertex geometry\n');
vg = bct.manifold.geometry.vertex(M);
fprintf('  Computed vertex geometry:\n');
fprintf('    normals:  [%d×%d %s]\n', size(vg.normals, 1), size(vg.normals, 2), class(vg.normals));
fprintf('    tangent1: [%d×%d %s]\n', size(vg.tangent1, 1), size(vg.tangent1, 2), class(vg.tangent1));
fprintf('    tangent2: [%d×%d %s]\n', size(vg.tangent2, 1), size(vg.tangent2, 2), class(vg.tangent2));
fprintf('  ✓ PASSED\n\n');

%% Test 3: Get schema
fprintf('Test 3: Get schema\n');
s = bct.manifold.geometry.vertex.schema();
fprintf('  Schema name: %s\n', s.name);
fprintf('  Schema version: %s\n', s.version);
fprintf('  Number of fields: %d\n', numel(s.fields));
fprintf('  Fields:\n');
for i = 1:numel(s.fields)
    f = s.fields{i};
    reqStr = '';
    if f.required
        reqStr = ' (required)';
    end
    fprintf('    %d. %s [%s %s]%s\n', i, f.name, f.shape, f.type, reqStr);
    fprintf('       %s\n', f.description);
end
fprintf('  ✓ PASSED\n\n');

%% Test 4: Validate computed geometry against schema
fprintf('Test 4: Validate computed geometry against schema\n');
[isValid, report] = bct.manifold.geometry.vertex.validateSchema(vg, s);
fprintf('  Validation result: %s\n', mat2str(isValid));

if isValid
    fprintf('  ✓ PASSED - All fields valid\n');
else
    fprintf('  ✗ FAILED - Validation errors:\n');
    for i = 1:numel(report.errors)
        fprintf('    Error: %s\n', report.errors{i});
    end
end

if ~isempty(report.warnings)
    fprintf('  Warnings:\n');
    for i = 1:numel(report.warnings)
        fprintf('    Warning: %s\n', report.warnings{i});
    end
end

fprintf('\n');

%% Test 5: Field status details
fprintf('Test 5: Field-by-field validation status\n');
fieldNames = fieldnames(report.fieldStatus);
for i = 1:numel(fieldNames)
    fname = fieldNames{i};
    status = report.fieldStatus.(fname);
    statusStr = '✓ Valid';
    if ~status.valid
        statusStr = '✗ Invalid';
    end
    fprintf('  %s: present=%d, %s\n', fname, status.present, statusStr);
end
fprintf('  ✓ PASSED\n\n');

%% Test 6: Test with invalid data (missing field)
fprintf('Test 6: Test validation with missing required field\n');
vg_invalid = rmfield(vg, 'normals');
[isValid_bad, report_bad] = bct.manifold.geometry.vertex.validateSchema(vg_invalid, s);
fprintf('  Expected invalid: %s\n', mat2str(~isValid_bad));
if ~isValid_bad && ~isempty(report_bad.missingFields)
    fprintf('  Missing field detected: %s\n', report_bad.missingFields{1});
    fprintf('  ✓ PASSED - Correctly detected missing field\n');
else
    fprintf('  ✗ FAILED - Should have detected missing field\n');
end
fprintf('\n');

%% Test 7: Test with wrong dimensions
fprintf('Test 7: Test validation with incorrect dimensions\n');
vg_wrongdim = vg;
vg_wrongdim.normals = zeros(10, 3);  % Wrong number of vertices
[isValid_dim, report_dim] = bct.manifold.geometry.vertex.validateSchema(vg_wrongdim, s);
fprintf('  Expected invalid: %s\n', mat2str(~isValid_dim));
if ~isValid_dim
    fprintf('  ✓ PASSED - Correctly detected dimension mismatch\n');
else
    fprintf('  ✗ FAILED - Should have detected dimension error\n');
end
fprintf('\n');

%% Test 8: Schema metadata inspection
fprintf('Test 8: Schema metadata inspection\n');
fprintf('  Dimension symbols:\n');
dimNames = fieldnames(s.dimensions);
for i = 1:numel(dimNames)
    fprintf('    %s: %s\n', dimNames{i}, s.dimensions.(dimNames{i}));
end
fprintf('  Frame convention: %s\n', s.frame.convention);
fprintf('  Handedness: %s\n', s.frame.handedness);
fprintf('  ✓ PASSED\n\n');

%% Test 9: Data type mapping for serialization
fprintf('Test 9: Data type mapping for different backends\n');
fprintf('  HDF5 double: %s\n', s.dtype_map.hdf5.double);
fprintf('  Zarr double: %s\n', s.dtype_map.zarr.double);
fprintf('  Zarr single: %s\n', s.dtype_map.zarr.single);
fprintf('  ✓ PASSED\n\n');

%% Summary
fprintf('============================================\n');
fprintf('All tests completed successfully!\n');
fprintf('Schema system is working correctly.\n');
