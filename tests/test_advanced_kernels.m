%% Quick Test: Advanced Kernels
% Verify Hermite, Meyer, Daubechies, and Slepian implementations

fprintf('Testing advanced kernels...\n\n');

%% Test 1: Hermite Functions
fprintf('1. Hermite functions... ');
try
    hermite = bct.kernel.get("Hermite");
    x = linspace(-3, 3, 100);
    psi0 = hermite(x, 0);  % Should be Gaussian
    psi1 = hermite(x, 1);
    psi2 = hermite(x, 2);
    
    assert(all(isfinite(psi0)), 'Hermite order 0 has NaN/Inf');
    assert(all(isfinite(psi1)), 'Hermite order 1 has NaN/Inf');
    assert(all(isfinite(psi2)), 'Hermite order 2 has NaN/Inf');
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 2: Meyer Wavelet
fprintf('2. Meyer wavelet... ');
try
    meyer = bct.kernel.get("MeyerHat");
    w = linspace(-4*pi, 4*pi, 1000);
    Y = meyer(w);
    
    assert(all(isfinite(Y)), 'Meyer has NaN/Inf');
    
    % Check compact support
    outOfBand = abs(w) < 2*pi/3 | abs(w) > 8*pi/3;
    assert(all(abs(Y(outOfBand)) < 1e-10), 'Meyer not compact in frequency');
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 3: Daubechies Generator
fprintf('3. Daubechies generator... ');
try
    dbGen = bct.kernel.get("Daubechies", 'Type', 'generator');
    [phi, psi, xval] = dbGen(4);
    
    assert(all(isfinite(phi)), 'Daubechies phi has NaN/Inf');
    assert(all(isfinite(psi)), 'Daubechies psi has NaN/Inf');
    assert(length(phi) == length(xval), 'Size mismatch');
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 4: Slepian Generator
fprintf('4. Slepian generator... ');
try
    slepianGen = bct.kernel.get("Slepian", 'Type', 'generator');
    [v, lambda] = slepianGen(256, 3);
    
    assert(size(v, 1) == 256, 'Slepian wrong size');
    assert(all(lambda >= 0 & lambda <= 1), 'Eigenvalues out of range');
    assert(issorted(flipud(lambda)), 'Eigenvalues not sorted descending');
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 5: List Functions
fprintf('5. List functionality... ');
try
    allKernels = bct.kernel.list();
    analyticKernels = bct.kernel.list('Type', 'analytic');
    generators = bct.kernel.list('Type', 'generator');
    
    assert(ismember("Hermite", analyticKernels), 'Hermite not in analytic list');
    assert(ismember("MeyerHat", analyticKernels), 'MeyerHat not in analytic list');
    assert(ismember("Daubechies", generators), 'Daubechies not in generator list');
    assert(ismember("Slepian", generators), 'Slepian not in generator list');
    
    fprintf('✓ PASS\n');
    fprintf('   Found %d analytic kernels\n', length(analyticKernels));
    fprintf('   Found %d generators\n', length(generators));
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

%% Test 6: Auto Lookup
fprintf('6. Auto lookup priority... ');
try
    % Should find in dictionary first
    gaussian = bct.kernel.get("Gaussian");
    
    % Should find in generators
    slepian = bct.kernel.get("Slepian");
    
    % Verify types
    assert(isa(gaussian, 'function_handle'), 'Gaussian not a function handle');
    assert(isa(slepian, 'function_handle'), 'Slepian not a function handle');
    
    fprintf('✓ PASS\n');
catch ME
    fprintf('✗ FAIL: %s\n', ME.message);
end

fprintf('\nAll tests completed!\n');
