% Test script for automatic units and coordinate mode updates
% Tests that units update correctly when coordinate mode changes

% Initialize BCT environment
bioctree_start;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' Testing Coordinate Mode and Units Updates\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

%% Test 1: Lambda default coordinate mode and units
fprintf('Test 1: Lambda default coordinate mode (Wavenumber)...\n');

try
    % Create Lambda
    eigenStruct = struct('eigenvalues', [1, 4, 9, 16, 25]');
    L = bct.Lambda(eigenStruct);
    
    % Check default is Wavenumber for filter design
    assert(L.displayCoordinateMode == bct.enum.CoordinateMode.Wavenumber, ...
        'Lambda default should be Wavenumber');
    assert(L.units == "1/mm", 'Lambda default units should be 1/mm');
    
    expected_k = sqrt([1, 4, 9, 16, 25]');
    assert(max(abs(L.axis - expected_k)) < 1e-10, 'Axis should be wavenumber');
    
    fprintf('  ✓ Default mode: Wavenumber\n');
    fprintf('  ✓ Default units: %s\n', L.units);
    fprintf('  ✓ Axis values: sqrt(lambda)\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 2: Lambda coordinate mode switching updates units
fprintf('Test 2: Lambda coordinate mode switching...\n');

try
    eigenStruct = struct('eigenvalues', [1, 4, 9, 16, 25]');
    L = bct.Lambda(eigenStruct);
    
    % Switch to Lambda mode
    L.displayCoordinateMode = bct.enum.CoordinateMode.Lambda;
    L = L.updateCoordinateMode();
    assert(L.units == "1/mm^2", 'Lambda mode units should be 1/mm^2');
    assert(isequal(L.axis, [1, 4, 9, 16, 25]'), 'Axis should be eigenvalues');
    fprintf('  ✓ Lambda mode: units=%s, axis=eigenvalues\n', L.units);
    
    % Switch to Wavenumber mode
    L.displayCoordinateMode = bct.enum.CoordinateMode.Wavenumber;
    L = L.updateCoordinateMode();
    assert(L.units == "1/mm", 'Wavenumber mode units should be 1/mm');
    expected_k = sqrt([1, 4, 9, 16, 25]');
    assert(max(abs(L.axis - expected_k)) < 1e-10, 'Axis should be sqrt(lambda)');
    fprintf('  ✓ Wavenumber mode: units=%s, axis=sqrt(lambda)\n', L.units);
    
    % Switch to Wavelength mode
    L.displayCoordinateMode = bct.enum.CoordinateMode.Wavelength;
    L = L.updateCoordinateMode();
    assert(L.units == "mm", 'Wavelength mode units should be mm');
    expected_wl = 1 ./ sqrt([1, 4, 9, 16, 25]');
    assert(max(abs(L.axis - expected_wl)) < 1e-10, 'Axis should be 1/sqrt(lambda)');
    fprintf('  ✓ Wavelength mode: units=%s, axis=1/sqrt(lambda)\n', L.units);
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 3: Omega default coordinate mode and units
fprintf('Test 3: Omega default coordinate mode (Frequency)...\n');

try
    % Create Time domain (which creates Omega)
    t = linspace(0, 1, 100)';
    fs = 100;
    timeDomain = bct.Time(t, fs);
    omegaDomain = timeDomain.dual;
    
    % Check default is Frequency for filter design
    assert(omegaDomain.displayCoordinateMode == bct.enum.CoordinateMode.Frequency, ...
        'Omega default should be Frequency');
    assert(omegaDomain.units == "Hz", 'Omega default units should be Hz');
    assert(isequal(omegaDomain.axis, omegaDomain.freq), 'Axis should be frequency');
    
    fprintf('  ✓ Default mode: Frequency\n');
    fprintf('  ✓ Default units: %s\n', omegaDomain.units);
    fprintf('  ✓ Axis values: frequency (Hz)\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 4: Omega coordinate mode switching updates units
fprintf('Test 4: Omega coordinate mode switching...\n');

try
    t = linspace(0, 1, 100)';
    fs = 100;
    timeDomain = bct.Time(t, fs);
    O = timeDomain.dual;
    
    % Switch to Omega mode
    O.displayCoordinateMode = bct.enum.CoordinateMode.Omega;
    O = O.updateCoordinateMode();
    assert(O.units == "rad/s", 'Omega mode units should be rad/s');
    assert(isequal(O.axis, O.omega), 'Axis should be angular frequency');
    fprintf('  ✓ Omega mode: units=%s, axis=omega (rad/s)\n', O.units);
    
    % Switch to Frequency mode
    O.displayCoordinateMode = bct.enum.CoordinateMode.Frequency;
    O = O.updateCoordinateMode();
    assert(O.units == "Hz", 'Frequency mode units should be Hz');
    assert(isequal(O.axis, O.freq), 'Axis should be frequency');
    fprintf('  ✓ Frequency mode: units=%s, axis=freq (Hz)\n', O.units);
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 5: Time default coordinate mode and units
fprintf('Test 5: Time default coordinate mode (Time)...\n');

try
    t = linspace(0, 1, 100)';
    fs = 100;
    T = bct.Time(t, fs);
    
    % Check default is Time in seconds
    assert(T.displayCoordinateMode == bct.enum.CoordinateMode.Time, ...
        'Time default should be Time');
    assert(T.units == "s", 'Time default units should be s');
    assert(isequal(T.axis, t), 'Axis should be time vector');
    
    fprintf('  ✓ Default mode: Time\n');
    fprintf('  ✓ Default units: %s\n', T.units);
    fprintf('  ✓ Axis values: time (seconds)\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 6: Time coordinate mode switching updates units
fprintf('Test 6: Time coordinate mode switching...\n');

try
    t = linspace(0, 1, 100)';
    fs = 100;
    T = bct.Time(t, fs);
    
    % Switch to Index mode
    T.displayCoordinateMode = bct.enum.CoordinateMode.Index;
    T = T.updateCoordinateMode();
    assert(T.units == "samples", 'Index mode units should be samples');
    assert(isequal(T.axis, (1:100)'), 'Axis should be sample indices');
    fprintf('  ✓ Index mode: units=%s, axis=sample indices\n', T.units);
    
    % Switch back to Time mode
    T.displayCoordinateMode = bct.enum.CoordinateMode.Time;
    T = T.updateCoordinateMode();
    assert(T.units == "s", 'Time mode units should be s');
    assert(isequal(T.axis, t), 'Axis should be time vector');
    fprintf('  ✓ Time mode: units=%s, axis=time (s)\n', T.units);
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 7: Manifold default coordinate mode and units
fprintf('Test 7: Manifold default coordinate mode (Vertex)...\n');

try
    % Create Manifold
    [V, F] = icosphere(2);
    B = bct.bct.fromMesh(V, F);
    M = B.Manifold;
    
    % Check default is Vertex
    assert(M.displayCoordinateMode == bct.enum.CoordinateMode.Vertex, ...
        'Manifold default should be Vertex');
    assert(M.units == "vertex", 'Manifold default units should be vertex');
    N = size(V, 1);
    assert(isequal(M.axis, (1:N)'), 'Axis should be vertex indices');
    
    fprintf('  ✓ Default mode: Vertex\n');
    fprintf('  ✓ Default units: %s\n', M.units);
    fprintf('  ✓ Axis values: vertex indices\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 8: Units persist after eigenbasis computation
fprintf('Test 8: Units update correctly after eigenbasis...\n');

try
    [V, F] = icosphere(2);
    B = bct.bct.fromMesh(V, F);
    
    % Check initial Lambda units (should be Wavenumber default)
    assert(B.Lambda.units == "1/mm", 'Initial Lambda units should be 1/mm (wavenumber)');
    fprintf('  ✓ Before eigenbasis: Lambda units=%s\n', B.Lambda.units);
    
    % Compute eigenbasis
    B = B.computeEigenbasis(30);
    
    % Units should still be correct (wavenumber)
    assert(B.Lambda.units == "1/mm", 'Lambda units should remain 1/mm after eigenbasis');
    assert(B.Lambda.displayCoordinateMode == bct.enum.CoordinateMode.Wavenumber, ...
        'Coordinate mode should remain Wavenumber');
    fprintf('  ✓ After eigenbasis: Lambda units=%s, mode=%s\n', ...
        B.Lambda.units, string(B.Lambda.displayCoordinateMode));
    
    % Switch mode and verify units update
    B.Lambda.displayCoordinateMode = bct.enum.CoordinateMode.Wavelength;
    B.Lambda = B.Lambda.updateCoordinateMode();
    assert(B.Lambda.units == "mm", 'Units should update to mm in Wavelength mode');
    fprintf('  ✓ After mode switch: Lambda units=%s\n', B.Lambda.units);
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('═══════════════════════════════════════════════════════════\n');
fprintf(' ✓ All tests passed!\n');
fprintf('═══════════════════════════════════════════════════════════\n\n');

fprintf('Coordinate mode and units system verified:\n');
fprintf('  Domain defaults for filter design:\n');
fprintf('    • Lambda: Wavenumber (1/mm)\n');
fprintf('    • Manifold: Vertex (vertex)\n');
fprintf('    • Time: Time (s)\n');
fprintf('    • Omega: Frequency (Hz)\n\n');
fprintf('  Units update automatically when coordinate mode changes:\n');
fprintf('    • Lambda: 1/mm^2 (eigenvalue) ↔ 1/mm (wavenumber) ↔ mm (wavelength)\n');
fprintf('    • Omega: rad/s (angular) ↔ Hz (frequency)\n');
fprintf('    • Time: s (time) ↔ samples (index)\n');
fprintf('    • Manifold: vertex (index) ↔ mm (geodesic-future)\n\n');
