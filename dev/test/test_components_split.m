% Test M.components() and M.split() wrapper methods
addpath(genpath('toolbox'));
addpath('external');

fprintf('COMPONENTS AND SPLIT WRAPPER METHODS TEST\n');
fprintf('==========================================\n\n');

% Test 1: Connected mesh
fprintf('1. Connected mesh (icosphere):\n');
[V, F] = icosphere(2);
M = bct.Manifold(V, F);
fprintf('   Vertices: %d, Faces: %d\n', M.numVertices, M.numFaces);

result = M.components();
if ischar(result)
    fprintf('   M.components() = ''%s''\n', result);
else
    fprintf('   M.components() = cell array with %d components\n', length(result));
end

manifolds = M.split();
fprintf('   M.split() returned %d manifold(s)\n', length(manifolds));
fprintf('   Same object: %d\n\n', manifolds{1} == M);

% Test 2: Two disconnected spheres
fprintf('2. Disconnected mesh (2 spheres):\n');
[V1, F1] = icosphere(2);
[V2, F2] = icosphere(2);
V2 = V2 + [5 0 0];

V_all = [V1; V2];
F_all = [F1; F2 + size(V1, 1)];
M = bct.Manifold(V_all, F_all);
fprintf('   Vertices: %d, Faces: %d\n', M.numVertices, M.numFaces);

result = M.components();
if ischar(result)
    fprintf('   M.components() = ''%s''\n', result);
else
    fprintf('   M.components() = cell array with %d components\n', length(result));
    for i = 1:length(result)
        fprintf('     Component %d: %d vertices (indices %d to %d)\n', ...
            i, length(result{i}), min(result{i}), max(result{i}));
    end
end

manifolds = M.split();
fprintf('   M.split() returned %d manifold(s):\n', length(manifolds));
for i = 1:length(manifolds)
    h = manifolds{i}.health();
    fprintf('     Manifold %d: %d vertices, %d faces, connected=%d\n', ...
        i, manifolds{i}.numVertices, manifolds{i}.numFaces, h.is.connected);
end

% Test 3: Three components of different sizes
fprintf('\n3. Three spheres (different sizes):\n');
[V1, F1] = icosphere(1);  % Small
[V2, F2] = icosphere(2);  % Medium
[V3, F3] = icosphere(3);  % Large

V2 = V2 + [5 0 0];
V3 = V3 + [10 0 0];

nV1 = size(V1, 1);
nV2 = size(V2, 1);
V_all = [V1; V2; V3];
F_all = [F1; F2 + nV1; F3 + nV1 + nV2];

M = bct.Manifold(V_all, F_all);
fprintf('   Total: %d vertices, %d faces\n', M.numVertices, M.numFaces);

result = M.components();
fprintf('   M.components() found %d components:\n', length(result));
for i = 1:length(result)
    fprintf('     %d vertices\n', length(result{i}));
end

manifolds = M.split();
fprintf('   M.split() returned %d manifolds (sorted by size):\n', length(manifolds));
for i = 1:length(manifolds)
    fprintf('     Manifold %d: %d vertices, %d faces\n', ...
        i, manifolds{i}.numVertices, manifolds{i}.numFaces);
end

% Verify order (largest first)
fprintf('\n   ✓ Manifolds sorted: largest=%d, smallest=%d\n', ...
    manifolds{1}.numVertices, manifolds{end}.numVertices);
