%% BCT UI Demo - Basic Manifold Visualization
% This script demonstrates basic visualization using the bct.ui system.
% Shows how to load and visualize a Manifold using bct.ui.show().

%% Initialize workspace
clearvars; close all;

% Ensure bioctree is initialized
if ~exist('bct.Manifold', 'class')
    error('bioctree toolbox not initialized. Run bioctree_start first.');
end

%% Load Manifold from default mesh
% Load the default fsaverage6 mesh from bct.data
mesh = bct.data.load();  % Default: fsaverage6 left hemisphere pial
M = bct.manifold.load(mesh);

disp(['Loaded: ' mesh.Meta.Id]);
disp(['Vertices: ' num2str(size(M.Vertices, 1))]);
disp(['Faces: ' num2str(size(M.Faces, 1))]);

%% Visualize using bct.ui.show
% The bct.ui.show() function automatically creates a figure with uigridlayout
% and displays the manifold with an appropriate inspector

[inspector, fig] = bct.ui.show(M);

% The inspector provides interactive controls for the manifold
disp('Manifold visualization created successfully!');
disp('Use the inspector controls to interact with the visualization.');
