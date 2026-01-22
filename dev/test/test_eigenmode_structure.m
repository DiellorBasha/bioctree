% test_eigenmode_structure.m
% Development test to verify new eigenmode dataset structure
%
% Tests that eigenmode output follows the dataset pattern:
%   eigen.eigenvalues.value      [k×1 double]
%   eigen.eigenvalues.attributes [struct]
%   eigen.eigenvectors.value     [N×k double]
%   eigen.eigenvectors.attributes [struct]
%   eigen.attributes             [struct with group metadata]

%% Setup
% Load canonical test manifold
M = bct.data.load('Id', 'fsaverage_rh_pial');

%% Test 1: Basic eigenmode structure
fprintf('Test 1: Basic eigenmode structure...\n');
eigen = M.eigenmodes(50);

% Check group structure
assert(isstruct(eigen), 'eigen must be a struct');
assert(isfield(eigen, 'eigenvalues'), 'eigen must have eigenvalues field');
assert(isfield(eigen, 'eigenvectors'), 'eigen must have eigenvectors field');
assert(isfield(eigen, 'attributes'), 'eigen must have attributes field');

% Check dataset structure for eigenvalues
assert(isstruct(eigen.eigenvalues), 'eigenvalues must be a struct');
assert(isfield(eigen.eigenvalues, 'value'), 'eigenvalues must have value field');
assert(isfield(eigen.eigenvalues, 'attributes'), 'eigenvalues must have attributes field');
assert(isnumeric(eigen.eigenvalues.value), 'eigenvalues.value must be numeric');
assert(isstruct(eigen.eigenvalues.attributes), 'eigenvalues.attributes must be struct');

% Check dataset structure for eigenvectors
assert(isstruct(eigen.eigenvectors), 'eigenvectors must be a struct');
assert(isfield(eigen.eigenvectors, 'value'), 'eigenvectors must have value field');
assert(isfield(eigen.eigenvectors, 'attributes'), 'eigenvectors must have attributes field');
assert(isnumeric(eigen.eigenvectors.value), 'eigenvectors.value must be numeric');
assert(isstruct(eigen.eigenvectors.attributes), 'eigenvectors.attributes must be struct');

fprintf('  ✓ Structure validation passed\n');

%% Test 2: Dimension consistency
fprintf('Test 2: Dimension consistency...\n');

k = 50;
nV = M.numVertices();

lambda = eigen.eigenvalues.value;
U = eigen.eigenvectors.value;

assert(length(lambda) == k, 'Should have k=%d eigenvalues', k);
assert(size(U, 1) == nV, 'Eigenvectors should have nV=%d rows', nV);
assert(size(U, 2) == k, 'Eigenvectors should have k=%d columns', k);

% Check group attributes consistency
assert(eigen.attributes.numModes == k, 'attributes.numModes should equal k');
assert(eigen.attributes.numVertices == nV, 'attributes.numVertices should equal nV');

fprintf('  ✓ Dimensions [%d×%d] eigenvalues, [%d×%d] eigenvectors\n', ...
    size(lambda, 1), size(lambda, 2), size(U, 1), size(U, 2));

%% Test 3: Dataset attributes metadata
fprintf('Test 3: Dataset attributes metadata...\n');

% Eigenvalues attributes
ev_attrs = eigen.eigenvalues.attributes;
assert(isfield(ev_attrs, 'name'), 'eigenvalues.attributes must have name');
assert(isfield(ev_attrs, 'path'), 'eigenvalues.attributes must have path');
assert(isfield(ev_attrs, 'description'), 'eigenvalues.attributes must have description');
assert(isfield(ev_attrs, 'shape'), 'eigenvalues.attributes must have shape');
assert(isfield(ev_attrs, 'dtype'), 'eigenvalues.attributes must have dtype');
assert(isfield(ev_attrs, 'units'), 'eigenvalues.attributes must have units');

% Eigenvectors attributes  
evec_attrs = eigen.eigenvectors.attributes;
assert(isfield(evec_attrs, 'name'), 'eigenvectors.attributes must have name');
assert(isfield(evec_attrs, 'path'), 'eigenvectors.attributes must have path');
assert(isfield(evec_attrs, 'description'), 'eigenvectors.attributes must have description');
assert(isfield(evec_attrs, 'shape'), 'eigenvectors.attributes must have shape');
assert(isfield(evec_attrs, 'dtype'), 'eigenvectors.attributes must have dtype');
assert(isfield(evec_attrs, 'orthonormality'), 'eigenvectors.attributes must have orthonormality');

fprintf('  ✓ Eigenvalues attributes: %s\n', ev_attrs.name);
fprintf('  ✓ Eigenvectors attributes: %s\n', evec_attrs.name);
fprintf('  ✓ Orthonormality: %s\n', evec_attrs.orthonormality);

