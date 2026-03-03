%% Development Test: Vector Heat Method
% Tests the complete vector heat method implementation in bct
%
% Tests:
% 1. DEC weights computation in geometry
% 2. Connection Laplacian assembly
% 3. Field conversion to tangent vectors
% 4. High-level vectorHeat API
% 5. Comparison with reference implementation (HeatVector.m)

clear; clc;

addpath('toolbox');
bct.start;

%% Load canonical test manifold
fprintf('=== Vector Heat Method Development Test ===\n\n');
fprintf('Loading canonical test manifold...\n');
M = bct.data.load('Dataset', 'fsaverage6', 'Hemi', 'rh', 'Surface', 'pial');
fprintf('  Loaded: |V|=%d, |F|=%d\n\n', size(M.Vertices,1), size(M.Faces,1));

%% Test 1: DEC weights in geometry package
fprintf('Test 1: DEC weights computation\n');
fprintf('--------------------------------------\n');

geom = M.geometry('includeDual', true);

% Check that weights_dec exists
assert(isfield(geom.edge, 'weights_dec'), 'geometry.edge.weights_dec not found');

wDec = geom.edge.weights_dec.value;
wCot = geom.edge.weights_cotangent.value;
wEuc = geom.edge.weights_euclidean.value;

nE = size(M.Edges, 1);
assert(numel(wDec) == nE, 'DEC weights wrong size');
assert(all(wDec >= 0), 'DEC weights should be non-negative');

fprintf('  DEC weights: min=%.3e, max=%.3e, mean=%.3e\n', ...
    min(wDec), max(wDec), mean(wDec));
fprintf('  Range: [%.3f, %.3f]\n', min(wDec), max(wDec));
fprintf('  ✓ DEC weights computed successfully\n\n');

%% Test 2: Connection Laplacian assembly
fprintf('Test 2: Connection Laplacian assembly\n');
fprintf('--------------------------------------\n');

% Create connection with two singularities
antIdx = 6653;
postIdx = 978;

conn = M.connection('trivial', ...
    'singularities', [antIdx, postIdx], ...
    'weights', [1, 1]);

delta = conn.combinedTransport.value;

% Assemble connection Laplacian
[header, Lconn] = bct.manifold.operator.connectionLaplacian(M, delta);

nF = size(M.Faces, 1);
assert(all(size(Lconn) == [nF, nF]), 'Lconn wrong size');
assert(~isreal(Lconn), 'Lconn should be complex');

