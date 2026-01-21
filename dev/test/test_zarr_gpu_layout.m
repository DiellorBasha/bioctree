%% TEST_ZARR_GPU_LAYOUT  Verify GPU-friendly Zarr export
%
% This test verifies that the Zarr export produces GPU-optimized data:
% 1. C-order (row-major) memory layout for interleaved attributes
% 2. Float32 vertices (not float64) for GPU efficiency
% 3. Uint32 faces/edges with 0-based indexing
% 4. Proper Zarr v2 metadata (order="C", dtype="<f4")
%
% Expected behavior:
% - Vertices stored as [x1,y1,z1, x2,y2,z2, ...] (interleaved)
% - NOT [x1...xN, y1...yN, z1...zN] (MATLAB column-major)
% - Ready for direct GPU buffer upload in Three.js

%% Setup
addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'toolbox'));

% Use bunny mesh for testing (canonical test would be fsaverage_rh_pial)
M = bct.Manifold.read(fullfile(fileparts(mfilename('fullpath')), '..', '..', ...
    'toolbox', '+bct', '+data', 'assets', 'bunny.obj'));

% Export to Zarr
testFile = 'test_gpu_layout.zarr';
if exist(testFile, 'dir')
    rmdir(testFile, 's');
end
bct.file.manifold.write.zarr(testFile, M);

%% Test 1: Verify float32 vertex dtype
fprintf('Test 1: Verify float32 vertex storage\n');
vertexMeta = jsondecode(fileread(fullfile(testFile, 'manifold', 'vertices', '.zarray')));
assert(strcmp(vertexMeta.dtype, '<f4'), 'Expected float32 (<f4) dtype for vertices');
assert(strcmp(vertexMeta.order, 'C'), 'Expected C-order (row-major) layout');
fprintf('  ✓ dtype = %s (float32, little-endian)\n', vertexMeta.dtype);
fprintf('  ✓ order = %s (row-major, GPU-friendly)\n', vertexMeta.order);

%% Test 2: Verify C-order interleaved layout
fprintf('\nTest 2: Verify C-order interleaved vertex layout\n');
fid = fopen(fullfile(testFile, 'manifold', 'vertices', '0.0'), 'r');
rawBytes = fread(fid, [3, 5], 'single')';  % Read first 5 vertices
fclose(fid);

% Compare with original MATLAB data
originalVerts = single(M.Vertices(1:5, :));

% If layout is correct, rawBytes should match originalVerts
maxDiff = max(abs(rawBytes(:) - originalVerts(:)));
assert(maxDiff < 1e-6, 'Vertex data mismatch (layout error)');
fprintf('  ✓ Interleaved layout verified\n');
fprintf('  ✓ First vertex: [%.4f, %.4f, %.4f]\n', rawBytes(1,:));
fprintf('  ✓ Matches MATLAB: [%.4f, %.4f, %.4f]\n', originalVerts(1,:));

%% Test 3: Verify 0-based face indices
fprintf('\nTest 3: Verify 0-based face indexing\n');
faceMeta = jsondecode(fileread(fullfile(testFile, 'manifold', 'faces', '.zarray')));
assert(strcmp(faceMeta.dtype, '<u4'), 'Expected uint32 (<u4) dtype for faces');
assert(strcmp(faceMeta.order, 'C'), 'Expected C-order layout for faces');

fid = fopen(fullfile(testFile, 'manifold', 'faces', '0.0'), 'r');
faces = fread(fid, [3, inf], 'uint32')';
fclose(fid);

minIdx = min(faces(:));
maxIdx = max(faces(:));
expectedMax = size(M.Vertices, 1) - 1;

assert(minIdx == 0, 'Expected min face index = 0');
assert(maxIdx == expectedMax, 'Expected max face index = N-1');
fprintf('  ✓ Min index: %d (0-based)\n', minIdx);
fprintf('  ✓ Max index: %d (expected %d)\n', maxIdx, expectedMax);

%% Test 4: Verify chunking policy (no chunking for manifold data)
fprintf('\nTest 4: Verify chunking policy\n');
fprintf('  Vertices: chunks = [%s] (shape = [%s])\n', ...
    sprintf('%d ', vertexMeta.chunks), sprintf('%d ', vertexMeta.shape));
fprintf('  Faces: chunks = [%s] (shape = [%s])\n', ...
    sprintf('%d ', faceMeta.chunks), sprintf('%d ', faceMeta.shape));

% Manifold topology should NOT be chunked (chunks == shape)
assert(isequal(vertexMeta.chunks, vertexMeta.shape), ...
    'Expected single chunk for vertices (chunks == shape)');
assert(isequal(faceMeta.chunks, faceMeta.shape), ...
    'Expected single chunk for faces (chunks == shape)');
fprintf('  ✓ Single chunk per dataset (no chunking)\n');
fprintf('  ✓ Chunking reserved for fields (future implementation)\n');

%% Test 5: Verify metadata attributes
fprintf('\nTest 5: Verify dataset attributes\n');
vertexAttrs = jsondecode(fileread(fullfile(testFile, 'manifold', 'vertices', '.zattrs')));
faceAttrs = jsondecode(fileread(fullfile(testFile, 'manifold', 'faces', '.zattrs')));

% JSON decodes arrays as cell arrays
assert(iscell(vertexAttrs.axis) && length(vertexAttrs.axis) == 2, ...
    'Expected vertex axis metadata');
assert(strcmp(vertexAttrs.dtype_target, 'float32'), 'Expected float32 target dtype');
assert(faceAttrs.index_base == 0, 'Expected 0-based index_base for faces');
assert(strcmp(faceAttrs.primitive, 'triangles'), 'Expected triangles primitive');

fprintf('  ✓ Vertex axis: [%s]\n', strjoin(string(vertexAttrs.axis), ', '));
fprintf('  ✓ Vertex dtype_target: %s\n', vertexAttrs.dtype_target);
fprintf('  ✓ Face index_base: %d\n', faceAttrs.index_base);
fprintf('  ✓ Face primitive: %s\n', faceAttrs.primitive);

%% Cleanup
rmdir(testFile, 's');

fprintf('\n✅ All GPU-friendly Zarr export tests passed!\n');
fprintf('\nSummary:\n');
fprintf('  • Vertices: float32, C-order interleaved [x,y,z, x,y,z, ...]\n');
fprintf('  • Faces: uint32, 0-based indices (min=0, max=N-1)\n');
fprintf('  • Ready for Three.js GPU buffer upload\n');
fprintf('  • No transpose or reordering needed on client side\n');
