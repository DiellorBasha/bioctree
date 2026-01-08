%% demo_viewer_scalar.m
% Demonstrates scalar field visualization in bct.ui.manifold.Viewer
%
% This demo shows:
%   1. Loading a mesh with bct.Manifold
%   2. Creating scalar data (e.g., distance from centroid)
%   3. Visualizing scalar data with different colormaps
%   4. Updating scalar data dynamically
%   5. Clearing scalar visualization

%% Initialize
clear; close all; clc;

% Load mesh data
fprintf('Loading fsaverage right hemisphere mesh...\n');
meshFile = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');
if ~isfile(meshFile)
    error('Mesh file not found: %s', meshFile);
end
data = load(meshFile);
V = data.V;
F = data.F;
fprintf('  Loaded: %d vertices, %d faces\n', size(V,1), size(F,1));

%% Create Manifold object
fprintf('\nCreating bct.Manifold object...\n');
M = bct.Manifold(V, F);

%% Create viewer
fprintf('\nCreating viewer...\n');
gr = groot;
v = bct.ui.manifold.Viewer(gr);
v.HTMLComponent.Position = [10 10 1200 800];

%% Load mesh
fprintf('\nLoading mesh into viewer...\n');
v.setMesh(M);
pause(1.0);  % Wait for rendering

%% Example 1: Distance from centroid
fprintf('\n=== EXAMPLE 1: Distance from Centroid ===\n');

% Compute centroid
centroid = mean(V, 1);

% Compute distance from centroid
distances = sqrt(sum((V - centroid).^2, 2));

% Visualize with viridis colormap (default)
fprintf('Visualizing distances with viridis colormap...\n');
v.setScalar(distances);
pause(2.0);

%% Example 2: Change colormap
fprintf('\n=== EXAMPLE 2: Different Colormaps ===\n');

colormaps = {'viridis', 'turbo', 'rainbow', 'hot', 'cooltowarm', 'grayscale'};

for i = 1:length(colormaps)
    fprintf('Colormap: %s\n', colormaps{i});
    v.setScalar(distances, 'colormap', colormaps{i});
    pause(1.5);
end

%% Example 3: Custom color limits
fprintf('\n=== EXAMPLE 3: Custom Color Limits ===\n');

% Use narrower range to emphasize certain features
dataRange = [min(distances), max(distances)];
fprintf('Data range: [%.2f, %.2f]\n', dataRange(1), dataRange(2));

% Show middle 50% of range
midRange = [prctile(distances, 25), prctile(distances, 75)];
fprintf('Using color limits: [%.2f, %.2f] (middle 50%%)\n', midRange(1), midRange(2));

v.setScalar(distances, 'colormap', 'viridis', 'clim', midRange);
pause(2.0);

%% Example 4: Coordinate-based coloring
fprintf('\n=== EXAMPLE 4: Coordinate-Based Coloring ===\n');

% Color by X coordinate
fprintf('Coloring by X coordinate...\n');
v.setScalar(V(:,1), 'colormap', 'cooltowarm');
pause(2.0);

% Color by Y coordinate
fprintf('Coloring by Y coordinate...\n');
v.setScalar(V(:,2), 'colormap', 'cooltowarm');
pause(2.0);

% Color by Z coordinate
fprintf('Coloring by Z coordinate...\n');
v.setScalar(V(:,3), 'colormap', 'cooltowarm');
pause(2.0);

%% Example 5: Gaussian random field
fprintf('\n=== EXAMPLE 5: Random Gaussian Field ===\n');

% Generate random scalar field
randomField = randn(size(V,1), 1);

fprintf('Visualizing random Gaussian field...\n');
v.setScalar(randomField, 'colormap', 'turbo');
pause(2.0);

%% Example 6: Clear visualization
fprintf('\n=== EXAMPLE 6: Clear Scalar Visualization ===\n');

fprintf('Clearing scalar visualization (back to uniform gray)...\n');
v.setScalar([]);  % Empty array clears visualization
pause(2.0);

%% Example 7: Restore distance visualization
fprintf('\n=== EXAMPLE 7: Restore Distance Visualization ===\n');

fprintf('Restoring distance from centroid with viridis colormap...\n');
v.setScalar(distances, 'colormap', 'viridis');

%% Check logs
pause(1.0);
logs = v.getLogs();
fprintf('\n=== JavaScript Logs ===\n%s\n', logs);

%% Summary
fprintf('\n=== DEMO COMPLETE ===\n');
fprintf('The viewer now shows scalar data mapped to vertex colors.\n');
fprintf('You can:\n');
fprintf('  - Rotate the view with mouse\n');
fprintf('  - Update scalar data: v.setScalar(newData)\n');
fprintf('  - Change colormap: v.setScalar(data, ''colormap'', ''turbo'')\n');
fprintf('  - Set color limits: v.setScalar(data, ''clim'', [min max])\n');
fprintf('  - Clear colors: v.setScalar([])\n');
fprintf('\nType "return" to continue or close figure to exit.\n');
keyboard;
