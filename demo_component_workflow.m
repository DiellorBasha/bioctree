% Complete workflow demonstration for component detection and splitting
addpath(genpath('toolbox'));
addpath('external');

fprintf('COMPONENT DETECTION AND SPLITTING WORKFLOW\n');
fprintf('===========================================\n\n');

% Load or create a potentially disconnected mesh
fprintf('Step 1: Create test mesh (3 disconnected spheres)\n');
[V1, F1] = icosphere(2);
[V2, F2] = icosphere(2);
[V3, F3] = icosphere(1);

V2 = V2 + [5 0 0];
V3 = V3 + [0 5 0];

nV1 = size(V1, 1);
nV2 = size(V2, 1);
V_all = [V1; V2; V3];
F_all = [F1; F2 + nV1; F3 + nV1 + nV2];

M = bct.Manifold(V_all, F_all);
fprintf('   Created: %d vertices, %d faces\n\n', M.numVertices, M.numFaces);

% Check connectivity
fprintf('Step 2: Check for disconnected components\n');
comp = M.components();

if ischar(comp)
    fprintf('   Result: Manifold is connected\n');
    fprintf('   → No action needed\n\n');
else
    fprintf('   Result: Found %d disconnected components\n', length(comp));
    for i = 1:length(comp)
        fprintf('     Component %d: %d vertices\n', i, length(comp{i}));
    end
    fprintf('   → Splitting recommended\n\n');
    
    % Split into separate manifolds
    fprintf('Step 3: Split into separate manifolds\n');
    manifolds = M.split();
    
    fprintf('   Created %d manifold objects:\n', length(manifolds));
    for i = 1:length(manifolds)
        h = manifolds{i}.health();
        fprintf('     M%d: %d vertices, %d faces, status=%s\n', ...
            i, manifolds{i}.numVertices, manifolds{i}.numFaces, h.severity);
    end
    
    fprintf('\n   Each component is now a separate, connected manifold\n');
    
    % Process each component independently
    fprintf('\nStep 4: Process each component\n');
    fprintf('   Example: Compute eigenmodes for largest component\n');
    M_largest = manifolds{1};
    fprintf('   M_largest: %d vertices\n', M_largest.numVertices);
    fprintf('   → Ready for spectral analysis\n');
end

fprintf('\n✓ Workflow complete\n');
