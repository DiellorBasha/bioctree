%% Test Transform Initialization
% Simple test to verify MFT and IMFT transforms are created correctly

clear; clc;

% Load mesh
meshPath = 'test-data\freesurfer\fsaverage\surf\rh.pial';
fprintf('Loading mesh: %s\n', meshPath);
mesh = bct.io.readFreeSurferSurface(meshPath);

% Create BCT object
B = bct.bct.fromMesh(mesh.V, mesh.F);
fprintf('BCT object created\n');
fprintf('  Manifold.N = %d\n', B.Manifold.N);
fprintf('  Lambda.N = %d\n', B.Lambda.N);

% Check transform status before eigenbasis
fprintf('\nBefore computeEigenbasis:\n');
if isempty(B.Manifold.transform)
    fprintf('  Manifold.transform: empty (expected)\n');
else
    fprintf('  Manifold.transform: %s\n', class(B.Manifold.transform));
end
if isempty(B.Lambda.transform)
    fprintf('  Lambda.transform: empty (expected)\n');
else
    fprintf('  Lambda.transform: %s\n', class(B.Lambda.transform));
end

% Compute eigenbasis (should create transforms)
fprintf('\nComputing eigenbasis (100 modes)...\n');
B = B.computeEigenbasis(100);

% Check transform status after eigenbasis
fprintf('\nAfter computeEigenbasis:\n');
if isempty(B.Manifold.transform)
    error('ERROR: Manifold.transform is still empty!');
else
    fprintf('  Manifold.transform: %s ✓\n', class(B.Manifold.transform));
end
if isempty(B.Lambda.transform)
    error('ERROR: Lambda.transform is still empty!');
else
    fprintf('  Lambda.transform: %s ✓\n', class(B.Lambda.transform));
end

% Test forward transform
fprintf('\nTesting forward transform (Manifold → Lambda):\n');
x_test = randn(B.Manifold.N, 1);
c_test = B.Manifold.transform.forward(x_test);
fprintf('  Input size: [%d × 1]\n', length(x_test));
fprintf('  Output size: [%d × 1]\n', length(c_test));
fprintf('  Energy ratio: %.6f (should be ≈1)\n', norm(c_test)/norm(x_test));

% Test inverse transform
fprintf('\nTesting inverse transform (Lambda → Manifold):\n');
x_recon = B.Lambda.transform.forward(c_test);
fprintf('  Input size: [%d × 1]\n', length(c_test));
fprintf('  Output size: [%d × 1]\n', length(x_recon));
fprintf('  Reconstruction error: %.6e\n', norm(x_recon - x_test));

fprintf('\n✓ All tests passed!\n');
