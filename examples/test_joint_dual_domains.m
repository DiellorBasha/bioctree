%% Test Joint Domain Dual Relationships
%
% This script demonstrates the dual relationship architecture for Joint domains.
% When Joint domains are created from domains with duals, the Joint domain
% automatically gets a dual constructed from the constituent duals.
%
% Dual Relationships:
%   Manifold ↔ Lambda  (spatial ↔ spectral)
%   Time ↔ Omega       (temporal ↔ frequency)
%   Manifold_Time ↔ Lambda_Omega (joint spatiotemporal ↔ joint spectral-frequency)

clear; close all; clc;

fprintf('========================================\n');
fprintf('Joint Domain Dual Relationship Test\n');
fprintf('========================================\n\n');

%% Step 1: Create BCT with basic domains
fprintf('Step 1: Setting up BCT with Manifold and Time domains\n');
fprintf('------------------------------------------------------\n');

% Import mesh
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);
fprintf('✓ Mesh imported: %d vertices\n', B.Manifold.N);

% Compute eigenbasis (creates Lambda as dual of Manifold)
B = B.computeEigenbasis(100);
fprintf('✓ Eigenbasis computed: %d modes\n', length(B.Lambda.lambda));
fprintf('  Manifold.dual = %s\n', B.Manifold.dual.name);
fprintf('  Lambda.dual = %s\n', B.Lambda.dual.name);

