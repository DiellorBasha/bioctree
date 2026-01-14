function tests = test_manifold
    % test_manifold - Test bct.Manifold construction and methods
    %
    % Tests verify:
    % - Manifold construction from V and F arrays
    % - Eigenmode computation and caching
    % - Topology computation and caching
    % - Geometry wrapper methods (faceGeometry, vertexGeometry, edgeGeometry)
    %
    % Total: 6 tests
    
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Apply shared fixture that initializes BCT and loads default mesh
    testCase.TestData.fixture = testCase.applyFixture(ManifoldFixture());
end

function testManifoldFromVerticesAndFaces(testCase)
    % Test: Create Manifold from V and F arrays
    
    % Get V and F from fixture
    fixture = testCase.TestData.fixture;
    V = fixture.V;
    F = fixture.F;
    
    % Create Manifold object
    M = bct.Manifold(V, F);
    
    % Verify construction succeeded
    verifyClass(testCase, M, 'bct.Manifold');
    verifyNotEmpty(testCase, M.Vertices);
    verifyNotEmpty(testCase, M.Faces);
    
    % Verify dimensions - second dimension should be 3
    verifyEqual(testCase, size(M.Vertices, 2), 3, 'Vertices should be N×3');
    verifyEqual(testCase, size(M.Faces, 2), 3, 'Faces should be M×3');
    
    % Verify input data matches object properties
    verifyEqual(testCase, M.Vertices, V);
    verifyEqual(testCase, M.Faces, F);
    
    % Verify vertex and face counts
    verifyGreaterThan(testCase, size(M.Vertices, 1), 0, 'Should have at least one vertex');
    verifyGreaterThan(testCase, size(M.Faces, 1), 0, 'Should have at least one face');
end

function testManifoldEigenmodes(testCase)
    % Test: Compute eigenmodes from Manifold and verify caching
    
    % Get pre-constructed Manifold from fixture
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Verify eigenmodes not cached initially
    verifyFalse(testCase, M.hasCached('eigenmodes'), 'Eigenmodes should not be cached initially');
    
    % Compute 40 eigenmodes (DC mode removed by default, so we get 39)
    k_requested = 40;
    E = M.eigenmodes(k_requested);
    
    % Verify eigenmodes are now cached
    verifyTrue(testCase, M.hasCached('eigenmodes'), 'Eigenmodes should be cached after computation');
    
    % Verify returned eigenmodes structure
    verifyClass(testCase, E, 'struct');
    verifyTrue(testCase, isfield(E, 'vectors'), 'Should have vectors field');
    verifyTrue(testCase, isfield(E, 'values'), 'Should have values field');
    verifyTrue(testCase, isfield(E, 'k'), 'Should have k field');
    verifyTrue(testCase, isfield(E, 'removedDC'), 'Should have removedDC field');
    
    % Verify DC mode was removed (default behavior)
    verifyTrue(testCase, E.removedDC, 'DC mode should be removed by default');
    
    % Verify correct number of eigenmodes (k_requested - 1 due to DC removal)
    k_actual = k_requested - 1;
    verifyEqual(testCase, size(E.vectors, 2), k_actual, 'Should have k-1 eigenvectors (DC removed)');
    verifyEqual(testCase, length(E.values), k_actual, 'Should have k-1 eigenvalues (DC removed)');
    verifyEqual(testCase, E.k, k_actual, 'k field should reflect actual retained modes');
    
    % Verify eigenvectors have correct dimensions
    nVertices = size(M.Vertices, 1);
    verifyEqual(testCase, size(E.vectors, 1), nVertices, 'Eigenvectors should match vertex count');
    
    % Verify eigenvalues are sorted in ascending order
    verifyTrue(testCase, issorted(E.values), 'Eigenvalues should be sorted');
    
    % Verify eigenvalues are non-negative (Laplacian property)
    verifyGreaterThanOrEqual(testCase, E.values, 0, 'Eigenvalues should be non-negative');
    
    % Verify cache retrieval returns same eigenmodes without recomputation
    E_cached = M.eigenmodes();  % Should return cached version
    verifyEqual(testCase, E_cached.vectors, E.vectors, 'Cached eigenvectors should match');
    verifyEqual(testCase, E_cached.values, E.values, 'Cached eigenvalues should match');
    verifyEqual(testCase, E_cached.k, k_actual, 'Cached k should match actual retained modes');
