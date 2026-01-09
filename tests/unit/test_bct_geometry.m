classdef test_bct_geometry < BaseBctTest
    % TEST_BCT_GEOMETRY Unified tests for bct.geometry package
    %
    % Tests all geometry functions:
    % - centroids: Face geometric centers
    % - normals: Vertex and face normals
    % - tangents: Orthonormal tangent frames
    % - frame: Cached coordinate frame computation
    %
    % Tests both Manifold object and (V,F) calling patterns
    
    methods (Test)
        %% CENTROIDS TESTS
        function testCentroidsManifold(testCase)
            % Verify centroids with Manifold object
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            C = bct.geometry.centroids(M);
            
            testCase.verifySize(C, [size(F,1), 3], ...
                'Centroids should be [Nf×3]');
        end
        
        function testCentroidsVF(testCase)
            % Verify centroids with V,F input
            [V, F] = testCase.getDefaultTestMesh();
            
            C = bct.geometry.centroids(V, F);
            
            testCase.verifySize(C, [size(F,1), 3], ...
                'Centroids should be [Nf×3]');
        end
        
        function testCentroidsSimpleTriangle(testCase)
            % Verify correctness on simple triangle
            V = [0 0 0; 1 0 0; 0 1 0];
            F = [1 2 3];
            
            C = bct.geometry.centroids(V, F);
            C_expected = [1/3, 1/3, 0];
            
            testCase.verifyLessThan(abs(C - C_expected), 1e-12, ...
                'Centroid should be at (1/3, 1/3, 0)');
        end
        
        function testCentroidsManifoldMethod(testCase)
            % Verify Manifold.centroids() uses bct.geometry
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            C1 = M.centroids();
            C2 = bct.geometry.centroids(M);
            
            testCase.verifyEqual(C1, C2, ...
                'Manifold.centroids() should match bct.geometry.centroids()');
        end
        
        %% NORMALS TESTS
        function testNormalsVertexDefault(testCase)
            % Verify default returns vertex normals
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            N = bct.geometry.normals(M);
            
            testCase.verifySize(N, [size(V,1), 3], ...
                'Default should return vertex normals');
        end
        
        function testNormalsFace(testCase)
            % Verify 'Face' type returns face normals
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            N = bct.geometry.normals(M, 'Face');
            
            testCase.verifySize(N, [size(F,1), 3], ...
                'Face type should return face normals');
        end
        
        function testNormalsVFInput(testCase)
            % Verify V,F input works
            [V, F] = testCase.getDefaultTestMesh();
            
            N = bct.geometry.normals(V, F);
            
            testCase.verifySize(N, [size(V,1), 3], ...
                'V,F input should return vertex normals');
        end
        
        function testNormalsUnitLength(testCase)
            % Verify normals are unit length
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            N = bct.geometry.normals(M);
            norms = vecnorm(N, 2, 2);
            
            testCase.verifyLessThan(abs(norms - 1), 1e-10, ...
                'Normals should be unit length');
        end
        
        function testNormalsManifoldMethod(testCase)
            % Verify Manifold.normals() uses bct.geometry
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            N1 = M.normals();
            N2 = bct.geometry.normals(M);
            
            testCase.verifyEqual(N1, N2, ...
                'Manifold.normals() should match bct.geometry.normals()');
        end
        
        %% TANGENTS TESTS
        function testTangentsFaceDefault(testCase)
            % Verify default returns face tangents
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.geometry.tangents(M);
            
            testCase.verifySize(N, [size(F,1), 3], ...
                'Default should return face tangents');
            testCase.verifySize(e1, [size(F,1), 3]);
            testCase.verifySize(e2, [size(F,1), 3]);
        end
        
        function testTangentsVertex(testCase)
            % Verify 'vertex' domain returns vertex tangents
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.geometry.tangents(M, 'Domain', 'vertex');
            
            testCase.verifySize(N, [size(V,1), 3], ...
                'Vertex domain should return vertex tangents');
        end
        
        function testTangentsOrthonormal(testCase)
            % Verify tangent frame is orthonormal
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.geometry.tangents(M);
            
            % Unit length
            testCase.verifyLessThan(max(abs(vecnorm(N,2,2) - 1)), 1e-10, ...
                'N should be unit length');
            testCase.verifyLessThan(max(abs(vecnorm(e1,2,2) - 1)), 1e-10, ...
                'e1 should be unit length');
            testCase.verifyLessThan(max(abs(vecnorm(e2,2,2) - 1)), 1e-10, ...
                'e2 should be unit length');
            
            % Orthogonality
            dot_Ne1 = sum(N .* e1, 2);
            dot_Ne2 = sum(N .* e2, 2);
            dot_e1e2 = sum(e1 .* e2, 2);
            
            testCase.verifyLessThan(max(abs(dot_Ne1)), 1e-10, ...
                'N and e1 should be orthogonal');
            testCase.verifyLessThan(max(abs(dot_Ne2)), 1e-10, ...
                'N and e2 should be orthogonal');
            testCase.verifyLessThan(max(abs(dot_e1e2)), 1e-10, ...
                'e1 and e2 should be orthogonal');
        end
        
        function testTangentsRightHanded(testCase)
            % Verify frame is right-handed: e1 × e2 = N
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N, e1, e2] = bct.geometry.tangents(M);
            
            cross_prod = cross(e1, e2, 2);
            
            testCase.verifyLessThan(max(vecnorm(cross_prod - N, 2, 2)), 1e-10, ...
                'Frame should be right-handed: e1 × e2 = N');
        end
        
        function testTangentsManifoldMethod(testCase)
            % Verify Manifold.tangents() uses bct.geometry
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            [N1, e1_1, e2_1] = M.tangents();
            [N2, e1_2, e2_2] = bct.geometry.tangents(M);
            
            testCase.verifyEqual(N1, N2);
            testCase.verifyEqual(e1_1, e1_2);
            testCase.verifyEqual(e2_1, e2_2, ...
                'Manifold.tangents() should match bct.geometry.tangents()');
        end
        
        %% FRAME TESTS
        function testFrameStructure(testCase)
            % Verify frame returns correct structure
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fr = bct.geometry.frame(M);
            
            % Check structure fields
            testCase.verifyTrue(isstruct(fr), 'Output should be a struct');
            testCase.verifyTrue(isfield(fr, 'Face'), 'Should have Face field');
            testCase.verifyTrue(isfield(fr, 'Vertex'), 'Should have Vertex field');
            testCase.verifyTrue(isfield(fr, 'Meta'), 'Should have Meta field');
            
            % Check nested fields
            testCase.verifyTrue(isfield(fr.Face, 'N'));
            testCase.verifyTrue(isfield(fr.Face, 'T1'));
            testCase.verifyTrue(isfield(fr.Face, 'T2'));
            testCase.verifyTrue(isfield(fr.Vertex, 'N'));
            testCase.verifyTrue(isfield(fr.Vertex, 'T1'));
            testCase.verifyTrue(isfield(fr.Vertex, 'T2'));
        end
        
        function testFrameCaching(testCase)
            % Verify frame is cached in Manifold
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % First call - compute
            fr1 = bct.geometry.frame(M);
            
            % Second call - should be cached
            fr2 = bct.geometry.frame(M);
            
            testCase.verifyEqual(fr1.Meta.Hash, fr2.Meta.Hash, ...
                'Cache hash should be identical');
            testCase.verifyEqual(fr1.Face.N, fr2.Face.N, ...
                'Cached frame should be identical');
        end
        
        function testFrameDimensions(testCase)
            % Verify frame dimensions match mesh
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fr = bct.geometry.frame(M);
            
            testCase.verifySize(fr.Face.N, [size(F,1), 3]);
            testCase.verifySize(fr.Vertex.N, [size(V,1), 3]);
        end
        
        function testFrameConsistency(testCase)
            % Verify frame is consistent with normals/tangents
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fr = bct.geometry.frame(M);
            N = bct.geometry.normals(M, 'Face');
            
            testCase.verifyLessThan(max(vecnorm(fr.Face.N - N, 2, 2)), 1e-12, ...
                'Frame normals should match normals()');
        end
    end
end
