% Test script for basic bct object creation
% Tests creating bct objects using the bct package

% Initialize BCT environment
bioctree_start;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' Testing Basic BCT Object Creation\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

%% Test 1: Create bct object from mesh using fromMesh
fprintf('Test 1: Create bct object from icosphere mesh...\n');

try
    % Generate icosphere mesh (subdivision level 2)
    [V, F] = icosphere(2);
    
    % Create bct object from mesh
    B = bct.bct.fromMesh(V, F);
    
    % Verify object was created
    assert(~isempty(B), 'BCT object should not be empty');
    assert(isa(B, 'bct.bct'), 'Object should be of type bct.bct');
    
    % Verify Manifold was created
    assert(~isempty(B.Manifold), 'Manifold should not be empty');
    assert(isa(B.Manifold, 'bct.Manifold'), 'Manifold should be bct.Manifold object');
    
    % Verify mesh properties
    assert(B.Manifold.N > 0, 'Manifold should have vertices');
    assert(size(B.Manifold.coords, 2) == 3, 'Coordinates should be 3D');
    
    fprintf('  ✓ Created bct object with %d vertices\n', B.Manifold.N);
    fprintf('  ✓ Test 1 PASSED\n\n');
    
catch ME
    fprintf('  ✗ Test 1 FAILED: %s\n\n', ME.message);
    rethrow(ME);
end

%% Test 2: Verify Lambda domain (dual of Manifold)
fprintf('Test 2: Verify Lambda domain creation...\n');

try
    % Lambda should be automatically created as dual of Manifold
    assert(~isempty(B.Lambda), 'Lambda should not be empty');
    assert(isa(B.Lambda, 'bct.Lambda'), 'Lambda should be bct.Lambda object');
    
    % Lambda should have estimated axis (before eigenbasis computation)
    assert(~isempty(B.Lambda.axis), 'Lambda should have estimated axis');
    
    fprintf('  ✓ Lambda domain created as dual of Manifold\n');
    fprintf('  ✓ Estimated axis has %d points\n', length(B.Lambda.axis));
    fprintf('  ✓ Test 2 PASSED\n\n');
    
catch ME
    fprintf('  ✗ Test 2 FAILED: %s\n\n', ME.message);
    rethrow(ME);
end

%% Test 3: Compute eigenbasis
fprintf('Test 3: Compute eigenbasis for Lambda domain...\n');

try
    k = 50;  % Number of eigenmodes
    B = B.computeEigenbasis(k);
    
    % Verify eigenbasis was computed
    assert(~isempty(B.Lambda.lambda), 'Lambda.lambda should not be empty after eigenbasis');
    assert(~isempty(B.Lambda.U), 'Lambda.U should not be empty after eigenbasis');
    assert(B.Lambda.K == k, sprintf('Lambda.K should be %d', k));
    assert(length(B.Lambda.lambda) == k, sprintf('Should have %d eigenvalues', k));
    
    fprintf('  ✓ Computed %d eigenmodes\n', k);
    fprintf('  ✓ Eigenvalue range: [%.4f, %.4f]\n', min(B.Lambda.lambda), max(B.Lambda.lambda));
    fprintf('  ✓ Test 3 PASSED\n\n');
    
catch ME
    fprintf('  ✗ Test 3 FAILED: %s\n\n', ME.message);
    rethrow(ME);
end

%% Test 4: Add Time domain
fprintf('Test 4: Add Time domain to bct object...\n');

try
    % Create time vector (100 samples, 1 second duration, 100 Hz sampling rate)
    t = linspace(0, 1, 100)';
    fs = 100;  % Sampling frequency (Hz)
    
    % Create Time domain
    B.Time = bct.Time(t, fs);
    
    % Verify Time was created
    assert(~isempty(B.Time), 'Time should not be empty');
    assert(isa(B.Time, 'bct.Time'), 'Time should be bct.Time object');
    assert(B.Time.N == 100, 'Time should have 100 samples');
    assert(B.Time.fs == fs, sprintf('Sampling rate should be %d Hz', fs));
    
    fprintf('  ✓ Created Time domain with %d samples at %.1f Hz\n', B.Time.N, B.Time.fs);
    fprintf('  ✓ Test 4 PASSED\n\n');
    
catch ME
    fprintf('  ✗ Test 4 FAILED: %s\n\n', ME.message);
    rethrow(ME);
end

%% Test 5: Verify Omega domain (dual of Time)
fprintf('Test 5: Verify Omega domain creation...\n');

try
    % Omega should be automatically created as dual of Time
    assert(~isempty(B.Omega), 'Omega should not be empty');
    assert(isa(B.Omega, 'bct.Omega'), 'Omega should be bct.Omega object');
    
    % Verify frequency properties
    assert(~isempty(B.Omega.axis), 'Omega should have frequency axis');
    nyquist = B.Time.fs / 2;
    max_freq = max(B.Omega.axis) / (2*pi);
    assert(abs(max_freq - nyquist) < 1e-6, sprintf('Max frequency should be Nyquist (%.1f Hz)', nyquist));
    
    fprintf('  ✓ Omega domain created as dual of Time\n');
    fprintf('  ✓ Frequency range: [%.1f, %.1f] Hz\n', min(B.Omega.axis)/(2*pi), max(B.Omega.axis)/(2*pi));
    fprintf('  ✓ Test 5 PASSED\n\n');
    
catch ME
    fprintf('  ✗ Test 5 FAILED: %s\n\n', ME.message);
    rethrow(ME);
end

%% Test 6: Verify bct object structure
fprintf('Test 6: Verify complete bct object structure...\n');

try
    % Check all domains are present
    assert(~isempty(B.Manifold), 'Manifold should exist');
    assert(~isempty(B.Lambda), 'Lambda should exist');
    assert(~isempty(B.Time), 'Time should exist');
    assert(~isempty(B.Omega), 'Omega should exist');
    
    % Check dual relationships
    assert(isequal(B.Manifold.dual, B.Lambda), 'Manifold.dual should be Lambda');
    assert(isequal(B.Time.dual, B.Omega), 'Time.dual should be Omega');
    
    fprintf('  ✓ All primary domains present: Manifold, Lambda, Time, Omega\n');
    fprintf('  ✓ Dual relationships verified\n');
    fprintf('  ✓ Test 6 PASSED\n\n');
    
catch ME
    fprintf('  ✗ Test 6 FAILED: %s\n\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' All Basic BCT Creation Tests PASSED ✓\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

fprintf('Created bct object summary:\n');
fprintf('  - Manifold: %d vertices\n', B.Manifold.N);
fprintf('  - Lambda: %d eigenmodes (computed)\n', B.Lambda.K);
fprintf('  - Time: %d samples at %.1f Hz\n', B.Time.N, B.Time.fs);
fprintf('  - Omega: %.1f Hz Nyquist frequency\n', max(B.Omega.axis)/(2*pi));
fprintf('\n');
