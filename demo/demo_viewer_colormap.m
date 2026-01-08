%% Demo: Interactive Colormap Control for Scalar Visualization
%
% Demonstrates the JavaScript-side colormap control system for scalar
% data visualization. The colormap is controlled via a GUI dropdown
% in the visualization controls panel, not from MATLAB.
%
% Architecture:
% - MATLAB: sends only scalar data (no colormap/clim parameters)
% - JavaScript: handles all visualization parameters via GUI controls
% - Pattern: follows three.js geometrycolorslut.md example
%
% Usage:
%   demo_viewer_colormap

%% Initialize BCT
bct_start;

%% Load test mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
M = bct.Manifold(data.V, data.F);

%% Generate test scalar field
% Sine wave pattern on surface
fScalar = sin(5*M.Vertices(:,1)) .* cos(3*M.Vertices(:,2));

%% Create viewer and visualize
v = bct.ui.manifold.Viewer;
v.setMesh(M);
v.setScalar(fScalar);

%% Instructions
fprintf('\n=== Interactive Colormap Control Demo ===\n');
fprintf('The mesh is now displayed with scalar colors.\n\n');
fprintf('To change the colormap:\n');
fprintf('1. Open the Visualization Controls panel (top-right)\n');
fprintf('2. Expand the "Scalar" folder\n');
fprintf('3. Select a different colormap from the dropdown\n\n');
fprintf('Available colormaps:\n');
fprintf('  - viridis (default)\n');
fprintf('  - plasma\n');
fprintf('  - inferno\n');
fprintf('  - magma\n');
fprintf('  - turbo\n');
fprintf('  - rainbow\n');
fprintf('  - hot\n');
fprintf('  - cool\n');
fprintf('  - cooltowarm\n\n');
fprintf('The colormap will update immediately when you change the selection.\n');
fprintf('Color limits are automatically computed from the data range.\n');
