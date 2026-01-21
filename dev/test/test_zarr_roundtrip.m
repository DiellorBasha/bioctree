%% TEST_ZARR_ROUNDTRIP  Verify Zarr write → read round-trip
%
% This test verifies complete round-trip functionality:
% 1. Write manifold to Zarr format
% 2. Read manifold back from Zarr
% 3. Verify data integrity (vertices, faces, edges)
% 4. Verify metadata preservation (Header fields)
%
% Expected behavior:
% - Exact vertex/face/edge data preservation
% - 0-based → 1-based index conversion
% - C-order → MATLAB column-major conversion
% - Full Header metadata restoration

%% Setup
addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'toolbox'));

% Use bunny mesh for testing
M_orig = bct.Manifold.read(fullfile(fileparts(mfilename('fullpath')), '..', '..', ...
    'toolbox', '+bct', '+data', 'assets', 'bunny.obj'));

% Export to Zarr
testFile = 'test_roundtrip.zarr';
if exist(testFile, 'dir')
    rmdir(testFile, 's');
end
bct.file.manifold.write.zarr(testFile, M_orig);

%% Test 1: Read as bct.Manifold object
fprintf('Test 1: Read as bct.Manifold object\n');
M_read = bct.file.manifold.read.zarr(testFile);

% Verify class
assert(isa(M_read, 'bct.Manifold'), 'Expected bct.Manifold object');
fprintf('  ✓ Returned bct.Manifold object\n');

% Verify dimensions
assert(size(M_read.Vertices, 1) == size(M_orig.Vertices, 1), ...
    'Vertex count mismatch');
assert(size(M_read.Faces, 1) == size(M_orig.Faces, 1), ...
    'Face count mismatch');
fprintf('  ✓ Dimensions: %d vertices, %d faces\n', ...
    size(M_read.Vertices, 1), size(M_read.Faces, 1));

% Verify data integrity
vertDiff = max(abs(M_orig.Vertices(:) - M_read.Vertices(:)));
faceDiff = max(abs(M_orig.Faces(:) - M_read.Faces(:)));
edgeDiff = max(abs(M_orig.Edges(:) - M_read.Edges(:)));

assert(vertDiff < 1e-6, 'Vertex data mismatch');
assert(faceDiff == 0, 'Face data mismatch');
assert(edgeDiff == 0, 'Edge data mismatch');

fprintf('  ✓ Data integrity: vertex diff=%.2e, face diff=%d, edge diff=%d\n', ...
    vertDiff, faceDiff, edgeDiff);

%% Test 2: Read as struct with metadata
fprintf('\nTest 2: Read as struct with full metadata\n');
data = bct.file.manifold.read.zarr(testFile, 'ReturnStruct', true);

% Verify structure
assert(isstruct(data), 'Expected struct');
assert(isfield(data, 'Vertices'), 'Missing Vertices field');
assert(isfield(data, 'Faces'), 'Missing Faces field');
assert(isfield(data, 'Edges'), 'Missing Edges field');
assert(isfield(data, 'Header'), 'Missing Header field');
fprintf('  ✓ Struct fields: Vertices, Faces, Edges, Header\n');

% Verify Header metadata
H = data.Header;
assert(isfield(H, 'Id') && strlength(H.Id) > 0, 'Missing ID');
assert(isfield(H, 'Name') && strcmp(H.Name, 'bunny'), 'Name mismatch');
assert(isfield(H, 'CoordinateSystem'), 'Missing CoordinateSystem');
assert(isfield(H, 'FaceWinding') && strcmp(H.FaceWinding, 'CCW'), 'FaceWinding mismatch');
assert(isfield(H, 'Metric') && isfield(H.Metric, 'Unit'), 'Missing Metric.Unit');
assert(isfield(H, 'Source'), 'Missing Source');
assert(isfield(H, 'CreatedBy'), 'Missing CreatedBy');

fprintf('  ✓ Header metadata preserved:\n');
fprintf('    - Name: %s\n', H.Name);
fprintf('    - ID: %s\n', H.Id);
fprintf('    - Coordinate System: %s\n', H.CoordinateSystem);
fprintf('    - Face Winding: %s\n', H.FaceWinding);
fprintf('    - Units: %s\n', H.Metric.Unit);

%% Test 3: Verify index conversion (0-based → 1-based)
fprintf('\nTest 3: Verify index conversion\n');

% Read raw Zarr data to check 0-based indices
fid = fopen(fullfile(testFile, 'manifold', 'faces', '0.0'), 'r');
rawFaces = fread(fid, [3, inf], 'uint32')';
fclose(fid);

minIdx = min(rawFaces(:));
maxIdx = max(rawFaces(:));
assert(minIdx == 0, 'Expected 0-based indices in Zarr file');
fprintf('  ✓ Zarr file has 0-based indices (min=%d, max=%d)\n', minIdx, maxIdx);

% Verify converted data is 1-based
minIdxConverted = min(data.Faces(:));
maxIdxConverted = max(data.Faces(:));
assert(minIdxConverted == 1, 'Expected 1-based indices after reading');
assert(maxIdxConverted == size(data.Vertices, 1), 'Max index should equal vertex count');
fprintf('  ✓ Converted to 1-based (min=%d, max=%d)\n', minIdxConverted, maxIdxConverted);

%% Test 4: Verify C-order → MATLAB column-major conversion
fprintf('\nTest 4: Verify memory layout conversion\n');

% Read first vertex from Zarr (C-order: x1,y1,z1, x2,y2,z2, ...)
fid = fopen(fullfile(testFile, 'manifold', 'vertices', '0.0'), 'r');
rawVertex1 = fread(fid, 3, 'single');  % First 3 values: x1, y1, z1
fclose(fid);

% Compare with MATLAB data
vertex1 = data.Vertices(1, :);
diff = max(abs(rawVertex1 - vertex1'));
assert(diff < 1e-6, 'Vertex layout mismatch');
fprintf('  ✓ C-order correctly converted to MATLAB layout\n');
fprintf('    Raw Zarr: [%.4f, %.4f, %.4f]\n', rawVertex1);
fprintf('    MATLAB:   [%.4f, %.4f, %.4f]\n', vertex1);

%% Test 5: Schema validation
fprintf('\nTest 5: Schema validation\n');

% Read root attributes
rootAttrs = jsondecode(fileread(fullfile(testFile, '.zattrs')));
assert(strcmp(rootAttrs.schema, 'bct.manifold@1'), 'Schema mismatch');
assert(strcmp(rootAttrs.format, 'zarr'), 'Format should be zarr');
fprintf('  ✓ Schema: %s\n', rootAttrs.schema);
fprintf('  ✓ Format: %s\n', rootAttrs.format);

%% Cleanup
rmdir(testFile, 's');

fprintf('\n✅ All Zarr round-trip tests passed!\n');
fprintf('\nSummary:\n');
fprintf('  • bct.Manifold object reconstruction: ✓\n');
fprintf('  • Struct with full metadata: ✓\n');
fprintf('  • Index conversion (0→1 based): ✓\n');
fprintf('  • Memory layout conversion (C→MATLAB): ✓\n');
fprintf('  • Schema validation: ✓\n');
fprintf('  • Data integrity: exact match\n');
