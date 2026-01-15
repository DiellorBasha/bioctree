% Test scale health check
addpath(genpath('toolbox'));
addpath('external');

fprintf('SCALE HEALTH CHECK DEMONSTRATION\n');
fprintf('=================================\n\n');

[V, F] = icosphere(3);

% Test 1: Normal mesh
fprintf('1. Normal mesh (radius ~1m):\n');
M = bct.Manifold(V, F);
h = M.health();
fprintf('   Status: %s ✓\n\n', h.severity);

% Test 2: Mesh in millimeters (anatomical data)
fprintf('2. Anatomical data in mm (scaled x1000):\n');
M_mm = bct.Manifold(V*1000, F);
h_mm = M_mm.health();
fprintf('   Status: %s (scale warning)\n', h_mm.severity);
fprintf('   Extent: %.1f m, Edge: %.1f m\n', ...
    h_mm.statsByCheck.scale.vertexExtent_max, ...
    h_mm.statsByCheck.scale.edgeLength_median);
fprintf('   Warning: %s\n\n', h_mm.issues(1).message);

% Test 3: After rescaling
fprintf('3. After rescaling to meters:\n');
M_fixed = M_mm.rescale('Factor', 0.001);
h_fixed = M_fixed.health();
fprintf('   Status: %s ✓\n', h_fixed.severity);
fprintf('   Extent: %.2f m, Edge: %.4f m\n', ...
    h_fixed.statsByCheck.scale.vertexExtent_max, ...
    h_fixed.statsByCheck.scale.edgeLength_median);
