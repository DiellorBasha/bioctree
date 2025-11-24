% Test script for bct.createJoint method
% Tests creating joint domains via the bct class

% Initialize BCT environment
bioctree_start;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' Testing bct.createJoint Method\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

%% Test 1: Create Lambda-Omega joint domain
fprintf('Test 1: Create Lambda-Omega joint domain...\n');

try
    % Create bct object
    [V, F] = icosphere(2);
    B = bct.bct.fromMesh(V, F);
    B = B.computeEigenbasis(50);
    
    % Create Time domain
    t = linspace(0, 1, 100)';
    B.Time = bct.Time(t, 100);
    B.Omega = B.Time.dual;
    
    % Create joint domain using bct method
    B = B.createJoint('Lambda', 'Omega');
    
    % Verify Joint was created
    assert(~isempty(B.Joint), 'Joint should not be empty');
    assert(isa(B.Joint, 'bct.Joint'), 'Joint should be bct.Joint object');
    fprintf('  ✓ Joint domain created via bct.createJoint\n');
    
    % Verify properties
    assert(B.Joint.Domain == "Lambda_Omega", 'Joint name should be Lambda_Omega');
    sz = B.Joint.N;
    fprintf('  ✓ Domain: %s\n', B.Joint.Domain);
    fprintf('  ✓ Grid size: [%d×%d]\n', sz(1), sz(2));
    fprintf('  ✓ Units: %s\n', B.Joint.units);
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 2: Create Manifold-Time joint domain
fprintf('Test 2: Create Manifold-Time joint domain...\n');

try
    [V, F] = icosphere(1);
    B = bct.bct.fromMesh(V, F);
    
    t = linspace(0, 2, 50)';
    B.Time = bct.Time(t, 50);
    
    % Create joint domain
    B = B.createJoint('Manifold', 'Time');
    
    % Verify
    assert(~isempty(B.Joint), 'Joint should not be empty');
    assert(B.Joint.Domain == "Manifold_Time", 'Joint name should be Manifold_Time');
    fprintf('  ✓ Joint domain: %s\n', B.Joint.Domain);
    fprintf('  ✓ Grid size: [%d×%d]\n', B.Joint.N);
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 3: Create Time-Omega joint domain
fprintf('Test 3: Create Time-Omega joint domain...\n');

try
    [V, F] = icosphere(1);
    B = bct.bct.fromMesh(V, F);
    
    t = linspace(0, 1, 200)';
    B.Time = bct.Time(t, 200);
    B.Omega = B.Time.dual;
    
    % Create joint domain
    B = B.createJoint('Time', 'Omega');
    
    % Verify
    assert(B.Joint.Domain == "Time_Omega", 'Joint name should be Time_Omega');
    sz = B.Joint.N;
    assert(isequal(sz, [200, 200]), 'Size should be [200×200]');
    fprintf('  ✓ Joint domain: %s\n', B.Joint.Domain);
    fprintf('  ✓ Grid size: [%d×%d]\n', sz(1), sz(2));
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 4: Create Lambda-Time joint domain
fprintf('Test 4: Create Lambda-Time joint domain...\n');

try
    [V, F] = icosphere(2);
    B = bct.bct.fromMesh(V, F);
    B = B.computeEigenbasis(30);
    
    t = linspace(0, 3, 75)';
    B.Time = bct.Time(t, 25);
    
    % Create joint domain
    B = B.createJoint('Lambda', 'Time');
    
    % Verify
    assert(B.Joint.Domain == "Lambda_Time", 'Joint name should be Lambda_Time');
    fprintf('  ✓ Joint domain: %s\n', B.Joint.Domain);
    fprintf('  ✓ Grid size: [%d×%d]\n', B.Joint.N);
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 5: Error handling - invalid domain name
fprintf('Test 5: Error handling - invalid domain name...\n');

