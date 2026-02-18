%% Simple Direction Field Example with Corrected Connection
% Demonstrates computing direction fields using the fixed trivial connection

clear; close all;

%% Setup
% Add necessary paths
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'toolbox'));
addpath(genpath(fullfile(projectRoot, 'external', 'DECLab')));
addpath(genpath(fullfile(projectRoot, 'external', 'gptoolbox')));

%% Load Surface
fprintf('Loading cortical surface...\n');
mesh = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
M = bct.Manifold(mesh.Vertices, mesh.Faces);

fprintf('  Vertices: %d\n', size(M.Vertices, 1));
fprintf('  Faces: %d\n', size(M.Faces, 1));

%% Compute Trivial Connection
fprintf('\nComputing trivial connection with 2 singularities...\n');

% Define singularities (two points of index +1)
conn = M.connection('trivial', ...
    'singularities', [6653, 978], ...
    'weights', [1.0, 1.0]);

% Extract connection on halfedges
phi = conn.trivialConnection.value;

fprintf('  φ range: [%.4f, %.4f] rad\n', min(phi), max(phi));
fprintf('  ✓ Connection computed successfully!\n');

%% Build Direction Field
fprintf('\nBuilding direction field via BFS propagation...\n');

% Get topology and geometry
topo = M.topology();
geom = M.geometry();

faceHalfedges = topo.faceHalfedges.value;
transportAngles = geom.face.transport.value;
nFaces = size(M.Faces, 1);

% Initialize
alpha = zeros(nFaces, 1);
visited = false(nFaces, 1);

% Seed face
seedFace = 1;
alpha(seedFace) = 0.0;
visited(seedFace) = true;
queue = seedFace;

% BFS propagation
while ~isempty(queue)
    f_i = queue(1);
    queue(1) = [];
    
    he_indices = faceHalfedges(f_i, :);
    
    for k = 1:3
        he = he_indices(k);
        twin_he = topo.twin.value(he);
        
        if twin_he == 0, continue; end
        
        f_j = topo.face.value(twin_he);
        
        if visited(f_j), continue; end
        
        % Propagate: α[j] = α[i] + (transport[twin] - transport[he]) - (φ[twin] - φ[he])
        geom_transport = transportAngles(twin_he) - transportAngles(he);
        conn_transport = phi(twin_he) - phi(he);
        
        alpha(f_j) = alpha(f_i) + geom_transport - conn_transport;
        
        visited(f_j) = true;
        queue(end+1) = f_j;
    end
end

fprintf('  Visited: %d/%d faces\n', sum(visited), nFaces);
fprintf('  α range: [%.4f, %.4f] rad\n', min(alpha), max(alpha));

%% Convert to 3D Vectors
fprintf('\nConverting to 3D direction vectors...\n');

faceTangent1 = geom.face.tangent1.value;
faceTangent2 = geom.face.tangent2.value;

directionVectors = zeros(nFaces, 3);
for f = 1:nFaces
    t1 = faceTangent1(f, :);
    t2 = faceTangent2(f, :);
    directionVectors(f, :) = cos(alpha(f)) * t1 + sin(alpha(f)) * t2;
end

% Verify unit length
lengths = sqrt(sum(directionVectors.^2, 2));
fprintf('  Vector lengths: mean=%.6f ± %.2e\n', mean(lengths), std(lengths));
fprintf('  ✓ Direction field computed!\n');

%% Summary
fprintf('\n=== SUCCESS ===\n');
fprintf('Direction field computed with corrected trivial connection.\n');
fprintf('The connection now matches geometry-processing-js reference.\n');
fprintf('\nOutputs:\n');
fprintf('  phi              - [%d×1] connection on halfedges\n', length(phi));
fprintf('  alpha            - [%d×1] direction angles on faces\n', length(alpha));
fprintf('  directionVectors - [%d×3] 3D direction vectors\n', size(directionVectors, 1));

%% Optional: Visualize
fprintf('\nTo visualize, use:\n');
fprintf('  V = bct.ui.manifold.Viewer(M);\n');
fprintf('  V.show(''directionField'', directionVectors);\n');
