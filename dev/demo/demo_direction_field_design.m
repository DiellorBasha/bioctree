%% Direction Field Design - Complete Workflow
%
% This demo implements the complete direction field design workflow
% following the geometry-processing-js reference implementation:
% external\geometry-processing-js\projects\direction-field-design
%
% Workflow:
% 1. Compute trivial connection φ = δβ + γ
% 2. Compute combined transport = geometricTransport - connection
% 3. Build direction field by BFS propagation on dual graph
% 4. Convert angles to 3D vectors using face tangent frames
% 5. Visualize the result

clear; close all;

%% Load manifold
fprintf('=== Direction Field Design ===\n\n');
fprintf('Loading mesh...\n');
M = bct.data.load('Id', 'fsaverage_rh_pial');

nV = size(M.vertices, 1);
nF = size(M.faces, 1);
nE = size(M.edges, 1);

fprintf('  Vertices: %d\n', nV);
fprintf('  Faces: %d\n', nF);
fprintf('  Edges: %d\n\n', nE);

%% Check topology
topo = M.topology();
chi = nV - nE + nF;
genus = (2 - chi) / 2;

fprintf('Topology:\n');
fprintf('  Euler characteristic χ = %d\n', chi);
fprintf('  Genus g = %.1f\n', genus);

if genus > 1e-6
    warning('Mesh has genus > 0. Harmonic component not implemented.');
    fprintf('  ⚠️ Results will be approximate\n\n');
else
    fprintf('  ✓ Mesh is topologically a sphere (genus 0)\n\n');
end

%% Define singularities
% Two singularities with index +1 each (sum = 2 = χ for sphere)
% These act like north/south poles of the direction field

% Option 1: Pick vertices manually
singIdx = [6653, 978];
singWeights = [1, 1];

% Option 2: Random vertices far apart
% dist = pdist2(M.vertices, M.vertices);
% [~, idx1] = max(sum(dist, 2));
% [~, idx2] = max(dist(idx1, :));
% singIdx = [idx1, idx2];
% singWeights = [1, 1];

fprintf('Singularities:\n');
fprintf('  Indices: [%d, %d]\n', singIdx(1), singIdx(2));
fprintf('  Weights: [%d, %d]\n', singWeights(1), singWeights(2));
fprintf('  Sum: %d (should equal χ = %d)\n\n', sum(singWeights), chi);

if abs(sum(singWeights) - chi) > 1e-6
    error('Singularity sum (%d) ≠ χ (%d). Gauss-Bonnet violated!', ...
        sum(singWeights), chi);
end

%% Step 1: Compute trivial connection
fprintf('Step 1: Computing trivial connection φ = δβ + γ...\n');
tic;
conn = M.connection('trivial', 'singularities', singIdx, 'weights', singWeights);
t_conn = toc;

fprintf('  ✓ Connection computed in %.3f sec\n', t_conn);
fprintf('    Method: %s\n', conn.attributes.method);
fprintf('    Formula: %s\n\n', conn.attributes.formula);

%% Step 2: Compute combined transport
fprintf('Step 2: Computing combined transport = geometric - connection...\n');
tic;
trans = bct.manifold.connection.transport(M, conn, 'sign', 'minus');
t_trans = toc;

combinedTransport = trans.combinedTransport.value;  % [nH×1]
geometricTransport = trans.geometricTransport.value;
connectionTransport = trans.connectionTransport.value;

fprintf('  ✓ Transport computed in %.3f sec\n', t_trans);
fprintf('    Formula: %s\n', trans.attributes.formula);
fprintf('    Range: [%.3f, %.3f] rad\n\n', ...
    min(combinedTransport), max(combinedTransport));

%% Step 3: Build direction field by BFS on dual graph
fprintf('Step 3: Propagating direction field on dual graph...\n');
tic;

% Start from face 1 with angle 0
seedFace = 1;
seedAngle = 0;

result = bct.manifold.query.dual(M, combinedTransport, ...
    'seedFace', seedFace, ...
    'seedValue', seedAngle, ...
    'wrap', true);

alpha_face = result.alpha_face;  % [nF×1] direction angle in each face
t_bfs = toc;

nReached = sum(~isnan(alpha_face));
fprintf('  ✓ BFS propagation in %.3f sec\n', t_bfs);
fprintf('    Reached %d/%d faces (%.1f%%)\n', nReached, nF, 100*nReached/nF);
fprintf('    Angle range: [%.3f, %.3f] rad\n\n', ...
    min(alpha_face(~isnan(alpha_face))), max(alpha_face(~isnan(alpha_face))));

if nReached < nF
    warning('Not all faces reached! Mesh may have disconnected components.');
end

%% Step 4: Convert angles to 3D vectors
fprintf('Step 4: Converting angles to 3D direction vectors...\n');
tic;

geom = M.geometry();
e1 = geom.face.tangent1.value;   % [nF×3] first tangent vector
e2 = geom.face.tangent2.value;   % [nF×3] second tangent vector

% Direction vector: v = cos(α)*e1 + sin(α)*e2
directionField = cos(alpha_face) .* e1 + sin(alpha_face) .* e2;

% Handle unreached faces
validFaces = ~isnan(alpha_face);
directionField(~validFaces, :) = 0;

t_vec = toc;
fprintf('  ✓ Vectors computed in %.3f sec\n', t_vec);
fprintf('    Valid vectors: %d/%d\n\n', sum(validFaces), nF);

%% Step 5: Visualize
fprintf('Step 5: Visualizing direction field...\n');
tic;

% Create viewer
viewer = bct.ui.manifold.Viewer(M);

% Set white background
viewer.background('Color', 'white');

% Show direction field as arrows
viewer.setVector(directionField, ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Normals', geom.face.normals.value, ...
    'Style', 'arrow', ...
    'LengthScale', 2.0, ...
    'Color', 0x0000ff, ...
    'LineWidth', 2, ...
    'Stride', 5);  % Show every 5th vector for clarity

% Mark singularities
viewer.addPoint('Indices', singIdx, ...
    'Color', 0xff0000, ...
    'Radius', 3.0);

t_viz = toc;
fprintf('  ✓ Visualization created in %.3f sec\n\n', t_viz);

%% Summary
fprintf('=== Summary ===\n');
fprintf('Total time: %.3f sec\n', t_conn + t_trans + t_bfs + t_vec + t_viz);
fprintf('  Connection:   %.3f sec\n', t_conn);
fprintf('  Transport:    %.3f sec\n', t_trans);
fprintf('  BFS:          %.3f sec\n', t_bfs);
fprintf('  Vectors:      %.3f sec\n', t_vec);
fprintf('  Viz:          %.3f sec\n\n', t_viz);

fprintf('✓ Direction field design complete!\n');
fprintf('  Red spheres = singularities (index %d, %d)\n', singWeights(1), singWeights(2));
fprintf('  Blue arrows = direction field\n');
fprintf('  Field should flow smoothly except at singularities\n');
