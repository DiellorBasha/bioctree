%% Direction Field Design with Corrected Trivial Connection
% This demo shows how to compute direction fields on surfaces using the
% now-fixed trivial connection implementation that matches geometry-processing-js

clear; close all;

% Add paths
addpath(fullfile(pwd, '..', '..', 'toolbox'));

%% Load a cortical surface
mesh = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
M = bct.Manifold(mesh.Vertices, mesh.Faces);

fprintf('=== MANIFOLD PROPERTIES ===\n');
fprintf('Vertices: %d\n', size(M.Vertices, 1));
fprintf('Faces: %d\n', size(M.Faces, 1));

% Compute Euler characteristic χ = V - E + F
topo = M.topology();
nVertices = size(M.Vertices, 1);
nEdges = size(topo.edgeList.value, 1);
nFaces = size(M.Faces, 1);
chi = nVertices - nEdges + nFaces;
fprintf('Euler characteristic: %d\n', chi);

%% Define singularities
% Place two singularities (index +1 each) on the surface
% These will be "sources" where field lines emanate from

singularityIndices = [6653, 978];  % Two vertex indices
singularityWeights = [1.0, 1.0];   % Both have index +1

fprintf('\n=== SINGULARITIES ===\n');
fprintf('Singularity 1: vertex %d, weight %.1f\n', singularityIndices(1), singularityWeights(1));
fprintf('Singularity 2: vertex %d, weight %.1f\n', singularityIndices(2), singularityWeights(2));
fprintf('Total index: %.1f (should equal χ=%d for closed surface)\n', ...
    sum(singularityWeights), chi);

%% Compute trivial connection (now with corrected sign!)
fprintf('\n=== COMPUTING TRIVIAL CONNECTION ===\n');

conn = M.connection('trivial', ...
    'singularities', singularityIndices, ...
    'weights', singularityWeights);

% Extract connection values
phi_halfedges = conn.trivialConnection.value;  % [nHalfedges×1] connection on halfedges
phi_edges = conn.connectionEdge.value;         % [nEdges×1] connection on edges
beta = conn.scalarPotential.value;             % [nVertices×1] scalar potential

fprintf('Connection computed successfully!\n');
fprintf('  φ range on halfedges: [%.4f, %.4f] rad\n', min(phi_halfedges), max(phi_halfedges));
fprintf('  φ range on edges: [%.4f, %.4f] rad\n', min(phi_edges), max(phi_edges));
fprintf('  β range (potential): [%.4f, %.4f] rad\n', min(beta), max(beta));

%% Build direction field from connection
% The direction field α on faces is computed by parallel transport along a
% spanning tree, starting from a seed face with initial direction α₀

fprintf('\n=== BUILDING DIRECTION FIELD ===\n');

% Get topology
topo = M.topology();
faceHalfedges = topo.faceHalfedges.value;  % [nFaces×3] halfedge indices per face

% Get geometry
geom = M.geometry();
faceTangent1 = geom.face.tangent1.value;    % [nFaces×3] reference tangent frame
transportAngles = geom.face.transport.value; % [nHalfedges×1] parallel transport angles

nFaces = size(M.Faces, 1);

% Initialize direction field angles
alpha = zeros(nFaces, 1);
visited = false(nFaces, 1);

% Seed face (arbitrary choice)
seedFace = 1;
seedAngle = 0.0;  % Initial direction aligned with tangent1

% BFS to propagate directions
alpha(seedFace) = seedAngle;
visited(seedFace) = true;
queue = seedFace;

while ~isempty(queue)
    f_i = queue(1);
    queue(1) = [];
    
    % Get halfedges of this face
    he_indices = faceHalfedges(f_i, :);
    
    for k = 1:3
        he = he_indices(k);
        
        % Get twin halfedge (crosses to neighbor face)
        twin_he = topo.twin.value(he);
        
        if twin_he == 0
            continue;  % Boundary edge
        end
        
        % Find neighbor face
        f_j = topo.face.value(twin_he);
        
        if visited(f_j)
            continue;  % Already visited
        end
        
        % Propagate direction with connection and transport
        % α[f_j] = α[f_i] + (transport[twin] - transport[he]) - (φ[twin] - φ[he])
        
        geom_transport = transportAngles(twin_he) - transportAngles(he);
        conn_transport = phi_halfedges(twin_he) - phi_halfedges(he);
        
        alpha(f_j) = alpha(f_i) + geom_transport - conn_transport;
        
        visited(f_j) = true;
        queue(end+1) = f_j;
    end
end

fprintf('Direction field computed via BFS propagation\n');
fprintf('  Visited faces: %d/%d\n', sum(visited), nFaces);
fprintf('  α range: [%.4f, %.4f] rad\n', min(alpha), max(alpha));

%% Convert to 3D direction vectors
fprintf('\n=== CONVERTING TO 3D VECTORS ===\n');

% Direction vectors in face tangent frames
directionVectors = zeros(nFaces, 3);

for f = 1:nFaces
    % Get tangent frame
    t1 = faceTangent1(f, :);
    t2 = geom.face.tangent2.value(f, :);
    
    % Direction as linear combination: d = cos(α)*t1 + sin(α)*t2
    directionVectors(f, :) = cos(alpha(f)) * t1 + sin(alpha(f)) * t2;
end

% Verify unit length
lengths = sqrt(sum(directionVectors.^2, 2));
fprintf('Direction vector lengths: mean=%.6f, std=%.6e\n', mean(lengths), std(lengths));

%% Visualize (if viewer available)
fprintf('\n=== VISUALIZATION ===\n');

try
    % Create viewer
    V = bct.ui.manifold.Viewer(M);
    
    % Show direction field with scalar potential as background
    V.show('scalarField', beta, ...
           'directionField', directionVectors, ...
           'title', 'Direction Field with Trivial Connection');
    
    fprintf('✓ Visualization opened in viewer\n');
catch ME
    fprintf('⚠ Viewer not available: %s\n', ME.message);
    fprintf('  Direction field computed successfully but cannot visualize\n');
end

%% Verify correctness
fprintf('\n=== VERIFICATION ===\n');

% Check Gauss-Bonnet
K = geom.vertex.angleDefect.value;
totalCurvature = sum(K);
expectedCurvature = 2*pi*chi;

fprintf('Gauss-Bonnet verification:\n');
fprintf('  ∫K dA = %.6f\n', totalCurvature);
fprintf('  2πχ   = %.6f\n', expectedCurvature);
fprintf('  Error = %.2e\n', abs(totalCurvature - expectedCurvature));

% Check singularity index sum
fprintf('\nSingularity index sum:\n');
fprintf('  Σsᵢ = %.1f\n', sum(singularityWeights));
fprintf('  χ   = %d\n', chi);

if abs(sum(singularityWeights) - chi) < 1e-6
    fprintf('  ✓ Singularity constraint satisfied\n');
else
    fprintf('  ✗ Singularity constraint violated!\n');
end

fprintf('\n=== COMPLETE ===\n');
fprintf('Direction field successfully computed with corrected connection!\n');
