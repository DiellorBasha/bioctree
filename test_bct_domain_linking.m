%% Test New bct Class with @Manifold and Domain Dual Linking
% Tests the updated bct class constructor using:
% - New bct.Manifold class (instead of bct.manifold.Manifold)
% - Automatic Lambda domain creation and linking
% - Automatic Time/Omega domain creation and linking
% - Domain.setDual() method for bidirectional dual linking

clear; clc;

% Add required paths
addpath('toolbox');
addpath('external');
addpath(genpath('external/gptoolbox/mesh'));

%% Test 1: Create bct from mesh (Manifold + Lambda linking)
fprintf('Test 1: bct.fromMesh with automatic Manifold↔Lambda dual linking...\n');

% Create simple icosphere
[V, F] = icosphere(2);  % 162 vertices, 320 faces
fprintf('  Created mesh: %d vertices, %d faces\n', size(V,1), size(F,1));

% Create bct object from mesh
B = bct.bct.fromMesh(V, F);

% Verify Manifold is created with new class
assert(isa(B.Manifold, 'bct.Manifold'), 'Manifold should be bct.Manifold class');
fprintf('  ✓ Manifold created with new bct.Manifold class\n');

% Verify Manifold properties
assert(isequal(size(B.Manifold.Vertices), [162, 3]), 'Vertices size mismatch');
assert(isequal(size(B.Manifold.Faces), [320, 3]), 'Faces size mismatch');
assert(~isempty(B.Manifold.Laplacian), 'Laplacian should be computed');
assert(~isempty(B.Manifold.MassMatrix), 'MassMatrix should be computed');
assert(~isempty(B.Manifold.CotangentMatrix), 'CotangentMatrix should be computed');
fprintf('  ✓ Manifold properties populated (Vertices, Faces, Laplacian, MassMatrix, CotangentMatrix)\n');

% Verify Lambda domain is created
assert(~isempty(B.Lambda), 'Lambda should be created');
assert(isa(B.Lambda, 'bct.Lambda'), 'Lambda should be bct.Lambda class');
fprintf('  ✓ Lambda domain created\n');

% Verify Lambda has placeholder eigenvalues
assert(~isempty(B.Lambda.lambda), 'Lambda should have eigenvalues');
assert(B.Lambda.K == 100, 'Lambda should have 100 placeholder modes');
fprintf('  ✓ Lambda initialized with %d placeholder eigenvalues\n', B.Lambda.K);

% Verify dual linking Manifold ↔ Lambda
assert(~isempty(B.Manifold.dual), 'Manifold.dual should be set');
assert(B.Manifold.dual == B.Lambda, 'Manifold.dual should point to Lambda');
assert(~isempty(B.Lambda.dual), 'Lambda.dual should be set');
assert(B.Lambda.dual == B.Manifold, 'Lambda.dual should point to Manifold');
fprintf('  ✓ Dual linking verified: Manifold ↔ Lambda\n');

% Verify estimated lambda_max
lambda_max_est = max(B.Lambda.lambda);
lambda_max_true = B.Manifold.estimateLambdaMax();
assert(abs(lambda_max_est - lambda_max_true) < 1e-6, 'Lambda max should match estimate');
fprintf('  ✓ Lambda range: [%.4f, %.4f] (estimated max: %.4f)\n', ...
    min(B.Lambda.lambda), max(B.Lambda.lambda), lambda_max_true);

%% Test 2: Add Time domain (Time + Omega linking)
fprintf('\nTest 2: Add Time domain with automatic Time↔Omega dual linking...\n');

% Create time vector
fs = 100;  % 100 Hz
T_duration = 2.0;  % 2 seconds
t = (0:1/fs:T_duration-1/fs)';
N_time = length(t);
fprintf('  Created time vector: %d samples at %.0f Hz\n', N_time, fs);

% Create Time domain (should auto-create Omega)
B.Time = bct.Time(t, fs);

% Verify Time domain
assert(~isempty(B.Time), 'Time should be created');
assert(isa(B.Time, 'bct.Time'), 'Time should be bct.Time class');
assert(B.Time.N == N_time, 'Time.N should match sample count');
assert(B.Time.fs == fs, 'Time.fs should match sampling frequency');
fprintf('  ✓ Time domain created: %d samples, fs=%.0f Hz\n', B.Time.N, B.Time.fs);

% Verify Omega is auto-created by Time constructor
assert(~isempty(B.Time.dual), 'Time.dual should be set');
assert(isa(B.Time.dual, 'bct.Omega'), 'Time.dual should be bct.Omega');
fprintf('  ✓ Omega domain auto-created by Time constructor\n');

% Store Omega reference in bct object for convenience
B.Omega = B.Time.dual;

