% demo_particle_flow.m
%
% Demonstration of particle flow advection on cortical surface.
%
% This demo shows:
% 1. Loading a cortical mesh
% 2. Computing a scalar field (eigenmode)
% 3. Computing gradient of scalar field
% 4. Visualizing flow with advected particles
%
% The particles are transported along the gradient field and stay on the
% mesh surface via GPU-based time-stepping in three.js.

%% Setup
clear; close all;

%% Load canonical test manifold
M = bct.data.load('Id', 'fsaverage_rh_pial');

fprintf('Loaded mesh: %d vertices, %d faces\n', M.nV, M.nF);

%% Compute eigenmodes
fprintf('Computing eigenmodes...\n');
[lambda, U] = M.eigenmodes(100);
fprintf('Computed 100 eigenmodes\n');

%% Select eigenmode as scalar field
% Use mode 10 for interesting spatial structure
u = U(:, 10);

fprintf('Eigenmode 10: eigenvalue = %.6f\n', lambda(10));

%% Compute face gradient
fprintf('Computing face gradient...\n');
gradU = bct.field.generate.faceGradient(M, u);

fprintf('Gradient field: %d faces × 3D\n', size(gradU, 1));

%% Create viewer
viewer = bct.ui.manifold.Viewer();

% Set mesh
viewer.setMesh('Vertices', M.V, 'Faces', M.F);

% Show scalar field
viewer.setScalar(u, 'Name', 'eigenmode_10', ...
    'ColorMap', 'viridis', 'Support', 'vertex');

fprintf('Viewer created with eigenmode scalar field\n');

%% Add particle flow
% Particles will be advected along the gradient
viewer.addParticleFlow(gradU, ...
    'Name', 'heat_flow', ...
    'Support', 'face', ...
    'NumParticles', 2000, ...
    'StepSize', 0.1, ...
    'ParticleSize', 3.0, ...
    'Color', 0xffffff, ...  % White particles
    'Fade', true, ...
    'FadeTime', 2.0, ...
    'Respawn', true, ...
    'AutoStart', true);

fprintf('Added particle flow with 2000 particles\n');

%% Add gradient vectors for comparison (optional - commented out to reduce clutter)
% Compute face centroids for vector positions
% V = M.V;
% F = M.F;
% centroids = (V(F(:,1), :) + V(F(:,2), :) + V(F(:,3), :)) / 3;
% 
% % Subsample for visualization
% stride = 10;
% viewer.addVector(gradU(1:stride:end, :), ...
%     'Name', 'gradient', ...
%     'Positions', centroids(1:stride:end, :), ...
%     'Support', 'face', ...
%     'Style', 'arrow', ...
%     'LengthScale', 1.0, ...
%     'Color', 0xff0000, ...
%     'LineWidth', 2);

fprintf('\n=== Particle Flow Demo Complete ===\n');
fprintf('Particles are being advected along the gradient field.\n');
fprintf('Watch them flow along the eigenmode gradient on the mesh surface.\n');
fprintf('Particles will fade and respawn to create continuous visualization.\n');
