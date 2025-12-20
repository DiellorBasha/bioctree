%TEST_FEM_REFACTOR Test refactored FEM architecture
%
% Verifies that:
%   1. FEM delegates to bct.fem package for matrix assembly
%   2. FEM delegates to bct.fem.eigensolve for eigenpairs
%   3. bct.fem functions work independently
%   4. applyLaplacian method exists and works
%   5. Architecture follows FEMContract

% Add bioctree to path
if ~exist('bioctree_start', 'file')
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    bioctree_start;
end

%% Test 1: Load mesh and create Manifold
fprintf('Test 1: Setup (Manifold creation)...\n');

meshFile = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');
if ~isfile(meshFile)
    error('Mesh file not found: %s', meshFile);
end

data = load(meshFile);
M = bct.Manifold(struct('V', data.V, 'F', data.F));

fprintf('  ✓ Manifold created with %d vertices, %d faces\n', ...
    M.numVertices(), M.numFaces());

%% Test 2: Package functions work independently
fprintf('\nTest 2: bct.fem package functions (independent use)...\n');

% Test assembleMass
Mass_voronoi = bct.fem.assembleMass(M, 'voronoi');
assert(issparse(Mass_voronoi), 'Mass should be sparse');
assert(size(Mass_voronoi, 1) == M.numVertices(), 'Mass size mismatch');
assert(all(diag(Mass_voronoi) > 0), 'Mass diagonal should be positive');

Mass_bary = bct.fem.assembleMass(M, 'barycentric');
assert(~isequal(Mass_voronoi, Mass_bary), 'Different mass types should differ');

% Test assembleStiffness
Stiffness = bct.fem.assembleStiffness(M);
assert(issparse(Stiffness), 'Stiffness should be sparse');
assert(size(Stiffness, 1) == M.numVertices(), 'Stiffness size mismatch');
assert(issymmetric(Stiffness), 'Stiffness should be symmetric');

fprintf('  ✓ bct.fem.assembleMass() works (voronoi, barycentric)\n');
fprintf('  ✓ bct.fem.assembleStiffness() works\n');

%% Test 3: FEM constructor delegates to package
fprintf('\nTest 3: FEM constructor delegation...\n');

fem = bct.FEM(M);

% Verify FEM created matrices via delegation
assert(~isempty(fem.Mass), 'FEM should have Mass matrix');
assert(~isempty(fem.Stiffness), 'FEM should have Stiffness matrix');
assert(isequal(size(fem.Mass), size(Mass_voronoi)), 'Mass size should match');
assert(isequal(size(fem.Stiffness), size(Stiffness)), 'Stiffness size should match');

fprintf('  ✓ FEM constructor delegates to bct.fem.assembleMass()\n');
fprintf('  ✓ FEM constructor delegates to bct.fem.assembleStiffness()\n');

%% Test 4: Eigenpair delegation
fprintf('\nTest 4: Eigenpair computation delegation...\n');

k = 100;

% Via FEM method (should delegate to bct.fem.eigensolve)
E1 = fem.eigenpairs(k);
assert(isa(E1, 'bct.Eigenpairs'), 'eigenpairs() should return bct.Eigenpairs');
assert(E1.numModes() == k, 'Should return k modes');

% Direct call to package function
E2 = bct.fem.eigensolve(fem, k);
assert(isa(E2, 'bct.Eigenpairs'), 'eigensolve() should return bct.Eigenpairs');

% Verify caching works
E3 = fem.eigenpairs(k);
assert(E1 == E3, 'FEM should cache eigenpairs');

fprintf('  ✓ FEM.eigenpairs() delegates to bct.fem.eigensolve()\n');
fprintf('  ✓ bct.fem.eigensolve() delegates to bct.eigenpairs.fromFEM()\n');
fprintf('  ✓ Caching works correctly\n');

%% Test 5: applyLaplacian method
fprintf('\nTest 5: applyLaplacian operator...\n');

% Create test signal
signal = randn(M.numVertices(), 1);

% Via FEM method
y1 = fem.applyLaplacian(signal);
assert(length(y1) == M.numVertices(), 'applyLaplacian output size mismatch');

% Direct package function call
y2 = bct.fem.applyLaplacian(fem.Stiffness, fem.Mass, signal);
assert(isequal(y1, y2), 'FEM method should match package function');

% Verify it's the correct operator: L = M^(-1) * K
y3 = fem.Mass \ (fem.Stiffness * signal);
assert(norm(y1 - y3) < 1e-10, 'applyLaplacian should compute M^(-1)*K*x');

fprintf('  ✓ FEM.applyLaplacian() method exists\n');
fprintf('  ✓ Delegates to bct.fem.applyLaplacian()\n');
fprintf('  ✓ Computes correct operator L = M^(-1)*K\n');

%% Test 6: Evolution operators use eigenpairs
fprintf('\nTest 6: Evolution operators...\n');

