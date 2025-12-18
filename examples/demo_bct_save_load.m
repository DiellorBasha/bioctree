%% Quick reference for saving and loading bct objects
%
% This script demonstrates the recommended ways to save and load bct objects
% with file-backed HDF5 storage.

%% METHOD 1: Using bct.save() (RECOMMENDED)
% This automatically sets the H5File path to match the .mat file location

% Create object
fs6 = bct.io.import.mesh('C:\path\to\mesh.pial');
fs6 = fs6.computeEigenbasis('K', 600);

% Save - creates both .mat and .h5 in same directory
bct.save('data/bct/fs6_rh_pial.mat', fs6);
% Creates:
%   data/bct/fs6_rh_pial.mat  (metadata only)
%   data/bct/fs6_rh_pial.h5   (scientific data)

% Load
clear fs6
load('data/bct/fs6_rh_pial.mat', 'fs6');

%% METHOD 2: Set H5File manually, then use save()
% Gives you full control over file locations

% Create object
fs6 = bct.io.import.mesh('C:\path\to\mesh.pial');
fs6 = fs6.computeEigenbasis('K', 600);

% Set H5File path explicitly
fs6.H5File = 'data/bct/fs6_rh_pial.h5';

% Save with MATLAB's save
save('data/bct/fs6_rh_pial.mat', 'fs6');

% Load
clear fs6
load('data/bct/fs6_rh_pial.mat', 'fs6');

%% METHOD 3: Using save() without setting H5File (NOT RECOMMENDED)
% This creates H5 file in current directory with timestamp

% Create object
fs6 = bct.io.import.mesh('C:\path\to\mesh.pial');
fs6 = fs6.computeEigenbasis('K', 600);

% Save - H5File is auto-generated in current directory
save('data/bct/fs6_rh_pial.mat', 'fs6');
% Creates:
%   data/bct/fs6_rh_pial.mat
%   ./bct_20251214_143052.h5  (in current directory with timestamp)

%% VERIFYING SAVED FILES

% Check what was saved
dir('data/bct/fs6_rh_pial.*')

% Load and check
load('data/bct/fs6_rh_pial.mat', 'fs6');
fprintf('H5 file location: %s\n', fs6.H5File);
fprintf('Manifold: %d vertices\n', fs6.Manifold.N);
fprintf('Lambda: %d eigenmodes\n', fs6.Lambda.K);

%% MOVING FILES

% If you need to move the .mat and .h5 files together:
% 1. Move both files to the new location
% 2. After loading, update the H5File path if needed

% Load from old location
load('data/bct/fs6_rh_pial.mat', 'fs6');

% Update path if H5 file was moved
fs6.H5File = 'new_location/fs6_rh_pial.h5';

% Re-save in new location
bct.save('new_location/fs6_rh_pial.mat', fs6);

%% CHECKING FILE SIZES

% The .mat file should be small (metadata only)
matInfo = dir('data/bct/fs6_rh_pial.mat');
h5Info = dir('data/bct/fs6_rh_pial.h5');

fprintf('\nFile sizes:\n');
fprintf('  .mat: %.2f KB (metadata)\n', matInfo.bytes / 1024);
fprintf('  .h5:  %.2f MB (scientific data)\n', h5Info.bytes / 1024^2);

%% SUMMARY

% RECOMMENDED: Use bct.save() for automatic file management
% bct.save('path/to/file.mat', obj)
%
% This ensures:
%   ✓ .mat and .h5 files in same directory
%   ✓ Matching filenames
%   ✓ No orphaned temp files
%   ✓ Easy file management