try
    [V, F] = icosphere(1);
    B = bct.bct.fromMesh(V, F);
    
    % Try to create joint with invalid domain name
    errorCaught = false;
    try
        B = B.createJoint('InvalidDomain', 'Time');
    catch ME
        errorCaught = true;
        assert(contains(ME.identifier, 'InvalidDomain'), ...
            'Should throw InvalidDomain error');
    end
    
    assert(errorCaught, 'Should have caught error for invalid domain name');
    fprintf('  ✓ Correctly throws error for invalid domain name\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 6: Error handling - uninitialized domain
fprintf('Test 6: Error handling - uninitialized domain...\n');

try
    [V, F] = icosphere(1);
    B = bct.bct.fromMesh(V, F);
    % Time not created yet
    
    % Try to create joint with uninitialized Time
    errorCaught = false;
    try
        B = B.createJoint('Manifold', 'Time');
    catch ME
        errorCaught = true;
        assert(contains(ME.identifier, 'DomainNotInitialized'), ...
            'Should throw DomainNotInitialized error');
    end
    
    assert(errorCaught, 'Should have caught error for uninitialized domain');
    fprintf('  ✓ Correctly throws error for uninitialized domain\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 7: Access joint domain grids and utilities
fprintf('Test 7: Access joint domain grids and utilities...\n');

try
    [V, F] = icosphere(1);
    B = bct.bct.fromMesh(V, F);
    B = B.computeEigenbasis(20);
    
    t = linspace(0, 1, 30)';
    B.Time = bct.Time(t, 30);
    
    % Create joint domain
    B = B.createJoint('Lambda', 'Time');
    
    % Access grids
    lambda_grid = B.Joint.A_grid;
    time_grid = B.Joint.B_grid;
    
    % Verify grid sizes
    sz = B.Joint.N;
    assert(isequal(size(lambda_grid), sz), 'A_grid size should match');
    assert(isequal(size(time_grid), sz), 'B_grid size should match');
    fprintf('  ✓ Accessed A_grid: [%d×%d]\n', size(lambda_grid));
    fprintf('  ✓ Accessed B_grid: [%d×%d]\n', size(time_grid));
    
    % Test reshape/flatten
    x = (1:B.Joint.numel())';
    X = B.Joint.reshape2D(x);
    x_back = B.Joint.flatten(X);
    assert(isequal(x, x_back), 'Reshape/flatten roundtrip should be exact');
    fprintf('  ✓ Reshape and flatten utilities work correctly\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 8: Update joint domain when constituent changes
fprintf('Test 8: Update joint domain when constituent changes...\n');

try
    [V, F] = icosphere(1);
    B = bct.bct.fromMesh(V, F);
    B = B.computeEigenbasis(30);
    
    t = linspace(0, 1, 40)';
    B.Time = bct.Time(t, 40);
    
    % Create joint domain
    B = B.createJoint('Lambda', 'Time');
    
    % Initial size
    sz1 = B.Joint.N;
    fprintf('  ✓ Initial joint size: [%d×%d]\n', sz1(1), sz1(2));
    
    % Change Lambda eigenvalues
    B.Lambda.lambda = (1:10)';  % Reduce to 10 modes
    
    % Recreate joint domain
    B = B.createJoint('Lambda', 'Time');
    
    % New size
    sz2 = B.Joint.N;
    fprintf('  ✓ Updated joint size: [%d×%d]\n', sz2(1), sz2(2));
    
    % Verify size changed
    assert(sz2(1) == 10, 'First dimension should be 10');
    assert(sz2(2) == 40, 'Second dimension should be 40');
    fprintf('  ✓ Joint domain updates correctly with constituent changes\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('═══════════════════════════════════════════════════════════\n');
fprintf(' ✓ All tests passed!\n');
fprintf('═══════════════════════════════════════════════════════════\n\n');

fprintf('bct.createJoint method verified:\n');
fprintf('  • Lambda×Omega joint domain creation\n');
fprintf('  • Manifold×Time joint domain creation\n');
fprintf('  • Time×Omega joint domain creation\n');
fprintf('  • Lambda×Time joint domain creation\n');
fprintf('  • Error handling for invalid domain names\n');
fprintf('  • Error handling for uninitialized domains\n');
fprintf('  • Access to joint grids and utilities\n');
fprintf('  • Joint domain updates with constituent changes\n\n');

fprintf('Usage pattern:\n');
fprintf('  B = bct.bct.fromMesh(V, F);\n');
fprintf('  B = B.computeEigenbasis(100);\n');
fprintf('  B.Time = bct.Time(t, fs);\n');
fprintf('  B.Omega = B.Time.dual;\n');
fprintf('  B = B.createJoint(''Lambda'', ''Omega'');\n');
fprintf('  % Now access: B.Joint.A_grid, B.Joint.B_grid, etc.\n\n');

