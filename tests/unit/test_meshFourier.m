% test_meshFourier - Test script for Manifold.meshFourier method
%
% This script demonstrates the usage of the meshFourier method in the
% Manifold class for computing and caching the mesh Fourier basis.

%% Create a simple mesh manifold
% Using icosphere as example (requires external/icosphere.m)
[V, F] = icosphere(3);  % 642 vertices

% Create Manifold object
mani = bct.manifold.Manifold(V, F);

fprintf('Created mesh manifold with %d vertices and %d faces\n', ...
    size(mani.V, 1), size(mani.F, 1));

%% Compute mesh Fourier basis with default parameters (k=600 modes)
fprintf('\nComputing mesh Fourier basis...\n');
[U, lam] = mani.meshFourier();

fprintf('Computed %d Fourier modes\n', length(lam));
fprintf('Eigenvalue range: [%.6f, %.6f]\n', min(lam), max(lam));

%% Verify properties are set
fprintf('\nVerifying cached properties:\n');
fprintf('  Eigenvectors size: [%d x %d]\n', size(mani.Eigenvectors));
fprintf('  Eigenvalues size: [%d x 1]\n', length(mani.Eigenvalues));
fprintf('  NumModes: %d\n', mani.NumModes);
fprintf('  MassMatrix size: [%d x %d]\n', size(mani.MassMatrix));
fprintf('  LaplacianType: %s\n', mani.LaplacianType);

%% Test signal projection and reconstruction
fprintf('\nTesting signal projection and reconstruction...\n');

% Create a synthetic signal (e.g., based on z-coordinate)
signal = V(:, 3);  % z-coordinate

% Project onto first 50 modes
nModes = 50;
Sinv = spdiags(1./sqrt(full(diag(mani.MassMatrix))), 0, size(V,1), size(V,1));
coeffs = mani.Eigenvectors(:, 1:nModes)' * (Sinv * signal);

% Reconstruct
signal_recon = mani.Eigenvectors(:, 1:nModes) * coeffs;

% Compute reconstruction error
rel_error = norm(signal - signal_recon) / norm(signal);
fprintf('Relative reconstruction error (50 modes): %.6f\n', rel_error);

%% Test with custom k parameter
fprintf('\nComputing with custom k=100 modes...\n');
[U2, lam2, K, M] = mani.meshFourier(100);

fprintf('Computed %d modes\n', mani.NumModes);
fprintf('K matrix size: [%d x %d], nnz: %d\n', size(K, 1), size(K, 2), nnz(K));
fprintf('M matrix size: [%d x %d], nnz: %d\n', size(M, 1), size(M, 2), nnz(M));

%% Visualize first few eigenmodes
fprintf('\nVisualizing first 4 eigenmodes...\n');
figure('Name', 'Mesh Fourier Basis Functions');
for i = 1:4
    subplot(2, 2, i);
    trisurf(F, V(:,1), V(:,2), V(:,3), mani.Eigenvectors(:,i), ...
        'EdgeColor', 'none', 'FaceColor', 'interp');
    axis equal off;
    colorbar;
    title(sprintf('Mode %d (\\lambda = %.4f)', i, mani.Eigenvalues(i)));
    view(3);
    lighting gouraud;
    camlight;
end

fprintf('\nTest completed successfully!\n');

