%% Test Resolution auto-computation on Manifold construction
clear all;

% Import mesh
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
fprintf('Loading mesh from: %s\n', path);
B = bct.io.import.mesh(path);

% Check Manifold properties
fprintf('\n=== Manifold Properties ===\n');
fprintf('Type: %s\n', B.Manifold.Type);
fprintf('NumVertices: %d\n', B.Manifold.N);
fprintf('NumModes: %d\n', B.Manifold.NumModes);
fprintf('LaplacianType: %s\n', B.Manifold.LaplacianType);
fprintf('MassMatrix size: %s\n', mat2str(size(B.Manifold.MassMatrix)));

% Check Resolution
fprintf('\n=== Resolution Property ===\n');
res = B.Manifold.Resolution;
fprintf('lambda_max: %.4f\n', res.lambda_max);
fprintf('k (wavenumber): %.4f rad/mm\n', res.k);
fprintf('freq: %.4f Hz (spatial)\n', res.freq);
fprintf('wavelength: %.4f mm\n', res.wavelength);

% Now compute eigenmodes
fprintf('\n=== Computing 600 eigenmodes ===\n');
B.Manifold.meshFourier(600);
fprintf('NumModes after meshFourier(600): %d\n', B.Manifold.NumModes);
fprintf('Eigenvalues range: [%.6f, %.6f]\n', min(B.Manifold.Eigenvalues), max(B.Manifold.Eigenvalues));
fprintf('Resolution lambda_max: %.4f (should be >> max eigenvalue)\n', B.Manifold.Resolution.lambda_max);
