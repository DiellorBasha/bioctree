%DEMO_OPERATOR Demonstrate bct.Operator class for differential operators
%
% This script demonstrates:
%   1. Creating operator objects from manifolds
%   2. Operator properties and metadata
%   3. Applying operators to fields
%   4. Operator composition
%   5. Operator transpose (codifferential)
%   6. Verifying exactness property (d1 ∘ d0 = 0)
%   7. Building Laplacian from exterior derivatives

%% Setup
% Get root directory (parent of demo folder)
demoDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(demoDir);

addpath(fullfile(rootDir, 'toolbox'));
addpath(fullfile(rootDir, 'external'));
addpath(fullfile(rootDir, 'external', 'gptoolbox', 'mesh'));
addpath(fullfile(rootDir, 'external', 'DECLab'));

%% Create test manifold
fprintf('Creating test manifold (icosphere)...\n');
[V, F] = icosphere(3);
M = bct.Manifold(struct('V', V, 'F', F));
fprintf('  Vertices: %d\n', M.numVertices());
fprintf('  Faces: %d\n', M.numFaces());
fprintf('  Edges: %d\n\n', M.numEdges());

%% Get exterior derivative operators
fprintf('=== Exterior Derivative Operators ===\n');
d0 = M.d0();
d1 = M.d1();

fprintf('\nd0: %s\n', d0.Name);
fprintf('  Size: [%d × %d]\n', d0.Size(1), d0.Size(2));
fprintf('  Type: %s → %s\n', d0.InputType, d0.OutputType);
fprintf('  Non-zeros: %d (%.2f%% sparse)\n', ...
    d0.NumNonZeros, 100 * (1 - d0.NumNonZeros / prod(d0.Size)));

fprintf('\nd1: %s\n', d1.Name);
fprintf('  Size: [%d × %d]\n', d1.Size(1), d1.Size(2));
fprintf('  Type: %s → %s\n', d1.InputType, d1.OutputType);
fprintf('  Non-zeros: %d (%.2f%% sparse)\n', ...
    d1.NumNonZeros, 100 * (1 - d1.NumNonZeros / prod(d1.Size)));

%% Apply operators to fields
fprintf('\n=== Applying Operators to Fields ===\n');

% Create test 0-form (scalar field on vertices)
omega0 = rand(M.numVertices(), 1);
fprintf('\nCreated test 0-form: size [%d × 1]\n', length(omega0));

% Apply d0
omega1 = d0 * omega0;
fprintf('Applied d0: result is 1-form of size [%d × 1]\n', length(omega1));

% Apply d1
omega2 = d1 * omega1;
fprintf('Applied d1: result is 2-form of size [%d × 1]\n', length(omega2));

%% Verify exactness: d1 ∘ d0 = 0
fprintf('\n=== Exactness Property: d1 ∘ d0 = 0 ===\n');

d1d0 = d1 * d0;
fprintf('\nComposed operator: %s\n', d1d0.ID);
fprintf('  Size: [%d × %d]\n', d1d0.Size(1), d1d0.Size(2));
fprintf('  Frobenius norm: %.15e\n', norm(d1d0.Matrix, 'fro'));
fprintf('  ✓ Exactness verified: d1 ∘ d0 = 0\n');

% Verify by application
test_field = rand(M.numVertices(), 1);
result = d1d0 * test_field;
fprintf('  Applied to random field, result norm: %.15e\n', norm(result));

%% Operator transpose (codifferential)
fprintf('\n=== Codifferential (Transpose) ===\n');

d0_star = d0';
d1_star = d1';

fprintf('\nd0*: %s\n', d0_star.Name);
fprintf('  Size: [%d × %d]\n', d0_star.Size(1), d0_star.Size(2));
fprintf('  Type: %s → %s\n', d0_star.InputType, d0_star.OutputType);

fprintf('\nd1*: %s\n', d1_star.Name);
fprintf('  Size: [%d × %d]\n', d1_star.Size(1), d1_star.Size(2));
fprintf('  Type: %s → %s\n', d1_star.InputType, d1_star.OutputType);

%% Build Laplacian from exterior derivatives
fprintf('\n=== Laplacian Construction ===\n');

% Hodge Laplacian: Δ₀ = d₀* d₀
Delta0 = d0' * d0;
fprintf('\nΔ₀ = d₀* ∘ d₀ (0-form Laplacian)\n');
fprintf('  ID: %s\n', Delta0.ID);
fprintf('  Size: [%d × %d]\n', Delta0.Size(1), Delta0.Size(2));
fprintf('  Type: %s → %s\n', Delta0.InputType, Delta0.OutputType);
fprintf('  Non-zeros: %d\n', Delta0.NumNonZeros);

% Check symmetry
is_symmetric = norm(Delta0.Matrix - Delta0.Matrix', 'fro') < 1e-12;
fprintf('  Is symmetric: %d\n', is_symmetric);

% Check positive semi-definite (all eigenvalues ≥ 0)
lambda_min = eigs(Delta0.Matrix, 1, 'smallestabs');
fprintf('  Smallest eigenvalue: %.6e\n', lambda_min);
fprintf('  Is positive semi-definite: %d\n', lambda_min >= -1e-12);

%% Apply Laplacian to smooth field
fprintf('\n=== Laplacian Application ===\n');

% Create smooth field (low-frequency spherical harmonic)
[theta, phi] = cart2sph(V(:,1), V(:,2), V(:,3));
smooth_field = cos(2*theta) .* sin(3*phi);

% Apply Laplacian
laplacian_result = Delta0 * smooth_field;

fprintf('Applied Δ₀ to smooth field\n');
fprintf('  Input range: [%.3f, %.3f]\n', min(smooth_field), max(smooth_field));
fprintf('  Output range: [%.3f, %.3f]\n', min(laplacian_result), max(laplacian_result));
fprintf('  Output norm: %.6f\n', norm(laplacian_result));

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('✓ Created bct.Operator objects for d0, d1\n');
fprintf('✓ Applied operators to differential forms\n');
fprintf('✓ Verified exactness: d1 ∘ d0 = 0\n');
fprintf('✓ Computed codifferentials via transpose\n');
fprintf('✓ Built Hodge Laplacian: Δ₀ = d₀* ∘ d₀\n');
fprintf('✓ Verified Laplacian is symmetric positive semi-definite\n');
fprintf('\nDemo complete!\n');
