% demo_viewer_setMesh.m
% Demonstrates using bct.ui.manifold.Viewer with setMesh method
%
% This demo shows how to:
% 1. Create a Viewer component in a uifigure
% 2. Load mesh data from MATLAB (V, F)
% 3. Display it in the three.js viewer

%% Setup
close all;

%% Load mesh data
% Use the standard fsaverage test mesh
meshFile = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');
if ~isfile(meshFile)
    error('Test mesh not found: %s', meshFile);
end

data = load(meshFile);
V = data.V;  % Vertices [N×3] double
F = data.F;  % Faces [M×3] uint32 (1-based)

fprintf('Loaded mesh: %d vertices, %d faces\n', size(V, 1), size(F, 1));

%% Create figure and viewer
fig = uifigure('Position', [100 100 1200 800], 'Name', 'BCT Manifold Viewer - setMesh Demo');
gr = uigridlayout(fig, [1 1]);
gr.RowHeight = {'1x'};
gr.ColumnWidth = {'1x'};

%% Create viewer (initially empty)
v = bct.ui.manifold.Viewer(gr);
v.Layout.Row = 1;
v.Layout.Column = 1;

%% Set mesh data
% This will trigger the JavaScript viewer to display the mesh
v.setMesh(V, F);

fprintf('Mesh sent to viewer. The three.js visualization should now display.\n');
fprintf('Use mouse to interact:\n');
fprintf('  - Left click + drag: rotate\n');
fprintf('  - Right click + drag: pan\n');
fprintf('  - Scroll: zoom\n');
