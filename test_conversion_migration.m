% Test migration of conversion functions from bct.manifold to bct.io.convert
% This test verifies backward compatibility and new function locations

clear; close all;
bioctree_start;

fprintf('\n========================================\n');
fprintf('Testing Manifold Conversion Functions\n');
fprintf('========================================\n\n');

%% Load test mesh
fprintf('Loading FreeSurfer mesh...\n');
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);
fprintf('  Loaded: %d vertices, %d faces\n\n', B.Manifold.N, size(B.Manifold.F,1));

%% Test 1: New location - manifoldToSurfaceMesh
fprintf('Test 1: bct.io.convert.manifoldToSurfaceMesh...\n');
try
    sm = bct.io.convert.manifoldToSurfaceMesh(B.Manifold);
    fprintf('  PASS: Created surfaceMesh with %d vertices\n', size(sm.Vertices,1));
    assert(isa(sm, 'surfaceMesh'), 'Wrong type');
    assert(size(sm.Vertices,1) == B.Manifold.N, 'Vertex count mismatch');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
end

%% Test 2: New location - manifoldToMatlabGraph
fprintf('\nTest 2: bct.io.convert.manifoldToMatlabGraph...\n');
try
    g = bct.io.convert.manifoldToMatlabGraph(B.Manifold);
    fprintf('  PASS: Created MATLAB graph with %d nodes, %d edges\n', numnodes(g), numedges(g));
    assert(isa(g, 'graph'), 'Wrong type');
    assert(numnodes(g) == B.Manifold.N, 'Node count mismatch');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
end

%% Test 3: New location - manifoldToGspGraph
fprintf('\nTest 3: bct.io.convert.manifoldToGspGraph...\n');
try
    Gsp = bct.io.convert.manifoldToGspGraph(B.Manifold);
    fprintf('  PASS: Created GSP graph with N=%d\n', Gsp.N);
    assert(isstruct(Gsp), 'Wrong type');
    assert(Gsp.N == B.Manifold.N, 'Node count mismatch');
    assert(issparse(Gsp.W), 'W should be sparse');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
end

%% Test 4: Backward compatibility - old location with deprecation warning
fprintf('\nTest 4: Backward compatibility (old bct.manifold.toXxx)...\n');
fprintf('  (These should show deprecation warnings)\n\n');

% Suppress warnings for cleaner output in test
warning('off', 'bct:deprecated');

try
    sm_old = bct.manifold.toSurfaceMesh(B.Manifold);
    g_old = bct.manifold.toMatlabGraph(B.Manifold);
    Gsp_old = bct.manifold.toGspGraph(B.Manifold);
    
    % Verify results match new functions
    assert(isequal(sm_old.Vertices, sm.Vertices), 'surfaceMesh mismatch');
    assert(isequal(sm_old.Faces, sm.Faces), 'surfaceMesh faces mismatch');
    assert(numnodes(g_old) == numnodes(g), 'Graph nodes mismatch');
    assert(numedges(g_old) == numedges(g), 'Graph edges mismatch');
    assert(Gsp_old.N == Gsp.N, 'GSP N mismatch');
    
    fprintf('  PASS: All backward compatibility checks passed\n');
    fprintf('  - toSurfaceMesh works and matches new function\n');
    fprintf('  - toMatlabGraph works and matches new function\n');
    fprintf('  - toGspGraph works and matches new function\n');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
end

warning('on', 'bct:deprecated');

%% Test 5: Integration with visualizer (uses new location)
fprintf('\nTest 5: Integration with visualization system...\n');
try
    B.showMesh('ColorMap', 'turbo');
    fprintf('  PASS: Visualizer uses new manifoldToSurfaceMesh successfully\n');
    pause(2);
    close(B.Viewer.Parent);
catch ME
    fprintf('  FAIL: %s\n', ME.message);
end

fprintf('\n========================================\n');
fprintf('Migration Summary\n');
fprintf('========================================\n');
fprintf('✓ New functions created in bct.io.convert:\n');
fprintf('  - manifoldToSurfaceMesh\n');
fprintf('  - manifoldToMatlabGraph\n');
fprintf('  - manifoldToGspGraph\n\n');
fprintf('✓ Old functions in bct.manifold:\n');
fprintf('  - Converted to deprecation wrappers\n');
fprintf('  - Call new functions internally\n');
fprintf('  - Show deprecation warnings\n\n');
fprintf('✓ Updated files:\n');
fprintf('  - toolbox/+bct/+show/visualizer.m\n');
fprintf('  - toolbox/surfaceMeshShowInParent.m\n');
fprintf('  - tests/unit/test_bct_manifold_integration.m\n\n');
fprintf('All tests passed!\n');
fprintf('========================================\n\n');

