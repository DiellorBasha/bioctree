%% Test Filter Workflow - Verify filter design works without eigenvalues
%
% This script tests that:
% 1. Spatial filters can be designed without calling meshFourier first
% 2. JointFilters can be designed without eigenvalues
% 3. Eigenvalues are only computed during Synthesize/synthesis
%
% Author: BioCTree Project
% Date: 2025-11-19

clear; clc;

%% Setup - Create bct object with Manifold and Time
fprintf('=== Test 1: Spatial Filter Design (no eigenvalues) ===\n');

% Create simple test mesh
V = randn(100, 3);  % 100 vertices
F = delaunay(V(:,1), V(:,2));  % Triangulate

% Create bct object
B = bct.bct();
B.Manifold = bct.manifold.Manifold(V, F);
B.Time = bct.manifold.Time(1000, 250);  % 1000 samples @ 250 Hz

% Verify NO eigenvalues computed yet
assert(isempty(B.Manifold.Eigenvalues), 'Eigenvalues should be empty initially');
fprintf('✓ Manifold created without eigenvalues\n');

%% Test 2: Design spatial filter (should work without eigenvalues)
fprintf('\n=== Test 2: Design Spatial Filter ===\n');

try
    % Design filter using wavelength range
    filt1 = B.designFilter([10, 50], 'wavelength', 'band', 'taper', 'hann');
    fprintf('✓ Filter designed successfully without eigenvalues\n');
    
    % Verify filter has lambda_support but NOT g_lambda yet
    assert(~isempty(filt1.lambda_support), 'lambda_support should be populated');
    assert(~isempty(filt1.g_support), 'g_support should be populated');
    fprintf('✓ Filter kernel defined on lambda_support\n');
    
    % Verify eigenvalues still not computed
    assert(isempty(B.Manifold.Eigenvalues), 'Eigenvalues should still be empty after design');
    fprintf('✓ No eigenvalues computed during filter design\n');
    
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 3: Design JointFilter (should work without eigenvalues)
fprintf('\n=== Test 3: Design Joint Filter ===\n');

try
    % Design diffusion filter
    filt2 = B.designJointFilter([10, 50], 'wavelength', [8, 12], 'frequency', ...
        'type', 'diffusion', 'label', 'alpha_diffusion');
    fprintf('✓ JointFilter designed successfully\n');
    
    % Verify filter has kernels defined
    assert(~isempty(filt2.psi_mesh), 'Spatial kernel should be defined');
    assert(~isempty(filt2.phi_time), 'Temporal kernel should be defined');
    assert(~isempty(filt2.K_dispersion), 'Dispersion kernel should be defined');
    fprintf('✓ Joint filter kernels defined\n');
    
    % Verify eigenvalues STILL not computed
    assert(isempty(B.Manifold.Eigenvalues), 'Eigenvalues should still be empty');
    fprintf('✓ No eigenvalues computed during joint filter design\n');
    
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 4: Synthesize should compute eigenvalues
fprintf('\n=== Test 4: Synthesize (should compute eigenvalues) ===\n');

try
    % Synthesize spatial filter
    A_kl = B.Synthesize('alpha_diffusion', 'numModes', 50);
    fprintf('✓ Synthesize completed\n');
    
    % NOW eigenvalues should be computed
    assert(~isempty(B.Manifold.Eigenvalues), 'Eigenvalues should be computed during Synthesize');
    fprintf('✓ Eigenvalues computed during Synthesize (as expected)\n');
    fprintf('  Number of modes: %d\n', length(B.Manifold.Eigenvalues));
    
    % Verify SpectralGrid created
    assert(~isempty(B.SpectralGrid.lambda_grid), 'SpectralGrid should be built');
    fprintf('✓ SpectralGrid built: %d modes × %d time points\n', ...
        size(B.SpectralGrid.lambda_grid, 1), size(B.SpectralGrid.lambda_grid, 2));
    
    % Verify A_kl has correct size
    expected_size = [length(B.SpectralGrid.lambda_band), length(B.SpectralGrid.t)];
    assert(all(size(A_kl) == expected_size), 'A_kl should match spectral grid size');
    fprintf('✓ Spectral coefficients A_kl: %d × %d\n', size(A_kl, 1), size(A_kl, 2));
    
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 5: Generate signal
fprintf('\n=== Test 5: Generate Signal ===\n');

try
    sig = B.Generate();
    fprintf('✓ Signal generated\n');
    
    % Verify signal size [N × T]
    expected_size = [B.Manifold.N, B.Time.T];
    assert(all(size(sig) == expected_size), 'Signal should be [N × T]');
    fprintf('✓ Signal size: %d vertices × %d time points\n', size(sig, 1), size(sig, 2));
    
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('\n=== All Tests Passed! ===\n');
fprintf('Summary:\n');
fprintf('  1. ✓ Spatial filters can be designed without eigenvalues\n');
fprintf('  2. ✓ Joint filters can be designed without eigenvalues\n');
fprintf('  3. ✓ Eigenvalues computed during Synthesize (lazy evaluation)\n');
fprintf('  4. ✓ Signal generation works correctly\n');
fprintf('\nWorkflow verified: designFilter → Synthesize → Generate\n');

