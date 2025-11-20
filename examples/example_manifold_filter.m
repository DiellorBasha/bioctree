%% Example: Using Manifold Gaussian Filter
% This example shows how to design a spatial filter and generate signals

clear; close all;

%% 1. Load mesh and compute eigendecomposition
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.import.mesh(path);

% Resolution is auto-created with lambda_max, just compute eigenmodes
B.Manifold.meshFourier(200);

%% 2. Design Gaussian manifold filter
filt = bct.filters.Filter('Manifold');
filt.Manifold = B.Manifold;

% Design filter: Gaussian centered at lambda0 with bandwidth sigma
filt.g = bct.filters.design.manifold.gaussian(B.Manifold, ...
    'lambda0', 50, ...
    'sigma', 20);

filt.lambda_band = [10, 110];  % 3-sigma support
filt.KernelType = "gaussian";

% Add to filterbank
B.addFilter(filt);

%% 3. Synthesize spectral coefficients
B.Synthesize(1);  % Use filter #1

%% 4. Generate signal
sig = B.Generate('label', 'my_signal');

%% 5. Visualize
figure;
trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
    sig.Data, 'EdgeColor', 'none');
axis equal; axis off; view(-90, 0);
colorbar;
title('Generated Signal');
