% Test script for Domain transform initialization
% Tests that transforms are properly set for Manifold/Lambda and Time/Omega

% Initialize BCT environment
bioctree_start;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' Testing Domain Transform Initialization\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

%% Test 1: Time domain transforms (FFT/IFFT)
fprintf('Test 1: Time domain transforms (FFT/IFFT)...\n');

try
    % Create Time domain (automatically creates Omega dual)
    t = linspace(0, 1.99, 200)';
    fs = 100;  % Hz
    timeDomain = bct.Time(t, fs);
    
    % Verify Time has transform
    assert(~isempty(timeDomain.transform), 'Time domain should have transform');
    fprintf('  ✓ Time domain has transform\n');
    
    % Verify Omega dual has transform
    omegaDomain = timeDomain.dual;
    assert(~isempty(omegaDomain.transform), 'Omega domain should have transform');
    fprintf('  ✓ Omega domain has transform\n');
    
    % Verify transform types
    assert(isa(timeDomain.transform, 'bct.factory.transforms.FFT'), 'Time transform should be FFT');
    fprintf('  ✓ Time transform is FFT\n');
    
    assert(isa(omegaDomain.transform, 'bct.factory.transforms.IFFT'), 'Omega transform should be IFFT');
    fprintf('  ✓ Omega transform is IFFT\n');
    
    % Test forward/inverse
    signal = sin(2*pi*5*t) + 0.5*sin(2*pi*10*t);  % 5Hz + 10Hz signal
    
    % Time → Omega (FFT forward)
    spectrum = timeDomain.transform.forward(signal);
    
    % Omega → Time (IFFT forward, NOT inverse!)
    % Note: IFFT.forward does ifft(), IFFT.inverse does fft()
    reconstructed = omegaDomain.transform.forward(spectrum);
    
    % Debug: check error
    error_mag = max(abs(signal - reconstructed));
    fprintf('  → Reconstruction error: %.2e\n', error_mag);
    fprintf('  → Signal size: %d, Spectrum size: %d, Reconstructed size: %d\n', ...
            length(signal), length(spectrum), length(reconstructed));
    
    assert(error_mag < 1e-10, sprintf('FFT/IFFT should be inverse operations (error: %.2e)', error_mag));
    fprintf('  ✓ FFT/IFFT are proper inverses\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 2: Manifold/Lambda transforms (initially empty, set after eigendecomposition)
fprintf('Test 2: Manifold/Lambda transforms (placeholder)...\n');

try
    % Create simple icosphere mesh
    [V, F] = icosphere(2);  % 162 vertices
    
    % Create bct object with Manifold and Lambda
    B = bct.bct.fromMesh(V, F);
    
    % Verify dual linking exists
    assert(B.Manifold.dual == B.Lambda, 'Manifold dual should be Lambda');
    fprintf('  ✓ Manifold ↔ Lambda dual linking verified\n');
    
    % Initially, transforms should be empty because eigenvectors not computed
    % (Lambda has placeholder eigenvalues but no eigenvectors yet)
    assert(isempty(B.Manifold.transform), 'Manifold transform should be empty (no eigenvectors yet)');
    assert(isempty(B.Lambda.transform), 'Lambda transform should be empty (no eigenvectors yet)');
    fprintf('  ✓ Transforms initially empty (eigenvectors not computed)\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 3: Manifold/Lambda transforms after eigendecomposition
fprintf('Test 3: Manifold/Lambda transforms after eigendecomposition...\n');

try
    % Create mesh
    [V, F] = icosphere(2);
    B = bct.bct.fromMesh(V, F);
    
    % Compute eigenvectors using meshFourier
    numModes = 50;  % Request 50 modes
    [U, lambda] = bct.Manifold.meshFourier(V, F, numModes);
    
    % meshFourier may remove DC and negative eigenvalues, so actual K < numModes
    K = size(U, 2);  % Actual number of modes returned
    fprintf('  → Requested %d modes, got %d modes after DC removal\n', numModes, K);
    
    % Update Lambda with actual eigenvectors
    B.Lambda.U = U;
    B.Lambda.lambda = lambda;
    
    % Now initialize transforms (should work because eigenvectors exist)
    B.Manifold.initializeTransform();
    B.Lambda.initializeTransform();
    
    % Verify transforms are now set
    assert(~isempty(B.Manifold.transform), 'Manifold transform should be set after eigenvectors computed');
    assert(~isempty(B.Lambda.transform), 'Lambda transform should be set after eigenvectors computed');
    fprintf('  ✓ Transforms set after eigenvector computation\n');
    
    % Verify transform types
    assert(isa(B.Manifold.transform, 'bct.factory.transforms.MFT'), 'Manifold transform should be MFT');
    fprintf('  ✓ Manifold transform is MFT\n');
    
    assert(isa(B.Lambda.transform, 'bct.factory.transforms.IMFT'), 'Lambda transform should be IMFT');
    fprintf('  ✓ Lambda transform is IMFT\n');
    
    % Test forward/inverse on a simple signal
    N = size(V, 1);
    spatialSignal = randn(N, 1);  % Random signal on vertices
    
    % Forward: Space → Lambda (MFT.forward)
    spectralCoeffs = B.Manifold.transform.forward(spatialSignal);
    fprintf('  ✓ Forward MFT: %d spatial samples → %d spectral coefficients\n', N, length(spectralCoeffs));
    
    % Inverse: Lambda → Space (IMFT.forward, NOT .inverse!)
    % Note: IMFT.forward = Lambda → Space, IMFT.inverse = Space → Lambda
    reconstructed = B.Lambda.transform.forward(spectralCoeffs);
    fprintf('  ✓ Inverse IMFT: %d spectral coefficients → %d spatial samples\n', length(spectralCoeffs), length(reconstructed));
    
    % Verify dimensions
    assert(length(spectralCoeffs) == K, 'Spectral coefficients should have K modes');
    assert(length(reconstructed) == N, 'Reconstructed signal should have N vertices');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 4: Complete bct object with all transforms
fprintf('Test 4: Complete bct object with all domain transforms...\n');

try
    % Create mesh
    [V, F] = icosphere(2);
    B = bct.bct.fromMesh(V, F);
    
    % Add Time domain
    t = linspace(0, 1.99, 200)';
    B.Time = bct.Time(t, 100);
    B.Omega = B.Time.dual;
    
    % Verify all domains exist
    assert(~isempty(B.Manifold), 'Manifold should exist');
    assert(~isempty(B.Lambda), 'Lambda should exist');
    assert(~isempty(B.Time), 'Time should exist');
    assert(~isempty(B.Omega), 'Omega should exist');
    fprintf('  ✓ All four domains created\n');
    
    % Verify Time/Omega transforms are set
    assert(~isempty(B.Time.transform), 'Time transform should be set');
    assert(~isempty(B.Omega.transform), 'Omega transform should be set');
    fprintf('  ✓ Time/Omega transforms initialized\n');
    
    % Manifold/Lambda transforms initially empty (no eigenvectors)
    assert(isempty(B.Manifold.transform), 'Manifold transform empty until eigenvectors computed');
    assert(isempty(B.Lambda.transform), 'Lambda transform empty until eigenvectors computed');
    fprintf('  ✓ Manifold/Lambda transforms awaiting eigenvector computation\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('═══════════════════════════════════════════════════════════\n');
fprintf(' ✓ All tests passed!\n');
fprintf('═══════════════════════════════════════════════════════════\n\n');

fprintf('Domain transform system verified:\n');
fprintf('  • Time domain: FFT transform initialized on construction\n');
fprintf('  • Omega domain: IFFT transform initialized on construction\n');
fprintf('  • Manifold domain: MFT transform set after eigenvectors computed\n');
fprintf('  • Lambda domain: IMFT transform set after eigenvectors computed\n');
fprintf('  • Forward/inverse transforms work correctly\n');
fprintf('  • Transform factory integration complete\n\n');