end

function testManifoldTopology(testCase)
    % Test: Compute topology from Manifold and verify caching
    
    % Get pre-constructed Manifold from fixture
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Verify topology not cached initially
    verifyFalse(testCase, M.hasCached('topology'), 'Topology should not be cached initially');
    
    % Compute topology
    topo = M.topology();
    
    % Verify topology is now cached
    verifyTrue(testCase, M.hasCached('topology'), 'Topology should be cached after computation');
    
    % Verify returned topology structure
    verifyClass(testCase, topo, 'struct');
    verifyTrue(testCase, isfield(topo, 'edges'), 'Should have edges field');
    verifyTrue(testCase, isfield(topo, 'adjacency'), 'Should have adjacency field');
    verifyTrue(testCase, isfield(topo, 'halfedge'), 'Should have halfedge field');
    
    % Verify edges structure
    verifyEqual(testCase, size(topo.edges, 2), 2, 'Edges should be nE×2');
    verifyGreaterThan(testCase, size(topo.edges, 1), 0, 'Should have at least one edge');
    
    % Verify adjacency matrix
    nVertices = size(M.Vertices, 1);
    verifySize(testCase, topo.adjacency, [nVertices, nVertices], 'Adjacency should be N×N');
    verifyTrue(testCase, issparse(topo.adjacency), 'Adjacency matrix should be sparse');
    verifyEqual(testCase, topo.adjacency, topo.adjacency', 'Adjacency should be symmetric');
    
    % Verify halfedge structure exists
    verifyClass(testCase, topo.halfedge, 'struct');
    
    % Verify cache retrieval returns same topology without recomputation
    topo_cached = M.topology();  % Should return cached version
    verifyEqual(testCase, topo_cached.edges, topo.edges, 'Cached edges should match');
    verifyEqual(testCase, topo_cached.adjacency, topo.adjacency, 'Cached adjacency should match');
end

function testManifoldFaceGeometry(testCase)
    % Test: Compute face geometry from Manifold and verify caching
    
    % Get pre-constructed Manifold from fixture
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Compute face geometry
    faceGeom = M.faceGeometry();
    
    % Verify returned face geometry structure
    verifyClass(testCase, faceGeom, 'struct');
    verifyTrue(testCase, isfield(faceGeom, 'areas'), 'Should have areas field');
    verifyTrue(testCase, isfield(faceGeom, 'centroids'), 'Should have centroids field');
    verifyTrue(testCase, isfield(faceGeom, 'circumcenters'), 'Should have circumcenters field');
    verifyTrue(testCase, isfield(faceGeom, 'normals'), 'Should have normals field');
    verifyTrue(testCase, isfield(faceGeom, 'cotan'), 'Should have cotan field');
    verifyTrue(testCase, isfield(faceGeom, 'tangent1'), 'Should have tangent1 field');
    verifyTrue(testCase, isfield(faceGeom, 'tangent2'), 'Should have tangent2 field');
    
    % Verify dimensions
    nFaces = size(M.Faces, 1);
    verifyEqual(testCase, size(faceGeom.areas, 1), nFaces, 'Should have one area per face');
    verifyEqual(testCase, size(faceGeom.centroids), [nFaces, 3], 'Centroids should be nF×3');
    verifyEqual(testCase, size(faceGeom.normals), [nFaces, 3], 'Normals should be nF×3');
    verifyEqual(testCase, size(faceGeom.tangent1), [nFaces, 3], 'Tangent1 should be nF×3');
    verifyEqual(testCase, size(faceGeom.tangent2), [nFaces, 3], 'Tangent2 should be nF×3');
    
    % Verify all areas are positive
    verifyGreaterThan(testCase, faceGeom.areas, 0, 'All face areas should be positive');
    
    % Verify normals are unit vectors
    norms = sqrt(sum(faceGeom.normals.^2, 2));
    verifyEqual(testCase, norms, ones(nFaces, 1), 'AbsTol', 1e-10, 'Normals should be unit vectors');
    
    % Verify cache retrieval returns same geometry without recomputation
    faceGeom_cached = M.faceGeometry();
    verifyEqual(testCase, faceGeom_cached.areas, faceGeom.areas, 'Cached areas should match');
    verifyEqual(testCase, faceGeom_cached.normals, faceGeom.normals, 'Cached normals should match');
end

function testManifoldVertexGeometry(testCase)
    % Test: Compute vertex geometry from Manifold and verify caching
    
    % Get pre-constructed Manifold from fixture
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Compute vertex geometry
    vertexGeom = M.vertexGeometry();
    
    % Verify returned vertex geometry structure
    verifyClass(testCase, vertexGeom, 'struct');
    verifyTrue(testCase, isfield(vertexGeom, 'normals'), 'Should have normals field');
    verifyTrue(testCase, isfield(vertexGeom, 'tangent1'), 'Should have tangent1 field');
    verifyTrue(testCase, isfield(vertexGeom, 'tangent2'), 'Should have tangent2 field');
    
    % Verify dimensions
    nVertices = size(M.Vertices, 1);
    verifyEqual(testCase, size(vertexGeom.normals), [nVertices, 3], 'Normals should be nV×3');
    verifyEqual(testCase, size(vertexGeom.tangent1), [nVertices, 3], 'Tangent1 should be nV×3');
    verifyEqual(testCase, size(vertexGeom.tangent2), [nVertices, 3], 'Tangent2 should be nV×3');
    
    % Verify normals are unit vectors
    norms = sqrt(sum(vertexGeom.normals.^2, 2));
    verifyEqual(testCase, norms, ones(nVertices, 1), 'AbsTol', 1e-10, 'Normals should be unit vectors');
    
    % Verify tangents are orthogonal to normals (spot check first vertex)
    dot_n_t1 = dot(vertexGeom.normals(1,:), vertexGeom.tangent1(1,:));
    dot_n_t2 = dot(vertexGeom.normals(1,:), vertexGeom.tangent2(1,:));
    verifyEqual(testCase, dot_n_t1, 0, 'AbsTol', 1e-10, 'Tangent1 should be orthogonal to normal');
    verifyEqual(testCase, dot_n_t2, 0, 'AbsTol', 1e-10, 'Tangent2 should be orthogonal to normal');
    
    % Verify cache retrieval returns same geometry without recomputation
    vertexGeom_cached = M.vertexGeometry();
    verifyEqual(testCase, vertexGeom_cached.normals, vertexGeom.normals, 'Cached normals should match');
    verifyEqual(testCase, vertexGeom_cached.tangent1, vertexGeom.tangent1, 'Cached tangent1 should match');
end

function testManifoldEdgeGeometry(testCase)
    % Test: Compute edge geometry from Manifold and verify caching
    
    % Get pre-constructed Manifold from fixture
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Compute edge geometry
    edgeGeom = M.edgeGeometry();
    
    % Verify returned edge geometry structure
    verifyClass(testCase, edgeGeom, 'struct');
    verifyTrue(testCase, isfield(edgeGeom, 'lengths'), 'Should have lengths field');
    verifyTrue(testCase, isfield(edgeGeom, 'weights'), 'Should have weights field');
    
    % Verify weights is a structure
    verifyClass(testCase, edgeGeom.weights, 'struct');
    
    % Verify dimensions
    nEdges = size(edgeGeom.lengths, 1);
    verifyGreaterThan(testCase, nEdges, 0, 'Should have at least one edge');
    verifyEqual(testCase, size(edgeGeom.lengths, 2), 1, 'Lengths should be nE×1');
    
    % Verify all edge lengths are positive
    verifyGreaterThan(testCase, edgeGeom.lengths, 0, 'All edge lengths should be positive');
    
    % Verify cache retrieval returns same geometry without recomputation
    edgeGeom_cached = M.edgeGeometry();
    verifyEqual(testCase, edgeGeom_cached.lengths, edgeGeom.lengths, 'Cached lengths should match');
end
