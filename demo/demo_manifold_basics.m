%% BCT Manifold Workflow Demo
% This script demonstrates the typical BCT workflow:
%   1. Loading a Manifold from file
%   2. FEM (Finite Element Method) analysis
%   3. DEC (Discrete Exterior Calculus) operations
%   4. Graph-based analysis
%
% Uses the default fsaverage6 test mesh included with the toolbox.

%% Initialize workspace
clearvars; close all;

% Ensure bioctree is initialized
if ~exist('bct.Manifold', 'class')
    error('bioctree toolbox not initialized. Run bioctree_start first.');
end

%% Load Manifold from file
% Direct loading using bct.manifold.load() with default mesh from bct.data
% The default mesh is fsaverage6 left hemisphere pial surface

% Get the default mesh path from bct.data
mesh = bct.data.load();  % Load default mesh struct
M = bct.manifold.load(mesh);  % Create Manifold object

% Display basic properties
nVertices = size(M.Vertices, 1);
nFaces = size(M.Faces, 1);
disp(['Loaded Manifold: ' num2str(nVertices) ' vertices, ' num2str(nFaces) ' faces']);

%% FEM Analysis - Finite Element Method
% Access the FEM representation (lazy initialization)
% This provides the discrete Laplace-Beltrami operator and mass matrix

fem = M.FEM();

% The FEM object contains:
%   - Stiffness matrix (discrete Laplace-Beltrami): fem.S
%   - Mass matrix (vertex areas): fem.M
%   - Lumped mass matrix (diagonal): fem.Ml

% Display FEM properties
disp(['FEM stiffness matrix: ' num2str(size(fem.Stiffness, 1)) ' × ' num2str(size(fem.Stiffness, 2))]);
disp(['Mass matrix sparsity: ' num2str(nnz(fem.Mass) / numel(fem.Mass) * 100, '%.2f') '%']);

% Compute eigendecomposition (spatial frequency modes)
K = 100;  % Number of eigenmodes
[Psi, Lambda] = M.eigensolve(K);

% Psi: eigenvectors (columns are spatial modes)
% Lambda: eigenvalues (spatial frequencies)
disp(['Computed ' num2str(K) ' eigenmodes']);
disp(['Eigenvalue range: [' num2str(Lambda(1), '%.6f') ', ' num2str(Lambda(end), '%.2f') ']']);

%% DEC Analysis - Discrete Exterior Calculus
% Access the DEC representation for differential forms
% Provides gradient, divergence, and curl operators

dec = M.DEC();

% The DEC object contains:
%   - Gradient operator: dec.Gradient (vertices → edges)
%   - Divergence operator: dec.Divergence (edges → vertices)
%   - Curl operator: dec.Curl (edges → faces)

% Display DEC properties
disp(['DEC gradient operator: ' num2str(size(dec.Gradient, 1)) ' × ' num2str(size(dec.Gradient, 2))]);
nEdges = size(dec.Gradient, 1);
disp(['Number of edges: ' num2str(nEdges)]);

% Example: Compute gradient of a scalar field
% Create a test scalar field (distance from a vertex)
seedVertex = 1000;
distances = vecnorm(M.Vertices - M.Vertices(seedVertex, :), 2, 2);

% Compute gradient (two equivalent methods)
% Method 1: Using operator matrix
gradField1 = dec.Gradient * distances;
% Method 2: Using method
gradField2 = dec.gradient(distances);
disp(['Gradient field dimension: ' num2str(length(gradField1))]);

% Compute divergence of gradient (should approximate Laplacian)
divGrad = dec.divergence(gradField1);
disp(['Divergence of gradient dimension: ' num2str(length(divGrad))]);

%% Graph Analysis - Connectivity and Topology
% Access the graph representation for connectivity-based analysis

G = M.Graph();

% The Graph object provides:
%   - Adjacency matrix: G.Adjacency
%   - Degree matrix: G.Degree
%   - Graph Laplacian: G.Laplacian

