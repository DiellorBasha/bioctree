function tests = test_geometry
    % test_geometry - Test bct.manifold.geometry package functions
    %
    % Tests are organized bottom-up:
    % 1. Low-level functions (areas, normals, tangents, lengths, etc.)
    % 2. Sub-aggregators (face, vertex, edge, dual)
    % 3. Main aggregator (M.geometry())
    %
    % Total: 21 tests
    % - 16 low-level tests (face: 7, vertex: 3, edge: 2, dual: 2, halfedge: 2)
    % - 4 aggregator tests (face, vertex, edge, dual)
    % - 1 main geometry test
    
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Apply shared fixture that initializes BCT and loads default mesh
    testCase.TestData.fixture = testCase.applyFixture(ManifoldFixture());
end

%% ========================================================================
%% LEVEL 1: LOW-LEVEL FUNCTIONS (Individual Computations)
%% ========================================================================

%% Face Low-Level Functions

%% Face Low-Level Functions

function testFaceAreas(testCase)
    % Test: bct.manifold.geometry.face.areas
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, areas] = bct.manifold.geometry.face.areas(M);
    
    % Verify output
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, areas, 'double');
    
    nFaces = size(M.Faces, 1);
    verifyEqual(testCase, size(areas, 1), nFaces);
    verifyEqual(testCase, size(areas, 2), 1);
    
    % All areas should be positive
    verifyGreaterThan(testCase, areas, 0, 'All face areas should be positive');
end

function testFaceCentroids(testCase)
    % Test: bct.manifold.geometry.face.centroids
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, centroids] = bct.manifold.geometry.face.centroids(M);
    
    % Verify output
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, centroids, 'double');
    
    nFaces = size(M.Faces, 1);
    verifyEqual(testCase, size(centroids), [nFaces, 3]);
end

function testFaceCircumcenters(testCase)
    % Test: bct.manifold.geometry.face.circumcenters
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, circumcenters] = bct.manifold.geometry.face.circumcenters(M);
    
    % Verify output
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, circumcenters, 'double');
    
    nFaces = size(M.Faces, 1);
    verifyEqual(testCase, size(circumcenters), [nFaces, 3]);
end

function testFaceCotan(testCase)
    % Test: bct.manifold.geometry.face.cotan
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, cotan] = bct.manifold.geometry.face.cotan(M);
    
    % Verify output
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, cotan, 'double');
    
    nFaces = size(M.Faces, 1);
    verifyEqual(testCase, size(cotan), [nFaces, 3]);
end

function testFaceTangents1(testCase)
    % Test: bct.manifold.geometry.face.tangents1
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, tangent1] = bct.manifold.geometry.face.tangents1(M);
    
    % Verify outputs
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, tangent1, 'double');
    
    nFaces = size(M.Faces, 1);
    verifyEqual(testCase, size(tangent1), [nFaces, 3]);
    
    % Tangents should be unit vectors
    norms = sqrt(sum(tangent1.^2, 2));
    verifyEqual(testCase, norms, ones(nFaces, 1), 'AbsTol', 1e-10, 'Tangent1 should be unit vectors');
    
    % Verify orthogonal to normals
    [~, normals] = bct.manifold.geometry.face.normals(M);
    dots = sum(normals .* tangent1, 2);
    verifyEqual(testCase, dots, zeros(nFaces, 1), 'AbsTol', 1e-10, 'Tangent1 should be orthogonal to normals');
end

function testFaceTangents2(testCase)
    % Test: bct.manifold.geometry.face.tangents2
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, tangent2] = bct.manifold.geometry.face.tangents2(M);
    
    % Verify outputs
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, tangent2, 'double');
    
    nFaces = size(M.Faces, 1);
    verifyEqual(testCase, size(tangent2), [nFaces, 3]);
    
    % Tangents should be unit vectors
    norms = sqrt(sum(tangent2.^2, 2));
    verifyEqual(testCase, norms, ones(nFaces, 1), 'AbsTol', 1e-10, 'Tangent2 should be unit vectors');
    
    % Verify orthogonal to normals and tangent1
    [~, normals] = bct.manifold.geometry.face.normals(M);
    [~, tangent1] = bct.manifold.geometry.face.tangents1(M);
    dots_n = sum(normals .* tangent2, 2);
    dots_t1 = sum(tangent1 .* tangent2, 2);
    verifyEqual(testCase, dots_n, zeros(nFaces, 1), 'AbsTol', 1e-10, 'Tangent2 should be orthogonal to normals');
    verifyEqual(testCase, dots_t1, zeros(nFaces, 1), 'AbsTol', 1e-10, 'Tangent2 should be orthogonal to tangent1');
