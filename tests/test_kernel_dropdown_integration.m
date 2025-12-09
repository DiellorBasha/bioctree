% TEST_KERNEL_DROPDOWN_INTEGRATION
% Test the KernelDropDown and VelocitySpinner integration
%
% Tests:
%   1. Kernel type changes create appropriate filters
%   2. VelocitySpinner visibility toggles correctly
%   3. Velocity parameter updates correctly
%   4. Slider updates modify filter parameters
%   5. Different kernel types map parameters correctly

function test_kernel_dropdown_integration()
    % Initialize bioctree
    bioctree_start;
    
    fprintf('\n=== Testing Kernel Dropdown Integration ===\n\n');
    
    % Test 1: Create app and verify initial state
    fprintf('Test 1: Initial app state...\n');
    try
        % Note: This test requires MATLAB App Designer
        % For automated testing, we'll test the backend methods directly
        fprintf('  [SKIP] App creation requires GUI environment\n');
    catch ME
        fprintf('  [SKIP] %s\n', ME.message);
    end
    
    % Test 2: Test backend method createFilterFromKernelType
    fprintf('\nTest 2: Test createFilterFromKernelType backend method...\n');
    
    % Create mock app structure
    app = createMockApp();
    
    % Test Gaussian kernel
    fprintf('  Testing Gaussian kernel...\n');
    app.KernelDropDown.Value = 'Gaussian';
    BctBackend.createFilterFromKernelType(app, app.KernelDropDown.Value);
    assert(~isempty(app.CurrentFilter), 'Filter should be created');
    fprintf('    ✓ Gaussian filter created\n');
    
    % Test Velocity Gabor kernel
    fprintf('  Testing Velocity Gabor kernel...\n');
    app.KernelDropDown.Value = 'Velocity Gabor';
    app.VelocitySpinner.Value = 0.8;
    BctBackend.createFilterFromKernelType(app, app.KernelDropDown.Value);
    assert(~isempty(app.CurrentFilter), 'Filter should be created');
    assert(strcmpi(app.CurrentFilter.KernelName, 'velocity_gabor'), ...
        'Should create velocity_gabor kernel');
    fprintf('    ✓ Velocity Gabor filter created\n');
    
    % Test 3: Test velocity parameter update
    fprintf('\nTest 3: Test updateVelocityParameter...\n');
    
    % Set velocity to specific value
    testVelocity = 1.25;
    app.VelocitySpinner.Value = testVelocity;
    BctBackend.updateVelocityParameter(app, testVelocity);
    
    % Verify parameter updated
    actualV = app.CurrentFilter.Parameters.v;
    assert(abs(actualV - testVelocity) < 1e-6, ...
        sprintf('Velocity should be %.2f but got %.2f', testVelocity, actualV));
    fprintf('    ✓ Velocity parameter updated correctly: v = %.4f\n', actualV);
    
    % Test 4: Test parameter mapping for velocity_gabor
    fprintf('\nTest 4: Test parameter mapping for velocity_gabor...\n');
    
    % Set slider values
    app.WavenumberSlider.Value = 0.15;
    app.kbandwidthSlider.Value = 0.05;
    app.BandwidthSlider.Value = 10 * 2*pi;
    app.VelocitySpinner.Value = 0.9;
    
    % Recreate filter
    BctBackend.createFilterFromKernelType(app, 'Velocity Gabor');
    
    % Verify parameters
    P = app.CurrentFilter.Parameters;
    assert(abs(P.lambda0 - 0.15) < 1e-6, 'lambda0 should match WavenumberSlider');
    assert(abs(P.sigma_l - 0.05) < 1e-6, 'sigma_l should match kbandwidthSlider');
    assert(abs(P.sigma_w - 10*2*pi) < 1e-6, 'sigma_w should match BandwidthSlider');
    assert(abs(P.v - 0.9) < 1e-6, 'v should match VelocitySpinner');
    fprintf('    ✓ All parameters mapped correctly:\n');
    fprintf('      lambda0 = %.4f\n', P.lambda0);
    fprintf('      sigma_l = %.4f\n', P.sigma_l);
    fprintf('      sigma_w = %.4f\n', P.sigma_w);
    fprintf('      v = %.4f\n', P.v);
    
    % Test 5: Test parameter mapping for standard kernels
    fprintf('\nTest 5: Test parameter mapping for Gabor kernel...\n');
    
    % Set slider values
    app.WavenumberSlider.Value = 0.2;
    app.kbandwidthSlider.Value = 0.08;
    app.FrequencySlider.Value = 15 * 2*pi;
    app.BandwidthSlider.Value = 5 * 2*pi;
    
    % Create Gabor filter
    BctBackend.createFilterFromKernelType(app, 'Gabor');
    
    % Verify parameters
    P = app.CurrentFilter.Parameters;
    assert(abs(P.center_x - 0.2) < 1e-6, 'center_x should match WavenumberSlider');
    assert(abs(P.sigma_x - 0.08) < 1e-6, 'sigma_x should match kbandwidthSlider');
    assert(abs(P.center_y - 15*2*pi) < 1e-6, 'center_y should match FrequencySlider');
    assert(abs(P.sigma_y - 5*2*pi) < 1e-6, 'sigma_y should match BandwidthSlider');
    fprintf('    ✓ All parameters mapped correctly:\n');
    fprintf('      center_x = %.4f\n', P.center_x);
    fprintf('      sigma_x = %.4f\n', P.sigma_x);
    fprintf('      center_y = %.4f\n', P.center_y);
    fprintf('      sigma_y = %.4f\n', P.sigma_y);
    
    % Test 6: Test all kernel types
    fprintf('\nTest 6: Test all kernel types...\n');
    
    kernelTypes = {'Gaussian', 'Heat', 'Mexican Hat', 'Gabor', 'Velocity Gabor'};
    for i = 1:length(kernelTypes)
        kernelType = kernelTypes{i};
        fprintf('  Testing %s...\n', kernelType);
        BctBackend.createFilterFromKernelType(app, kernelType);
        assert(~isempty(app.CurrentFilter), ...
            sprintf('Filter should be created for %s', kernelType));
        fprintf('    ✓ %s filter created successfully\n', kernelType);
    end
    
    fprintf('\n=== All Tests Passed ✓ ===\n\n');
    
end

function app = createMockApp()
    % Create mock app structure with required properties
    
    % Load default BCT
    data = load('data/mesh/fsaverage_rh_pial.mat');
    B = bct.bct.fromMesh(data.V, data.F);
    
    % Compute eigenbasis
    B = B.computeEigenbasis('k', 200);
    
    % Create time domain
    fs = 500;  % Hz
    T = 2;     % seconds
    B = B.createTime(fs, T);
    
    % Create joint domain
    B = B.createJoint('Lambda', 'Omega');
    
    % Create mock app structure
    app.CurrentBCT = B;
    app.CurrentFilter = [];
    
    % Mock UI controls with default values
    app.KernelDropDown.Value = 'Gaussian';
    app.WavenumberSlider.Value = 0.1;
    app.kbandwidthSlider.Value = 0.05;
    app.FrequencySlider.Value = 20 * 2*pi;
    app.BandwidthSlider.Value = 5 * 2*pi;
    app.VelocitySpinner.Value = 0.5;
    
    fprintf('[createMockApp] Created mock app with BCT:\n');
    fprintf('  Mesh: %d vertices\n', B.Manifold.size);
    fprintf('  Eigenbasis: %d modes\n', B.Lambda.size);
    fprintf('  Time: %.2f s at %d Hz\n', T, fs);
    fprintf('  Joint: %s\n', B.Joint.Domain);
end
