%% Test bct.resolution package
% This script tests the resolution package functionality including:
% - spectral function
% - spatial class
% - temporal class
% - Integration with Manifold

%% Setup
clear classes; clc;

% Load test mesh (use absolute path for batch mode)
bioctree_root = fileparts(fileparts(mfilename('fullpath')));
path = fullfile(bioctree_root, 'test-data', 'freesurfer', 'fsaverage', 'surf', 'lh.pial');
fprintf('Loading test mesh: %s\n', path);
B = bct.io.import.mesh(path);

%% Test 1: Manifold Resolution Auto-Computation
fprintf('\n=== Test 1: Manifold Resolution Auto-Computation ===\n');

% Check that Resolution was auto-computed during construction
assert(~isempty(B.Manifold.Resolution), 'Resolution should be auto-computed');
assert(isa(B.Manifold.Resolution, 'bct.resolution.spatial'), 'Resolution should be spatial object');

fprintf('✓ Resolution auto-computed on construction\n');
fprintf('  Type: %s\n', class(B.Manifold.Resolution));

%% Test 2: Resolution Properties
fprintf('\n=== Test 2: Resolution Properties ===\n');

% Check basic properties
res = B.Manifold.Resolution;
fprintf('Mesh Resolution:\n');
fprintf('  Wavelength (L_max):        %.2f %s\n', res.Wavelength, B.Manifold.Units);
fprintf('  Spatial Frequency (f_max): %.4f cycles/%s\n', res.SpatialFrequency, B.Manifold.Units);
fprintf('  Wavenumber (k_max):        %.4f rad/%s\n', res.Wavenumber, B.Manifold.Units);
fprintf('  Lambda (eigenvalue):       %.4f\n', res.lambda_max);

% Verify legacy properties still work
assert(abs(res.L_min - res.Wavelength) < 1e-10, 'L_min should equal Wavelength');
assert(abs(res.f_max - res.SpatialFrequency) < 1e-10, 'f_max should equal SpatialFrequency');
assert(abs(res.k_max - res.Wavenumber) < 1e-10, 'k_max should equal Wavenumber');

fprintf('✓ All resolution properties accessible\n');

%% Test 3: bct.resolution.spectral Function
fprintf('\n=== Test 3: bct.resolution.spectral Function ===\n');

lambda_test = 10.0;
spec = bct.resolution.spectral(lambda_test);

fprintf('Input: lambda_max = %.2f\n', lambda_test);
fprintf('Output:\n');
fprintf('  lambda_max: %.4f\n', spec.lambda_max);
fprintf('  k_max:      %.4f\n', spec.k_max);
fprintf('  f_max:      %.4f\n', spec.f_max);
fprintf('  L_min:      %.4f\n', spec.L_min);

% Verify relationships
expected_k = sqrt(lambda_test);
expected_f = expected_k / (2 * pi);
expected_L = 1 / expected_f;

assert(abs(spec.k_max - expected_k) < 1e-10, 'k_max = sqrt(lambda)');
assert(abs(spec.f_max - expected_f) < 1e-10, 'f_max = k / (2*pi)');
assert(abs(spec.L_min - expected_L) < 1e-10, 'L_min = 1 / f_max');

fprintf('✓ Spectral function computes correct relationships\n');

%% Test 4: Instrument Resolution
fprintf('\n=== Test 4: Instrument Resolution ===\n');

% Set instrument resolution using wavelength
res.setInstrumentResolution(25, bct.resolution.Quantity.wavelength, 'MEG');

fprintf('Instrument Resolution (MEG):\n');
fprintf('  Wavelength:        %.2f %s\n', res.L_min_instrument, B.Manifold.Units);
fprintf('  Spatial Frequency: %.4f cycles/%s\n', res.f_max_instrument, B.Manifold.Units);
fprintf('  Wavenumber:        %.4f rad/%s\n', res.k_max_instrument, B.Manifold.Units);
fprintf('  Instrument Name:   %s\n', res.InstrumentName);

% Verify instrument resolution was set correctly
assert(abs(res.L_min_instrument - 25) < 1e-10, 'Instrument wavelength should be 25');
assert(strcmp(res.InstrumentName, 'MEG'), 'Instrument name should be MEG');

fprintf('✓ Instrument resolution set successfully\n');

%% Test 5: Set Band for Filtering
fprintf('\n=== Test 5: Set Band for Filtering ===\n');

% Set a wavelength band
res.setBand([10, 50], bct.resolution.Quantity.wavelength);

fprintf('Band set to wavelengths: [10, 50] %s\n', B.Manifold.Units);
fprintf('  Lambda band: [%.4f, %.4f]\n', res.lambda_band(1), res.lambda_band(2));

% Verify band was converted correctly to lambda
% L = 2*pi/k, k = sqrt(lambda), so lambda = (2*pi/L)^2
expected_lambda_low = (2 * pi / 50)^2;  % Lower wavelength -> lower lambda
expected_lambda_high = (2 * pi / 10)^2; % Higher wavelength -> higher lambda

tolerance = 1e-6;
assert(abs(res.lambda_band(1) - expected_lambda_low) < tolerance, 'Lower lambda bound');
assert(abs(res.lambda_band(2) - expected_lambda_high) < tolerance, 'Upper lambda bound');

fprintf('✓ Band converted correctly from wavelength to lambda\n');

%% Test 6: Get Mode Indices
fprintf('\n=== Test 6: Get Mode Indices ===\n');