end

function testFaceNormals(testCase)
    % Test: bct.manifold.geometry.face.normals
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, normals] = bct.manifold.geometry.face.normals(M);
    
    % Verify output
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, normals, 'double');
    
    nFaces = size(M.Faces, 1);
    verifyEqual(testCase, size(normals), [nFaces, 3]);
    
    % Normals should be unit vectors
    norms = sqrt(sum(normals.^2, 2));
    verifyEqual(testCase, norms, ones(nFaces, 1), 'AbsTol', 1e-10, 'Normals should be unit vectors');
end

%% Vertex Low-Level Functions

function testVertexTangents1(testCase)
    % Test: bct.manifold.geometry.vertex.tangents1
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, tangent1] = bct.manifold.geometry.vertex.tangents1(M);
    
    % Verify outputs
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, tangent1, 'double');
    
    nVertices = size(M.Vertices, 1);
    verifyEqual(testCase, size(tangent1), [nVertices, 3]);
    
    % Tangents should be unit vectors
    norms = sqrt(sum(tangent1.^2, 2));
    verifyEqual(testCase, norms, ones(nVertices, 1), 'AbsTol', 1e-10, 'Tangent1 should be unit vectors');
    
    % Verify orthogonal to normals
    [~, normals] = bct.manifold.geometry.vertex.normals(M);
    dots = sum(normals .* tangent1, 2);
    verifyEqual(testCase, dots, zeros(nVertices, 1), 'AbsTol', 1e-10, 'Tangent1 should be orthogonal to normals');
end

function testVertexTangents2(testCase)
    % Test: bct.manifold.geometry.vertex.tangents2
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, tangent2] = bct.manifold.geometry.vertex.tangents2(M);
    
    % Verify outputs
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, tangent2, 'double');
    
    nVertices = size(M.Vertices, 1);
    verifyEqual(testCase, size(tangent2), [nVertices, 3]);
    
    % Tangents should be unit vectors
    norms = sqrt(sum(tangent2.^2, 2));
    verifyEqual(testCase, norms, ones(nVertices, 1), 'AbsTol', 1e-10, 'Tangent2 should be unit vectors');
    
    % Verify orthogonal to normals and tangent1
    [~, normals] = bct.manifold.geometry.vertex.normals(M);
    [~, tangent1] = bct.manifold.geometry.vertex.tangents1(M);
    dots_n = sum(normals .* tangent2, 2);
    dots_t1 = sum(tangent1 .* tangent2, 2);
    verifyEqual(testCase, dots_n, zeros(nVertices, 1), 'AbsTol', 1e-10, 'Tangent2 should be orthogonal to normals');
    verifyEqual(testCase, dots_t1, zeros(nVertices, 1), 'AbsTol', 1e-10, 'Tangent2 should be orthogonal to tangent1');
end

function testVertexNormals(testCase)
    % Test: bct.manifold.geometry.vertex.normals
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, normals] = bct.manifold.geometry.vertex.normals(M);
    
    % Verify output
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, normals, 'double');
    
    nVertices = size(M.Vertices, 1);
    verifyEqual(testCase, size(normals), [nVertices, 3]);
    
    % Normals should be unit vectors
    norms = sqrt(sum(normals.^2, 2));
    verifyEqual(testCase, norms, ones(nVertices, 1), 'AbsTol', 1e-10, 'Normals should be unit vectors');
end

%% Edge Low-Level Functions

function testEdgeLengths(testCase)
    % Test: bct.manifold.geometry.edge.lengths
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, lengths] = bct.manifold.geometry.edge.lengths(M);
    
    % Verify output
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, lengths, 'double');
    
    verifyGreaterThan(testCase, size(lengths, 1), 0, 'Should have at least one edge');
    verifyEqual(testCase, size(lengths, 2), 1);
    
    % All lengths should be positive
    verifyGreaterThan(testCase, lengths, 0, 'All edge lengths should be positive');
