% Test split repair function
addpath(genpath('toolbox'));
addpath('external');

fprintf('MANIFOLD SPLIT REPAIR TEST\n');
fprintf('===========================\n\n');

% Test 1: Split disconnected components
fprintf('1. Splitting disconnected components:\n');
[V1, F1] = icosphere(1);  % 42 vertices, 80 faces
[V2, F2] = icosphere(1);

% Offset second sphere
V2 = V2 + [5 0 0];

% Combine
nV1 = size(V1, 1);
V_all = [V1; V2];
F_all = [F1; F2 + nV1];

M = bct.Manifold(V_all, F_all);
fprintf('   Input: %d vertices, %d faces\n', M.numVertices, M.numFaces);

% Get components from health check
h = M.health('Verbose', true);
fprintf('   Components detected: %d\n', h.statsByCheck.connectivity.numComponents);

if ~h.is.connected && length(h.data.connectivity.components) == 2
    comp1 = h.data.connectivity.components{1};
    comp2 = h.data.connectivity.components{2};
    
    [M1, M2, stats] = bct.manifold.health.repair.split(M, comp1, comp2);
    
    fprintf('   Component 1: %d vertices, %d faces\n', M1.numVertices, M1.numFaces);
    fprintf('   Component 2: %d vertices, %d faces\n', M2.numVertices, M2.numFaces);
    fprintf('   Discarded faces: %d\n', stats.nDiscarded);
    
    % Verify each component is connected
    h1 = M1.health();
    h2 = M2.health();
    fprintf('   Component 1 connected: %d\n', h1.is.connected);
    fprintf('   Component 2 connected: %d\n', h2.is.connected);
end

% Test 2: Split by manual vertex selection (hemisphere-like)
fprintf('\n2. Splitting sphere by hemisphere (x < 0 vs x >= 0):\n');
[V, F] = icosphere(3);
M = bct.Manifold(V, F);

% Define components by x-coordinate
leftHemi = find(V(:,1) < 0);
rightHemi = find(V(:,1) >= 0);

fprintf('   Left hemisphere vertices: %d\n', length(leftHemi));
fprintf('   Right hemisphere vertices: %d\n', length(rightHemi));

[MLH, MRH, stats] = bct.manifold.health.repair.split(M, leftHemi, rightHemi);

fprintf('   Left submesh: %d vertices, %d faces\n', MLH.numVertices, MLH.numFaces);
fprintf('   Right submesh: %d vertices, %d faces\n', MRH.numVertices, MRH.numFaces);
fprintf('   Discarded (bridge) faces: %d\n', stats.nDiscarded);

% Verify health
hLH = MLH.health();
hRH = MRH.health();
fprintf('   Left submesh status: %s\n', hLH.severity);
fprintf('   Right submesh status: %s\n', hRH.severity);

% Test 3: Split with overlap (duplicated vertices)
fprintf('\n3. Splitting with overlapping vertex sets:\n');
[V, F] = icosphere(2);
M = bct.Manifold(V, F);

% Create overlapping sets (some vertices in both)
comp1 = 1:80;
comp2 = 60:162;  % 21 vertices overlap

fprintf('   Component 1: %d vertices\n', length(comp1));
fprintf('   Component 2: %d vertices\n', length(comp2));
fprintf('   Overlap: %d vertices\n', length(intersect(comp1, comp2)));

[M1, M2, stats] = bct.manifold.health.repair.split(M, comp1, comp2);

fprintf('   After split:\n');
fprintf('   Component 1: %d vertices, %d faces\n', M1.numVertices, M1.numFaces);
fprintf('   Component 2: %d vertices, %d faces\n', M2.numVertices, M2.numFaces);
fprintf('   Discarded faces: %d\n', stats.nDiscarded);
