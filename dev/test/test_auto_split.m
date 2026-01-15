% Test automatic component splitting
addpath(genpath('toolbox'));
addpath('external');

fprintf('AUTOMATIC COMPONENT SPLITTING TEST\n');
fprintf('===================================\n\n');

% Test 1: Three disconnected spheres of different sizes
fprintf('1. Three spheres (different sizes):\n');
[V1, F1] = icosphere(1);  % Small: 42 vertices
[V2, F2] = icosphere(2);  % Medium: 162 vertices  
[V3, F3] = icosphere(3);  % Large: 642 vertices

% Offset spheres
V2 = V2 + [5 0 0];
V3 = V3 + [10 0 0];

% Combine
nV1 = size(V1, 1);
nV2 = size(V2, 1);
V_all = [V1; V2; V3];
F_all = [F1; F2 + nV1; F3 + nV1 + nV2];

M = bct.Manifold(V_all, F_all);
fprintf('   Input: %d vertices, %d faces\n', M.numVertices, M.numFaces);

% Split using convenience method
components = M.splitComponents();
fprintf('   Found %d components\n', length(components));

for i = 1:length(components)
    h = components{i}.health();
    fprintf('   Component %d: %d vertices, %d faces, connected=%d\n', ...
        i, components{i}.numVertices, components{i}.numFaces, h.is.connected);
end

% Test 2: Already connected mesh
fprintf('\n2. Single connected mesh (should return as-is):\n');
[V, F] = icosphere(3);
M_connected = bct.Manifold(V, F);

components = M_connected.splitComponents();
fprintf('   Input: %d vertices\n', M_connected.numVertices);
fprintf('   Output: %d component(s)\n', length(components));
fprintf('   Same object: %d\n', components{1} == M_connected);

% Test 3: Filter by minimum size
fprintf('\n3. Filter small components (MinSize=100):\n');
% Create mesh with many small components
V_multi = [];
F_multi = [];
offset = 0;

% Add 3 large components and 5 small ones
for i = 1:8
    if i <= 3
        [v, f] = icosphere(2);  % Large: 162 vertices
    else
        [v, f] = icosphere(0);  % Small: 12 vertices
    end
    
    v = v + [i*5 0 0];  % Offset
    V_multi = [V_multi; v];
    F_multi = [F_multi; f + offset];
    offset = offset + size(v, 1);
end

M_multi = bct.Manifold(V_multi, F_multi);
fprintf('   Input: %d components total\n', ...
    M_multi.health().statsByCheck.connectivity.numComponents);

components_all = M_multi.splitComponents();
fprintf('   Without filter: %d components\n', length(components_all));

components_large = M_multi.splitComponents('MinSize', 100);
fprintf('   With MinSize=100: %d components\n', length(components_large));

for i = 1:length(components_large)
    fprintf('   Component %d: %d vertices\n', ...
        i, components_large{i}.numVertices);
end

% Test 4: Use split for pair-wise separation
fprintf('\n4. Manual split of first two components:\n');
h = M.health('Verbose', true);
if length(h.data.connectivity.components) >= 2
    comp1_idx = h.data.connectivity.components{1};
    comp2_idx = h.data.connectivity.components{2};
    
    [M1, M2, stats] = bct.manifold.health.repair.split(M, comp1_idx, comp2_idx);
    
    fprintf('   Component 1: %d vertices (%d faces)\n', M1.numVertices, M1.numFaces);
    fprintf('   Component 2: %d vertices (%d faces)\n', M2.numVertices, M2.numFaces);
    fprintf('   Stats match auto-split: %d\n', ...
        M1.numVertices == components{1}.numVertices && ...
        M2.numVertices == components{2}.numVertices);
end