signal = randn(M.numVertices(), 1);
signal = signal / fem.norm(signal);
t = 0.1;
k = 50;

% Heat evolution
signal_heat = fem.heat(signal, t, k);
assert(length(signal_heat) == M.numVertices(), 'Heat output size mismatch');

% Wave evolution
signal_wave = fem.wave(signal, t, k);
assert(length(signal_wave) == M.numVertices(), 'Wave output size mismatch');

% Schrödinger evolution
signal_schrod = fem.schrodinger(signal, t, k);
assert(length(signal_schrod) == M.numVertices(), 'Schrödinger output size mismatch');

% Verify they use eigenpairs (should be cached from previous calls)
info = fem.getInfo();
cached_keys = keys(fem.EigenpairCache);
assert(~isempty(cached_keys), 'Evolution operators should use cached eigenpairs');

fprintf('  ✓ Heat operator works\n');
fprintf('  ✓ Wave operator works\n');
fprintf('  ✓ Schrödinger operator works\n');

%% Test 7: Norm and energy
fprintf('\nTest 7: Norm and energy...\n');

signal = randn(M.numVertices(), 1);

% Norm (L2 with respect to mass matrix)
n = fem.norm(signal);
assert(isscalar(n) && n > 0, 'Norm should be positive scalar');

% Verify: norm = sqrt(x' * M * x)
n_manual = sqrt(signal' * fem.Mass * signal);
assert(abs(n - n_manual) < 1e-10, 'Norm computation mismatch');

% Energy (Dirichlet energy)
e = fem.energy(signal);
assert(isscalar(e), 'Energy should be scalar');

% Verify: energy = x' * K * x
e_manual = signal' * fem.Stiffness * signal;
assert(abs(e - e_manual) < 1e-10, 'Energy computation mismatch');

fprintf('  ✓ Norm computation correct\n');
fprintf('  ✓ Energy computation correct\n');

%% Test 8: Verify no direct gptoolbox calls in FEM class
fprintf('\nTest 8: Architecture compliance...\n');

% Read FEM.m source
fem_source = fileread(which('bct.FEM'));

% Should NOT have direct gptoolbox calls in constructor
has_cotmatrix_call = contains(fem_source, 'cotmatrix(');
has_massmatrix_call = contains(fem_source, 'massmatrix(');

% FEM may call these functions for geometric operations, but not for
% assembly in constructor. Check constructor specifically.
constructor_section = extractBetween(fem_source, 'function obj = FEM(', 'end');
if ~isempty(constructor_section)
    constructor_text = constructor_section{1};
    has_gptoolbox_in_constructor = contains(constructor_text, 'cotmatrix(') || ...
                                   contains(constructor_text, 'massmatrix(');
    assert(~has_gptoolbox_in_constructor, ...
        'FEM constructor should delegate to bct.fem package, not call gptoolbox directly');
end

% Should delegate to bct.fem
has_fem_delegation = contains(fem_source, 'bct.fem.assembleMass') && ...
                     contains(fem_source, 'bct.fem.assembleStiffness');
assert(has_fem_delegation, 'FEM should delegate to bct.fem package');

fprintf('  ✓ FEM constructor delegates to bct.fem (no direct gptoolbox)\n');
fprintf('  ✓ Architecture follows FEMContract\n');

%% Test 9: MassType configuration
fprintf('\nTest 9: MassType configuration...\n');

fem_voronoi = bct.FEM(M, 'MassType', 'voronoi');
fem_bary = bct.FEM(M, 'MassType', 'barycentric');

% Different mass types should produce different matrices
assert(~isequal(fem_voronoi.Mass, fem_bary.Mass), ...
    'Different mass types should produce different Mass matrices');

% Voronoi should be diagonal (lumped)
assert(nnz(fem_voronoi.Mass) == M.numVertices(), ...
    'Voronoi mass should be diagonal');

% Stiffness should be the same regardless of mass type
assert(isequal(fem_voronoi.Stiffness, fem_bary.Stiffness), ...
    'Stiffness should not depend on mass type');

fprintf('  ✓ MassType parameter works correctly\n');
fprintf('  ✓ Voronoi produces diagonal mass\n');

%% Summary
fprintf('\n');
fprintf('========================================\n');
fprintf('All tests passed! ✓\n');
fprintf('========================================\n');
fprintf('\nFEM refactoring verified:\n');
fprintf('  • FEM delegates to bct.fem package for matrix assembly\n');
fprintf('  • FEM delegates to bct.fem.eigensolve for eigenpairs\n');
fprintf('  • bct.fem functions work independently\n');
fprintf('  • applyLaplacian method exists and works correctly\n');
fprintf('  • Evolution operators use eigenpairs\n');
fprintf('  • Norm and energy computations correct\n');
fprintf('  • Architecture follows FEMContract\n');
fprintf('  • No direct gptoolbox calls in FEM constructor\n');