% Compute eigenmodes first
fprintf('Computing eigenmodes (k=100)...\n');
B.Manifold.meshFourier(100);

% Get modes in the band
mode_indices = res.getModeIndices();

fprintf('Modes in band [10, 50] %s:\n', B.Manifold.Units);
fprintf('  Number of modes: %d\n', length(mode_indices));
fprintf('  Mode range: [%d, %d]\n', min(mode_indices), max(mode_indices));

assert(~isempty(mode_indices), 'Should find modes in band');
assert(all(mode_indices > 0), 'Mode indices should be positive');

fprintf('✓ Mode indices retrieved successfully\n');

%% Test 7: Get Patch Size
fprintf('\n=== Test 7: Get Patch Size ===\n');

% Get patch size for current band (uses geometric mean of band limits)
patch_size_L = res.getPatchSize(bct.resolution.Quantity.wavelength);
patch_size_k = res.getPatchSize(bct.resolution.Quantity.k);

fprintf('Patch size for band [10, 50] %s:\n', B.Manifold.Units);
fprintf('  Wavelength: %.2f %s\n', patch_size_L, B.Manifold.Units);
fprintf('  Wavenumber: %.4f rad/%s\n', patch_size_k, B.Manifold.Units);

assert(patch_size_L > 0, 'Patch size should be positive');
% Geometric mean of [10, 50] is sqrt(10*50) = sqrt(500) ≈ 22.36
expected_L = sqrt(10 * 50);
assert(abs(patch_size_L - expected_L) < 0.1, 'Patch size should be geometric mean');

fprintf('✓ Patch size computed correctly\n');

%% Test 8: Temporal Resolution
fprintf('\n=== Test 8: Temporal Resolution ===\n');

% Create time dimension
fs = 1000; % Hz
duration = 2; % seconds
nTimePoints = fs * duration;  % Number of samples
T = bct.manifold.Time(nTimePoints, fs);

fprintf('Temporal Resolution:\n');
fprintf('  Sampling frequency: %.2f Hz\n', T.SamplingFrequency);
fprintf('  Nyquist frequency:  %.2f Hz\n', T.Resolution.f_nyquist);
fprintf('  Min period:         %.4f s\n', T.Resolution.T_min);
fprintf('  Max omega:          %.2f rad/s\n', T.Resolution.omega_max);

% Verify Nyquist frequency
assert(abs(T.Resolution.f_nyquist - fs/2) < 1e-10, 'Nyquist = fs/2');

fprintf('✓ Temporal resolution computed correctly\n');

%% Test 9: Temporal Band Selection
fprintf('\n=== Test 9: Temporal Band Selection ===\n');

% Set frequency band
T.Resolution.setBand([8, 12], bct.resolution.Quantity.frequency);

fprintf('Frequency band: [8, 12] Hz\n');
fprintf('  f_band: [%.1f, %.1f] Hz\n', ...
    T.Resolution.f_band(1), T.Resolution.f_band(2));

% Verify band was set
assert(~isempty(T.Resolution.f_band), 'Frequency band should be set');
assert(T.Resolution.f_band(1) == 8, 'Lower frequency bound');
assert(T.Resolution.f_band(2) == 12, 'Upper frequency bound');

fprintf('✓ Temporal band selection working\n');

%% Test 10: Units Enum
fprintf('\n=== Test 10: Units Enum ===\n');

% Test unit conversions
mm_to_si = bct.resolution.Units.mm.toSI();
cm_to_si = bct.resolution.Units.cm.toSI();
m_to_si = bct.resolution.Units.m.toSI();

fprintf('Unit conversions to SI:\n');
fprintf('  mm: %.4f\n', mm_to_si);
fprintf('  cm: %.4f\n', cm_to_si);
fprintf('  m:  %.4f\n', m_to_si);

assert(mm_to_si == 0.001, 'mm to SI');
assert(cm_to_si == 0.01, 'cm to SI');
assert(m_to_si == 1.0, 'm to SI');

fprintf('✓ Units enumeration working correctly\n');

%% Test 11: Quantity Enum
fprintf('\n=== Test 11: Quantity Enum ===\n');

% Test quantity symbols
fprintf('Quantity symbols:\n');
fprintf('  wavelength: %s\n', bct.resolution.Quantity.wavelength.symbol());
fprintf('  lambda:     %s\n', bct.resolution.Quantity.lambda.symbol());
fprintf('  k:          %s\n', bct.resolution.Quantity.k.symbol());
fprintf('  frequency:  %s\n', bct.resolution.Quantity.frequency.symbol());

assert(strcmp(bct.resolution.Quantity.wavelength.symbol(), 'L'), 'wavelength symbol');
assert(~isempty(bct.resolution.Quantity.lambda.symbol()), 'lambda symbol should not be empty');
assert(strcmp(bct.resolution.Quantity.k.symbol(), 'k'), 'k symbol');

fprintf('✓ Quantity enumeration working correctly\n');

%% Summary
fprintf('\n=== All Tests Passed ===\n');
fprintf('✓ Manifold auto-computes Resolution\n');
fprintf('✓ Resolution properties accessible\n');
fprintf('✓ spectral() function computes correctly\n');
fprintf('✓ Instrument resolution works\n');
fprintf('✓ Band selection and mode indices work\n');
fprintf('✓ Patch size computation works\n');
fprintf('✓ Temporal resolution works\n');
fprintf('✓ Temporal band selection works\n');
fprintf('✓ Units and Quantity enums work\n');
fprintf('\nbct.resolution package is fully functional!\n');

