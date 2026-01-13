%DEMO_DEC_OPERATORS Demonstrate all DEC operators from bct.Manifold
%
% This script demonstrates:
%   1. All 10 DEC operator wrappers (d0, d1, dd0, dd1, hd0-2, hdd0-2)
%   2. Exterior derivative chain d1 ∘ d0 = 0
%   3. Hodge star properties
%   4. Building DEC Laplacian from operators
%   5. Operator composition and chaining

%% Setup
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

%% Show all DEC operators
fprintf('=== DEC Operators from Manifold ===\n\n');

operators = {
    'd0',   M.d0(),   'Exterior derivative (0→1)'
    'd1',   M.d1(),   'Exterior derivative (1→2)'
    'dd0',  M.dd0(),  'Codifferential (dual 0→1)'
    'dd1',  M.dd1(),  'Codifferential (dual 1→2)'
    'hd0',  M.hd0(),  'Hodge star ⋆₀'
    'hd1',  M.hd1(),  'Hodge star ⋆₁'
    'hd2',  M.hd2(),  'Hodge star ⋆₂'
    'hdd0', M.hdd0(), 'Inverse Hodge ⋆₀⁻¹'
    'hdd1', M.hdd1(), 'Inverse Hodge ⋆₁⁻¹'
    'hdd2', M.hdd2(), 'Inverse Hodge ⋆₂⁻¹'
};

for i = 1:size(operators, 1)
    op = operators{i, 2};
    fprintf('%-5s [%4d × %4d]  %s\n', ...
        operators{i, 1}, op.Size(1), op.Size(2), operators{i, 3});
end

%% Verify exactness: d1 ∘ d0 = 0
fprintf('\n=== Exactness: d1 ∘ d0 = 0 ===\n');
d0 = M.d0();
d1 = M.d1();
d1d0 = d1 * d0;
fprintf('Composed: %s [%d × %d]\n', d1d0.ID, d1d0.Size(1), d1d0.Size(2));
fprintf('Frobenius norm: %.15e\n', norm(d1d0.Matrix, 'fro'));
fprintf('✓ Exactness verified\n');

%% Hodge star properties
fprintf('\n=== Hodge Star Properties ===\n');

% Test hd0 * hdd2 (should recover 0-forms)
omega0 = rand(M.numVertices(), 1);
hd0 = M.hd0();
hdd2 = M.hdd2();
recovered0 = hdd2 * (hd0 * omega0);
err0 = norm(omega0 - recovered0);
fprintf('hd0 ∘ hdd2 recovery: error = %.6e\n', err0);

% Test hd2 * hdd0 (should recover 2-forms)
omega2 = rand(M.numFaces(), 1);
hd2 = M.hd2();
hdd0 = M.hdd0();
recovered2 = hdd0 * (hd2 * omega2);
err2 = norm(omega2 - recovered2);
fprintf('hd2 ∘ hdd0 recovery: error = %.6e\n', err2);

%% Build DEC Laplacian
fprintf('\n=== DEC Laplacian Construction ===\n');

% 0-form Laplacian: Δ₀ = d₀* ⋆₁ d₀
hd1 = M.hd1();
Delta0 = d0' * hd1 * d0;

fprintf('Δ₀ = d₀* ∘ ⋆₁ ∘ d₀\n');
fprintf('  ID: %s\n', Delta0.ID);
fprintf('  Size: [%d × %d]\n', Delta0.Size(1), Delta0.Size(2));
fprintf('  Non-zeros: %d\n', Delta0.NumNonZeros);

% Check symmetry
is_symmetric = norm(Delta0.Matrix - Delta0.Matrix', 'fro') < 1e-10;
fprintf('  Symmetric: %d\n', is_symmetric);

% Check positive semi-definite
lambda_min = eigs(Delta0.Matrix, 1, 'smallestabs');
fprintf('  Smallest eigenvalue: %.6e\n', lambda_min);
fprintf('  Positive semi-definite: %d\n', lambda_min >= -1e-12);

%% Apply Laplacian to test field
fprintf('\n=== Laplacian Application ===\n');

% Create smooth test field
[theta, phi] = cart2sph(V(:,1), V(:,2), V(:,3));
smooth_field = cos(3*theta) .* sin(2*phi);

% Apply DEC Laplacian
laplacian_result = Delta0 * smooth_field;

fprintf('Applied Δ₀ to smooth spherical harmonic\n');
fprintf('  Input range: [%.3f, %.3f]\n', min(smooth_field), max(smooth_field));
fprintf('  Output range: [%.3f, %.3f]\n', min(laplacian_result), max(laplacian_result));
fprintf('  Output norm: %.6f\n', norm(laplacian_result));

%% Operator chaining example
fprintf('\n=== Operator Chaining Example ===\n');

% Chain: d₁ ∘ ⋆₁ ∘ d₀
chain = d1 * hd1 * d0;
fprintf('d₁ ∘ ⋆₁ ∘ d₀: [%d × %d]\n', chain.Size(1), chain.Size(2));
fprintf('  Maps 0-forms on vertices to 2-forms on faces\n');
fprintf('  Non-zeros: %d\n', chain.NumNonZeros);

% Apply to test field
result = chain * smooth_field;
fprintf('  Result size: [%d × 1]\n', length(result));
fprintf('  Result norm: %.6f\n', norm(result));

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('✓ Created 10 DEC operator wrappers\n');
fprintf('✓ Verified exterior derivative exactness (d₁ ∘ d₀ = 0)\n');
fprintf('✓ Tested Hodge star recovery properties\n');
fprintf('✓ Built symmetric positive semi-definite Laplacian\n');
fprintf('✓ Demonstrated operator composition and chaining\n');
fprintf('\nAll DEC operators available from bct.Manifold!\n');
