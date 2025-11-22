%% Test Resolution Property
% Test the new Resolution dependent property in Manifold class

clear all;
close all;

% Add toolbox to path
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));
addpath(fullfile(root, 'external'));

fprintf('=== Testing Manifold.Resolution Property ===\n\n');

%% Test 1: Resolution property when no eigenvalues computed
fprintf('Test 1: Resolution with no eigenvalues...\n');

[V, F] = icosphere(3);
B = bct.bct.fromMesh(V, F);

R = B.Manifold.Resolution;

fprintf('  Resolution fields:\n');
fprintf('    lambda_max: %s\n', mat2str(R.lambda_max));
fprintf('    k: %s\n', mat2str(R.k));
fprintf('    freq: %s\n', mat2str(R.freq));
fprintf('    wavelength: %s\n', mat2str(R.wavelength));

assert(isempty(R.lambda_max), 'lambda_max should be empty');
assert(isempty(R.k), 'k should be empty');
assert(isempty(R.freq), 'freq should be empty');
assert(isempty(R.wavelength), 'wavelength should be empty');

fprintf('  ✓ Resolution returns empty fields when no eigenvalues\n\n');

%% Test 2: Resolution after computing Fourier basis
fprintf('Test 2: Resolution after manually setting eigenvalues...\n');

% Manually set eigenvalues to test the property
test_eigenvalues = linspace(0.1, 10, 100)';
B.Manifold.Eigenvalues = test_eigenvalues;
B.Manifold.NumModes = length(test_eigenvalues);

fprintf('  Set %d test eigenvalues\n', B.Manifold.NumModes);

R = B.Manifold.Resolution;

fprintf('  Resolution:\n');
fprintf('    lambda_max: %.6f\n', R.lambda_max);
fprintf('    k (wavenumber): %.6f rad/unit\n', R.k);
fprintf('    freq: %.6f cycles/unit\n', R.freq);
fprintf('    wavelength: %.6f units\n', R.wavelength);

% Verify values
assert(~isempty(R.lambda_max), 'lambda_max should not be empty');
assert(R.lambda_max == max(B.Manifold.Eigenvalues), 'lambda_max should match max eigenvalue');
assert(abs(R.k - sqrt(R.lambda_max)) < 1e-10, 'k should equal sqrt(lambda_max)');
assert(abs(R.freq - R.k/(2*pi)) < 1e-10, 'freq should equal k/(2*pi)');
assert(abs(R.wavelength - 1/R.freq) < 1e-10, 'wavelength should equal 1/freq');

fprintf('  ✓ Resolution computed correctly\n');
fprintf('  ✓ All conversions verified\n\n');

%% Test 3: Compare with bct.manifold.resolution function
fprintf('Test 3: Verify consistency with bct.manifold.resolution...\n');

R_prop = B.Manifold.Resolution;
R_func = bct.manifold.resolution(B.Manifold, 'manifold', 'basis');

fprintf('  Property resolution:\n');
fprintf('    lambda: %.6f\n', R_prop.lambda_max);
fprintf('    wavelength: %.6f\n', R_prop.wavelength);

fprintf('  Function resolution:\n');
fprintf('    lambda: %.6f\n', R_func.lambda);
fprintf('    wavelength: %.6f\n', R_func.wavelength);

assert(abs(R_prop.lambda_max - R_func.lambda) < 1e-10, 'lambda_max should match');
assert(abs(R_prop.k - R_func.k) < 1e-10, 'k should match');
assert(abs(R_prop.freq - R_func.freq) < 1e-10, 'freq should match');
assert(abs(R_prop.wavelength - R_func.wavelength) < 1e-10, 'wavelength should match');

fprintf('  ✓ Property matches function output\n\n');

%% Test 4: Resolution updates when more modes computed
fprintf('Test 4: Resolution updates with more eigenvalues...\n');

R1 = B.Manifold.Resolution;
fprintf('  Resolution with %d modes: wavelength = %.6f\n', ...
    B.Manifold.NumModes, R1.wavelength);

% Add more eigenvalues
test_eigenvalues2 = linspace(0.1, 20, 200)';
B.Manifold.Eigenvalues = test_eigenvalues2;
B.Manifold.NumModes = length(test_eigenvalues2);

R2 = B.Manifold.Resolution;
fprintf('  Resolution with %d modes: wavelength = %.6f\n', ...
    B.Manifold.NumModes, R2.wavelength);

assert(R2.lambda_max >= R1.lambda_max, 'lambda_max should increase or stay same');
assert(R2.wavelength <= R1.wavelength, 'wavelength should decrease or stay same');

fprintf('  ✓ Resolution updates correctly with more modes\n');
fprintf('  ✓ Wavelength decreased from %.6f to %.6f\n', R1.wavelength, R2.wavelength);

fprintf('\n');

%% Test 5: Real-world example with FreeSurfer mesh
fprintf('Test 5: Testing with FreeSurfer mesh (if available)...\n');

test_path = fullfile('test-data', 'freesurfer', 'fsaverage', 'surf', 'lh.pial');

if isfile(test_path)
    B_fs = bct.io.import.mesh(test_path);
    
    fprintf('  FreeSurfer mesh loaded: %d vertices\n', B_fs.Manifold.N);
    
    % Manually set test eigenvalues for FreeSurfer mesh
    test_eigenvalues_fs = linspace(0.001, 5, 600)';
    B_fs.Manifold.Eigenvalues = test_eigenvalues_fs;
    B_fs.Manifold.NumModes = length(test_eigenvalues_fs);
    
    R = B_fs.Manifold.Resolution;
    
    fprintf('  Resolution (units assumed to be mm):\n');
    fprintf('    lambda_max: %.6f [1/mm²]\n', R.lambda_max);
    fprintf('    k: %.6f [rad/mm]\n', R.k);
    fprintf('    freq: %.6f [cycles/mm]\n', R.freq);
    fprintf('    wavelength: %.3f mm\n', R.wavelength);
    fprintf('  ✓ FreeSurfer mesh resolution computed\n');
else
    fprintf('  Skipped: Test data not found\n');
end

fprintf('\n');

%% Summary
fprintf('=== Summary ===\n\n');

fprintf('Resolution Property Implementation:\n');
fprintf('  • Dependent property - computed on access\n');
fprintf('  • Returns struct with lambda_max, k, freq, wavelength\n');
fprintf('  • Uses bct.manifold.maxLambda internally\n');
fprintf('  • Returns empty fields when no eigenvalues computed\n');
fprintf('  • Updates automatically when more modes are computed\n\n');

fprintf('Usage:\n');
fprintf('  B.Manifold.meshFourier(600);\n');
fprintf('  R = B.Manifold.Resolution;\n');
fprintf('  fprintf(''Min wavelength: %%.3f mm\\n'', R.wavelength);\n\n');

fprintf('Fields:\n');
fprintf('  .lambda_max  - Maximum eigenvalue [1/units²]\n');
fprintf('  .k           - Angular wavenumber [rad/units]\n');
fprintf('  .freq        - Spatial frequency [cycles/units]\n');
fprintf('  .wavelength  - Minimum wavelength [units]\n\n');

fprintf('All tests passed! ✓\n\n');

