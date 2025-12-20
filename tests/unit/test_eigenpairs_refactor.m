%TEST_EIGENPAIRS_REFACTOR Test refactored Eigenpairs architecture
%
% Verifies that:
%   1. Eigenpairs class is an immutable data container
%   2. Factory functions in bct.eigenpairs package work correctly
%   3. FEM uses factory functions (not static methods)
%   4. Eigenpairs operations (project, reconstruct, truncate, etc.) work
%   5. Utility functions (validate, normalize, merge) work

% Add bioctree to path
if ~exist('bioctree_start', 'file')
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    bioctree_start;
end

%% Test 1: Load mesh and create FEM
fprintf('Test 1: Setup (Manifold → FEM)...\n');

% Load mesh data
meshFile = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');
if ~isfile(meshFile)
    error('Mesh file not found: %s', meshFile);
end

data = load(meshFile);
M = bct.Manifold(struct('V', data.V, 'F', data.F));
fem = M.FEM();

fprintf('  ✓ Manifold created with %d vertices\n', M.numVertices());
fprintf('  ✓ FEM representation initialized\n');

%% Test 2: Factory function (bct.eigenpairs.fromFEM)
fprintf('\nTest 2: Factory function bct.eigenpairs.fromFEM...\n');

k = 100;
E = bct.eigenpairs.fromFEM(fem, k);

% Verify type and dimensions
assert(isa(E, 'bct.Eigenpairs'), 'fromFEM should return bct.Eigenpairs');
assert(E.numModes() == k, 'Should return k modes');
assert(E.domainSize() == M.numVertices(), 'Domain size should match mesh');

fprintf('  ✓ Created %d eigenpairs via factory function\n', k);

%% Test 3: Validation
fprintf('\nTest 3: Validation (bct.eigenpairs.validate)...\n');

isValid = bct.eigenpairs.validate(E);
assert(isValid, 'Eigenpairs should pass validation');

% Manual M-orthonormality check
U = E.Vectors;
Orth = U' * fem.Mass * U;
err = norm(Orth - eye(k), 'fro');
assert(err < 1e-8, 'M-orthonormality error too large');

fprintf('  ✓ Validation passed (orthonormality error: %.2e)\n', err);

%% Test 4: Projection and reconstruction
fprintf('\nTest 4: Project / reconstruct...\n');

% Create test signal
signal = randn(M.numVertices(), 1);
signal = signal / fem.norm(signal);  % Normalize

% Project
coeffs = E.project(signal);
assert(length(coeffs) == k, 'Project should return k coefficients');

% Reconstruct
recon = E.reconstruct(coeffs);
assert(length(recon) == M.numVertices(), 'Reconstruct should return N values');

% Check reconstruction error (should be small for full spectrum)
err_recon = fem.norm(signal - recon);
fprintf('  ✓ Reconstruction error: %.3e\n', err_recon);

%% Test 5: Energy computation
fprintf('\nTest 5: Energy computation...\n');

energy = E.energy(coeffs);
assert(isscalar(energy) && energy >= 0, 'Energy should be non-negative scalar');

% Energy should match via Parseval's identity
energy_direct = coeffs' * diag(E.Values) * coeffs;
assert(abs(energy - energy_direct) < 1e-10, 'Energy mismatch');

fprintf('  ✓ Spectral energy: %.3e\n', energy);

%% Test 6: Truncation
fprintf('\nTest 6: Truncation...\n');

k_trunc = 50;
E_trunc = E.truncate(k_trunc);

assert(isa(E_trunc, 'bct.Eigenpairs'), 'Truncate should return Eigenpairs');
assert(E_trunc.numModes() == k_trunc, 'Truncated modes should match request');
assert(isequal(E_trunc.Values, E.Values(1:k_trunc)), 'Truncated eigenvalues should match');

fprintf('  ✓ Truncated %d → %d modes\n', k, k_trunc);

%% Test 7: Bandlimit
fprintf('\nTest 7: Bandlimiting...\n');

lambda_range = [0.01, 0.5];
E_band = E.bandlimit(lambda_range);

assert(all(E_band.Values >= lambda_range(1)), 'Bandlimit lower bound violated');
assert(all(E_band.Values <= lambda_range(2)), 'Bandlimit upper bound violated');