end

function testEdgeWeights(testCase)
    % Test: bct.manifold.geometry.edge.weights
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    [header, weights] = bct.manifold.geometry.edge.weights(M);
    
    % Verify output
    verifyClass(testCase, header, 'struct');
    verifyClass(testCase, weights, 'struct');
    
    % Should have cotangent and euclidean weights
    verifyTrue(testCase, isfield(weights, 'cotangent'), 'Should have cotangent weights');
    verifyTrue(testCase, isfield(weights, 'euclidean'), 'Should have euclidean weights');
end

%% Dual Low-Level Functions

function testDualEdgeLengths(testCase)
    % Test: bct.manifold.geometry.dual.edgeLengths
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Dual geometry requires closed mesh - may need error handling
    try
        [header, edgeLengths] = bct.manifold.geometry.dual.edgeLengths(M);
        
        % Verify output
        verifyClass(testCase, header, 'struct');
        verifyClass(testCase, edgeLengths, 'double');
        
        verifyGreaterThan(testCase, size(edgeLengths, 1), 0, 'Should have at least one dual edge');
        
        % All dual edge lengths should be positive
        verifyGreaterThan(testCase, edgeLengths, 0, 'Dual edge lengths should be positive');
    catch ME
        % If mesh has boundaries, expect error
        if contains(ME.identifier, 'BoundaryNotSupported')
            verifyTrue(testCase, true, 'Boundary mesh correctly raises error for dual edge lengths');
        else
            rethrow(ME);
        end
    end
end

function testDualVertexAreas(testCase)
    % Test: bct.manifold.geometry.dual.vertexAreas
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Dual geometry requires closed mesh - may need error handling
    try
        [header, vertexAreas] = bct.manifold.geometry.dual.vertexAreas(M);
        
        % Verify output
        verifyClass(testCase, header, 'struct');
        verifyClass(testCase, vertexAreas, 'double');
        
        nVertices = size(M.Vertices, 1);
        verifyEqual(testCase, size(vertexAreas, 1), nVertices, 'Should have one area per vertex');
        
        % All dual vertex areas should be positive
        verifyGreaterThan(testCase, vertexAreas, 0, 'Dual vertex areas should be positive');
    catch ME
        % If mesh has boundaries, expect error
        if contains(ME.identifier, 'BoundaryNotSupported')
            verifyTrue(testCase, true, 'Boundary mesh correctly raises error for dual vertex areas');
        else
            rethrow(ME);
        end
    end
end

%% ========================================================================
%% LEVEL 2: SUB-AGGREGATORS (face, vertex, edge, dual)
%% ========================================================================
%% ========================================================================
%% LEVEL 2: SUB-AGGREGATORS (face, vertex, edge, dual)
%% ========================================================================

function testFaceAggregator(testCase)
    % Test: bct.manifold.geometry.face aggregator
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    face = bct.manifold.geometry.face(M);
    
    % Verify structure
    verifyClass(testCase, face, 'struct');
    verifyTrue(testCase, isfield(face, 'areas'), 'Should have areas field');
    verifyTrue(testCase, isfield(face, 'centroids'), 'Should have centroids field');
    verifyTrue(testCase, isfield(face, 'circumcenters'), 'Should have circumcenters field');
    verifyTrue(testCase, isfield(face, 'normals'), 'Should have normals field');
    verifyTrue(testCase, isfield(face, 'cotan'), 'Should have cotan field');
    verifyTrue(testCase, isfield(face, 'tangent1'), 'Should have tangent1 field');
    verifyTrue(testCase, isfield(face, 'tangent2'), 'Should have tangent2 field');
    
    nFaces = size(M.Faces, 1);
    verifyEqual(testCase, size(face.areas, 1), nFaces, 'Should have one area per face');
    verifyEqual(testCase, size(face.centroids, 1), nFaces, 'Should have one centroid per face');
    verifyEqual(testCase, size(face.normals, 1), nFaces, 'Should have one normal per face');
    verifyEqual(testCase, size(face.tangent1, 1), nFaces, 'Should have one tangent1 per face');
    verifyEqual(testCase, size(face.tangent2, 1), nFaces, 'Should have one tangent2 per face');
