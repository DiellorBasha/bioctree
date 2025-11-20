% Test script for Filterbank integration with Bct class
% Tests filter design using different spectral quantities

%% Setup
clear; close all; clc;

% Load an existing Bct object or create a minimal test one
fprintf('=== Testing Bct Filterbank Integration ===\n\n');

% For this test, we'll assume you have a Bct object already saved
% If not, you'll need to create one with a proper Manifold first
% Example: B = bct('path/to/your/data.h5');

% Try to find an example file
example_files = dir('**/*.h5');
if isempty(example_files)
    fprintf('No .h5 files found. Please create a Bct object first.\n');
    fprintf('Example:\n');
    fprintf('  B = bct();\n');
    fprintf('  B.Manifold = bct.manifold.Manifold(vertices, faces);\n');
    return;
end

fprintf('Found example file: %s\n', example_files(1).name);
try
    B = bct(fullfile(example_files(1).folder, example_files(1).name));
catch ME
    fprintf('Error loading file: %s\n', ME.message);
    fprintf('Please ensure you have a valid Bct object with Manifold.\n');
    return;
end

% Check that Manifold exists
if isempty(B.Manifold)
    fprintf('Manifold not set. Please set up Manifold first.\n');
    return;
end

fprintf('Loaded Bct object: N=%d nodes\n\n', B.N);

%% Test 1: Design spatial filter using wavelength
fprintf('Test 1: Design bandpass filter using wavelength (10-50 mm)\n');
try
    filt1 = B.designFilter([10, 50], 'wavelength', 'band', ...
        'label', 'alpha_spatial', 'taper', 'hann');
    fprintf('  ✓ Successfully designed filter\n');
    fprintf('  Lambda band: [%.4f, %.4f]\n', filt1.lambda_band(1), filt1.lambda_band(2));
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

%% Test 2: Design spatial filter using wavenumber
fprintf('Test 2: Design filter using wavenumber (0.1-1.0 rad/mm)\n');
try
    filt2 = B.designFilter([0.1, 1.0], 'wavenumber', 'band', ...
        'label', 'beta_spatial');
    fprintf('  ✓ Successfully designed filter\n');
    fprintf('  Lambda band: [%.4f, %.4f]\n', filt2.lambda_band(1), filt2.lambda_band(2));
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

%% Test 3: Design heat diffusion filter using lambda directly
fprintf('Test 3: Design heat diffusion filter using lambda (0.01-0.5)\n');
try
    filt3 = B.designFilter([0.01, 0.5], 'lambda', 'heat', ...
        'label', 'diffusion', 'time', 1.0);
    fprintf('  ✓ Successfully designed filter\n');
    fprintf('  Lambda band: [%.4f, %.4f]\n', filt3.lambda_band(1), filt3.lambda_band(2));
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

%% Test 4: List all filters in filterbank
fprintf('Test 4: List all filters in filterbank\n');
try
    B.listFilters();
    fprintf('  ✓ Successfully listed filters\n');
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

%% Test 5: Retrieve filter by label
fprintf('Test 5: Retrieve filter by label "alpha_spatial"\n');
try
    filt_retrieved = B.getFilter('alpha_spatial');
    fprintf('  ✓ Successfully retrieved filter\n');
    fprintf('  Lambda band: [%.4f, %.4f]\n', ...
        filt_retrieved.lambda_band(1), filt_retrieved.lambda_band(2));
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

%% Test 6: Retrieve filter by index
fprintf('Test 6: Retrieve filter by index 2\n');
try
    filt_idx = B.getFilter(2);
    fprintf('  ✓ Successfully retrieved filter\n');
    if isfield(filt_idx.KernelParams, 'label')
        fprintf('  Label: %s\n', filt_idx.KernelParams.label);
    end
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

%% Test 7: Test joint filter design (if Time is available)
if ~isempty(B.Time)
    fprintf('Test 7: Design joint mesh-time diffusion filter\n');
    try
        joint_filt = B.designJointFilter([10, 50], 'wavelength', ...
            [8, 12], 'frequency', ...
            'type', 'diffusion', 'label', 'alpha_diffusion');
        fprintf('  ✓ Successfully designed joint filter\n');
    catch ME
        fprintf('  ✗ Error: %s\n', ME.message);
    end
    fprintf('\n');
else
    fprintf('Test 7: Skipped (Time not set)\n\n');
end

%% Test 8: Remove filter by label
fprintf('Test 8: Remove filter "beta_spatial"\n');
try
    B.removeFilter('beta_spatial');
    fprintf('  ✓ Successfully removed filter\n');
    B.listFilters();
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

%% Test 9: Clear filterbank
fprintf('Test 9: Clear entire filterbank\n');
try
    B.clearFilterbank();
    fprintf('  ✓ Successfully cleared filterbank\n');
    B.listFilters();
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end
fprintf('\n');

fprintf('=== Testing Complete ===\n');
