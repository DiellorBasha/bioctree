classdef test_bct_manifold_tangents < BaseBctTest
    % TEST_BCT_MANIFOLD_TANGENTS Unit tests for bct.manifold.tangents
    %
    % Tests tangent frame computation with cached geometry:
    % - Face tangents (default)
    % - Vertex tangents
    % - Direct V,F input (non-cached path)
    % - Instance method wrappers
    % - Unit length verification
    % - Orthogonality
    % - Right-handedness
    % - Simple test case correctness
    % - Consistency with normals and cached frames
    
    methods (Test)
        function testDefaultFaceTangents(testCase)
            % Verify default returns face tangents
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.manifold.tangents(M);
            
            testCase.verifySize(N, [size(F,1), 3], ...
                'Default should return face tangents');
            testCase.verifySize(e1, [size(F,1), 3], ...
                'e1 should match face count');
            testCase.verifySize(e2, [size(F,1), 3], ...
                'e2 should match face count');
        end
        
        function testExplicitFaceTangents(testCase)
            % Verify explicit 'face' domain
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'face');
            
            testCase.verifySize(N, [size(F,1), 3], ...
                'Face domain should return face tangents');
        end
        
        function testVertexTangents(testCase)
            % Verify 'vertex' domain returns vertex tangents
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'vertex');
            
            testCase.verifySize(N, [size(V,1), 3], ...
                'Vertex domain should return vertex tangents');
            testCase.verifySize(e1, [size(V,1), 3], ...
                'e1 should match vertex count');
            testCase.verifySize(e2, [size(V,1), 3], ...
                'e2 should match vertex count');
        end
        
        function testDirectVFFaceTangents(testCase)
            % Verify V,F input computes face tangents
            [V, F] = testCase.getDefaultTestMesh();
            
            [N, e1, e2] = bct.manifold.tangents(V, F);
            
            testCase.verifySize(N, [size(F,1), 3], ...
                'V,F should return face tangents by default');
        end
        
        function testDirectVFVertexTangents(testCase)
            % Verify V,F with 'vertex' computes vertex tangents
            [V, F] = testCase.getDefaultTestMesh();
            
            [N, e1, e2] = bct.manifold.tangents(V, F, 'Domain', 'vertex');
            
            testCase.verifySize(N, [size(V,1), 3], ...
                'V,F with vertex domain should return vertex tangents');
        end
        
        function testInstanceMethodDefault(testCase)
            % Verify instance method M.tangents()
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = M.tangents();
            
            testCase.verifySize(N, [size(F,1), 3], ...
                'Instance method should return face tangents by default');
        end
        
        function testInstanceMethodVertex(testCase)
            % Verify instance method M.tangents('Domain', 'vertex')
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = M.tangents('Domain', 'vertex');
            
            testCase.verifySize(N, [size(V,1), 3], ...
                'Instance method with vertex domain should return vertex tangents');
        end
        
        function testFaceTangentsUnitLength(testCase)
            % Verify face tangent vectors are unit length
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'face');
            
            N_norms = vecnorm(N, 2, 2);
            e1_norms = vecnorm(e1, 2, 2);
            e2_norms = vecnorm(e2, 2, 2);
            
            testCase.verifyTrue(all(abs(N_norms - 1) < 1e-6), ...
                'Face normals should be unit vectors');
            testCase.verifyTrue(all(abs(e1_norms - 1) < 1e-6), ...
                'Face e1 should be unit vectors');
            testCase.verifyTrue(all(abs(e2_norms - 1) < 1e-6), ...
                'Face e2 should be unit vectors');
        end
        
        function testVertexTangentsUnitLength(testCase)
            % Verify vertex tangent vectors are unit length
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'vertex');
            
            N_norms = vecnorm(N, 2, 2);
            e1_norms = vecnorm(e1, 2, 2);
            e2_norms = vecnorm(e2, 2, 2);
            
            testCase.verifyTrue(all(abs(N_norms - 1) < 1e-6), ...
                'Vertex normals should be unit vectors');
            testCase.verifyTrue(all(abs(e1_norms - 1) < 1e-6), ...
                'Vertex e1 should be unit vectors');
            testCase.verifyTrue(all(abs(e2_norms - 1) < 1e-6), ...
                'Vertex e2 should be unit vectors');
        end
        
        function testFaceTangentsOrthogonality(testCase)
            % Verify face tangent frame is orthogonal
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'face');
            
            dot_e1_N = abs(sum(e1 .* N, 2));
            dot_e2_N = abs(sum(e2 .* N, 2));
            dot_e1_e2 = abs(sum(e1 .* e2, 2));
            
            testCase.verifyTrue(all(dot_e1_N < 1e-6), ...
                'e1 should be orthogonal to N');
            testCase.verifyTrue(all(dot_e2_N < 1e-6), ...
                'e2 should be orthogonal to N');
            testCase.verifyTrue(all(dot_e1_e2 < 1e-6), ...
                'e1 should be orthogonal to e2');
        end
        
        function testVertexTangentsOrthogonality(testCase)
            % Verify vertex tangent frame is orthogonal
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'vertex');
            
            dot_e1_N = abs(sum(e1 .* N, 2));
            dot_e2_N = abs(sum(e2 .* N, 2));
            dot_e1_e2 = abs(sum(e1 .* e2, 2));
            
            testCase.verifyTrue(all(dot_e1_N < 1e-6), ...
                'e1 should be orthogonal to N');
            testCase.verifyTrue(all(dot_e2_N < 1e-6), ...
                'e2 should be orthogonal to N');
            testCase.verifyTrue(all(dot_e1_e2 < 1e-6), ...
                'e1 should be orthogonal to e2');
        end
        
        function testFaceTangentsRightHanded(testCase)
            % Verify face frame is right-handed: e1 × e2 = N
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'face');
            
            cross_e1_e2 = cross(e1, e2, 2);
            diff = vecnorm(cross_e1_e2 - N, 2, 2);
            
            testCase.verifyTrue(all(diff < 1e-6), ...
                'Face frame should be right-handed: e1 × e2 = N');
        end
        
        function testVertexTangentsRightHanded(testCase)
            % Verify vertex frame is right-handed: e1 × e2 = N
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'vertex');
            
            cross_e1_e2 = cross(e1, e2, 2);
            diff = vecnorm(cross_e1_e2 - N, 2, 2);
            
            testCase.verifyTrue(all(diff < 1e-6), ...
                'Vertex frame should be right-handed: e1 × e2 = N');
        end
        
        function testSimpleTriangleCorrectness(testCase)
            % Verify correctness on simple triangle in XY plane
            V_tri = [0 0 0; 1 0 0; 0 1 0];
            F_tri = [1 2 3];
            M_tri = bct.Manifold(V_tri, F_tri);
            
            [N, e1, e2] = bct.manifold.tangents(M_tri, 'Domain', 'face');
            
            expected_N = [0, 0, 1];
            expected_e1 = [1, 0, 0];
            expected_e2 = [0, 1, 0];
            
            testCase.verifyEqual(N, expected_N, 'AbsTol', 1e-6, ...
                'Normal should be [0,0,1]');
            testCase.verifyEqual(e1, expected_e1, 'AbsTol', 1e-6, ...
                'e1 should be [1,0,0]');
            testCase.verifyEqual(e2, expected_e2, 'AbsTol', 1e-6, ...
                'e2 should be [0,1,0]');
        end
        
        function testConsistencyWithNormals(testCase)
            % Verify N matches bct.manifold.normals()
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Face tangents and normals
            [N_tangents, ~, ~] = bct.manifold.tangents(M, 'Domain', 'face');
            N_normals = bct.manifold.normals(M, 'Face');
            
            testCase.verifyEqual(N_tangents, N_normals, ...
                'Face normals from tangents should match normals()');
            
            % Vertex tangents and normals
            [N_tangents_v, ~, ~] = bct.manifold.tangents(M, 'Domain', 'vertex');
            N_normals_v = bct.manifold.normals(M, 'Vertex');
            
            testCase.verifyEqual(N_tangents_v, N_normals_v, ...
                'Vertex normals from tangents should match normals()');
        end
        
        function testCachedFrameConsistency(testCase)
            % Verify tangents() uses cached frame
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Get frame first
            fr = bct.manifold.frame(M);
            
            % Get face tangents (should use cached frame)
            [N_f, e1_f, e2_f] = bct.manifold.tangents(M, 'Domain', 'face');
            
            testCase.verifyEqual(N_f, fr.Face.N, ...
                'Face normals should match cached frame');
            testCase.verifyEqual(e1_f, fr.Face.T1, ...
                'Face e1 should match cached frame');
            testCase.verifyEqual(e2_f, fr.Face.T2, ...
                'Face e2 should match cached frame');
            
            % Get vertex tangents (should use cached frame)
            [N_v, e1_v, e2_v] = bct.manifold.tangents(M, 'Domain', 'vertex');
            
            testCase.verifyEqual(N_v, fr.Vertex.N, ...
                'Vertex normals should match cached frame');
            testCase.verifyEqual(e1_v, fr.Vertex.T1, ...
                'Vertex e1 should match cached frame');
            testCase.verifyEqual(e2_v, fr.Vertex.T2, ...
                'Vertex e2 should match cached frame');
        end
        
        function testSimpleTetrahedron(testCase)
            % Verify vertex tangents on simple tetrahedron
            V_tet = [0 0 0; 1 0 0; 0.5 sqrt(3)/2 0; 0.5 sqrt(3)/6 sqrt(2/3)];
            F_tet = [1 2 3; 1 3 4; 1 4 2; 2 4 3];
            M_tet = bct.Manifold(V_tet, F_tet);
            
            [N, e1, e2] = bct.manifold.tangents(M_tet, 'Domain', 'vertex');
            
            % Verify dimensions
            testCase.verifySize(N, [4, 3], ...
                'Should have 4 vertex normals');
            
            % Verify unit length
            testCase.verifyTrue(all(abs(vecnorm(N, 2, 2) - 1) < 1e-6), ...
                'Vertex normals should be unit');
            testCase.verifyTrue(all(abs(vecnorm(e1, 2, 2) - 1) < 1e-6), ...
                'e1 should be unit');
            testCase.verifyTrue(all(abs(vecnorm(e2, 2, 2) - 1) < 1e-6), ...
                'e2 should be unit');
        end
    end
end
