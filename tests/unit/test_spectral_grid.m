% Test script for SpectralGrid functionality
% Tests the new joint mesh-time spectral grid in bct class

clear; close all;

% Initialize bioctree (adds all paths including gptoolbox)
bioctree_start();

% Load FreeSurfer mesh
fprintf('\n=== Loading FreeSurfer mesh ===\n');
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
[V, F] = in_fs_read_surf(path);

% Create bct object with mesh manifold
fprintf('Creating bct object...\n');
B2 = bct.bct();
B2.Manifold = bct.manifold.Manifold(V, F);

% Add time dimension (100 samples @ 100 Hz = 1 second)
fprintf('Adding time dimension (100 samples @ 100 Hz)...\n');
B2.Time = bct.manifold.Time(100, 100);

% Build spectral grid with small lambda band for testing
fprintf('Building spectral grid for lambda band [0, 5]...\n');
tic;
B2.buildSpectralGrid([0, 5]);
elapsed = toc;

% Display results
fprintf('\n=== SpectralGrid Test Results ===\n');
fprintf('Build time: %.2f seconds\n', elapsed);
fprintf('Lambda grid size: %d x %d\n', size(B2.SpectralGrid.lambda_grid, 1), size(B2.SpectralGrid.lambda_grid, 2));
fprintf('Time grid size: %d x %d\n', size(B2.SpectralGrid.t_grid, 1), size(B2.SpectralGrid.t_grid, 2));
fprintf('Number of modes in band: %d\n', length(B2.SpectralGrid.lambda_band));
fprintf('Time points: %d\n', length(B2.SpectralGrid.t));
fprintf('Eigenvalue range: [%.4f, %.4f]\n', min(B2.SpectralGrid.lambda_band), max(B2.SpectralGrid.lambda_band));
fprintf('Time range: [%.4f, %.4f] seconds\n', min(B2.SpectralGrid.t), max(B2.SpectralGrid.t));

% Verify grid construction
fprintf('\n=== Verification ===\n');
fprintf('Grid shape matches [numModes × T]: %s\n', ...
    isequal(size(B2.SpectralGrid.lambda_grid), [length(B2.SpectralGrid.lambda_band), length(B2.SpectralGrid.t)]));

% Test hasSpectralGrid
fprintf('hasSpectralGrid(): %s\n', mat2str(B2.hasSpectralGrid()));

% Test clearSpectralGrid
fprintf('\nClearing spectral grid...\n');
B2.clearSpectralGrid();
fprintf('hasSpectralGrid() after clear: %s\n', mat2str(B2.hasSpectralGrid()));

fprintf('\n=== Test completed successfully! ===\n');
