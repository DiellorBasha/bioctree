% Test script for Manifold read/write methods
% Tests instance method syntax: M.write() and static method: bct.Manifold.read()

% Initialize bioctree
bct_start;

fprintf('\n=== Testing Manifold Read/Write Methods ===\n\n');

% Load test mesh
fprintf('Loading test mesh...\n');
data = load('data/mesh/fsaverage_rh_pial.mat');
M = bct.Manifold(data.V, data.F);
fprintf('Original mesh: %d vertices, %d faces\n\n', size(M.Vertices,1), size(M.Faces,1));

% Test 1: OBJ format
fprintf('Test 1: OBJ format\n');
M.write('test_output.obj');
fprintf('  Written to test_output.obj\n');
M_obj = bct.Manifold.read('test_output.obj');
fprintf('  Read back: %d vertices, %d faces\n', size(M_obj.Vertices,1), size(M_obj.Faces,1));
assert(size(M_obj.Vertices,1) == size(M.Vertices,1), 'OBJ vertex count mismatch');
delete('test_output.obj');
fprintf('  ✓ OBJ test passed\n\n');

% Test 2: GLB format
fprintf('Test 2: GLB format\n');
M.write('test_output.glb');
fprintf('  Written to test_output.glb\n');
M_glb = bct.Manifold.read('test_output.glb');
fprintf('  Read back: %d vertices, %d faces\n', size(M_glb.Vertices,1), size(M_glb.Faces,1));
assert(size(M_glb.Vertices,1) == size(M.Vertices,1), 'GLB vertex count mismatch');
delete('test_output.glb');
fprintf('  ✓ GLB test passed\n\n');

% Test 3: GLTF format
fprintf('Test 3: GLTF format\n');
M.write('test_output.gltf');
fprintf('  Written to test_output.gltf\n');
M_gltf = bct.Manifold.read('test_output.gltf');
fprintf('  Read back: %d vertices, %d faces\n', size(M_gltf.Vertices,1), size(M_gltf.Faces,1));
assert(size(M_gltf.Vertices,1) == size(M.Vertices,1), 'GLTF vertex count mismatch');
delete('test_output.gltf');
fprintf('  ✓ GLTF test passed\n\n');

% Test 4: HDF5 format (.h5)
fprintf('Test 4: HDF5 format (.h5)\n');
M.write('test_output.h5');
fprintf('  Written to test_output.h5\n');
M_h5 = bct.Manifold.read('test_output.h5');
fprintf('  Read back: %d vertices, %d faces\n', size(M_h5.Vertices,1), size(M_h5.Faces,1));
assert(size(M_h5.Vertices,1) == size(M.Vertices,1), 'HDF5 vertex count mismatch');
assert(size(M_h5.Faces,1) == size(M.Faces,1), 'HDF5 face count mismatch');
delete('test_output.h5');
fprintf('  ✓ HDF5 (.h5) test passed\n\n');

% Test 5: HDF5 format (.hdf5)
fprintf('Test 5: HDF5 format (.hdf5)\n');
M.write('test_output.hdf5');
fprintf('  Written to test_output.hdf5\n');
M_hdf5 = bct.Manifold.read('test_output.hdf5');
fprintf('  Read back: %d vertices, %d faces\n', size(M_hdf5.Vertices,1), size(M_hdf5.Faces,1));
assert(size(M_hdf5.Vertices,1) == size(M.Vertices,1), 'HDF5 vertex count mismatch');
assert(size(M_hdf5.Faces,1) == size(M.Faces,1), 'HDF5 face count mismatch');
delete('test_output.hdf5');
fprintf('  ✓ HDF5 (.hdf5) test passed\n\n');

% Test 6: MAT format
fprintf('Test 6: MAT format\n');
M.write('test_output.mat');
fprintf('  Written to test_output.mat\n');
M_mat = bct.Manifold.read('test_output.mat');
fprintf('  Read back: %d vertices, %d faces\n', size(M_mat.Vertices,1), size(M_mat.Faces,1));
assert(size(M_mat.Vertices,1) == size(M.Vertices,1), 'MAT vertex count mismatch');
assert(size(M_mat.Faces,1) == size(M.Faces,1), 'MAT face count mismatch');
delete('test_output.mat');
fprintf('  ✓ MAT test passed\n\n');

% Test 7: Using bct.manifold.write and bct.manifold.read directly
fprintf('Test 7: Direct function call syntax\n');
bct.manifold.write(M, 'test_output_direct.obj');
fprintf('  Written using bct.manifold.write()\n');
M_direct = bct.manifold.read('test_output_direct.obj');
fprintf('  Read using bct.manifold.read()\n');
assert(size(M_direct.Vertices,1) == size(M.Vertices,1), 'Direct call vertex count mismatch');
delete('test_output_direct.obj');
fprintf('  ✓ Direct function call test passed\n\n');

fprintf('=== All tests passed! ===\n');