% Verify Omega properties
assert(B.Omega.N == N_time, 'Omega.N should match Time.N');
assert(~isempty(B.Omega.omega), 'Omega should have angular frequencies');
assert(~isempty(B.Omega.freq), 'Omega should have frequencies in Hz');
fprintf('  ✓ Omega properties: %d frequency bins\n', B.Omega.N);

% Verify dual linking Time ↔ Omega
assert(B.Omega.dual == B.Time, 'Omega.dual should point to Time');
fprintf('  ✓ Dual linking verified: Time ↔ Omega\n');

% Check frequency range
freq_max = B.Omega.freq(end);
omega_max = B.Omega.omega(end);
fprintf('  ✓ Frequency range: [0, %.2f] Hz, Omega: [0, %.2f] rad/s\n', freq_max, omega_max);

%% Test 3: Verify Domain inheritance
fprintf('\nTest 3: Verify all domains inherit from bct.Domain...\n');

assert(isa(B.Manifold, 'bct.Domain'), 'Manifold should inherit from Domain');
assert(isa(B.Lambda, 'bct.Domain'), 'Lambda should inherit from Domain');
assert(isa(B.Time, 'bct.Domain'), 'Time should inherit from Domain');
assert(isa(B.Omega, 'bct.Domain'), 'Omega should inherit from Domain');
fprintf('  ✓ All domains inherit from bct.Domain base class\n');

% Verify Domain properties
assert(B.Manifold.name == "Manifold", 'Manifold name should be "Manifold"');
assert(B.Lambda.name == "Lambda", 'Lambda name should be "Lambda"');
assert(B.Time.name == "Time", 'Time name should be "Time"');
assert(B.Omega.name == "Omega", 'Omega name should be "Omega"');
fprintf('  ✓ Domain names: %s, %s, %s, %s\n', ...
    B.Manifold.name, B.Lambda.name, B.Time.name, B.Omega.name);

assert(B.Manifold.units == "mm", 'Manifold units should be "mm"');
assert(B.Lambda.units == "1/mm^2", 'Lambda units should be "1/mm^2"');
assert(B.Time.units == "s", 'Time units should be "s"');
assert(B.Omega.units == "rad/s", 'Omega units should be "rad/s"');
fprintf('  ✓ Domain units: %s, %s, %s, %s\n', ...
    B.Manifold.units, B.Lambda.units, B.Time.units, B.Omega.units);

%% Test 4: Verify axis building
fprintf('\nTest 4: Verify axis building for each domain...\n');

% Manifold axis (vertex indices)
assert(~isempty(B.Manifold.axis), 'Manifold should have axis');
assert(length(B.Manifold.axis) == 162, 'Manifold axis should have 162 elements');
assert(B.Manifold.axis(1) == 1 && B.Manifold.axis(end) == 162, 'Manifold axis should be 1:N');
fprintf('  ✓ Manifold axis: [%d, ..., %d] (vertex indices)\n', ...
    B.Manifold.axis(1), B.Manifold.axis(end));

% Lambda axis (eigenvalues)
assert(~isempty(B.Lambda.axis), 'Lambda should have axis');
assert(length(B.Lambda.axis) == 100, 'Lambda axis should have 100 elements');
fprintf('  ✓ Lambda axis: [%.4f, ..., %.4f] (eigenvalues)\n', ...
    B.Lambda.axis(1), B.Lambda.axis(end));

% Time axis (time vector)
assert(~isempty(B.Time.axis), 'Time should have axis');
assert(length(B.Time.axis) == N_time, 'Time axis should match sample count');
assert(abs(B.Time.axis(1)) < 1e-10, 'Time axis should start at 0');
fprintf('  ✓ Time axis: [%.4f, ..., %.4f] seconds\n', ...
    B.Time.axis(1), B.Time.axis(end));

% Omega axis (angular frequencies)
assert(~isempty(B.Omega.axis), 'Omega should have axis');
assert(length(B.Omega.axis) == N_time, 'Omega axis should match sample count');
fprintf('  ✓ Omega axis: [%.4f, ..., %.4f] rad/s\n', ...
    B.Omega.axis(1), B.Omega.axis(end));

%% Summary
fprintf('\n═══════════════════════════════════════════════\n');
fprintf('✓ All tests passed!\n');
fprintf('═══════════════════════════════════════════════\n');
fprintf('\nNew bct architecture verified:\n');
fprintf('  • bct.Manifold class with descriptive properties\n');
fprintf('  • Automatic Lambda domain creation and Manifold↔Lambda linking\n');
fprintf('  • Automatic Omega domain creation and Time↔Omega linking\n');
fprintf('  • All domains inherit from bct.Domain base class\n');
fprintf('  • Dual linking uses inherited Domain.setDual() method\n');
fprintf('  • Proper axis initialization for all domains\n');
fprintf('\nDomain structure:\n');
fprintf('  Manifold ↔ Lambda (spatial/spectral duality)\n');
fprintf('  Time ↔ Omega (temporal/frequency duality)\n');
fprintf('\n');
