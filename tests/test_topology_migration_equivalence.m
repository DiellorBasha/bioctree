classdef test_topology_migration_equivalence < matlab.unittest.TestCase
    %TEST_TOPOLOGY_MIGRATION_EQUIVALENCE Verify bct.topology.* matches existing methods
    %
    % This test suite validates that the new bct.topology package produces
    % identical results to the original implementations in bct.manifold and
    % bct.Manifold methods.
    %
    % Test coverage:
    %   - edges: Unique edge extraction
    %   - adjacency: Binary adjacency matrix
    %   - halfedge: Halfedge connectivity structure
    %
    % Tolerance: Exact matches for integer/logical arrays
    
    properties
        TestMesh           % Small test mesh with boundary (Manifold object)
        ClosedMesh         % Closed mesh (Manifold object)
        TestV              % Test vertices
        TestF              % Test faces
        ClosedV            % Closed mesh vertices
        ClosedF            % Closed mesh faces
    end
    
    methods (TestClassSetup)
        function createTestMeshes(testCase)
            % Create small mesh with boundary (two triangles)
            testCase.TestV = [0 0 0; 1 0 0; 1 1 0; 0 1 0];
            testCase.TestF = [1 2 3; 1 3 4];
            testCase.TestMesh = bct.Manifold(testCase.TestV, testCase.TestF);
            
            % Create closed mesh (tetrahedron)
            testCase.ClosedV = [0 0 0; 1 0 0; 0.5 sqrt(3)/2 0; 0.5 sqrt(3)/6 sqrt(2/3)];
            testCase.ClosedF = [1 2 3; 1 3 4; 1 4 2; 2 4 3];
            testCase.ClosedMesh = bct.Manifold(testCase.ClosedV, testCase.ClosedF);
        end
    end
    
    methods (Test)
        %% Edges Tests
        
        function testEdgesFromManifold(testCase)
            % Test edges from Manifold object
            E_old = testCase.TestMesh.Edges;
            E_new = bct.topology.edges(testCase.TestMesh);
            
            % Sort for comparison (order may differ)
            E_old_sorted = sortrows(E_old);
            E_new_sorted = sortrows(E_new);
            
            testCase.verifyEqual(E_old_sorted, E_new_sorted, ...
                'Edges from Manifold must match exactly');
        end
        
        function testEdgesFromFaces(testCase)
            % Test edges from faces directly
            E_manifold = testCase.TestMesh.Edges;
            E_topo = bct.topology.edges(testCase.TestF);
            
            % Sort for comparison
            E_manifold_sorted = sortrows(E_manifold);
            E_topo_sorted = sortrows(E_topo);
            
            testCase.verifyEqual(E_manifold_sorted, E_topo_sorted, ...
                'Edges from faces must match Manifold.Edges');
        end
        
        function testEdgesClosedMesh(testCase)
            % Test edges on closed mesh
            E_old = testCase.ClosedMesh.Edges;
            E_new = bct.topology.edges(testCase.ClosedMesh);
            
            E_old_sorted = sortrows(E_old);
            E_new_sorted = sortrows(E_new);
            
            testCase.verifyEqual(E_old_sorted, E_new_sorted, ...
                'Edges on closed mesh must match');
        end
        
        function testEdgesCount(testCase)
            % Verify edge counts match Euler characteristic
            % For boundary mesh: E = V + F - 1 (one boundary component)
            % For closed mesh: E = V + F - 2 (Euler characteristic)
            
            % Test mesh with boundary
            E_test = bct.topology.edges(testCase.TestF);
            V_test = size(testCase.TestV, 1);
            F_test = size(testCase.TestF, 1);
            nE_test = size(E_test, 1);
            testCase.verifyEqual(nE_test, V_test + F_test - 1, ...
                'Boundary mesh edge count incorrect (should be V+F-1)');
            
            % Closed mesh
            E_closed = bct.topology.edges(testCase.ClosedF);
            V_closed = size(testCase.ClosedV, 1);
            F_closed = size(testCase.ClosedF, 1);
            nE_closed = size(E_closed, 1);
            testCase.verifyEqual(nE_closed, V_closed + F_closed - 2, ...
                'Closed mesh edge count incorrect (should be V+F-2)');
        end
        
        %% Adjacency Tests
        
        function testAdjacencyFromManifold(testCase)
            % Test adjacency from Manifold object
            A_old = testCase.TestMesh.adjacency();
            A_new = bct.topology.adjacency(testCase.TestMesh);
            
            testCase.verifyEqual(nnz(A_old - A_new), 0, ...
                'Adjacency from Manifold must match exactly');
        end
        
        function testAdjacencyFromFaces(testCase)
            % Test adjacency from faces directly
            A_manifold = testCase.TestMesh.adjacency();
            A_topo = bct.topology.adjacency(testCase.TestF);
            
            testCase.verifyEqual(nnz(A_manifold - A_topo), 0, ...
                'Adjacency from faces must match Manifold.adjacency()');
        end
        
        function testAdjacencyFromFacesExplicitN(testCase)
            % Test adjacency with explicit vertex count
            nV = size(testCase.TestV, 1);
            A_manifold = testCase.TestMesh.adjacency();
            A_topo = bct.topology.adjacency(testCase.TestF, nV);
            
            testCase.verifyEqual(nnz(A_manifold - A_topo), 0, ...
                'Adjacency with explicit N must match');
        end
        
        function testAdjacencyProperties(testCase)
            % Test adjacency matrix properties
            A = bct.topology.adjacency(testCase.TestMesh);
            
            % Symmetric
            testCase.verifyEqual(nnz(A - A.'), 0, ...
                'Adjacency must be symmetric');
            
            % No self-loops
            testCase.verifyEqual(nnz(diag(A)), 0, ...
                'Adjacency must have no self-loops');
            
            % Binary (logical or 0/1)
            testCase.verifyTrue(all(A(:) == 0 | A(:) == 1), ...
                'Adjacency must be binary');
        end
        
        function testAdjacencyClosedMesh(testCase)
            % Test adjacency on closed mesh
            A_old = testCase.ClosedMesh.adjacency();
            A_new = bct.topology.adjacency(testCase.ClosedMesh);
            
            testCase.verifyEqual(nnz(A_old - A_new), 0, ...
                'Adjacency on closed mesh must match');
        end
        
        %% Halfedge Tests
        
        function testHalfedgeStructure(testCase)
            % Test halfedge from manifold function
            he_old = bct.manifold.halfedge(testCase.TestV, testCase.TestF);
            he_new = bct.topology.halfedge(testCase.TestV, testCase.TestF);
            
            % Compare all integer/logical fields
            testCase.verifyEqual(he_old.nV, he_new.nV, 'nV must match');
            testCase.verifyEqual(he_old.nF, he_new.nF, 'nF must match');
            testCase.verifyEqual(he_old.nH, he_new.nH, 'nH must match');
            
            testCase.verifyEqual(he_old.v, he_new.v, 'Halfedge tail vertices must match');
            testCase.verifyEqual(he_old.to, he_new.to, 'Halfedge head vertices must match');
            testCase.verifyEqual(he_old.face, he_new.face, 'Halfedge face IDs must match');
            testCase.verifyEqual(he_old.next, he_new.next, 'Halfedge next pointers must match');
            testCase.verifyEqual(he_old.prev, he_new.prev, 'Halfedge prev pointers must match');
            testCase.verifyEqual(he_old.twin, he_new.twin, 'Halfedge twin pointers must match');
            testCase.verifyEqual(he_old.edge, he_new.edge, 'Halfedge edge IDs must match');
            testCase.verifyEqual(he_old.isBoundary, he_new.isBoundary, 'Boundary flags must match');
            testCase.verifyEqual(he_old.E, he_new.E, 'Edge list must match');
            testCase.verifyEqual(he_old.fh, he_new.fh, 'Face halfedges must match');
        end
        
        function testHalfedgeBoundaryDetection(testCase)
            % Test boundary detection on mesh with boundary
            he = bct.topology.halfedge(testCase.TestV, testCase.TestF);
            
            % Count boundary halfedges
            nBoundary = sum(he.isBoundary);
            
            % Mesh with 2 triangles sharing edge should have 4 boundary edges
            % (Two triangles form a square: 4 edges on perimeter, 1 shared interior edge)
            testCase.verifyGreaterThan(nBoundary, 0, ...
                'Boundary mesh must have boundary halfedges');
            testCase.verifyEqual(nBoundary, 4, ...
                'Expected 4 boundary halfedges for 2-triangle mesh forming square');
        end
        
        function testHalfedgeClosedMesh(testCase)
            % Test halfedge on closed mesh (no boundary)
            he = bct.topology.halfedge(testCase.ClosedV, testCase.ClosedF);
            
            % Closed mesh should have no boundary
            nBoundary = sum(he.isBoundary);
            testCase.verifyEqual(nBoundary, 0, ...
                'Closed mesh should have no boundary halfedges');
            
            % All halfedges should have twins
            testCase.verifyTrue(all(he.twin > 0), ...
                'Closed mesh: all halfedges should have twins');
        end
        
        function testHalfedgeConsistency(testCase)
            % Test halfedge structure internal consistency
            he = bct.topology.halfedge(testCase.TestV, testCase.TestF);
            
            % Test next/prev circularity: next(prev(h)) == h
            for h = 1:he.nH
                testCase.verifyEqual(he.next(he.prev(h)), h, ...
                    sprintf('Halfedge %d: next(prev(h)) != h', h));
                testCase.verifyEqual(he.prev(he.next(h)), h, ...
                    sprintf('Halfedge %d: prev(next(h)) != h', h));
            end
            
            % Test twin symmetry: if twin(h) > 0, then twin(twin(h)) == h
            for h = 1:he.nH
                if he.twin(h) > 0
                    testCase.verifyEqual(he.twin(he.twin(h)), h, ...
                        sprintf('Halfedge %d: twin(twin(h)) != h', h));
                end
            end
        end
    end
end