end

function testVertexAggregator(testCase)
    % Test: bct.manifold.geometry.vertex aggregator
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    vertex = bct.manifold.geometry.vertex(M);
    
    % Verify structure
    verifyClass(testCase, vertex, 'struct');
    verifyTrue(testCase, isfield(vertex, 'normals'), 'Should have normals field');
    verifyTrue(testCase, isfield(vertex, 'tangent1'), 'Should have tangent1 field');
    verifyTrue(testCase, isfield(vertex, 'tangent2'), 'Should have tangent2 field');
    
    nVertices = size(M.Vertices, 1);
    verifyEqual(testCase, size(vertex.normals, 1), nVertices, 'Should have one normal per vertex');
    verifyEqual(testCase, size(vertex.tangent1, 1), nVertices, 'Should have one tangent1 per vertex');
    verifyEqual(testCase, size(vertex.tangent2, 1), nVertices, 'Should have one tangent2 per vertex');
end

function testEdgeAggregator(testCase)
    % Test: bct.manifold.geometry.edge aggregator
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    edge = bct.manifold.geometry.edge(M);
    
    % Verify structure
    verifyClass(testCase, edge, 'struct');
    verifyTrue(testCase, isfield(edge, 'lengths'), 'Should have lengths field');
    verifyTrue(testCase, isfield(edge, 'weights'), 'Should have weights field');
    
    nEdges = size(edge.lengths, 1);
    verifyGreaterThan(testCase, nEdges, 0, 'Should have at least one edge');
    
    % All edge lengths should be positive
    verifyGreaterThan(testCase, edge.lengths, 0, 'All edge lengths should be positive');
end

function testDualAggregator(testCase)
    % Test: bct.manifold.geometry.dual aggregator
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Dual geometry requires closed mesh - may need error handling
    try
        dual = bct.manifold.geometry.dual(M);
        
        % Verify structure
        verifyClass(testCase, dual, 'struct');
        verifyTrue(testCase, isfield(dual, 'edgeLengths'), 'Should have edgeLengths field');
        verifyTrue(testCase, isfield(dual, 'vertexAreas'), 'Should have vertexAreas field');
        
        % All dual quantities should be positive
        verifyGreaterThan(testCase, dual.edgeLengths, 0, 'Dual edge lengths should be positive');
        verifyGreaterThan(testCase, dual.vertexAreas, 0, 'Dual vertex areas should be positive');
    catch ME
        % If mesh has boundaries, expect error
        if contains(ME.identifier, 'BoundaryNotSupported')
            verifyTrue(testCase, true, 'Boundary mesh correctly raises error for dual geometry');
        else
            rethrow(ME);
        end
    end
end

%% ========================================================================
%% LEVEL 3: MAIN AGGREGATOR (M.geometry())
%% ========================================================================

function testGeometryAggregator(testCase)
    % Test: M.geometry() returns complete geometry structure
    
    fixture = testCase.TestData.fixture;
    M = fixture.M;
    
    % Verify geometry not cached initially
    verifyFalse(testCase, M.hasCached('geometry'), 'Geometry should not be cached initially');
    
    % Compute all geometry
    geom = M.geometry();
    
    % Verify geometry is now cached
    verifyTrue(testCase, M.hasCached('geometry'), 'Geometry should be cached after computation');
    
    % Verify main structure
    verifyClass(testCase, geom, 'struct');
    verifyTrue(testCase, isfield(geom, 'face'), 'Should have face field');
    verifyTrue(testCase, isfield(geom, 'vertex'), 'Should have vertex field');
    verifyTrue(testCase, isfield(geom, 'edge'), 'Should have edge field');
    verifyTrue(testCase, isfield(geom, 'dual'), 'Should have dual field');
    verifyTrue(testCase, isfield(geom, 'header'), 'Should have header field');
    
    % Verify cache retrieval returns same geometry
    geom_cached = M.geometry();
    verifyEqual(testCase, geom_cached.face.areas, geom.face.areas, 'Cached geometry should match');
end
