%% Test Graph Integration with Manifold
% Tests that the new bct.Graph class integrates correctly with Manifold

bioctree_start;

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' Testing Graph Integration\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

%% Test 1: Graph is automatically created with Manifold
fprintf('Test 1: Graph is automatically created with Manifold...\n');

try
    [V, F] = icosphere(2);
    B = bct.bct.fromMesh(V, F);
    
    % Check Graph exists
    assert(~isempty(B.Manifold.Graph), 'Graph should be created automatically');
    assert(isa(B.Manifold.Graph, 'bct.Graph'), 'Graph should be bct.Graph class');
    
    fprintf('  ✓ Graph automatically created\n');
    fprintf('  ✓ Graph is bct.Graph class\n');
    fprintf('  ✓ Number of vertices: %d\n', B.Manifold.Graph.N);
    fprintf('  ✓ Number of edges: %d\n', size(B.Manifold.Graph.edgeIndex, 1));
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 2: Graph has correct topology
fprintf('Test 2: Graph has correct topology...\n');

try
    % Check N matches
    assert(B.Manifold.Graph.N == size(B.Manifold.Vertices, 1), ...
           'Graph N should match vertex count');
    
    % Check edge list is valid
    E = B.Manifold.Graph.edgeIndex;
    assert(all(E(:) >= 1 & E(:) <= B.Manifold.Graph.N), ...
           'Edge indices should be in valid range');
    
    % Check MATLAB graph object
    assert(isa(B.Manifold.Graph.G, 'graph'), 'G should be MATLAB graph');
    
    fprintf('  ✓ Topology dimensions correct\n');
    fprintf('  ✓ Edge indices valid\n');
    fprintf('  ✓ MATLAB graph object created\n');
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 3: Metrics are computed
fprintf('Test 3: Metrics are computed...\n');

try
    % Check geometry metric
    assert(isfield(B.Manifold.Graph.weights, 'geometry'), ...
           'Geometry metric should exist');
    
    w_geo = B.Manifold.Graph.weights.geometry;
    assert(length(w_geo) == size(B.Manifold.Graph.edgeIndex, 1), ...
           'Geometry weights should match edge count');
    assert(all(w_geo > 0), 'Geometry weights should be positive');
    
    % Check FEM metric
    assert(isfield(B.Manifold.Graph.weights, 'fem'), ...
           'FEM metric should exist');
    
    w_fem = B.Manifold.Graph.weights.fem;
    assert(length(w_fem) == size(B.Manifold.Graph.edgeIndex, 1), ...
           'FEM weights should match edge count');
    assert(all(w_fem >= 0), 'FEM weights should be non-negative');
    
    fprintf('  ✓ Geometry metric computed\n');
    fprintf('  ✓ FEM metric computed\n');
    fprintf('  ✓ Weight dimensions correct\n');
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 4: Neighbors query works
fprintf('Test 4: Neighbors query works...\n');

try
    v = 10;
    nbrs = B.Manifold.Graph.neighbors(v);
    
    assert(~isempty(nbrs), 'Vertex should have neighbors');
    assert(all(nbrs >= 1 & nbrs <= B.Manifold.Graph.N), ...
           'Neighbor indices should be valid');
    assert(all(nbrs ~= v), 'Neighbors should not include self');
    
    fprintf('  ✓ Vertex %d has %d neighbors\n', v, length(nbrs));
    fprintf('  ✓ Neighbor indices valid\n');
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 5: Shortest path with different metrics
fprintf('Test 5: Shortest path with different metrics...\n');

try
    s = 1;
    t = 50;
    
    % Geometry metric
    [path_geo, dist_geo] = B.Manifold.Graph.shortestPath(s, t, "geometry");
    assert(path_geo(1) == s, 'Path should start at source');
    assert(path_geo(end) == t, 'Path should end at target');
    assert(dist_geo > 0, 'Distance should be positive');
    
    % FEM metric
    [path_fem, dist_fem] = B.Manifold.Graph.shortestPath(s, t, "fem");
    assert(path_fem(1) == s, 'Path should start at source');
    assert(path_fem(end) == t, 'Path should end at target');
    assert(dist_fem > 0, 'Distance should be positive');
    
    fprintf('  ✓ Geometry path: %d hops, distance: %.3f\n', ...
            length(path_geo), dist_geo);
    fprintf('  ✓ FEM path: %d hops, distance: %.3f\n', ...
            length(path_fem), dist_fem);
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 6: graphWithMetric returns weighted graph
fprintf('Test 6: graphWithMetric returns weighted graph...\n');

try
    Ggeo = B.Manifold.Graph.graphWithMetric("geometry");
    Gfem = B.Manifold.Graph.graphWithMetric("fem");
    
    assert(isa(Ggeo, 'graph'), 'Should return MATLAB graph');
    assert(isa(Gfem, 'graph'), 'Should return MATLAB graph');
    
    assert(numnodes(Ggeo) == B.Manifold.Graph.N, 'Node count should match');
    assert(numedges(Ggeo) == size(B.Manifold.Graph.edgeIndex, 1), ...
           'Edge count should match');
    
    % Check weights are assigned
    assert(all(Ggeo.Edges.Weight > 0), 'Geometry weights should be positive');
    assert(all(Gfem.Edges.Weight >= 0), 'FEM weights should be non-negative');
    
    fprintf('  ✓ Geometry graph created with weights\n');
    fprintf('  ✓ FEM graph created with weights\n');
    fprintf('  ✓ Graph dimensions correct\n');
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 7: Error handling for unknown metric
fprintf('Test 7: Error handling for unknown metric...\n');

try
    errorCaught = false;
    try
        G = B.Manifold.Graph.graphWithMetric("nonexistent");
    catch ME
        errorCaught = true;
        assert(contains(ME.identifier, 'UnknownMetric'), ...
               'Should throw UnknownMetric error');
    end
    
    assert(errorCaught, 'Should have caught error for unknown metric');
    fprintf('  ✓ Correctly throws error for unknown metric\n');
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' All Graph Integration Tests Passed!\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

fprintf('Summary:\n');
fprintf('  • Graph automatically created with Manifold\n');
fprintf('  • Canonical topology extracted from cotangent matrix\n');
fprintf('  • Geometry and FEM metrics computed as overlays\n');
fprintf('  • Neighbor queries work correctly\n');
fprintf('  • Shortest path with multiple metrics\n');
fprintf('  • graphWithMetric returns weighted MATLAB graphs\n');
fprintf('  • Error handling for invalid metrics\n\n');

fprintf('Usage pattern:\n');
fprintf('  B = bct.bct.fromMesh(V, F);\n');
fprintf('  [path, dist] = B.Manifold.Graph.shortestPath(1, 100, "geometry");\n');
fprintf('  nbrs = B.Manifold.Graph.neighbors(42);\n');
fprintf('  Gfem = B.Manifold.Graph.graphWithMetric("fem");\n\n');