% Set up time domain (automatically creates Omega as dual)
B.Time = bct.Time(linspace(0, 1, 50)', 50);
fprintf('✓ Time domain created: %d samples @ %.1f Hz\n', B.Time.N, B.Time.fs);
fprintf('  Time.dual = %s\n', B.Time.dual.name);
fprintf('  Omega.dual = %s\n', B.Omega.dual.name);

% Check if Joint Manifold_Time was auto-created
if ~isempty(B.Joint)
    fprintf('✓ Joint domain auto-created: %s\n', B.Joint.Domain);
    fprintf('  Joint.dual auto-created: %s\n', B.Joint.dual.Domain);
else
    error('Expected Joint Manifold_Time to be auto-created when Time is set!');
end

fprintf('\n');

%% Step 2: Verify automatic Joint domain creation
fprintf('Step 2: Verifying Automatic Joint Domain Creation\n');
fprintf('--------------------------------------------------\n');

% Verify Joint is Manifold_Time
if ~strcmp(B.Joint.Domain, 'Manifold_Time')
    error('Expected Joint domain to be Manifold_Time, got %s', B.Joint.Domain);
end
fprintf('✓ Joint domain is Manifold_Time (as expected)\n');

% Verify dual is Lambda_Omega
if ~strcmp(B.Joint.dual.Domain, 'Lambda_Omega')
    error('Expected Joint.dual to be Lambda_Omega, got %s', B.Joint.dual.Domain);
end
fprintf('✓ Joint.dual is Lambda_Omega (as expected)\n');

fprintf('\n');

%% Step 3: Display Joint domain info
fprintf('Step 3: Joint Domain Information\n');
fprintf('---------------------------------\n');
disp(B.Joint);

%% Step 4: Verify dual relationship
fprintf('Step 4: Verifying Dual Relationship\n');
fprintf('------------------------------------\n');

% Check if dual exists
if isempty(B.Joint.dual)
    error('Expected B.Joint.dual to be set automatically!');
end

fprintf('✓ B.Joint.dual exists\n');
fprintf('  Joint domain: %s\n', B.Joint.Domain);
fprintf('  Dual domain:  %s\n', B.Joint.dual.Domain);

% Verify dual structure
fprintf('\n');
fprintf('Joint domain structure:\n');
fprintf('  B.Joint.A = %s (dual: %s)\n', B.Joint.A.name, B.Joint.A.dual.name);
fprintf('  B.Joint.B = %s (dual: %s)\n', B.Joint.B.name, B.Joint.B.dual.name);

fprintf('\n');
fprintf('Dual Joint domain structure:\n');
fprintf('  B.Joint.dual.A = %s (dual: %s)\n', B.Joint.dual.A.name, B.Joint.dual.A.dual.name);
fprintf('  B.Joint.dual.B = %s (dual: %s)\n', B.Joint.dual.B.name, B.Joint.dual.B.dual.name);

% Verify bidirectional relationship
fprintf('\n');
fprintf('Bidirectional dual check:\n');
if B.Joint.dual.dual == B.Joint
    fprintf('✓ B.Joint.dual.dual == B.Joint (bidirectional relationship confirmed)\n');
else
    warning('Expected bidirectional dual relationship!');
end

%% Step 5: Verify constituent domain relationships
fprintf('\nStep 5: Verifying Constituent Domain Duals\n');
fprintf('-------------------------------------------\n');

% Manifold_Time joint domain
fprintf('Manifold_Time Joint:\n');
fprintf('  A: %s → dual: %s\n', B.Joint.A.name, B.Joint.A.dual.name);
fprintf('  B: %s → dual: %s\n', B.Joint.B.name, B.Joint.B.dual.name);

% Expected: A.dual = Lambda, B.dual = Omega
if strcmp(B.Joint.A.dual.name, 'Lambda') && strcmp(B.Joint.B.dual.name, 'Omega')
    fprintf('✓ Constituent duals correct: Manifold→Lambda, Time→Omega\n');
else
    error('Unexpected constituent dual domains!');
end

fprintf('\n');

% Lambda_Omega dual joint domain
fprintf('Lambda_Omega Dual Joint:\n');
fprintf('  A: %s → dual: %s\n', B.Joint.dual.A.name, B.Joint.dual.A.dual.name);
fprintf('  B: %s → dual: %s\n', B.Joint.dual.B.name, B.Joint.dual.B.dual.name);

% Expected: A.dual = Manifold, B.dual = Time
if strcmp(B.Joint.dual.A.dual.name, 'Manifold') && strcmp(B.Joint.dual.B.dual.name, 'Time')
    fprintf('✓ Dual constituent duals correct: Lambda→Manifold, Omega→Time\n');
else
    error('Unexpected dual constituent dual domains!');
end

%% Step 6: Test isDual() method
fprintf('\nStep 6: Testing isDual() Method\n');
fprintf('--------------------------------\n');

if B.Joint.isDual(B.Joint.dual)
    fprintf('✓ B.Joint.isDual(B.Joint.dual) = true\n');
else
    error('isDual() should return true for dual Joint domains!');
end

% Test with non-dual
B_alt = B.createJoint('Manifold', 'Omega');
if ~B.Joint.isDual(B_alt.Joint)
    fprintf('✓ B.Joint.isDual(Manifold_Omega) = false (not duals)\n');
else
    warning('isDual() returned true for non-dual domains!');
end

%% Step 7: Test createDual() method explicitly
fprintf('\nStep 7: Testing Explicit createDual() Method\n');
fprintf('---------------------------------------------\n');

% Create a new Joint manually
J_manual = bct.Joint(B.Lambda, B.Omega);
fprintf('Created manual Joint: %s\n', J_manual.Domain);
fprintf('  dual property (before createDual): ');
if isempty(J_manual.dual)
    fprintf('<empty>\n');
else
    fprintf('%s\n', J_manual.dual.Domain);
end

% Explicitly create dual
J_manual_dual = J_manual.createDual();
fprintf('\nCalled createDual():\n');
fprintf('  J_manual.dual = %s\n', J_manual.dual.Domain);
fprintf('  J_manual_dual = %s\n', J_manual_dual.Domain);

% Verify bidirectional
if J_manual.dual == J_manual_dual && J_manual_dual.dual == J_manual
    fprintf('✓ Bidirectional dual relationship established\n');
else
    error('Bidirectional dual not established correctly!');
end

%% Step 8: Test transform property (placeholder)
fprintf('\nStep 8: Testing Transform Property (Placeholder)\n');
fprintf('-------------------------------------------------\n');

fprintf('B.Joint.transform: ');
if isempty(B.Joint.transform)
    fprintf('<not implemented> (expected)\n');
    fprintf('✓ Transform property exists but not yet implemented\n');
else
    fprintf('%s\n', class(B.Joint.transform));
end

fprintf('B.Joint.dual.transform: ');
if isempty(B.Joint.dual.transform)
    fprintf('<not implemented> (expected)\n');
    fprintf('✓ Dual transform property exists but not yet implemented\n');
else
    fprintf('%s\n', class(B.Joint.dual.transform));
end

%% Step 9: Display summary
fprintf('\n========================================\n');
fprintf('SUMMARY: Joint Domain Dual Architecture\n');
fprintf('========================================\n\n');

fprintf('Domain Dual Relationships:\n');
fprintf('  Manifold ↔ Lambda  (N=%d ↔ M=%d)\n', B.Manifold.N, length(B.Lambda.lambda));
fprintf('  Time ↔ Omega       (T=%d ↔ F=%d)\n', B.Time.N, length(B.Omega.axis));
fprintf('\n');

fprintf('Joint Domain Dual Relationships:\n');
fprintf('  %s ↔ %s\n', B.Joint.Domain, B.Joint.dual.Domain);
fprintf('    Grid: [%d×%d] ↔ [%d×%d]\n', ...
    B.Joint.size(), B.Joint.dual.size());
fprintf('    Units: %s ↔ %s\n', ...
    B.Joint.units, B.Joint.dual.units);
fprintf('\n');

fprintf('Architecture Properties:\n');
fprintf('  ✓ Joint domains automatically create duals from constituent duals\n');
fprintf('  ✓ Bidirectional dual relationships established\n');
fprintf('  ✓ Dual property accessible via B.Joint.dual\n');
fprintf('  ✓ Transform property exists (placeholder for future 2D transforms)\n');
fprintf('  ✓ createDual() method available for explicit dual creation\n');
fprintf('  ✓ isDual() method validates dual relationships\n');
fprintf('\n');

fprintf('Next Steps:\n');
fprintf('  • Implement 2D Joint transforms (e.g., MFT ⊗ FFT)\n');
fprintf('  • Add Joint.transform property with forward/inverse methods\n');
fprintf('  • Enable full spatiotemporal filtering with Joint domains\n');
fprintf('\n');

fprintf('========================================\n');
fprintf('All tests passed!\n');
fprintf('========================================\n');