% Check Hermitian property
hermErr = norm(Lconn - Lconn', 'fro') / norm(Lconn, 'fro');
fprintf('  Hermitian error: %.3e\n', hermErr);
assert(hermErr < 1e-10, 'Lconn not Hermitian');

% Check PSD property (sample test)
ztest = randn(nF,1) + 1i*randn(nF,1);
q = real(ztest' * (Lconn * ztest));
fprintf('  PSD test: z^H*L*z = %.3e (should be >= 0)\n', q);
assert(q >= -1e-10, 'Lconn not PSD');

fprintf('  Matrix properties:\n');
fprintf('    Size: %d × %d\n', nF, nF);
fprintf('    Nonzeros: %d (%.2f%% sparse)\n', nnz(Lconn), 100*(1-nnz(Lconn)/nF^2));
fprintf('    Complex: %s\n', mat2str(~isreal(Lconn)));
fprintf('    Hermitian: %s (err=%.2e)\n', mat2str(hermErr < 1e-10), hermErr);
fprintf('  ✓ Connection Laplacian assembled correctly\n\n');

%% Test 3: Complex to tangent conversion
fprintf('Test 3: Complex field to tangent conversion\n');
fprintf('--------------------------------------\n');

% Create simple test field
z = randn(nF,1) + 1i*randn(nF,1);
z = z / norm(z);

% Convert without normalization
result1 = bct.field.toTangent(M, z, 'Normalize', false);
assert(all(size(result1.vectors) == [nF, 3]), 'vectors wrong size');
assert(numel(result1.magnitude) == nF, 'magnitude wrong size');

% Convert with normalization
result2 = bct.field.toTangent(M, z, 'Normalize', true, 'MaskPercentile', 20);
assert(result2.normalized == true, 'normalization flag wrong');
assert(sum(result2.mask) > 0, 'no vectors in mask');

% Check orthogonality to normals
Nf = geom.face.normals.value;
mask = result2.mask;
dotProd = sum(result2.vectors(mask,:) .* Nf(mask,:), 2);
maxDot = max(abs(dotProd));
fprintf('  Max |dot(vector, normal)| = %.3e (should be ~0)\n', maxDot);
assert(maxDot < 1e-6, 'Vectors not tangent to surface');

% Check normalization
norms = vecnorm(result2.vectors(mask,:), 2, 2);
normErr = max(abs(norms - 1));
fprintf('  Max ||vector|| - 1 = %.3e (should be ~0)\n', normErr);
assert(normErr < 1e-10, 'Normalized vectors not unit');

fprintf('  Conversion statistics:\n');
fprintf('    Total faces: %d\n', nF);
fprintf('    Masked faces (top 20%%): %d\n', sum(mask));
fprintf('    Magnitude range: [%.3e, %.3e]\n', min(result1.magnitude), max(result1.magnitude));
fprintf('  ✓ Conversion to tangent vectors correct\n\n');

%% Test 4: High-level vectorHeat API
fprintf('Test 4: High-level vectorHeat API\n');
fprintf('--------------------------------------\n');

% Test 4a: Single face seed
result = bct.field.generate.vectorHeat(M, ...
    'SeedFace', 1, ...
    'SeedDirection', 0, ...
    'Singularities', [antIdx, postIdx], ...
    'Weights', [1, 1]);

assert(isfield(result, 'vectors'), 'result missing vectors');
assert(isfield(result, 'magnitude'), 'result missing magnitude');
assert(isfield(result, 'complexField'), 'result missing complexField');
assert(isfield(result, 'connection'), 'result missing connection');
assert(isfield(result, 'solver'), 'result missing solver');

fprintf('  Single face seed:\n');
fprintf('    Diffusion time: t = %.4g\n', result.diffusionTime);
fprintf('    Solver residual: %.3e\n', result.solver.residual);
fprintf('    Magnitude range: [%.3e, %.3e]\n', min(result.magnitude), max(result.magnitude));
fprintf('    Masked vectors: %d (%.1f%%)\n', sum(result.mask), 100*mean(result.mask));

% Check solver residual
assert(result.solver.residual < 1e-8, 'Solver residual too large');
fprintf('  ✓ Single face seed successful\n');

% Test 4b: Patch seed
patchResult = bct.field.generate.vectorHeat(M, ...
    'SeedPatch', struct('center', antIdx, 'radius', 5, 'direction', pi/4), ...
    'TimeMultiplier', 16);

fprintf('\n  Patch seed (vertex %d, radius 5%%):\n', antIdx);
fprintf('    Diffusion time: t = %.4g\n', patchResult.diffusionTime);
fprintf('    Solver residual: %.3e\n', patchResult.solver.residual);
fprintf('    Masked vectors: %d (%.1f%%)\n', sum(patchResult.mask), 100*mean(patchResult.mask));

assert(patchResult.solver.residual < 1e-8, 'Patch solver residual too large');
fprintf('  ✓ Patch seed successful\n\n');

%% Test 5: Comparison with reference implementation
fprintf('Test 5: Comparison with HeatVector.m reference\n');
fprintf('--------------------------------------\n');

% Run reference calculation (simplified from HeatVector.m)
topo = M.topology();
nH = numel(topo.face.value);
faceH = topo.face.value;
twinH = topo.twin.value;
edgeH = topo.edge.value;

% Get geometry
t1 = double(geom.face.tangent1.value);
t2 = double(geom.face.tangent2.value);
Af = double(geom.face.areas.value);
Mf = spdiags(Af(:), 0, nF, nF);

% Use same connection
delta_ref = double(conn.combinedTransport.value(:));
R_h = exp(1i * delta_ref);

% DEC weights (reference implementation)
ell = double(geom.edge.lengths.value(:));
ellDualRaw = double(geom.dual.edgeLengths.value(:));
if numel(ellDualRaw) == nH
    ellD = accumarray(double(edgeH), ellDualRaw, [nE 1], @mean, 0);
else
    ellD = ellDualRaw;
end
wE_ref = ellD ./ max(ell, 1e-12);
wE_ref = max(wE_ref, 0);

% Assemble Lconn (reference)
repH = accumarray(double(edgeH), (1:nH).', [nE 1], @(x)x(1), 0);
eIdx = find(repH > 0);
h = repH(eIdx);
ht = double(twinH(h));
i = double(faceH(h));
j = double(faceH(ht));
okE = (ht > 0) & (i > 0) & (j > 0);
h = h(okE); ht = ht(okE); i = i(okE); j = j(okE); eIdx = eIdx(okE);
w = wE_ref(eIdx);
keepW = (w > 0);
h = h(keepW); i = i(keepW); j = j(keepW); w = w(keepW);
Rij = R_h(h);
Rji = conj(Rij);
I = [i; j; i; j];
J = [i; j; j; i];
S = [w; w; -w .* Rij; -w .* Rji];
Lconn_ref = sparse(I, J, S, nF, nF);
Lconn_ref = (Lconn_ref + Lconn_ref')/2;

% Compare Laplacians
Ldiff = norm(Lconn - Lconn_ref, 'fro') / norm(Lconn_ref, 'fro');
fprintf('  Relative Laplacian difference: %.3e\n', Ldiff);
assert(Ldiff < 1e-12, 'Laplacian differs from reference');

% Solve with same seed
meanEll = mean(ell);
t = meanEll^2 * 16;
z0 = complex(zeros(nF,1));
z0(1) = 1;

Hvec_ref = Mf + t * Lconn_ref;
Hvec_ref = (Hvec_ref + Hvec_ref')/2;
Hchol_ref = decomposition(Hvec_ref, 'chol');
z_ref = Hchol_ref \ (Mf * z0);

% Compare solutions
resultRef = bct.field.generate.vectorHeat(M, ...
    'SeedFace', 1, ...
    'SeedDirection', 0, ...
    'Connection', conn, ...
    'DiffusionTime', t, ...
    'Normalize', false);

zDiff = norm(resultRef.complexField - z_ref) / norm(z_ref);
fprintf('  Relative solution difference: %.3e\n', zDiff);
assert(zDiff < 1e-10, 'Solution differs from reference');

fprintf('  ✓ Implementation matches reference\n\n');

%% Summary
fprintf('===========================================\n');
fprintf('All tests passed ✓\n');
fprintf('===========================================\n');
fprintf('\nImplemented components:\n');
fprintf('  1. bct.manifold.geometry.edge.weights (DEC weights)\n');
fprintf('  2. bct.manifold.operator.connectionLaplacian\n');
fprintf('  3. bct.field.toTangent\n');
fprintf('  4. bct.field.generate.vectorHeat\n');
fprintf('\nVector heat method is ready for use!\n');
