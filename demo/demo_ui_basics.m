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
% The bct.ui.show() function automatically:
%   1. Creates a figure with uigridlayout
%   2. Selects appropriate inspector via registry (bct.ui.manifold.Inspector)
%   3. Uses bct.ui.data.manifoldToMesh adapter to extract Vertices/Faces
%   4. Displays the manifold with interactive controls

[inspector, fig] = bct.ui.show(M);

disp(' ');
disp('✓ Manifold visualization created successfully!');
disp('✓ Inspector: bct.ui.manifold.Inspector');
disp('✓ Interactive controls available');

%% Optional: Customize the visualization
% You can also specify custom title and position
% [inspector, fig] = bct.ui.show(M, 'Title', 'My Manifold', 'Position', [100 100 800 600]);

%% Optional: List available inspectors
% See what other inspectors are registered
inspectors = bct.ui.listInspectors();
disp(' ');
disp(['Available inspectors: ' num2str(length(inspectors))]);
for i = 1:length(inspectors)
    disp(['  - ' char(inspectors(i).Id) ' (' char(inspectors(i).Class) ')']);
end
