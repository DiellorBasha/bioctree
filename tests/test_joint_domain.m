% Test script for Joint domain
% Tests creation and manipulation of joint domains

% Initialize BCT environment
bioctree_start;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' Testing Joint Domain\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

%% Test 1: Lambda-Omega joint domain
fprintf('Test 1: Lambda-Omega joint domain (space-time frequency)...\n');

try
    % Create bct object with domains
    [V, F] = icosphere(2);
    B = bct.bct.fromMesh(V, F);
    B = B.computeEigenbasis(30);
    
    % Create Time domain
    t = linspace(0, 1, 50)';
    B.Time = bct.Time(t, 50);
    B.Omega = B.Time.dual;
    
    % Create Lambda-Omega joint domain
    J = bct.Joint(B.Lambda, B.Omega);
    
    % Verify basic properties
    assert(J.A_name == "Lambda", 'First domain should be Lambda');
    assert(J.B_name == "Omega", 'Second domain should be Omega');
    assert(J.Domain == "Lambda_Omega", 'Joint name should be Lambda_Omega');
    fprintf('  ✓ Joint domain created: %s\n', J.Domain);
    
    % Verify axes
    assert(length(J.A_axis) == B.Lambda.K, 'A_axis should match Lambda.K');
    assert(length(J.B_axis) == 50, 'B_axis should have 50 points');
    fprintf('  ✓ A_axis: %d eigenvalues\n', length(J.A_axis));
    fprintf('  ✓ B_axis: %d frequency points\n', length(J.B_axis));
    
    % Verify grids
    sz = J.size();
    assert(isequal(sz, [B.Lambda.K, 50]), 'Grid size should be [K×50]');
    assert(isequal(size(J.A_grid), sz), 'A_grid size should match');
    assert(isequal(size(J.B_grid), sz), 'B_grid size should match');
    fprintf('  ✓ Grid size: [%d×%d] = %d points\n', sz(1), sz(2), J.numel());
    
    % Verify units
    fprintf('  ✓ Units: %s\n', J.units);
    fprintf('  ✓ A_units: %s, B_units: %s\n', J.A_units, J.B_units);
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 2: Manifold-Time joint domain
fprintf('Test 2: Manifold-Time joint domain (spatiotemporal)...\n');

try
    [V, F] = icosphere(1);
    B = bct.bct.fromMesh(V, F);
    
    t = linspace(0, 2, 100)';
    B.Time = bct.Time(t, 50);
    
    % Create Manifold-Time joint domain
    J = bct.Joint(B.Manifold, B.Time);
    
    % Verify properties
    assert(J.A_name == "Manifold", 'First domain should be Manifold');
    assert(J.B_name == "Time", 'Second domain should be Time');
    assert(J.Domain == "Manifold_Time", 'Joint name should be Manifold_Time');
    fprintf('  ✓ Joint domain created: %s\n', J.Domain);
    
    % Verify dimensions
    N = size(V, 1);
    T = 100;
    sz = J.size();
    assert(isequal(sz, [N, T]), 'Grid size should be [N×T]');
    fprintf('  ✓ Grid size: [%d×%d] = %d points\n', sz(1), sz(2), J.numel());
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 3: Time-Omega joint domain
fprintf('Test 3: Time-Omega joint domain (time-frequency)...\n');

try
    t = linspace(0, 1, 100)';
    timeDomain = bct.Time(t, 100);
    omegaDomain = timeDomain.dual;
    
    % Create Time-Omega joint domain
    J = bct.Joint(timeDomain, omegaDomain);
    
    % Verify
    assert(J.Domain == "Time_Omega", 'Joint name should be Time_Omega');
    sz = J.size();
    assert(isequal(sz, [100, 100]), 'Grid size should be [100×100]');
    fprintf('  ✓ Joint domain created: %s\n', J.Domain);
    fprintf('  ✓ Grid size: [%d×%d]\n', sz(1), sz(2));
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 4: Reshape and flatten operations
fprintf('Test 4: Reshape and flatten operations...\n');

