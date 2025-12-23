classdef test_bct_manifold_normals < BaseBctTest
    % TEST_BCT_MANIFOLD_NORMALS Unit tests for bct.manifold.normals
    %
    % Tests normal computation with cached frames:
    % - Vertex normals (default)
    % - Face normals
    % - Direct V,F input (non-cached path)
    % - Instance method wrappers
    % - Case-insensitive type arguments
    % - Unit length verification
    % - Simple triangle correctness
    
    methods (Test)
        function testDefaultVertexNormals(testCase)
            % Verify default returns vertex normals
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            N = bct.manifold.normals(M);
            
            testCase.verifySize(N, [size(V,1), 3], ...
                'Default should return vertex normals');
        end
        
        function testExplicitVertexNormals(testCase)
            % Verify explicit 'Vertex' type
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            N = bct.manifold.normals(M, 'Vertex');
            
            testCase.verifySize(N, [size(V,1), 3], ...
                'Vertex type should return vertex normals');
        end
        
        function testFaceNormals(testCase)
            % Verify 'Face' type returns face normals
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            N = bct.manifold.normals(M, 'Face');
            
            testCase.verifySize(N, [size(F,1), 3], ...
                'Face type should return face normals');
        end
        
        function testDirectVFVertexNormals(testCase)
            % Verify V,F input computes vertex normals
            [V, F] = testCase.getDefaultTestMesh();
            
            N = bct.manifold.normals(V, F);
            
            testCase.verifySize(N, [size(V,1), 3], ...
                'V,F should return vertex normals by default');
        end
        
        function testDirectVFFaceNormals(testCase)
            % Verify V,F with 'Face' computes face normals
            [V, F] = testCase.getDefaultTestMesh();
            
            N = bct.manifold.normals(V, F, 'Face');
            
            testCase.verifySize(N, [size(F,1), 3], ...
                'V,F with Face type should return face normals');
        end
        
        function testInstanceMethodDefault(testCase)
            % Verify instance method M.normals()
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            N = M.normals();
            
            testCase.verifySize(N, [size(V,1), 3], ...
                'Instance method should return vertex normals by default');
        end
        
        function testInstanceMethodFace(testCase)
            % Verify instance method M.normals('Face')
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            N = M.normals('Face');
            
            testCase.verifySize(N, [size(F,1), 3], ...
                'Instance method with Face should return face normals');
        end
        
        function testCaseInsensitiveTypes(testCase)
            % Verify case-insensitive type arguments
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            N_vertex = bct.manifold.normals(M, 'vertex');
            N_Vertex = bct.manifold.normals(M, 'Vertex');
            N_VERTEX = bct.manifold.normals(M, 'VERTEX');
            
            testCase.verifyEqual(N_vertex, N_Vertex, ...
                'Lowercase vertex should work');
            testCase.verifyEqual(N_vertex, N_VERTEX, ...
                'Uppercase VERTEX should work');
            
            N_face = bct.manifold.normals(M, 'face');
            N_Face = bct.manifold.normals(M, 'Face');
            N_FACE = bct.manifold.normals(M, 'FACE');
            
            testCase.verifyEqual(N_face, N_Face, ...
                'Lowercase face should work');
            testCase.verifyEqual(N_face, N_FACE, ...
                'Uppercase FACE should work');
        end
        
        function testUnitLength(testCase)
            % Verify all normals are unit vectors
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Vertex normals
            VN = bct.manifold.normals(M, 'Vertex');
            VN_norms = vecnorm(VN, 2, 2);
            testCase.verifyTrue(all(abs(VN_norms - 1) < 1e-6), ...
                'Vertex normals should be unit vectors');
            
            % Face normals
            FN = bct.manifold.normals(M, 'Face');
            FN_norms = vecnorm(FN, 2, 2);
            testCase.verifyTrue(all(abs(FN_norms - 1) < 1e-6), ...
                'Face normals should be unit vectors');
        end
        
        function testSimpleTriangleCorrectness(testCase)
            % Verify correctness on simple triangle in XY plane
            V_tri = [0 0 0; 1 0 0; 0 1 0];
            F_tri = [1 2 3];
            M_tri = bct.Manifold(V_tri, F_tri);
            
            N = bct.manifold.normals(M_tri, 'Face');
            
            expected = [0, 0, 1];
            testCase.verifyEqual(N, expected, 'AbsTol', 1e-6, ...
                'Triangle face normal should be [0,0,1]');
        end
        
        function testCachedFrameConsistency(testCase)
            % Verify normals() uses cached frame
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Get frame first
            fr = bct.manifold.frame(M);
            
            % Get normals (should use cached frame)
            VN = bct.manifold.normals(M, 'Vertex');
            FN = bct.manifold.normals(M, 'Face');
            
            % Should match frame
            testCase.verifyEqual(VN, fr.Vertex.N, ...
                'Vertex normals should match cached frame');
            testCase.verifyEqual(FN, fr.Face.N, ...
                'Face normals should match cached frame');
        end
    end
end
