%% demo_manifold.m
% Basic demonstration of bct.Manifold visualization
%
% This demo shows different mesh loading approaches:
%   1. Manual file loading - for custom/external mesh files
%   2. Catalog-based loading - for bundled datasets (bct.data.load)
%   3. File format loading - for standard mesh formats (bct.manifold.read)
%
% RECOMMENDED APIS:
%   - bct.data.load()      - Bundled catalog assets (Brainstorm, fsaverage)
%   - bct.manifold.read()  - Standard formats (.obj, .stl, .ply, .glb, .gltf)
%   - bct.manifold.load()  - Generic .mat files or struct/object conversion

%% Initialize
clear; close all; clc;

%% EXAMPLE 1: Manual file loading (for custom external files)
fprintf('=== EXAMPLE 1: Manual file loading ===\n');
fprintf('Loading fsaverage right hemisphere mesh from file...\n');
fprintf('API: Manual load() for custom/external mesh files\n\n');

meshFile = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');

if ~isfile(meshFile)
    error('Mesh file not found: %s\nPlease ensure the data folder is in your MATLAB path.', meshFile);
end

data = load(meshFile);
V = data.V;  % Vertices [N×3]
F = data.F;  % Faces [M×3]

fprintf('  Loaded: %d vertices, %d faces\n', size(V, 1), size(F, 1));

%% Create bct.Manifold object
fprintf('\nCreating bct.Manifold object...\n');
M = bct.Manifold(V, F);

fprintf('  Manifold created successfully\n');
fprintf('  - Vertices: %d\n', size(M.Vertices, 1));
fprintf('  - Faces: %d\n', size(M.Faces, 1));

%% Visualize with bct.ui.show
fprintf('\nLaunching viewer...\n');
[viewer1, fig1] = bct.ui.show(M);
fig1.Name = 'Manual Load: FreeSurfer fsaverage';

fprintf('\n=== EXAMPLE 2: Catalog-based loading (Brainstorm) ===\n');
fprintf('Loading Brainstorm cortical surface from bundled catalog...\n');
fprintf('API: bct.data.load() - catalog-based asset management\n\n');

% Load Brainstorm mesh using catalog API
mesh_bs = bct.data.load('brainstorm_default_cortex_pial_low');

fprintf('  Loaded: %d vertices, %d faces\n', mesh_bs.Meta.NumVertices, mesh_bs.Meta.NumFaces);
fprintf('  Dataset: %s\n', mesh_bs.Meta.Dataset);
fprintf('  Surface: %s\n', mesh_bs.Meta.Surface);
fprintf('  Has vertex normals: %s\n', mat2str(mesh_bs.Meta.HasVertexNormals));

%% Create bct.Manifold from Brainstorm data
fprintf('\nCreating bct.Manifold from Brainstorm mesh...\n');
M_bs = bct.Manifold(mesh_bs.Vertices, mesh_bs.Faces);

fprintf('  Manifold created successfully\n');
fprintf('  - Vertices: %d\n', size(M_bs.Vertices, 1));
fprintf('  - Faces: %d\n', size(M_bs.Faces, 1));

%% Visualize Brainstorm mesh
fprintf('\nLaunching viewer for Brainstorm mesh...\n');
[viewer2, fig2] = bct.ui.show(M_bs);
fig2.Name = 'Catalog: Brainstorm Cortical Surface';

%% List other available Brainstorm surfaces
fprintf('\n=== Available catalog assets ===\n');
bs_ids = bct.data.list(Dataset="brainstorm");
fprintf('Found %d Brainstorm surfaces in catalog:\n', length(bs_ids));
for i = 1:min(5, length(bs_ids))
    fprintf('  - %s\n', bs_ids(i));
end
if length(bs_ids) > 5
    fprintf('  ... and %d more\n', length(bs_ids) - 5);
end

fprintf('\nTip: Load any catalog asset with bct.data.load(id)\n');

%% Summary
fprintf('\n=== DEMO COMPLETE ===\n');
fprintf('Two manifolds are now displayed in separate viewers:\n');
fprintf('  1. FreeSurfer fsaverage (manual file loading)\n');
fprintf('  2. Brainstorm cortical surface (catalog loading)\n');
fprintf('\n--- DATA LOADING API SUMMARY ---\n');
fprintf('  bct.data.load()      - Bundled catalog assets (Brainstorm, fsaverage)\n');
fprintf('  bct.manifold.read()  - Standard formats (.obj, .stl, .ply, .glb, .gltf)\n');
fprintf('  bct.manifold.load()  - Generic .mat files or struct/object conversion\n');
fprintf('  load() + Manifold()  - Manual loading for custom external files\n');
fprintf('\nViewer Controls:\n');
fprintf('  - Rotate: Click and drag\n');
fprintf('  - Zoom: Mouse wheel\n');
fprintf('  - Adjust rendering: Use the GUI controls on the right\n');
fprintf('\nClose the figure windows when done.\n');
