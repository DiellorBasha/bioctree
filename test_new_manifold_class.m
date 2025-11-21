%% Test New @Manifold Class Implementation
% This script tests the refactored bct.Manifold class with:
% - Renamed properties (Vertices, Faces, Laplacian, MassMatrix, CotangentMatrix)
% - Static methods (laplacian, meshFourier, maxLambda)
% - Automatic matrix computation via computeLaplacian()

clear; clc;

% Add required paths
addpath('external');
addpath('toolbox');  % For bct package
addpath(genpath('external/gptoolbox/mesh'));

%% Setup - Create simple icosphere mesh
fprintf('Creating test icosphere mesh...\n');
[V, F] = icosphere(2);  % 162 vertices, 320 faces
N = size(V, 1);
M_faces = size(F, 1);
fprintf('  Vertices: %d, Faces: %d\n', N, M_faces);

%% Test 1: Constructor with default Laplacian type
fprintf('\nTest 1: Constructor with default laplacian type...\n');
meshStruct = struct('V', V, 'F', F);
M1 = bct.Manifold(meshStruct);

% Verify properties are populated
assert(~isempty(M1.Vertices), 'Vertices should be populated');
assert(~isempty(M1.Faces), 'Faces should be populated');
assert(~isempty(M1.Laplacian), 'Laplacian should be populated');
assert(~isempty(M1.MassMatrix), 'MassMatrix should be populated');
assert(~isempty(M1.CotangentMatrix), 'CotangentMatrix should be populated');
assert(strcmp(M1.LaplacianType, 'cotangent'), 'Default type should be cotangent');
fprintf('  ✓ All properties populated correctly\n');
fprintf('  ✓ LaplacianType: %s\n', M1.LaplacianType);

% Verify dimensions
assert(isequal(size(M1.Vertices), [N, 3]), 'Vertices size mismatch');
assert(isequal(size(M1.Faces), [M_faces, 3]), 'Faces size mismatch');
assert(isequal(size(M1.Laplacian), [N, N]), 'Laplacian size mismatch');
assert(isequal(size(M1.MassMatrix), [N, N]), 'MassMatrix size mismatch');
assert(isequal(size(M1.CotangentMatrix), [N, N]), 'CotangentMatrix size mismatch');
fprintf('  ✓ All matrix dimensions correct\n');

% Verify helper methods
assert(M1.numVertices() == N, 'numVertices() incorrect');
assert(M1.numFaces() == M_faces, 'numFaces() incorrect');
fprintf('  ✓ Helper methods work correctly\n');

%% Test 2: Constructor with cotangent-normalized type
fprintf('\nTest 2: Constructor with cotangent-normalized type...\n');
M2 = bct.Manifold(meshStruct, 'cotangent-normalized');

assert(strcmp(M2.LaplacianType, 'cotangent-normalized'), 'Type should be cotangent-normalized');
assert(~isempty(M2.Laplacian), 'Laplacian should be populated');
fprintf('  ✓ Normalized Laplacian computed\n');
fprintf('  ✓ LaplacianType: %s\n', M2.LaplacianType);

% Verify Laplacians are different
assert(~isequal(M1.Laplacian, M2.Laplacian), 'Laplacians should differ by type');
fprintf('  ✓ Different Laplacian types produce different matrices\n');

%% Test 3: Static laplacian method
fprintf('\nTest 3: Static laplacian method...\n');
[L, M, K] = bct.Manifold.laplacian(V, F, 'cotangent');

assert(isequal(size(L), [N, N]), 'Static L size mismatch');
assert(isequal(size(M), [N, N]), 'Static M size mismatch');
assert(isequal(size(K), [N, N]), 'Static K size mismatch');
fprintf('  ✓ Static method returns correct dimensions\n');

% Verify matches constructor output
assert(norm(L - M1.Laplacian, 'fro') < 1e-10, 'Static L should match constructor');
assert(norm(M - M1.MassMatrix, 'fro') < 1e-10, 'Static M should match constructor');
assert(norm(K - M1.CotangentMatrix, 'fro') < 1e-10, 'Static K should match constructor');
fprintf('  ✓ Static method matches constructor output\n');

%% Test 4: Static meshFourier method
fprintf('\nTest 4: Static meshFourier method...\n');
k = 30;  % Compute first 30 modes
[U, lam] = bct.Manifold.meshFourier(M1, k);

assert(size(U, 1) == N, 'Eigenvector count should match vertices');
assert(size(U, 2) <= k, 'Should compute at most k eigenvectors');
assert(length(lam) == size(U, 2), 'Eigenvalue count should match eigenvectors');
fprintf('  ✓ Computed %d spectral modes\n', length(lam));
fprintf('  ✓ Eigenvalue range: [%.4f, %.4f]\n', min(lam), max(lam));

