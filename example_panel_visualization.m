% Example: Using B.showMesh with uipanel parent
% This demonstrates how to embed Bct visualization inside a uipanel

clear; close all;
bioctree_start;

% Load mesh
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);

% Create figure and panel
fig = uifigure('Name', 'Bct Mesh in Panel', 'Position', [100 100 800 600]);
panel = uipanel(fig, 'Position', [10 10 780 580], 'Title', 'Brain Mesh Visualization');

% Show mesh inside the panel
B.showMesh('Parent', panel);

% The viewer3d is now a child of the panel
fprintf('Viewer created: %s\n', class(B.Viewer));
fprintf('Viewer parent: %s\n', class(B.Viewer.Parent));
