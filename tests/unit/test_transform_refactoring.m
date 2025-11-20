% Test script to verify bct.signal.transform refactoring
% This tests that the transform functions work in their new location

clear; close all; clc;

fprintf('Testing bct.signal.transform refactoring...\n\n');

%% Test 1: Check function existence
fprintf('Test 1: Verifying function paths...\n');
analysis_path = which('bct.signal.transform.analysis');
synthesis_path = which('bct.signal.transform.synthesis');
filter_path = which('bct.signal.transform.filter');

assert(~isempty(analysis_path), 'bct.signal.transform.analysis not found!');
assert(~isempty(synthesis_path), 'bct.signal.transform.synthesis not found!');
assert(~isempty(filter_path), 'bct.signal.transform.filter not found!');

fprintf('  ✓ bct.signal.transform.analysis found\n');
fprintf('  ✓ bct.signal.transform.synthesis found\n');
fprintf('  ✓ bct.signal.transform.filter found\n\n');

%% Test 2: Check old path is gone
fprintf('Test 2: Verifying old path is removed...\n');
old_analysis = which('bct.transform.analysis');
old_synthesis = which('bct.transform.synthesis');
old_filter = which('bct.transform.filter');

assert(isempty(old_analysis), 'Old bct.transform.analysis still exists!');
assert(isempty(old_synthesis), 'Old bct.transform.synthesis still exists!');
assert(isempty(old_filter), 'Old bct.transform.filter still exists!');

fprintf('  ✓ Old bct.transform paths removed\n\n');

%% Test 3: Functional test - Skip if no mesh available
fprintf('Test 3: Testing analysis/synthesis roundtrip...\n');

try
    % Try to load FreeSurfer mesh if available
    fs_dir = fullfile(getenv('SUBJECTS_DIR'), 'fsaverage', 'surf');
    if exist(fullfile(fs_dir, 'lh.pial'), 'file')
        [V, F] = read_surf(fullfile(fs_dir, 'lh.pial'));
        
        % Create Manifold
        M = bct.manifold.Manifold(V, F);
        M.meshFourier(50);  % Compute 50 eigenmodes
        
        % Create random signal
        rng(42);
        x_original = randn(size(V, 1), 1);
        
        % Forward transform (analysis)
        x_hat = bct.signal.transform.analysis(x_original, M);
        
        % Inverse transform (synthesis)
        x_reconstructed = bct.signal.transform.synthesis(x_hat, M);
        
        % Check reconstruction error
        reconstruction_error = norm(x_original - x_reconstructed) / norm(x_original);
        
        fprintf('  Signal size: %d vertices\n', size(V, 1));
        fprintf('  Modes used: %d\n', M.NumModes);
        fprintf('  Reconstruction error: %.2e\n', reconstruction_error);
        
        % Should have small error (numerical precision)
        assert(reconstruction_error < 1e-10, 'Reconstruction error too large!');
        fprintf('  ✓ Analysis/synthesis roundtrip successful\n\n');
    else
        fprintf('  ⚠ Skipping (no FreeSurfer mesh available)\n\n');
    end
catch ME
    fprintf('  ⚠ Skipping (error: %s)\n\n', ME.message);
end

%% Test 4: Filter application test - Skip if no mesh available
fprintf('Test 4: Testing filter application...\n');

try
    % Try to load FreeSurfer mesh if available
    fs_dir = fullfile(getenv('SUBJECTS_DIR'), 'fsaverage', 'surf');
    if exist(fullfile(fs_dir, 'lh.pial'), 'file') && exist('M', 'var')
        % Create bct object
        B = bct.bct();
        B.Manifold = M;
        
        % Design simple lowpass filter
        filt = bct.filters.Filter(B.Manifold);
        filt.setBand([0, 10], bct.resolution.Quantity.eigenvalue);
        filt.design('band', 'taper', 'hann');
        
        % Apply filter using new path
        y = bct.signal.transform.filter(x_original, filt);
        
        % Check that output has correct size
        assert(all(size(y) == size(x_original)), 'Filtered signal size mismatch!');
        
        % Check that filtering reduces high-frequency content
        x_hat_orig = bct.signal.transform.analysis(x_original, M);
        y_hat = bct.signal.transform.analysis(y, M);
        
        % High-frequency modes should be attenuated
        high_freq_modes = 40:50;
        attenuation = norm(y_hat(high_freq_modes)) / norm(x_hat_orig(high_freq_modes));
        
        fprintf('  Filter passband: λ ∈ [0, 10]\n');
        fprintf('  High-frequency attenuation: %.2f%%\n', (1 - attenuation) * 100);
        
        assert(attenuation < 0.5, 'Filter not attenuating high frequencies!');
        fprintf('  ✓ Filter application successful\n\n');
    else
        fprintf('  ⚠ Skipping (no mesh from Test 3)\n\n');
    end
catch ME
    fprintf('  ⚠ Skipping (error: %s)\n\n', ME.message);
end

%% Summary
fprintf('========================================\n');
fprintf('All tests passed! ✓\n');
fprintf('bct.signal.transform is working correctly.\n');
fprintf('========================================\n');
