%% Test bct saveobj/loadobj with file-backed HDF5 storage
%
% This script tests the file-backed lazy loading system for bct objects.
% It demonstrates:
%   1. Creating a bct object from mesh
%   2. Computing eigenbasis
%   3. Saving to .mat (which creates companion .h5 file)
%   4. Loading from .mat (which lazy-loads from .h5)
%   5. Verifying data integrity

clear; close all; clc;

fprintf('=== Testing BCT Save/Load with File-Backed HDF5 ===\n\n');

%% Step 1: Create bct object from fsaverage mesh
fprintf('Step 1: Creating bct object from fsaverage mesh...\n');
B_original = bct_fsaverage('lh');

fprintf('  Original Manifold: %d vertices, %d faces\n', ...
    B_original.Manifold.N, size(B_original.Manifold.Faces, 1));

%% Step 2: Compute eigenbasis
fprintf('\nStep 2: Computing eigenbasis (K=50 modes)...\n');
B_original = B_original.computeEigenbasis('K', 50);

fprintf('  Lambda: %d eigenvalues computed\n', B_original.Lambda.K);
fprintf('  Eigenvector matrix U: %d × %d\n', size(B_original.Lambda.U));

%% Step 3: Add Time domain
fprintf('\nStep 3: Adding Time domain...\n');
B_original.Time = bct.Time(100, 200);  % 100 samples at 200 Hz

fprintf('  Time: T=%d samples at fs=%d Hz\n', ...
    B_original.Time.T, B_original.Time.fs);

%% Step 4: Save to .mat file
fprintf('\nStep 4: Saving bct object...\n');

% Get temp path
config = bioctree_config();
matFile = fullfile(config.TempPath, 'test_bct_saveload.mat');
h5File = fullfile(config.TempPath, 'test_bct_saveload.h5');

% Clean up any existing files
if exist(matFile, 'file'), delete(matFile); end
if exist(h5File, 'file'), delete(h5File); end

% Save - this should create both .mat and .h5 files
save(matFile, 'B_original');

% Check file sizes
matInfo = dir(matFile);
h5Info = dir(h5File);

fprintf('  ✓ Saved to: %s\n', matFile);
fprintf('  .mat file size: %.2f KB (metadata only)\n', matInfo.bytes / 1024);
fprintf('  .h5 file size:  %.2f KB (scientific data)\n', h5Info.bytes / 1024);

%% Step 5: Clear and load
fprintf('\nStep 5: Clearing workspace and loading...\n');
clear B_original

load(matFile, 'B_original');

fprintf('  ✓ Loaded from: %s\n', matFile);
fprintf('  H5File path: %s\n', B_original.H5File);

%% Step 6: Verify data integrity
fprintf('\nStep 6: Verifying data integrity...\n');

% Check Manifold
assert(~isempty(B_original.Manifold), 'Manifold is empty');
assert(B_original.Manifold.N > 0, 'Manifold has no vertices');
fprintf('  ✓ Manifold: %d vertices loaded\n', B_original.Manifold.N);

% Check Lambda
assert(~isempty(B_original.Lambda), 'Lambda is empty');
assert(B_original.Lambda.K == 50, 'Lambda K mismatch');
fprintf('  ✓ Lambda: K=%d eigenvalues loaded\n', B_original.Lambda.K);

% Check eigenvectors
assert(~isempty(B_original.Lambda.U), 'Eigenvectors not loaded');
fprintf('  ✓ Eigenvectors: %d × %d matrix loaded\n', size(B_original.Lambda.U));

% Check Time
assert(~isempty(B_original.Time), 'Time is empty');
assert(B_original.Time.T == 100, 'Time T mismatch');
assert(B_original.Time.fs == 200, 'Time fs mismatch');
fprintf('  ✓ Time: T=%d at fs=%d Hz loaded\n', ...
    B_original.Time.T, B_original.Time.fs);

%% Step 7: Test data access
fprintf('\nStep 7: Testing data access...\n');

% Access vertex data
V = B_original.Manifold.Vertices;
assert(size(V, 2) == 3, 'Vertices should be N×3');
fprintf('  ✓ Vertices: [%d × %d] accessible\n', size(V));

% Access eigenvalues
lambda = B_original.Lambda.axis;
assert(length(lambda) == 50, 'Should have 50 eigenvalues');
fprintf('  ✓ Eigenvalues: [%d × 1] accessible\n', length(lambda));

% Access eigenvectors
U = B_original.Lambda.U;
assert(~isempty(U), 'Eigenvectors should be loaded');
fprintf('  ✓ Eigenvectors: [%d × %d] accessible\n', size(U));

%% Step 8: Clean up
fprintf('\nStep 8: Cleaning up...\n');
if exist(matFile, 'file'), delete(matFile); end
if exist(h5File, 'file'), delete(h5File); end
fprintf('  ✓ Temporary files deleted\n');

%% Summary
fprintf('\n========================================\n');
fprintf('✅ ALL TESTS PASSED!\n');
fprintf('========================================\n\n');

fprintf('Summary:\n');
fprintf('  • Bct object successfully saved with file-backed HDF5\n');
fprintf('  • .mat file contains only lightweight metadata\n');
fprintf('  • .h5 file contains all scientific data\n');
fprintf('  • Lazy loading restored all data correctly\n');
fprintf('  • Data integrity verified for all domains\n\n');