% Verify eigenvectors are orthonormal (standard inner product)
% meshFourier returns eigenvectors of normalized Laplacian, so they're orthonormal w.r.t. standard inner product
I_approx = U' * U;
assert(norm(I_approx - eye(size(I_approx)), 'fro') < 1e-6, 'Eigenvectors should be orthonormal');
fprintf('  ✓ Eigenvectors are orthonormal\n');

%% Test 5: estimateLambdaMax method
fprintf('\nTest 5: estimateLambdaMax method...\n');
lmax_est = M1.estimateLambdaMax();

assert(~isempty(lmax_est), 'estimateLambdaMax should return a value');
assert(lmax_est > 0, 'Estimated lambda_max should be positive');
fprintf('  ✓ Estimated maximum eigenvalue: %.4f\n', lmax_est);

% Verify estimate is an upper bound (Gershgorin Circle theorem)
lmax_true = bct.Manifold.maxLambda(M1, 'true');
fprintf('  ✓ True maximum eigenvalue: %.4f\n', lmax_true);
assert(lmax_est >= lmax_true, 'Gershgorin estimate should be an upper bound');
fprintf('  ✓ Gershgorin bound verified: %.4f >= %.4f\n', lmax_est, lmax_true);

% Test normalized Laplacian estimate
lmax_est_norm = M2.estimateLambdaMax();
assert(lmax_est_norm == 2.0, 'Normalized Laplacian max should be exactly 2.0');
fprintf('  ✓ Normalized Laplacian estimate: %.4f (theoretical bound)\n', lmax_est_norm);

%% Test 6: Static maxLambda method
fprintf('\nTest 6: Static maxLambda method...\n');
lmax_true = bct.Manifold.maxLambda(M1, 'true');

assert(~isempty(lmax_true), 'maxLambda should return a value');
assert(lmax_true > 0, 'maxLambda should be positive');
fprintf('  ✓ Maximum eigenvalue: %.4f\n', lmax_true);

% Verify it's larger than computed eigenvalues
assert(lmax_true >= max(lam), 'True max should be >= computed max');
fprintf('  ✓ True max >= computed max (%.4f >= %.4f)\n', lmax_true, max(lam));

%% Test 7: Property name compatibility
fprintf('\nTest 7: Verify new property names work correctly...\n');
assert(isequal(M1.Vertices, V), 'Vertices should match input V');
assert(isequal(M1.Faces, F), 'Faces should match input F');
fprintf('  ✓ New property names (Vertices, Faces) work correctly\n');

% Verify sparse matrices
assert(issparse(M1.Laplacian), 'Laplacian should be sparse');
assert(issparse(M1.MassMatrix), 'MassMatrix should be sparse');
assert(issparse(M1.CotangentMatrix), 'CotangentMatrix should be sparse');
fprintf('  ✓ All matrices are sparse\n');

% Verify symmetry (CotangentMatrix K should be symmetric, Laplacian L = M^(-1)K may have numerical asymmetry)
assert(norm(M1.CotangentMatrix - M1.CotangentMatrix', 'fro') < 1e-8, 'CotangentMatrix should be symmetric');
fprintf('  ✓ CotangentMatrix is symmetric\n');

% Cotangent Laplacian L = M^(-1) K is NOT necessarily symmetric
% Only the normalized version L = M^(-1/2) K M^(-1/2) is symmetric
fprintf('  ✓ Cotangent Laplacian is computed (asymmetric by design)\n');

% Verify normalized Laplacian is symmetric
assert(norm(M2.Laplacian - M2.Laplacian', 'fro') < 1e-8, 'Normalized Laplacian should be symmetric');
fprintf('  ✓ Normalized Laplacian is symmetric\n');

%% Test 8: Alternative input formats for meshFourier
fprintf('\nTest 8: meshFourier with different input formats...\n');

% Using surfaceMesh object
meshObj = surfaceMesh(V, F);
[U2, lam2] = bct.Manifold.meshFourier(meshObj, k);
assert(isequal(U, U2), 'surfaceMesh input should give same result');
fprintf('  ✓ Works with surfaceMesh object\n');

% Using V, F directly
[U3, lam3] = bct.Manifold.meshFourier(V, F, k);
assert(isequal(U, U3), 'V, F input should give same result');
fprintf('  ✓ Works with V, F matrices\n');

%% Summary
fprintf('\n═══════════════════════════════════════════════\n');
fprintf('✓ All tests passed!\n');
fprintf('═══════════════════════════════════════════════\n');
fprintf('\nNew @Manifold class features verified:\n');
fprintf('  ✓ New property names (Vertices, Faces, Laplacian, MassMatrix)\n');
fprintf('  • CotangentMatrix property\n');
fprintf('  • LaplacianType property (cotangent/cotangent-normalized)\n');
fprintf('  • Automatic matrix computation via computeLaplacian()\n');
fprintf('  • Static methods: laplacian, meshFourier, maxLambda\n');
fprintf('  • Helper methods: numVertices, numFaces, estimateLambdaMax\n');
fprintf('\n');