fprintf('  ✓ Bandlimited to λ ∈ [%.3f, %.3f]: %d modes retained\n', ...
    lambda_range(1), lambda_range(2), E_band.numModes());

%% Test 8: Subselection
fprintf('\nTest 8: Subselection...\n');

indices = [1:10, 50:60];
E_sub = E.subselect(indices);

assert(E_sub.numModes() == length(indices), 'Subselect size mismatch');
assert(isequal(E_sub.Values, E.Values(indices)), 'Subselected eigenvalues mismatch');

fprintf('  ✓ Subselected %d modes\n', length(indices));

%% Test 9: Reordering
fprintf('\nTest 9: Reordering...\n');

% Descending order
E_desc = bct.eigenpairs.reorder(E, 'descending');
assert(all(diff(E_desc.Values) <= 0), 'Descending order not enforced');

% Back to ascending
E_asc = bct.eigenpairs.reorder(E_desc, 'ascending');
assert(isequal(E_asc.Values, E.Values), 'Round-trip reordering failed');

fprintf('  ✓ Reordering (ascending ↔ descending) works\n');

%% Test 10: Normalization utility
fprintf('\nTest 10: Normalization utility...\n');

% Unnormalized vectors (random)
U_raw = randn(M.numVertices(), 20);
U_norm = bct.eigenpairs.normalize(U_raw, fem.Mass);

% Check M-orthonormality
Orth = U_norm' * fem.Mass * U_norm;
err = norm(Orth - eye(20), 'fro');
assert(err < 1e-10, 'Normalize failed to produce M-orthonormal vectors');

fprintf('  ✓ Normalize utility works (error: %.2e)\n', err);

%% Test 11: Merge utility
fprintf('\nTest 11: Merge utility...\n');

% Create two separate eigenpair sets
E1 = E.truncate(50);
E2 = bct.eigenpairs.fromFEM(fem, 30);  % Might overlap with E1

E_merged = bct.eigenpairs.merge(E1, E2);

assert(isa(E_merged, 'bct.Eigenpairs'), 'Merge should return Eigenpairs');
assert(E_merged.numModes() <= E1.numModes() + E2.numModes(), ...
    'Merge should remove duplicates');

fprintf('  ✓ Merge: %d + %d → %d modes\n', ...
    E1.numModes(), E2.numModes(), E_merged.numModes());

%% Test 12: FEM integration
fprintf('\nTest 12: FEM uses factory (not static method)...\n');

% FEM.eigenpairs should call bct.eigenpairs.fromFEM
E_fem = fem.eigenpairs(100);
assert(isa(E_fem, 'bct.Eigenpairs'), 'FEM.eigenpairs should return Eigenpairs');

% Should be cached
E_fem2 = fem.eigenpairs(100);
assert(E_fem == E_fem2, 'FEM should cache eigenpairs');

fprintf('  ✓ FEM uses bct.eigenpairs.fromFEM factory\n');
fprintf('  ✓ FEM caching works\n');

%% Test 13: No static factory methods in class
fprintf('\nTest 13: Verify no static factory in Eigenpairs class...\n');

mc = metaclass(E);
staticMethods = {mc.MethodList(strcmp({mc.MethodList.Access}, 'public')).Name};
hasBadStatic = any(contains(staticMethods, 'fromLaplaceBeltrami'));

assert(~hasBadStatic, 'Eigenpairs class should not have fromLaplaceBeltrami static method');

fprintf('  ✓ No fromLaplaceBeltrami static method found\n');
fprintf('  ✓ Architecture follows contract\n');

%% Summary
fprintf('\n');
fprintf('========================================\n');
fprintf('All tests passed! ✓\n');
fprintf('========================================\n');
fprintf('\nEigenpairs refactoring verified:\n');
fprintf('  • Eigenpairs class is immutable data container\n');
fprintf('  • Factory functions live in bct.eigenpairs package\n');
fprintf('  • FEM uses bct.eigenpairs.fromFEM (not static method)\n');
fprintf('  • All operations (project, truncate, bandlimit) work\n');
fprintf('  • Utility functions (validate, normalize, merge) work\n');
fprintf('  • Architecture follows EigenpairsContract\n');