% Display graph properties
disp(['Graph adjacency matrix: ' num2str(size(G.Adjacency, 1)) ' × ' num2str(size(G.Adjacency, 2))]);
avgDegree = mean(sum(G.Adjacency, 2));
disp(['Average vertex degree: ' num2str(avgDegree, '%.2f')]);

% Compute graph-based metrics
% Example: diffusion distance from seed vertex
diffusionTime = 100;
diffusionKernel = expm(-diffusionTime * G.Laplacian);
diffusionDist = diffusionKernel(seedVertex, :)';
disp(['Computed diffusion distances from vertex ' num2str(seedVertex)]);

%% Visualization
% Visualize the manifold and scalar fields using bct.ui.show

% Create figure for visualization
fig = figure('Name', 'BCT Manifold Workflow', 'Position', [100, 100, 1200, 800]);

% Create grid layout
gl = uigridlayout(fig, [2, 2]);
gl.RowHeight = {'1x', '1x'};
gl.ColumnWidth = {'1x', '1x'};

% Panel 1: Original mesh
ax1 = uiaxes(gl);
ax1.Layout.Row = 1;
ax1.Layout.Column = 1;
patch('Parent', ax1, 'Vertices', M.Vertices, 'Faces', M.Faces, ...
      'FaceColor', [0.8, 0.8, 0.8], 'EdgeColor', 'none', ...
      'FaceAlpha', 1);
axis(ax1, 'equal', 'off');
lighting(ax1, 'gouraud');
camlight(ax1, 'headlight');
title(ax1, 'Manifold Mesh');
view(ax1, 3);

% Panel 2: First eigenmode
ax2 = uiaxes(gl);
ax2.Layout.Row = 1;
ax2.Layout.Column = 2;
eigenmode1 = Psi(:, 2);  % First non-DC mode
patch('Parent', ax2, 'Vertices', M.Vertices, 'Faces', M.Faces, ...
      'FaceVertexCData', eigenmode1, 'FaceColor', 'interp', ...
      'EdgeColor', 'none');
axis(ax2, 'equal', 'off');
lighting(ax2, 'gouraud');
camlight(ax2, 'headlight');
title(ax2, ['Eigenmode 2 (λ = ' num2str(Lambda(2), '%.4f') ')']);
colorbar(ax2);
view(ax2, 3);

% Panel 3: Geodesic distance field
ax3 = uiaxes(gl);
ax3.Layout.Row = 2;
ax3.Layout.Column = 1;
patch('Parent', ax3, 'Vertices', M.Vertices, 'Faces', M.Faces, ...
      'FaceVertexCData', distances, 'FaceColor', 'interp', ...
      'EdgeColor', 'none');
axis(ax3, 'equal', 'off');
lighting(ax3, 'gouraud');
camlight(ax3, 'headlight');
title(ax3, 'Euclidean Distance Field');
colorbar(ax3);
view(ax3, 3);

% Panel 4: Diffusion distance field
ax4 = uiaxes(gl);
ax4.Layout.Row = 2;
ax4.Layout.Column = 2;
patch('Parent', ax4, 'Vertices', M.Vertices, 'Faces', M.Faces, ...
      'FaceVertexCData', diffusionDist, 'FaceColor', 'interp', ...
      'EdgeColor', 'none');
axis(ax4, 'equal', 'off');
lighting(ax4, 'gouraud');
camlight(ax4, 'headlight');
title(ax4, 'Diffusion Distance Field');
colorbar(ax4);
view(ax4, 3);

%% Summary
% The BCT workflow provides a unified interface for:
%   - Manifold: mesh geometry and topology
%   - FEM: Laplace-Beltrami operator and eigendecomposition
%   - DEC: differential operators (gradient, divergence)
%   - Graph: connectivity-based analysis
%
% All representations are lazily initialized and cached for performance.
