classdef test_bct_topology < BaseBctTest
    % TEST_BCT_TOPOLOGY Unified tests for bct.manifold.topology package
    %
    % Tests all topology functions:
    % - edges: Extract unique edges from faces
    % - adjacency: Build vertex adjacency matrix
    % - halfedge: Halfedge connectivity structure
    %
    % Tests both Manifold object and face connectivity calling patterns
    
    methods (Test)
        %% EDGES TESTS
        function testEdgesManifold(testCase)
            % Verify edges extraction from Manifold
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E = bct.manifold.topology.edges(M);
            
            testCase.verifySize(E(:,1), [size(E,1), 1], ...
                'Edges should have first column');
            testCase.verifySize(E(:,2), [size(E,1), 1], ...
                'Edges should have second column');
            testCase.verifyEqual(min(E(:)), 1, ...
                'Min vertex index should be 1');
            testCase.verifyEqual(max(E(:)), size(V,1), ...
                'Max vertex index should be Nv');
        end
        
        function testEdgesFaces(testCase)
            % Verify edges extraction from faces directly
            [~, F] = testCase.getDefaultTestMesh();
            
            E = bct.manifold.topology.edges(F);
            
            testCase.verifyEqual(size(E,2), 2, ...
                'Edges should have 2 columns');
        end
        
        function testEdgesUnique(testCase)
            % Verify edges are unique
            [~, F] = testCase.getDefaultTestMesh();
            
            E = bct.manifold.topology.edges(F);
            E_unique = unique(sort(E, 2), 'rows');
            
            testCase.verifyEqual(size(E,1), size(E_unique,1), ...
                'All edges should be unique');
        end
        
        function testEdgesEulerClosedMesh(testCase)
            % Verify Euler characteristic for closed mesh: V - E + F = 2
            % Use fsaverage which is a closed mesh
            [V, F] = testCase.getDefaultTestMesh();
            
            E = bct.manifold.topology.edges(F);
            chi = size(V,1) - size(E,1) + size(F,1);
            
            testCase.verifyEqual(chi, 2, ...
                'Closed mesh (fsaverage) should have Euler characteristic χ = 2');
        end
        
        function testEdgesManifoldProperty(testCase)
            % Verify consistency with Manifold.Edges property
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            E1 = M.Edges;
            E2 = bct.manifold.topology.edges(M);
            
            testCase.verifyEqual(E1, E2, ...
                'bct.manifold.topology.edges should match Manifold.Edges');
        end
        
        %% ADJACENCY TESTS
        function testAdjacencyManifold(testCase)
            % Verify adjacency matrix from Manifold
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            A = bct.manifold.topology.adjacency(M);
            
            testCase.verifySize(A, [size(V,1), size(V,1)], ...
                'Adjacency should be [Nv×Nv]');
            testCase.verifyTrue(issparse(A), ...
                'Adjacency should be sparse');
            testCase.verifyTrue(islogical(A), ...
                'Adjacency should be logical');
        end
        
        function testAdjacencyFaces(testCase)
            % Verify adjacency from faces directly
            [V, F] = testCase.getDefaultTestMesh();
            
            A = bct.manifold.topology.adjacency(F, size(V,1));
            
            testCase.verifySize(A, [size(V,1), size(V,1)]);
        end
        
        function testAdjacencySymmetric(testCase)
            % Verify adjacency is symmetric
            [V, F] = testCase.getDefaultTestMesh();
            
            A = bct.manifold.topology.adjacency(F, size(V,1));
            
            testCase.verifyEqual(A, A', ...
                'Adjacency should be symmetric');
        end
        
        function testAdjacencyNoSelfLoops(testCase)
            % Verify no self-loops
            [V, F] = testCase.getDefaultTestMesh();
            
            A = bct.manifold.topology.adjacency(F, size(V,1));
            
            testCase.verifyEqual(double(full(diag(A))), zeros(size(V,1), 1), ...
                'Adjacency should have no self-loops');
        end
        
        function testAdjacencyBinary(testCase)
            % Verify adjacency is binary (0 or 1)
            [V, F] = testCase.getDefaultTestMesh();
            
            A = bct.manifold.topology.adjacency(F, size(V,1));
            vals = unique(A(:));
            
            testCase.verifyTrue(all(ismember(vals, [0; 1])), ...
                'Adjacency values should be 0 or 1');
        end
        
        function testAdjacencyManifoldMethod(testCase)
            % Verify consistency with Manifold.adjacency()
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            A1 = M.adjacency();
            A2 = bct.manifold.topology.adjacency(M);
            
            testCase.verifyEqual(A1, A2, ...
                'Manifold.adjacency() should match bct.manifold.topology.adjacency()');
        end
        
        %% HALFEDGE TESTS
        function testHalfedgeManifold(testCase)
            % Verify halfedge structure from Manifold
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            he = bct.manifold.topology.halfedge(V, F);
            
            testCase.verifyTrue(isstruct(he), ...
                'Output should be a struct');
            
            % Check required fields
            requiredFields = {'v', 'to', 'face', 'next', 'prev', 'twin', ...
                             'edge', 'isBoundary', 'E', 'fh'};
            for i = 1:length(requiredFields)
                testCase.verifyTrue(isfield(he, requiredFields{i}), ...
                    sprintf('Should have field: %s', requiredFields{i}));
            end
        end
        
        function testHalfedgeVF(testCase)
            % Verify halfedge from V,F directly
            [V, F] = testCase.getDefaultTestMesh();
            
            he = bct.manifold.topology.halfedge(V, F);
            
            testCase.verifyTrue(isstruct(he));
        end
        
        function testHalfedgeSize(testCase)
            % Verify halfedge array sizes
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            he = bct.manifold.topology.halfedge(V, F);
            
            % Each face contributes 3 halfedges
            Nh = size(F, 1) * 3;
            
            testCase.verifyEqual(length(he.v), Nh, ...
                'Should have 3 halfedges per face');
            testCase.verifyEqual(length(he.to), Nh);
            testCase.verifyEqual(length(he.face), Nh);
        end
        
        function testHalfedgeNextPrevCircular(testCase)
            % Verify next/prev form circular lists within faces
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            he = bct.manifold.topology.halfedge(V, F);
            
            % For each halfedge, next(prev(h)) == h and prev(next(h)) == h
            for h = 1:length(he.next)
                testCase.verifyEqual(he.next(he.prev(h)), h, ...
                    sprintf('next(prev(%d)) should equal %d', h, h));
                testCase.verifyEqual(he.prev(he.next(h)), h, ...
                    sprintf('prev(next(%d)) should equal %d', h, h));
            end
        end
        
        function testHalfedgeTwinSymmetry(testCase)
            % Verify twin relationship is symmetric
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            he = bct.manifold.topology.halfedge(V, F);
            
            % For non-boundary halfedges, twin(twin(h)) == h
            for h = 1:length(he.twin)
                if ~he.isBoundary(h)
                    twin_h = he.twin(h);
                    if twin_h > 0  % Has a twin
                        testCase.verifyEqual(he.twin(twin_h), h, ...
                            sprintf('twin(twin(%d)) should equal %d', h, h));
                    end
                end
            end
        end
        
        function testHalfedgeBoundaryDetection(testCase)
            % Verify boundary detection on mesh with boundary
            % Create simple 2-triangle mesh forming a square with one edge open
            V = [0 0 0; 1 0 0; 1 1 0; 0 1 0];
            F = [1 2 3; 1 3 4];
            
            he = bct.manifold.topology.halfedge(V, F);
            
            % Count boundary halfedges
            nBoundary = sum(he.isBoundary);
            
            % Square perimeter has 4 boundary edges
            testCase.verifyEqual(nBoundary, 4, ...
                'Should detect 4 boundary halfedges for open square');
        end
        
        function testHalfedgeEdgeMapping(testCase)
            % Verify edge mapping consistency
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            he = bct.manifold.topology.halfedge(V, F);
            E = bct.manifold.topology.edges(M);
            
            testCase.verifyEqual(size(he.E, 1), size(E, 1), ...
                'Halfedge edge list should match topology edges');
        end
        
        function testHalfedgeFaceHalfedges(testCase)
            % Verify fh (face halfedges) structure
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            he = bct.manifold.topology.halfedge(V, F);
            
            testCase.verifySize(he.fh, [size(F,1), 3], ...
                'fh should be [Nf×3] storing 3 halfedges per face');
            
            % Each fh entry should be a valid halfedge index
            testCase.verifyTrue(all(he.fh(:) >= 1 & he.fh(:) <= length(he.v)), ...
                'All fh entries should be valid halfedge indices');
        end
        
        function testHalfedgeClosedMeshNoBoundary(testCase)
            % Verify closed mesh has no boundary halfedges
            % Use fsaverage which is a closed mesh
            [V, F] = testCase.getDefaultTestMesh();
            
            he = bct.manifold.topology.halfedge(V, F);
            
            testCase.verifyEqual(sum(he.isBoundary), 0, ...
                'Closed mesh (fsaverage) should have no boundary halfedges');
        end
    end
end

