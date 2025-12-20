%% Test FEM Class
% Unit tests for FEM class implementation

fprintf('Testing FEM class...\n\n');

%% Setup: Create simple test mesh (icosphere)
fprintf('Setup: Creating test mesh... ');
[V, F] = icosphere(2);  % Simple sphere mesh
M = bct.Manifold(struct('V', V, 'F', F));
fprintf('✓ (%d vertices, %d faces)\n', size(V,1), size(F,1));

%% Test 1: Construction
fprintf('Test 1: FEM construction... ');
try
    fem = bct.FEM(M);
    assert(isa(fem, 'bct.FEM'), 'Not a FEM object');
    assert(isequal(fem.Manifold, M), 'Manifold not stored');
    assert(issparse(fem.MassMatrix), 'Mass matrix not sparse');
    assert(issparse(fem.StiffnessMatrix), 'Stiffness matrix not sparse');
    assert(fem.MassType == "voronoi", 'Default mass type wrong');
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 2: Mass type options
fprintf('Test 2: Mass type options... ');
try
    fem_bary = bct.FEM(M, 'MassType', 'barycentric');
    fem_full = bct.FEM(M, 'MassType', 'full');
    assert(fem_bary.MassType == "barycentric", 'Barycentric type not set');
    assert(fem_full.MassType == "full", 'Full type not set');
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 3: Eigenpairs computation
fprintf('Test 3: Eigenpairs computation... ');
try
    k = 20;
    E = fem.eigenpairs(k);
    
    assert(isa(E, 'bct.Eigenpairs'), 'Not Eigenpairs object');
    assert(length(E.Values) == k, 'Wrong number of eigenvalues');
    assert(size(E.Vectors, 2) == k, 'Wrong number of eigenvectors');
    
    % Verify M-orthonormality
    I = E.Vectors' * E.MassMatrix * E.Vectors;
    err = norm(I - eye(k), 'fro');
    assert(err < 1e-6, 'Not M-orthonormal');
    
    % Verify eigenvalue equation: K*u = λ*M*u
    for i = 1:3  % Check first 3
        lhs = fem.StiffnessMatrix * E.Vectors(:,i);
        rhs = E.Values(i) * fem.MassMatrix * E.Vectors(:,i);
        err_eig = norm(lhs - rhs) / norm(rhs);
        assert(err_eig < 1e-6, 'Eigenvalue equation not satisfied');
    end
    
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 4: Caching
fprintf('Test 4: Eigenpair caching... ');
try
    tic;
    E1 = fem.eigenpairs(20);
    t1 = toc;
    
    tic;
    E2 = fem.eigenpairs(20);
    t2 = toc;
    
    assert(isequal(E1.Values, E2.Values), 'Cached values differ');
    assert(t2 < t1/10, 'Cache not faster');
    fprintf('✓ PASS (%.1fx speedup)\n', t1/t2);
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 5: Projection and Reconstruction
fprintf('Test 5: Project/reconstruct... ');
try
    N = size(V, 1);
    signal = randn(N, 1);
    k = 30;
    
    coeffs = fem.project(signal, k);
    signal_recon = fem.reconstruct(coeffs, k);
    
    assert(length(coeffs) == k, 'Wrong coefficient size');
    assert(length(signal_recon) == N, 'Wrong signal size');
    
    % Reconstruction should be in span of first k modes
    E = fem.eigenpairs(k);
    signal_proj = E.Vectors * (E.Vectors' * E.MassMatrix * signal);
    err = norm(signal_recon - signal_proj);
    assert(err < 1e-10, 'Reconstruction incorrect');
    
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 6: Heat evolution
fprintf('Test 6: Heat evolution... ');
try
    N = size(V, 1);
    signal = randn(N, 1);
    signal = signal / fem.norm(signal);
    
    t = 0.1;
    k = 50;
    signal_heat = fem.heat(signal, t, k);
    
    % Heat should preserve positivity approximately
    % Heat should reduce energy
    energy_before = fem.energy(signal);
    energy_after = fem.energy(signal_heat);
    assert(energy_after <= energy_before, 'Heat increased energy');
    
    fprintf('✓ PASS (energy: %.4f → %.4f)\n', energy_before, energy_after);
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 7: Wave evolution
fprintf('Test 7: Wave evolution... ');
try
    N = size(V, 1);
    signal = randn(N, 1);
    signal = signal / fem.norm(signal);
    
    t = 0.1;
    k = 50;
    signal_wave = fem.wave(signal, t, k);
    
    % Wave should approximately preserve norm (in span of k modes)
    norm_before = fem.norm(signal);
    norm_after = fem.norm(signal_wave);
    rel_err = abs(norm_after - norm_before) / norm_before;
    assert(rel_err < 0.2, 'Wave norm not preserved');
    
    fprintf('✓ PASS (norm preserved within %.1f%%)\n', rel_err*100);
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 8: Schrödinger evolution
fprintf('Test 8: Schrödinger evolution... ');
try
    N = size(V, 1);
    signal = randn(N, 1);
    signal = signal / fem.norm(signal);
    
    t = 0.1;
    k = 50;
    signal_schrod = fem.schrodinger(signal, t, k);
    
    % Output should be complex
    assert(~isreal(signal_schrod), 'Schrödinger output not complex');
    
    % Should preserve norm
    norm_before = fem.norm(signal);
    norm_after = fem.norm(signal_schrod);
    rel_err = abs(norm_after - norm_before) / norm_before;
    assert(rel_err < 0.2, 'Schrödinger norm not preserved');
    
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 9: Spectral filtering
fprintf('Test 9: Spectral filtering... ');
try
    N = size(V, 1);
    signal = randn(N, 1);
    k = 50;
    
    % Low-pass filter
    kernel = @(lam) exp(-0.1 * lam);
    signal_filtered = fem.filter(signal, kernel, k);
    
    assert(length(signal_filtered) == N, 'Wrong output size');
    
    % Low-pass should reduce energy
    energy_before = fem.energy(signal);
    energy_after = fem.energy(signal_filtered);
    assert(energy_after <= energy_before, 'Low-pass increased energy');
    
    % Test with vector kernel
    E = fem.eigenpairs(k);
    kernel_vec = exp(-0.1 * E.Values);
    signal_filtered2 = fem.filter(signal, kernel_vec, k);
    err = norm(signal_filtered - signal_filtered2);
    assert(err < 1e-10, 'Vector kernel gives different result');
    
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 10: Norm and energy
fprintf('Test 10: Norm and energy... ');
try
    N = size(V, 1);
    signal = randn(N, 1);
    
    n = fem.norm(signal);
    e = fem.energy(signal);
    
    assert(n > 0, 'Norm not positive');
    assert(e >= 0, 'Energy negative');
    assert(isfinite(n), 'Norm not finite');
    assert(isfinite(e), 'Energy not finite');
    
    % Zero signal
    n_zero = fem.norm(zeros(N,1));
    e_zero = fem.energy(zeros(N,1));
    assert(n_zero == 0, 'Zero norm not zero');
    assert(abs(e_zero) < 1e-10, 'Zero energy not zero');
    
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 11: Geometric operations
fprintf('Test 11: Geometric operations... ');
try
    % Gradient
    G = fem.gradient();
    assert(issparse(G), 'Gradient not sparse');
    assert(size(G, 2) == size(V, 1), 'Gradient size wrong');
    
    % Areas
    A = fem.areas();
    assert(length(A) == size(V, 1), 'Areas size wrong');
    assert(all(A > 0), 'Areas not positive');
    
    % Edge lengths
    L = fem.edgeLengths();
    assert(all(L > 0), 'Edge lengths not positive');
    
    % Normals
    N = fem.vertexNormals();
    assert(size(N, 1) == size(V, 1), 'Normals size wrong');
    assert(size(N, 2) == 3, 'Normals not 3D');
    
    % Curvature
    [H, K] = fem.curvature();
    assert(length(H) == size(V, 1), 'Mean curvature size wrong');
    assert(length(K) == size(V, 1), 'Gaussian curvature size wrong');
    
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 12: Utility methods
fprintf('Test 12: Utility methods... ');
try
    % Get info
    info = fem.getInfo();
    assert(info.NumVertices == size(V, 1), 'Info vertices wrong');
    assert(info.NumFaces == size(F, 1), 'Info faces wrong');
    assert(info.MassType == "voronoi", 'Info mass type wrong');
    
    % Clear cache
    fem.clearCache();
    info_after = fem.getInfo();
    assert(isempty(info_after.CachedEigenvalues), 'Cache not cleared');
    
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 13: Contract invariants
fprintf('Test 13: FEM contract invariants... ');
try
    N = size(V, 1);
    
    % Self-adjointness with respect to M
    v1 = randn(N, 1);
    v2 = randn(N, 1);
    lhs = v1' * fem.MassMatrix * (fem.StiffnessMatrix * v2);
    rhs = (fem.StiffnessMatrix * v1)' * fem.MassMatrix * v2;
    err = abs(lhs - rhs);
    assert(err < 1e-10, 'Not self-adjoint');
    
    % Positive semi-definiteness
    v = randn(N, 1);
    quad = v' * fem.StiffnessMatrix * v;
    assert(quad >= -1e-10, 'Not positive semi-definite');
    
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

fprintf('\n=== All FEM tests completed ===\n');
