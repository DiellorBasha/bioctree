classdef test_bct_graph < BaseBctTest
    % TEST_BCT_GRAPH Unified tests for bct.graph package
    %
    % Tests all graph functions:
    % - assembleAdjacency: Graph adjacency matrix construction
    % - assembleDegree: Vertex degree computation
    % - assembleLaplacian: Graph Laplacian construction
    % - eigensolve: Laplace-Beltrami eigendecomposition
    % - distances: Geodesic distance computation
    % - shortestPath: Shortest path finding
    % - bfSearch: Breadth-first search
    % - dfSearch: Depth-first search
    % - edgeLengths: Edge length computation
    % - femWeights: FEM-based edge weights
    % - matlabGraph: MATLAB graph object conversion
    
    methods (Test)
        %% ADJACENCY TESTS
        function testAssembleAdjacencyBasic(testCase)
            % Verify adjacency matrix construction
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            A = bct.graph.assembleAdjacency(M);
            
            testCase.verifySize(A, [M.numVertices(), M.numVertices()], ...
                'Adjacency should be [Nv×Nv]');
            testCase.verifyTrue(issparse(A), ...
                'Adjacency should be sparse');
            testCase.verifyEqual(A, A', ...
                'Adjacency should be symmetric');
        end
        
        function testAssembleAdjacencyFromVF(testCase)
            % Verify adjacency from V, F input
            [V, F] = testCase.getDefaultTestMesh();
            
            A = bct.graph.assembleAdjacency(V, F);
            
            testCase.verifyTrue(issparse(A), ...
                'Adjacency should be sparse');
        end
        
        %% DEGREE TESTS
        function testAssembleDegree(testCase)
            % Verify degree computation
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            D = bct.graph.assembleDegree(M);
            
            testCase.verifySize(D, [M.numVertices(), M.numVertices()], ...
                'Degree matrix should be [Nv×Nv]');
            testCase.verifyTrue(issparse(D), ...
                'Degree matrix should be sparse');
            testCase.verifyTrue(all(diag(D) > 0), ...
                'All vertices should have positive degree');
        end
        
        %% LAPLACIAN TESTS
        function testAssembleLaplacian(testCase)
            % Verify Laplacian construction
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            L = bct.graph.assembleLaplacian(M);
            
            testCase.verifySize(L, [M.numVertices(), M.numVertices()], ...
                'Laplacian should be [Nv×Nv]');
            testCase.verifyTrue(issparse(L), ...
                'Laplacian should be sparse');
            testCase.verifyEqual(L, L', ...
                'Laplacian should be symmetric');
        end
        
        function testLaplacianRowSum(testCase)
            % Verify Laplacian row sums are zero
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            L = bct.graph.assembleLaplacian(M);
            rowSums = sum(L, 2);
            
            testCase.verifyLessThan(max(abs(rowSums)), 1e-10, ...
                'Laplacian row sums should be zero');
        end
        
        %% EIGENSOLVE TESTS
        function testEigensolveBasic(testCase)
            % Verify eigensolve returns eigenmode structure
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E = bct.graph.eigensolve(M, 10);
            
            testCase.verifyClass(E, 'struct', ...
                'Should return eigenmode structure');
            testCase.verifyEqual(E.k, 10, ...
                'Should have 10 eigenpairs');
        end
        
        function testEigensolveSorted(testCase)
            % Verify eigenvalues are sorted ascending
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E = bct.graph.eigensolve(M, 20);
            lambda = E.Values;
            
            testCase.verifyTrue(issorted(lambda), ...
                'Eigenvalues should be sorted ascending');
            testCase.verifyGreaterThanOrEqual(lambda(1), -1e-10, ...
                'First eigenvalue should be ~0 (DC mode)');
        end
        
        function testEigensolveOrthonormal(testCase)
            % Verify eigenvectors are orthonormal
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E = bct.graph.eigensolve(M, 10);
            Psi = E.Vectors;
            
            % Check orthonormality
            I_approx = Psi' * Psi;
            testCase.verifyLessThan(norm(I_approx - eye(10), 'fro'), 1e-8, ...
                'Eigenvectors should be orthonormal');
        end
        
        %% DISTANCES TESTS
        function testDistances(testCase)
            % Verify geodesic distance computation
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            sourceIdx = 1;
            D = bct.graph.distances(M, sourceIdx);
            
            testCase.verifySize(D, [M.numVertices(), 1], ...
                'Distances should be [Nv×1]');
            testCase.verifyEqual(D(sourceIdx), 0, ...
                'Distance to source should be zero');
            testCase.verifyTrue(all(D >= 0), ...
                'All distances should be non-negative');
        end
        
        function testDistancesMultipleSources(testCase)
            % Verify distances from multiple sources
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            sources = [1, 10, 100];
            D = bct.graph.distances(M, sources);
            
            testCase.verifySize(D, [M.numVertices(), length(sources)], ...
                'Distances should be [Nv×Nsources]');
            for i = 1:length(sources)
                testCase.verifyEqual(D(sources(i), i), 0, ...
                    'Distance to source should be zero');
            end
        end
        
        %% SHORTEST PATH TESTS
        function testShortestPath(testCase)
            % Verify shortest path finding
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            source = 1;
            target = 100;
            path = bct.graph.shortestPath(M, source, target);
            
            testCase.verifyGreaterThanOrEqual(length(path), 2, ...
                'Path should have at least 2 vertices');
            testCase.verifyEqual(path(1), source, ...
                'Path should start at source');
            testCase.verifyEqual(path(end), target, ...
                'Path should end at target');
        end
        
        %% SEARCH TESTS
        function testBreadthFirstSearch(testCase)
            % Verify BFS traversal
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            startVertex = 1;
            visited = bct.graph.bfSearch(M, startVertex);
            
            testCase.verifySize(visited, [M.numVertices(), 1], ...
                'Visited should be [Nv×1]');
            testCase.verifyEqual(visited(1), 1, ...
                'Start vertex should be visited first');
        end
        
        function testDepthFirstSearch(testCase)
            % Verify DFS traversal
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            startVertex = 1;
            visited = bct.graph.dfSearch(M, startVertex);
            
            testCase.verifySize(visited, [M.numVertices(), 1], ...
                'Visited should be [Nv×1]');
            testCase.verifyEqual(visited(1), 1, ...
                'Start vertex should be visited first');
        end
        
        %% EDGE TESTS
        function testEdgeLengths(testCase)
            % Verify edge length computation
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            lengths = bct.graph.edgeLengths(M);
            
            testCase.verifyTrue(isvector(lengths), ...
                'Edge lengths should be a vector');
            testCase.verifyTrue(all(lengths > 0), ...
                'All edge lengths should be positive');
        end
        
        function testFemWeights(testCase)
            % Verify FEM-based edge weights (cotangent)
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            W = bct.graph.femWeights(M);
            
            testCase.verifySize(W, [M.numVertices(), M.numVertices()], ...
                'Weights should be [Nv×Nv]');
            testCase.verifyTrue(issparse(W), ...
                'Weights should be sparse');
            testCase.verifyEqual(W, W', ...
                'Weights should be symmetric');
        end
        
        %% CONVERSION TESTS
        function testMatlabGraphConversion(testCase)
            % Verify conversion to MATLAB graph object
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            G = bct.graph.matlabGraph(M);
            
            testCase.verifyClass(G, 'graph', ...
                'Should return MATLAB graph object');
            testCase.verifyEqual(G.numnodes, M.numVertices(), ...
                'Graph should have same number of nodes');
        end
    end
end
