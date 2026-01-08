%% Demo: Scalar Visualization with Colorbar
% Demonstrates the colorbar UI overlay for scalar field visualization
%
% Features:
% - Vertical gradient bar showing the current colormap
% - Min/max value labels
% - Toggle on/off via visualization controls
% - Automatically updates when colormap or data changes

clear; close all;

%% Load mesh
fprintf('Loading mesh...\n');
meshFile = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');
data = load(meshFile);
V = data.V;
F = data.F;
fprintf('  Loaded: %d vertices, %d faces\n', size(V,1), size(F,1));

%% Create Viewer
fprintf('\nInitializing viewer...\n');
v = bct.ui.manifold.Viewer();
v.setMesh(V, F);
fprintf('  Mesh loaded into viewer\n');

%% Generate scalar field (Gaussian blob)
fprintf('\nGenerating scalar field...\n');

% Pick a random vertex as center
centerIdx = randi(size(V,1));
centerPos = V(centerIdx, :);

% Compute distances from center
distances = vecnorm(V - centerPos, 2, 2);

% Create Gaussian blob
sigma = 15;  % Controls spread
fScalar = exp(-(distances.^2) / (2 * sigma^2));

% Add some noise for visual interest
fScalar = fScalar + 0.05 * randn(size(fScalar));

fprintf('  Scalar range: [%.3f, %.3f]\n', min(fScalar), max(fScalar));

%% Apply scalar field
fprintf('\nApplying scalar field to mesh...\n');
v.setScalar(fScalar);
fprintf('  Done!\n');

%% Instructions
fprintf('\n=== COLORBAR DEMO ===\n');
fprintf('The colorbar is now visible in the top-right corner.\n\n');
fprintf('Try these controls in the "Field" folder:\n');
fprintf('  • Show Colorbar - Toggle colorbar on/off\n');
fprintf('  • Colormap - Change color scheme (watch colorbar update)\n');
fprintf('  • Auto Range - Toggle automatic min/max scaling\n\n');
fprintf('The colorbar shows:\n');
fprintf('  • Current colormap as vertical gradient\n');
fprintf('  • Maximum value at top\n');
fprintf('  • Minimum value at bottom\n');
fprintf('  • Automatic formatting (scientific notation for large values)\n\n');
fprintf('Note: Colorbar is initially HIDDEN. Enable it in Field > Show Colorbar\n');
