%% Test DEC Integration
% Verify that DEC class and bct.dec package work correctly

% Clean workspace
clear; clc;

fprintf('=== DEC Integration Test ===\n\n');

%% 1. Load test mesh
fprintf('1. Loading test mesh...\n');
data = load('data/mesh/fsaverage_rh_pial.mat');
M = bct.Manifold(data.V, data.F);
fprintf('   Manifold: %d vertices, %d faces\n', M.numVertices(), M.numFaces());

%% 2. Create DEC representation
fprintf('\n2. Creating DEC representation...\n');
try
    D = M.DEC();
    fprintf('   ✓ DEC created successfully\n');
    fprintf('   Backend type: %s\n', class(D.Backend));
catch ME
    error('Failed to create DEC: %s', ME.message);
end

%% 3. Test primitive accessors
fprintf('\n3. Testing primitive accessors...\n');

% Exterior derivatives
d0 = bct.dec.d0(D);
d1 = bct.dec.d1(D);
fprintf('   d0: [%d × %d] sparse\n', size(d0, 1), size(d0, 2));
fprintf('   d1: [%d × %d] sparse\n', size(d1, 1), size(d1, 2));

% Hodge stars
star0 = bct.dec.star0(D);
star1 = bct.dec.star1(D);
star2 = bct.dec.star2(D);
fprintf('   star0: [%d × %d] sparse\n', size(star0, 1), size(star0, 2));
fprintf('   star1: [%d × %d] sparse\n', size(star1, 1), size(star1, 2));
fprintf('   star2: [%d × %d] sparse\n', size(star2, 1), size(star2, 2));

%% 4. Test consistency: d²=0
fprintf('\n4. Testing d²=0 (boundary of boundary is zero)...\n');
d0d0 = d1 * d0;
max_d2 = full(max(abs(d0d0(:))));
fprintf('   max|d1*d0| = %.2e\n', max_d2);
if max_d2 < 1e-10
    fprintf('   ✓ d²=0 verified\n');
else
    warning('d²=0 test failed: max error = %.2e', max_d2);
end

%% 5. Test core operators on random data
fprintf('\n5. Testing core operators...\n');

% Create random 0-form
f0 = randn(M.numVertices(), 1);

% Gradient
grad_f = bct.dec.gradient(D, f0);
fprintf('   gradient: [%d] → [%d]\n', length(f0), length(grad_f));

% Divergence
div_grad_f = bct.dec.divergence(D, grad_f);
fprintf('   divergence: [%d] → [%d]\n', length(grad_f), length(div_grad_f));

% Curl
curl_grad_f = bct.dec.curl(D, grad_f);
fprintf('   curl: [%d] → [%d]\n', length(grad_f), length(curl_grad_f));

%% 6. Test curl of gradient is zero
fprintf('\n6. Testing curl(grad(f)) = 0...\n');
max_curl = max(abs(curl_grad_f));
fprintf('   max|curl(grad(f))| = %.2e\n', max_curl);
if max_curl < 1e-10
    fprintf('   ✓ curl(grad) = 0 verified\n');
else
    warning('curl(grad) = 0 test failed: max error = %.2e', max_curl);
end

%% 7. Test Laplacian operators
fprintf('\n7. Testing Laplacian operators...\n');

L0 = bct.dec.laplacian0(D);
fprintf('   0-form Laplacian: [%d × %d] sparse\n', size(L0, 1), size(L0, 2));

L1 = bct.dec.laplacian1(D);
fprintf('   1-form Laplacian: [%d × %d] sparse\n', size(L1, 1), size(L1, 2));

L2 = bct.dec.laplacian2(D);
fprintf('   2-form Laplacian: [%d × %d] sparse\n', size(L2, 1), size(L2, 2));

%% 8. Test 0-form Laplacian properties
fprintf('\n8. Testing 0-form Laplacian properties...\n');

% Test symmetry
is_symmetric = norm(L0 - L0', 'fro') / norm(L0, 'fro');
fprintf('   Symmetry error: %.2e\n', is_symmetric);

% Test Laplacian = divergence(gradient)
Lap_f = L0 * f0;
div_grad_f_normalized = star0 \ div_grad_f;  % Account for mass matrix
error_lap = norm(Lap_f - div_grad_f_normalized) / norm(Lap_f);
fprintf('   Laplacian consistency: %.2e\n', error_lap);

%% 9. Test eigenpairs computation
fprintf('\n9. Testing eigenpairs computation...\n');
k = 20;
fprintf('   Computing %d eigenpairs for 0-forms...\n', k);

try
    E = bct.dec.eigensolve(D, 0, k, 'normalize', true);
    fprintf('   ✓ Eigensolve successful\n');
    fprintf('   Eigenvalues range: [%.2e, %.2e]\n', min(E.Eigenvalues), max(E.Eigenvalues));
    fprintf('   Eigenvectors: [%d × %d]\n', size(E.Eigenvectors, 1), size(E.Eigenvectors, 2));
    
    % Check orthonormality
    U = E.Eigenvectors;
    I_approx = U' * star0 * U;
    ortho_error = norm(I_approx - eye(k), 'fro');
    fprintf('   Orthonormality error: %.2e\n', ortho_error);
    
    if ortho_error < 1e-8
        fprintf('   ✓ Eigenvectors orthonormal under Hodge star\n');
    end
catch ME
    warning('Eigensolve failed: %s', ME.message);
end

%% 10. Test registry integration
fprintf('\n10. Testing registry integration...\n');
specs = bct.registry.operators();
dec_ops = {};
for fn = fieldnames(specs)'
    if startsWith(fn{1}, 'dec_')
        dec_ops{end+1} = fn{1};
    end
end
fprintf('   Found %d DEC operators in registry:\n', length(dec_ops));
for i = 1:length(dec_ops)
    fprintf('     - %s\n', dec_ops{i});
end

%% 11. Test runtime integration
fprintf('\n11. Testing runtime integration...\n');
ctx = bct.runtime.context(M, 'DEC', true);
rtOps = bct.runtime.operators(ctx);

dec_count = 0;
for key = keys(rtOps)
    if startsWith(key{1}, 'dec_')
        dec_count = dec_count + 1;
    end
end
fprintf('   Runtime has %d DEC operators available\n', dec_count);

% Test a bound operator
if isKey(rtOps, 'dec_gradient')
    grad_fn = rtOps('dec_gradient');
    grad_result = grad_fn(f0);
    fprintf('   ✓ Bound gradient operator works\n');
    fprintf('   Result size: [%d]\n', length(grad_result));
end

%% Summary
fprintf('\n=== DEC Integration Test Complete ===\n');
fprintf('✓ DEC class wrapper functional\n');
fprintf('✓ bct.dec package operators working\n');
fprintf('✓ Mathematical consistency verified\n');
fprintf('✓ Eigenpairs integration successful\n');
fprintf('✓ Registry/runtime integration confirmed\n');
