% Test script for Lambda.eigenbasis and bct.computeEigenbasis
% Tests the new eigendecomposition orchestration

% Initialize BCT environment
bioctree_start;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' Testing Lambda.eigenbasis and bct.computeEigenbasis\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

%% Test 1: Direct Lambda.eigenbasis call
fprintf('Test 1: Direct Lambda.eigenbasis call...\n');

try
    % Create mesh
    [V, F] = icosphere(2);  % 162 vertices
    N = size(V, 1);
    
    % Create bct object
    B = bct.bct.fromMesh(V, F);
    
    % Verify initial state
    assert(isempty(B.Lambda.U), 'Lambda.U should be empty initially');
    assert(isempty(B.Lambda.transform), 'Lambda.transform should be empty initially');
    assert(isempty(B.Manifold.transform), 'Manifold.transform should be empty initially');
    fprintf('  ✓ Initial state verified (empty eigenvectors and transforms)\n');
    
    % Get matrices from Manifold
    M = B.Manifold.MassMatrix;
    K = B.Manifold.CotangentMatrix;
    
    % Compute eigenbasis directly
    numModes = 50;
    B.Lambda = B.Lambda.eigenbasis(M, K, numModes);
    
    % Verify eigenvectors computed
    assert(~isempty(B.Lambda.U), 'Lambda.U should be populated');
    assert(~isempty(B.Lambda.lambda), 'Lambda.lambda should be populated');
    assert(B.Lambda.K > 0, 'Lambda.K should be positive');
    fprintf('  ✓ Eigenbasis computed: %d modes\n', B.Lambda.K);
    
    % Verify eigenvalues are positive and sorted
    assert(all(B.Lambda.lambda > 0), 'All eigenvalues should be positive');
    assert(issorted(B.Lambda.lambda), 'Eigenvalues should be sorted ascending');
    fprintf('  ✓ Eigenvalues positive and sorted: [%.6f, %.6f]\n', ...
            min(B.Lambda.lambda), max(B.Lambda.lambda));
    
    % Re-initialize transforms
    B.Manifold.initializeTransform();
    B.Lambda.initializeTransform();
    
    % Verify transforms created
    assert(~isempty(B.Manifold.transform), 'Manifold.transform should be set');
    assert(~isempty(B.Lambda.transform), 'Lambda.transform should be set');
    assert(isa(B.Manifold.transform, 'bct.factory.transforms.MFT'), 'Should be MFT');
    assert(isa(B.Lambda.transform, 'bct.factory.transforms.IMFT'), 'Should be IMFT');
    fprintf('  ✓ Transforms initialized after eigenbasis computation\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 2: bct.computeEigenbasis orchestration
fprintf('Test 2: bct.computeEigenbasis orchestration...\n');

try
    % Create fresh mesh
    [V, F] = icosphere(3);  % 642 vertices
    N = size(V, 1);
    
    % Create bct object
    B = bct.bct.fromMesh(V, F);
    
    % Verify initial state
    assert(isempty(B.Lambda.U), 'Lambda.U should be empty initially');
    fprintf('  ✓ Initial state: eigenvectors empty\n');
    
    % Use orchestrated method
    numModes = 100;
    B = B.computeEigenbasis(numModes);
    
    % Verify eigenbasis computed
    assert(~isempty(B.Lambda.U), 'Lambda.U should be populated');
    assert(~isempty(B.Lambda.lambda), 'Lambda.lambda should be populated');
    fprintf('  ✓ Eigenbasis computed via orchestration: %d modes\n', B.Lambda.K);
    
    % Verify transforms automatically initialized
    assert(~isempty(B.Manifold.transform), 'Manifold.transform should be set');
    assert(~isempty(B.Lambda.transform), 'Lambda.transform should be set');
    fprintf('  ✓ Transforms automatically initialized\n');
    
    % Test MFT/IMFT round-trip
    signal = randn(N, 1);
    coeffs = B.Manifold.transform.forward(signal);  % Space → Lambda (MFT)
    reconstructed = B.Lambda.transform.forward(coeffs);  % Lambda → Space (IMFT)
    
    % Verify dimensions
    assert(length(coeffs) == B.Lambda.K, 'Spectral coeffs should have K modes');
    assert(length(reconstructed) == N, 'Reconstructed should have N vertices');
    fprintf('  ✓ MFT/IMFT round-trip: %d → %d → %d\n', N, B.Lambda.K, N);
    
    % Note: Perfect reconstruction requires full basis (K = N-1)
    % With partial basis (K < N), we lose high-frequency components
    fprintf('  → Reconstruction uses %d/%d modes (%.1f%% of full basis)\n', ...
            B.Lambda.K, N-1, 100*B.Lambda.K/(N-1));
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 3: Eigenbasis with custom parameters
fprintf('Test 3: Eigenbasis with custom parameters...\n');

try
    % Create mesh
    [V, F] = icosphere(2);  % 162 vertices
    B = bct.bct.fromMesh(V, F);
    
    % Compute with custom parameters
    B = B.computeEigenbasis(30, 'tol', 1e-12, 'maxit', 10000);
    
    % Verify computation successful
    assert(B.Lambda.K > 0, 'Should compute modes with custom parameters');
    fprintf('  ✓ Custom parameters accepted: K=%d modes\n', B.Lambda.K);
    
    % Verify transforms work
    signal = randn(size(V,1), 1);
    coeffs = B.Manifold.transform.forward(signal);
    assert(length(coeffs) == B.Lambda.K, 'Transform should work with custom params');
    fprintf('  ✓ Transforms functional with custom parameters\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 4: Eigenvalue properties (generalized eigenproblem)
fprintf('Test 4: Generalized eigenproblem K*U = M*U*D...\n');

try
    % Create mesh
    [V, F] = icosphere(2);
    B = bct.bct.fromMesh(V, F);
    
    % Compute eigenbasis
    B = B.computeEigenbasis(50);
    
    % Get matrices
    K = B.Manifold.CotangentMatrix;
    M = B.Manifold.MassMatrix;
    U = B.Lambda.U;
    lam = B.Lambda.lambda;
    
    % Verify generalized eigenproblem: K*U = M*U*D
    % For each eigenvector u_i with eigenvalue λ_i:
    %   K * u_i = λ_i * M * u_i
    
    % Check for a few eigenvectors
    numCheck = min(5, B.Lambda.K);
    maxError = 0;
    
    for i = 1:numCheck
        u_i = U(:, i);
        lambda_i = lam(i);
        
        % Left side: K * u_i
        Ku = K * u_i;
        
        % Right side: λ_i * M * u_i
        lMu = lambda_i * (M * u_i);
        
        % Relative error
        error_i = norm(Ku - lMu) / norm(Ku);
        maxError = max(maxError, error_i);
    end
    
    fprintf('  ✓ Generalized eigenproblem verified for %d modes\n', numCheck);
    fprintf('    Max relative error: %.2e\n', maxError);
    assert(maxError < 1e-6, 'Eigenproblem error should be small');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('═══════════════════════════════════════════════════════════\n');
fprintf(' ✓ All tests passed!\n');
fprintf('═══════════════════════════════════════════════════════════\n\n');

fprintf('Lambda.eigenbasis functionality verified:\n');
fprintf('  • Direct Lambda.eigenbasis() call works correctly\n');
fprintf('  • bct.computeEigenbasis() orchestration successful\n');
fprintf('  • Transforms automatically initialized after computation\n');
fprintf('  • Custom parameters (tol, maxit) accepted\n');
fprintf('  • Generalized eigenproblem K*U = M*U*D satisfied\n');
fprintf('  • MFT/IMFT transforms functional\n\n');