%% Test 4: Spectral decomposition (integration test)
fprintf('Test 4: Spectral decomposition...\n');

% Create random signal
signal = randn(nV, 1);

% Get mass matrix
Mass = M.massmatrix();

% Project to spectral domain
coeffs = eigen.eigenvectors.value' * Mass * signal;

% Reconstruct signal
reconstructed = eigen.eigenvectors.value * coeffs;

% Check dimensions
assert(length(coeffs) == k, 'Spectral coefficients should have k=%d elements', k);
assert(length(reconstructed) == nV, 'Reconstructed signal should have nV=%d elements', nV);

fprintf('  ✓ Spectral projection: [%d×1] → [%d×1] → [%d×1]\n', ...
    length(signal), length(coeffs), length(reconstructed));

%% Test 5: Spectral filtering (heat kernel)
fprintf('Test 5: Spectral filtering...\n');

tau = 10;
heat_kernel = exp(-eigen.eigenvalues.value * tau);
filtered = eigen.eigenvectors.value * (heat_kernel .* coeffs);

assert(length(filtered) == nV, 'Filtered signal should have nV=%d elements', nV);
assert(all(isfinite(filtered)), 'Filtered signal should be finite');

fprintf('  ✓ Heat kernel filtering (tau=%.1f): [%d×1] output\n', tau, length(filtered));

%% Test 6: Schema validation
fprintf('Test 6: Schema validation...\n');

% Validate using schema
tf = bct.manifold.eigen.schema.validate(eigen);
assert(tf, 'Eigenmode structure should pass schema validation');

fprintf('  ✓ Schema validation passed\n');

%% Test 7: RemoveDC default behavior
fprintf('Test 7: RemoveDC default behavior...\n');

% Default should keep DC mode (removedDC=0)
assert(eigen.attributes.removedDC == 0, 'Default RemoveDC should be false (removedDC=0)');
assert(eigen.eigenvalues.value(1) < 1e-10, 'First eigenvalue should be ~0 (DC mode)');

% Explicitly remove DC
eigen_no_dc = M.eigenmodes(50, 'RemoveDC', true);
assert(eigen_no_dc.attributes.removedDC == 1, 'RemoveDC=true should set removedDC=1');
assert(eigen_no_dc.eigenvalues.value(1) > 1e-10, 'First eigenvalue should be non-zero (DC removed)');

fprintf('  ✓ Default keeps DC mode (λ₁ = %.2e)\n', eigen.eigenvalues.value(1));
fprintf('  ✓ RemoveDC=true removes DC (λ₁ = %.2e)\n', eigen_no_dc.eigenvalues.value(1));

%% Test 8: Integration with operators
fprintf('Test 8: Integration with operators...\n');

% Test that operators expecting eigenmodes work correctly
try
    % Test modulate operator
    signal = randn(nV, 1);
    modulated = bct.manifold.operator.modulate(M, signal, 10);
    assert(length(modulated) == nV, 'Modulated signal should have nV elements');
    
    % Test localize operator  
    F = bct.filter.design(eigen.eigenvalues.value, "Heat", "tau", 10);
    localized = bct.manifold.operator.localize(M, 100, F);
    assert(length(localized) == nV, 'Localized field should have nV elements');
    
    fprintf('  ✓ Modulate operator works with new structure\n');
    fprintf('  ✓ Localize operator works with new structure\n');
catch ME
    fprintf('  ✗ Operator integration failed: %s\n', ME.message);
    rethrow(ME);
end

%% Test 9: Caching behavior
fprintf('Test 9: Caching behavior...\n');

% Clear cache
M.Cache.eigenmodes = [];

% First call should compute
tic;
eigen1 = M.eigenmodes(50);
t1 = toc;

% Second call should use cache
tic;
eigen2 = M.eigenmodes(50);
t2 = toc;

assert(t2 < t1, 'Cached call should be faster');
assert(isequal(eigen1.eigenvalues.value, eigen2.eigenvalues.value), ...
    'Cached eigenvalues should match computed ones');
assert(isequal(eigen1.eigenvectors.value, eigen2.eigenvectors.value), ...
    'Cached eigenvectors should match computed ones');

fprintf('  ✓ First call: %.3f sec (computed)\n', t1);
fprintf('  ✓ Second call: %.3f sec (cached)\n', t2);

%% Summary
fprintf('\n');
fprintf('========================================\n');
fprintf('All eigenmode structure tests PASSED ✓\n');
fprintf('========================================\n');
fprintf('Validated:\n');
fprintf('  • Dataset structure (.value + .attributes)\n');
fprintf('  • Dimension consistency\n');
fprintf('  • Metadata completeness\n');
fprintf('  • Spectral operations\n');
fprintf('  • Schema validation\n');
fprintf('  • RemoveDC default behavior\n');
fprintf('  • Operator integration\n');
fprintf('  • Caching mechanism\n');
fprintf('\n');
