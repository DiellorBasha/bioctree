% Test script for Lambda automatic axis update
% Tests that Lambda.axis updates when lambda property changes

% Initialize BCT environment
bioctree_start;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' Testing Lambda Automatic Axis Update\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

%% Test 1: Axis updates when lambda is set manually
fprintf('Test 1: Manual lambda update triggers axis rebuild...\n');

try
    % Create Lambda with placeholder eigenvalues
    eigenStruct = struct('eigenvalues', (1:10)');
    L = bct.Lambda(eigenStruct);
    
    % Check initial state
    assert(L.K == 10, 'Initial K should be 10');
    assert(length(L.axis) == 10, 'Initial axis should have 10 points');
    assert(isequal(L.axis, (1:10)'), 'Initial axis should match eigenvalues');
    fprintf('  ✓ Initial state: K=%d, axis length=%d\n', L.K, length(L.axis));
    
    % Manually update lambda
    newLambda = (1:20)';
    L.lambda = newLambda;
    
    % Check that K and axis updated automatically
    assert(L.K == 20, 'K should update to 20');
    assert(length(L.axis) == 20, 'Axis should update to 20 points');
    assert(isequal(L.axis, (1:20)'), 'Axis should match new eigenvalues');
    fprintf('  ✓ After manual update: K=%d, axis length=%d\n', L.K, length(L.axis));
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 2: Axis updates via eigenbasis computation
fprintf('Test 2: eigenbasis() automatically updates axis...\n');

try
    % Create mesh
    [V, F] = icosphere(2);  % 162 vertices
    B = bct.bct.fromMesh(V, F);
    
    % Check initial Lambda state
    initialK = B.Lambda.K;
    initialAxisLength = length(B.Lambda.axis);
    fprintf('  → Initial: K=%d, axis length=%d\n', initialK, initialAxisLength);
    
    % Compute eigenbasis with fewer modes
    numModes = 30;
    B = B.computeEigenbasis(numModes);
    
    % Check that K and axis updated
    assert(B.Lambda.K < initialK, 'K should be less than initial');
    assert(B.Lambda.K <= numModes, 'K should be at most numModes');
    assert(length(B.Lambda.axis) == B.Lambda.K, 'Axis length should match K');
    assert(length(B.Lambda.axis) == length(B.Lambda.lambda), 'Axis should match lambda');
    
    fprintf('  ✓ After eigenbasis: K=%d, axis length=%d\n', B.Lambda.K, length(B.Lambda.axis));
    fprintf('  ✓ Axis automatically updated from %d to %d points\n', initialAxisLength, length(B.Lambda.axis));
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 3: Axis updates with different coordinate modes
fprintf('Test 3: Axis updates correctly for different coordinate modes...\n');

try
    % Create Lambda
    eigenStruct = struct('eigenvalues', [1, 4, 9, 16, 25]');
    L = bct.Lambda(eigenStruct);
    
    % Lambda mode (default)
    assert(L.displayCoordinateMode == bct.enum.CoordinateMode.Lambda, 'Should be Lambda mode');
    assert(isequal(L.axis, [1, 4, 9, 16, 25]'), 'Axis should be eigenvalues');
    fprintf('  ✓ Lambda mode: axis = eigenvalues\n');
    
    % Switch to Wavenumber mode
    L.displayCoordinateMode = bct.enum.CoordinateMode.Wavenumber;
    L = L.updateCoordinateMode();
    expected_k = sqrt([1, 4, 9, 16, 25]');
    assert(max(abs(L.axis - expected_k)) < 1e-10, 'Axis should be sqrt(lambda)');
    fprintf('  ✓ Wavenumber mode: axis = sqrt(eigenvalues)\n');
    
    % Switch to Wavelength mode
    L.displayCoordinateMode = bct.enum.CoordinateMode.Wavelength;
    L = L.updateCoordinateMode();
    expected_wavelength = 1 ./ sqrt([1, 4, 9, 16, 25]');
    assert(max(abs(L.axis - expected_wavelength)) < 1e-10, 'Axis should be 1/sqrt(lambda)');
    fprintf('  ✓ Wavelength mode: axis = 1/sqrt(eigenvalues)\n');
    
    % Now update lambda and verify axis updates in Wavelength mode
    L.lambda = [4, 9, 16]';
    expected_wavelength_new = 1 ./ sqrt([4, 9, 16]');
    assert(L.K == 3, 'K should update to 3');
    assert(length(L.axis) == 3, 'Axis should have 3 points');
    assert(max(abs(L.axis - expected_wavelength_new)) < 1e-10, 'Axis should update for new lambda in Wavelength mode');
    fprintf('  ✓ Lambda update in Wavelength mode: axis correctly recalculated\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 4: Multiple eigenbasis calls update axis correctly
fprintf('Test 4: Multiple eigenbasis computations update axis...\n');

try
    % Create mesh
    [V, F] = icosphere(2);
    B = bct.bct.fromMesh(V, F);
    
    % First computation
    B = B.computeEigenbasis(50);
    K1 = B.Lambda.K;
    axisLen1 = length(B.Lambda.axis);
    fprintf('  → First computation: K=%d, axis length=%d\n', K1, axisLen1);
    
    % Second computation with different number of modes
    B = B.computeEigenbasis(20);
    K2 = B.Lambda.K;
    axisLen2 = length(B.Lambda.axis);
    fprintf('  → Second computation: K=%d, axis length=%d\n', K2, axisLen2);
    
    % Verify axis updated
    assert(K2 < K1, 'Second K should be smaller');
    assert(axisLen2 == K2, 'Axis length should match K');
    assert(axisLen2 < axisLen1, 'Axis should be shorter after second computation');
    
    fprintf('  ✓ Axis correctly updated across multiple computations\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('═══════════════════════════════════════════════════════════\n');
fprintf(' ✓ All tests passed!\n');
fprintf('═══════════════════════════════════════════════════════════\n\n');

fprintf('Lambda automatic axis update verified:\n');
fprintf('  • Axis updates automatically when lambda property is set\n');
fprintf('  • K (number of modes) updates automatically with lambda\n');
fprintf('  • eigenbasis() triggers automatic axis update\n');
fprintf('  • Axis updates correctly for all coordinate modes\n');
fprintf('  • Multiple eigenbasis computations handled correctly\n\n');
