% Test script for centroids function
bct_start;

fprintf('=== Testing bct.manifold.centroids ===\n\n');

% Load test mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
M = bct.Manifold(data.V, data.F);
fprintf('Test mesh: %d vertices, %d faces\n\n', size(M.Vertices,1), size(M.Faces,1));

% Test 1: Using Manifold object with package function
fprintf('Test 1: bct.manifold.centroids(M)\n');
C1 = bct.manifold.centroids(M);
fprintf('  Result: %d×%d matrix\n', size(C1,1), size(C1,2));
assert(size(C1,1) == size(M.Faces,1), 'Should have one centroid per face');
assert(size(C1,2) == 3, 'Should have 3 coordinates per centroid');
fprintf('  ✓ Test passed\n\n');

% Test 2: Using V, F with package function
fprintf('Test 2: bct.manifold.centroids(V, F)\n');
C2 = bct.manifold.centroids(M.Vertices, M.Faces);
fprintf('  Result: %d×%d matrix\n', size(C2,1), size(C2,2));
assert(isequal(C1, C2), 'Results should be identical');
fprintf('  ✓ Test passed\n\n');

% Test 3: Using instance method
fprintf('Test 3: M.centroids()\n');
C3 = M.centroids();
fprintf('  Result: %d×%d matrix\n', size(C3,1), size(C3,2));
assert(isequal(C1, C3), 'Results should be identical');
fprintf('  ✓ Test passed\n\n');

% Test 4: Verify correctness on simple triangle
fprintf('Test 4: Verify correctness on simple triangle\n');
V_simple = [0 0 0; 1 0 0; 0 1 0];
F_simple = [1 2 3];
C_simple = bct.manifold.centroids(V_simple, F_simple);
C_expected = [1/3, 1/3, 0];
assert(all(abs(C_simple - C_expected) < 1e-10), 'Centroid should be at (1/3, 1/3, 0)');
fprintf('  Expected: [%.4f, %.4f, %.4f]\n', C_expected);
fprintf('  Got:      [%.4f, %.4f, %.4f]\n', C_simple);
fprintf('  ✓ Test passed\n\n');

% Test 5: Check that centroids are within bounding box
fprintf('Test 5: Verify centroids are within mesh bounds\n');
bbox = M.boundingBox();
min_coords = min(C1);
max_coords = max(C1);
for dim = 1:3
    assert(min_coords(dim) >= bbox(dim,1) && max_coords(dim) <= bbox(dim,2), ...
        sprintf('Centroids should be within bounds for dimension %d', dim));
end
fprintf('  Min centroid coords: [%.2f, %.2f, %.2f]\n', min_coords);
fprintf('  Max centroid coords: [%.2f, %.2f, %.2f]\n', max_coords);
fprintf('  Mesh bounds: X[%.2f, %.2f], Y[%.2f, %.2f], Z[%.2f, %.2f]\n', ...
    bbox(1,1), bbox(1,2), bbox(2,1), bbox(2,2), bbox(3,1), bbox(3,2));
fprintf('  ✓ Test passed\n\n');

fprintf('=== All tests passed! ===\n');
