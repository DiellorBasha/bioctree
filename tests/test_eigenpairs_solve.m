%% Test bct.eigenpairs.solve
%
% Verify the new eigenbasis struct API

%% Setup
% Ensure we're in the bioctree root
if ~exist('bct_start.m', 'file')
    cd('..');
end
run('bct_start.m');

% Load test mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
M = bct.Manifold(data.V, data.F);

fprintf('Test mesh: %d vertices, %d faces\n', M.numVertices(), M.numFaces());

%% Test 1: Basic eigenbasis computation
fprintf('\n=== Test 1: Basic eigenbasis ===\n');

basis = bct.eigenpairs.solve(M, 50);

% Check mandatory fields
assert(isfield(basis, 'schemaVersion'), 'Missing schemaVersion');
assert(isfield(basis, 'meshId'), 'Missing meshId');
assert(isfield(basis, 'method'), 'Missing method');
assert(isfield(basis, 'operator'), 'Missing operator');
assert(isfield(basis, 'values'), 'Missing values');
assert(isfield(basis, 'vectors'), 'Missing vectors');
assert(isfield(basis, 'provenance'), 'Missing provenance');
assert(isfield(basis, 'checks'), 'Missing checks');

fprintf('✓ All mandatory fields present\n');

% Check dimensions
% Note: bct.Eigenpairs may auto-remove DC if it's near-zero
assert(length(basis.values) >= 49 && length(basis.values) <= 50, ...
    'Wrong number of eigenvalues');
assert(size(basis.vectors, 2) >= 49 && size(basis.vectors, 2) <= 50, ...
    'Wrong number of eigenvectors');
fprintf('✓ Dimensions correct: k=%d (requested 50)\n', basis.k);

% Check schema
fprintf('Schema version: %s\n', basis.schemaVersion);
fprintf('Method: %s\n', basis.method);
fprintf('Operator: %s\n', basis.operator);
fprintf('Mass type: %s\n', basis.massType);
fprintf('Normalization: %s\n', basis.normalization);
fprintf('Ordering: %s\n', basis.ordering);

%% Test 2: Quality checks
fprintf('\n=== Test 2: Quality checks ===\n');

fprintf('Orthonormality error: %.2e\n', basis.checks.orthonormError);
fprintf('Residual norm: %.2e\n', basis.checks.residualNorm);
fprintf('Eigenvalue range: [%.6f, %.6f]\n', ...
    basis.checks.eigenvalueRange(1), basis.checks.eigenvalueRange(2));
fprintf('Quality passed: %d\n', basis.checks.passed);

assert(basis.checks.passed, 'Quality checks failed');
fprintf('✓ Quality checks passed\n');

%% Test 3: Provenance metadata
fprintf('\n=== Test 3: Provenance ===\n');

fprintf('Timestamp: %s\n', basis.provenance.timestamp);
fprintf('Compute time: %.3f seconds\n', basis.provenance.computeTime);
fprintf('MATLAB version: %s\n', basis.provenance.matlabVersion);
fprintf('Solver method: %s\n', basis.provenance.solverMethod);
fprintf('Mesh dimensions: N=%d, F=%d, E=%d\n', ...
    basis.provenance.dimensions.numVertices, ...
    basis.provenance.dimensions.numFaces, ...
    basis.provenance.dimensions.numEdges);

%% Test 4: RemoveDC option
fprintf('\n=== Test 4: RemoveDC option ===\n');

basisDC = bct.eigenpairs.solve(M, 50, RemoveDC=true);

% DC is already removed by bct.Eigenpairs, so this mainly tests the flag
assert(basisDC.removeDC == true, 'RemoveDC flag not set');
fprintf('✓ DC removal: k=%d modes, first eigenvalue = %.6f (should be >0)\n', ...
    basisDC.k, basisDC.values(1));

%% Test 5: Different mass types
fprintf('\n=== Test 5: Mass type options ===\n');

basisVoronoi = bct.eigenpairs.solve(M, 20, MassType="voronoi");
basisBarycentric = bct.eigenpairs.solve(M, 20, MassType="barycentric");

fprintf('Voronoi mass: first eigenvalue = %.6f\n', basisVoronoi.values(1));
fprintf('Barycentric mass: first eigenvalue = %.6f\n', basisBarycentric.values(1));
fprintf('✓ Different mass types work\n');

%% Test 6: Optional matrices
fprintf('\n=== Test 6: Optional matrices ===\n');

basisFull = bct.eigenpairs.solve(M, 20, ReturnMass=true, ReturnStiffness=true);

assert(isfield(basisFull, 'mass'), 'Mass matrix not returned');
assert(isfield(basisFull, 'stiffness'), 'Stiffness matrix not returned');
assert(issparse(basisFull.mass), 'Mass should be sparse');
assert(issparse(basisFull.stiffness), 'Stiffness should be sparse');

fprintf('✓ Optional matrices included\n');
fprintf('  Mass: %d×%d sparse (%.2f%% nnz)\n', ...
    size(basisFull.mass, 1), size(basisFull.mass, 2), ...
    100*nnz(basisFull.mass)/numel(basisFull.mass));
fprintf('  Stiffness: %d×%d sparse (%.2f%% nnz)\n', ...
    size(basisFull.stiffness, 1), size(basisFull.stiffness, 2), ...
    100*nnz(basisFull.stiffness)/numel(basisFull.stiffness));

%% Test 7: Compare with bct.FEM.eigenpairs
fprintf('\n=== Test 7: Consistency with bct.FEM ===\n');

fem = bct.FEM(M);
E = fem.eigenpairs(30);

basisNew = bct.eigenpairs.solve(M, 30);

% Compare eigenvalues
maxDiff = max(abs(E.Values - basisNew.values));
fprintf('Max eigenvalue difference: %.2e\n', maxDiff);
assert(maxDiff < 1e-10, 'Eigenvalues do not match');

fprintf('✓ Results consistent with bct.FEM.eigenpairs\n');

%% Summary
fprintf('\n=== Test Summary ===\n');
fprintf('All tests passed!\n');
fprintf('bct.eigenpairs.solve returns structured eigenbasis with:\n');
fprintf('  ✓ Complete schema (version %s)\n', basis.schemaVersion);
fprintf('  ✓ Provenance metadata\n');
fprintf('  ✓ Quality checks\n');
fprintf('  ✓ Multiple mass type options\n');
fprintf('  ✓ DC removal option\n');
fprintf('  ✓ Optional matrix returns\n');