try
    % Create simple joint domain
    eigenStruct = struct('eigenvalues', (1:5)');
    lambda = bct.Lambda(eigenStruct);
    
    t = linspace(0, 1, 10)';
    time = bct.Time(t, 10);
    
    J = bct.Joint(lambda, time.dual);
    
    % Create 1D signal
    x = (1:50)';
    
    % Reshape to 2D
    X = J.reshape2D(x);
    assert(isequal(size(X), [5, 10]), 'Reshaped should be [5×10]');
    fprintf('  ✓ reshape2D: [50×1] → [5×10]\n');
    
    % Flatten back to 1D
    x_back = J.flatten(X);
    assert(isequal(x, x_back), 'Flatten should recover original');
    fprintf('  ✓ flatten: [5×10] → [50×1]\n');
    
    % Verify roundtrip
    assert(max(abs(x - x_back)) == 0, 'Roundtrip should be exact');
    fprintf('  ✓ Roundtrip verified\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 5: Grid coordinates
fprintf('Test 5: Grid coordinates verification...\n');

try
    % Create joint domain with known axes
    eigenStruct = struct('eigenvalues', [1, 4, 9]');
    lambda = bct.Lambda(eigenStruct);
    
    t = linspace(0, 1, 4)';
    time = bct.Time(t, 4);
    
    J = bct.Joint(lambda, time);
    
    % Verify A_grid repeats A_axis along columns
    for j = 1:4
        assert(isequal(J.A_grid(:, j), lambda.axis), ...
            'A_grid column should match A_axis');
    end
    fprintf('  ✓ A_grid correctly repeats A_axis along columns\n');
    
    % Verify B_grid repeats B_axis along rows
    for i = 1:3
        assert(isequal(J.B_grid(i, :)', time.axis), ...
            'B_grid row should match B_axis');
    end
    fprintf('  ✓ B_grid correctly repeats B_axis along rows\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 6: Axis update when constituent domains change
fprintf('Test 6: Axis updates when constituent domains change...\n');

try
    % Create domains
    eigenStruct = struct('eigenvalues', (1:10)');
    lambda = bct.Lambda(eigenStruct);
    
    t = linspace(0, 1, 20)';
    time = bct.Time(t, 20);
    
    J = bct.Joint(lambda, time);
    
    % Initial size
    sz1 = J.size();
    assert(isequal(sz1, [10, 20]), 'Initial size should be [10×20]');
    fprintf('  ✓ Initial grid size: [%d×%d]\n', sz1(1), sz1(2));
    
    % Change Lambda eigenvalues
    lambda.lambda = (1:5)';  % Triggers automatic axis update
    
    % Rebuild joint axis
    J = J.buildAxis();
    
    % Verify size changed
    sz2 = J.size();
    assert(isequal(sz2, [5, 20]), 'Size should update to [5×20]');
    fprintf('  ✓ After Lambda change: [%d×%d]\n', sz2(1), sz2(2));
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 7: isDual method
fprintf('Test 7: isDual method for joint domains...\n');

try
    % Create bct object
    [V, F] = icosphere(1);
    B = bct.bct.fromMesh(V, F);
    B = B.computeEigenbasis(20);
    
    t = linspace(0, 1, 30)';
    B.Time = bct.Time(t, 30);
    B.Omega = B.Time.dual;
    
    % Create dual joint domains
    J1 = bct.Joint(B.Manifold, B.Time);    % Space × Time
    J2 = bct.Joint(B.Lambda, B.Omega);      % Lambda × Omega (dual)
    
    % Verify duality
    assert(J1.isDual(J2), 'Manifold×Time should be dual to Lambda×Omega');
    fprintf('  ✓ Manifold×Time is dual to Lambda×Omega\n');
    
    % Create non-dual joint domain
    J3 = bct.Joint(B.Manifold, B.Omega);
    assert(~J1.isDual(J3), 'Manifold×Time should not be dual to Manifold×Omega');
    fprintf('  ✓ Duality correctly identifies non-dual domains\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 8: Custom display
fprintf('Test 8: Custom display method...\n');

try
    [V, F] = icosphere(1);
    B = bct.bct.fromMesh(V, F);
    B = B.computeEigenbasis(15);
    
    t = linspace(0, 2, 50)';
    B.Time = bct.Time(t, 25);
    
    J = bct.Joint(B.Lambda, B.Time);
    
    fprintf('  ✓ Display output:\n');
    fprintf('  ─────────────────────────────────────────\n');
    disp(J);
    fprintf('  ─────────────────────────────────────────\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('═══════════════════════════════════════════════════════════\n');
fprintf(' ✓ All tests passed!\n');
fprintf('═══════════════════════════════════════════════════════════\n\n');

fprintf('Joint domain functionality verified:\n');
fprintf('  • Lambda×Omega joint domain (space-time frequency)\n');
fprintf('  • Manifold×Time joint domain (spatiotemporal)\n');
fprintf('  • Time×Omega joint domain (time-frequency)\n');
fprintf('  • reshape2D and flatten operations\n');
fprintf('  • Grid coordinates (A_grid, B_grid)\n');
fprintf('  • Axis updates when constituent domains change\n');
fprintf('  • isDual method for dual domain detection\n');
fprintf('  • Custom display method\n\n');

fprintf('Joint domain can combine:\n');
fprintf('  • Any two canonical BCT domains\n');
fprintf('  • Maintains axes, units, and metadata from both\n');
fprintf('  • Provides 2D grid coordinates for joint analysis\n');
fprintf('  • Supports reshape/flatten for signal processing\n\n');

