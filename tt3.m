clear B
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.import.mesh(path);
B.Manifold  % Now contains the mesh topology

pathBst = 'Z:\brainstorm_protocols\TutorialOmega'

% Compute Fourier basis
[U, lam] = B.Manifold.meshFourier(200);


% Narrowband signal
spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;
[x, coeffs, freqs] = bct.sim.synth_mesh_signal(B, spec);

% 1/f noise
spec.type = 'powerlaw';
spec.alpha = 1;
x = bct.sim.synth_mesh_signal(B, spec, 'k', 300);

%% Create a mesh manifold from icosphere
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.graph.Import.fromFreeSurfer(path);

% Load FreeSurfer mesh
B = bct.io.mesh.Import.fromFreeSurfer(path);

% Access Manifold object
B.Manifold  % Now contains the mesh topology

% Compute Fourier basis
[U, lam] = B.Manifold.meshFourier(200);

% Access cached spectral properties
B.Manifold.Eigenvectors
B.Manifold.Eigenvalues
B.Manifold.NumModes
B.Manifold.MassMatrix
B.Manifold.LaplacianType


[V, F] = icosphere(3);  % 642 vertices

% Create Manifold object
% Create Manifold object
mani = bct.manifold.Manifold(V, F);

% Compute mesh Fourier basis
[U, lam] = mani.meshFourier(200);

% Now check - properties should be populated!
maniMesh = surfaceMesh(mani.V, mani.F)
fprintf('Computed %d Fourier modes\n', mani.NumModes);
fprintf('Eigenvalue range: [%.6f, %.6f]\n', min(lam), max(lam));
fprintf('LaplacianType: %s\n', mani.LaplacianType);

%% Create a test signal on the mesh
% Example: smooth signal based on spherical harmonic-like pattern
signal = sin(3*V(:,1)) .* cos(2*V(:,2));


% Visualize original signal
figure;
subplot(1,3,1);
trisurf(F, V(:,1), V(:,2), V(:,3), signal, 'EdgeColor', 'none');
axis equal off; colorbar; title('Original Signal');
view(3); lighting gouraud; camlight;

%% Project signal onto Fourier basis
% Get mass matrix inverse for proper inner product
d = full(diag(mani.MassMatrix));
Sinv = spdiags(1./sqrt(d), 0, length(d), length(d));

% Project: coefficients = U' * Sinv * signal
coeffs = mani.Eigenvectors' * (Sinv * signal);

% Low-pass filter: keep only first 50 modes
nModes = 50;
coeffs_lowpass = coeffs;
coeffs_lowpass(nModes+1:end) = 0;

% Reconstruct
signal_filtered = mani.Eigenvectors * coeffs_lowpass;

% Visualize filtered signal
subplot(1,3,2);
trisurf(F, V(:,1), V(:,2), V(:,3), signal_filtered, 'EdgeColor', 'none');
axis equal off; colorbar; title(sprintf('Low-pass (%d modes)', nModes));
view(3); lighting gouraud; camlight;

% Visualize difference (high-frequency component)
subplot(1,3,3);
trisurf(F, V(:,1), V(:,2), V(:,3), signal - signal_filtered, 'EdgeColor', 'none');
axis equal off; colorbar; title('High-frequency component');
view(3); lighting gouraud; camlight;

%% Access cached properties
fprintf('\nCached properties:\n');
fprintf('  Eigenvectors: [%d x %d]\n', size(mani.Eigenvectors));
fprintf('  Eigenvalues: [%d x 1]\n', length(mani.Eigenvalues));
fprintf('  MassMatrix: [%d x %d] (nnz=%d)\n', size(mani.MassMatrix), nnz(mani.MassMatrix));

%% Visualize some eigenmodes (Fourier basis functions)
figure('Name', 'First 6 Eigenmodes');
for i = 1:6
    subplot(2,3,i);
    trisurf(F, V(:,1), V(:,2), V(:,3), mani.Eigenvectors(:,i), ...
        'EdgeColor', 'none', 'FaceColor', 'interp');
    axis equal off;
    title(sprintf('Mode %d (\\lambda=%.4f)', i, mani.Eigenvalues(i)));
    view(3); lighting gouraud; camlight;
end