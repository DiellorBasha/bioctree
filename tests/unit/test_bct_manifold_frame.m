classdef test_bct_manifold_frame < BaseBctTest
    % TEST_BCT_MANIFOLD_FRAME Unit tests for bct.manifold.frame
    %
    % Tests cached orthonormal frame computation:
    % - Basic frame structure and fields
    % - Frame dimensions (face/vertex)
    % - Unit length verification
    % - Orthogonality
    % - Right-handedness
    % - Cache hits and performance
    % - Cache invalidation on geometry changes
    % - Simple triangle correctness
    
    methods (Test)
        function testBasicFrameComputation(testCase)
            % Verify frame returns correct structure
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fr = bct.manifold.frame(M);
            
            % Check structure fields
            testCase.verifyTrue(isstruct(fr), 'Output should be a struct');
            testCase.verifyTrue(isfield(fr, 'Face'), 'Output should have Face field');
            testCase.verifyTrue(isfield(fr, 'Vertex'), 'Output should have Vertex field');
            testCase.verifyTrue(isfield(fr, 'Meta'), 'Output should have Meta field');
            
            % Check Face frame fields
            testCase.verifyTrue(isfield(fr.Face, 'N'), 'Face should have N field');
            testCase.verifyTrue(isfield(fr.Face, 'T1'), 'Face should have T1 field');
            testCase.verifyTrue(isfield(fr.Face, 'T2'), 'Face should have T2 field');
            
            % Check Vertex frame fields
            testCase.verifyTrue(isfield(fr.Vertex, 'N'), 'Vertex should have N field');
            testCase.verifyTrue(isfield(fr.Vertex, 'T1'), 'Vertex should have T1 field');
            testCase.verifyTrue(isfield(fr.Vertex, 'T2'), 'Vertex should have T2 field');
            
            % Check Meta fields
            testCase.verifyTrue(isfield(fr.Meta, 'Hash'), 'Meta should have Hash field');
            testCase.verifyTrue(isfield(fr.Meta, 'CreatedOn'), 'Meta should have CreatedOn field');
        end
        
        function testFrameShapes(testCase)
            % Verify frame dimensions match mesh
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            Nv = size(V, 1);
            Nf = size(F, 1);
            
            fr = bct.manifold.frame(M);
            
            % Face frames
            testCase.verifySize(fr.Face.N, [Nf, 3], 'Face.N should be Nf×3');
            testCase.verifySize(fr.Face.T1, [Nf, 3], 'Face.T1 should be Nf×3');
            testCase.verifySize(fr.Face.T2, [Nf, 3], 'Face.T2 should be Nf×3');
            
            % Vertex frames
            testCase.verifySize(fr.Vertex.N, [Nv, 3], 'Vertex.N should be Nv×3');
            testCase.verifySize(fr.Vertex.T1, [Nv, 3], 'Vertex.T1 should be Nv×3');
            testCase.verifySize(fr.Vertex.T2, [Nv, 3], 'Vertex.T2 should be Nv×3');
        end
        
        function testUnitNorms(testCase)
            % Verify all frame vectors are unit length
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fr = bct.manifold.frame(M);
            
            % Face frame norms
            Nf_norms = vecnorm(fr.Face.N, 2, 2);
            T1f_norms = vecnorm(fr.Face.T1, 2, 2);
            T2f_norms = vecnorm(fr.Face.T2, 2, 2);
            
            testCase.verifyTrue(all(abs(Nf_norms - 1) < 1e-6), ...
                'Face normals should be unit vectors');
            testCase.verifyTrue(all(abs(T1f_norms - 1) < 1e-6), ...
                'Face T1 should be unit vectors');
            testCase.verifyTrue(all(abs(T2f_norms - 1) < 1e-6), ...
                'Face T2 should be unit vectors');
            
            % Vertex frame norms
            Nv_norms = vecnorm(fr.Vertex.N, 2, 2);
            T1v_norms = vecnorm(fr.Vertex.T1, 2, 2);
            T2v_norms = vecnorm(fr.Vertex.T2, 2, 2);
            
            testCase.verifyTrue(all(abs(Nv_norms - 1) < 1e-6), ...
                'Vertex normals should be unit vectors');
            testCase.verifyTrue(all(abs(T1v_norms - 1) < 1e-6), ...
                'Vertex T1 should be unit vectors');
            testCase.verifyTrue(all(abs(T2v_norms - 1) < 1e-6), ...
                'Vertex T2 should be unit vectors');
        end
        
        function testOrthogonality(testCase)
            % Verify frame vectors are mutually orthogonal
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fr = bct.manifold.frame(M);
            
            % Face frame orthogonality
            dot_Nf_T1f = abs(sum(fr.Face.N .* fr.Face.T1, 2));
            dot_Nf_T2f = abs(sum(fr.Face.N .* fr.Face.T2, 2));
            dot_T1f_T2f = abs(sum(fr.Face.T1 .* fr.Face.T2, 2));
            
            testCase.verifyTrue(all(dot_Nf_T1f < 1e-6), ...
                'Face N and T1 should be orthogonal');
            testCase.verifyTrue(all(dot_Nf_T2f < 1e-6), ...
                'Face N and T2 should be orthogonal');
            testCase.verifyTrue(all(dot_T1f_T2f < 1e-6), ...
                'Face T1 and T2 should be orthogonal');
            
            % Vertex frame orthogonality
            dot_Nv_T1v = abs(sum(fr.Vertex.N .* fr.Vertex.T1, 2));
            dot_Nv_T2v = abs(sum(fr.Vertex.N .* fr.Vertex.T2, 2));
            dot_T1v_T2v = abs(sum(fr.Vertex.T1 .* fr.Vertex.T2, 2));
            
            testCase.verifyTrue(all(dot_Nv_T1v < 1e-6), ...
                'Vertex N and T1 should be orthogonal');
            testCase.verifyTrue(all(dot_Nv_T2v < 1e-6), ...
                'Vertex N and T2 should be orthogonal');
            testCase.verifyTrue(all(dot_T1v_T2v < 1e-6), ...
                'Vertex T1 and T2 should be orthogonal');
        end
        
        function testRightHandedness(testCase)
            % Verify frames are right-handed: T2 = N × T1
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            fr = bct.manifold.frame(M);
            
            % Face frame
            cross_Nf_T1f = cross(fr.Face.N, fr.Face.T1, 2);
            diff_face = vecnorm(cross_Nf_T1f - fr.Face.T2, 2, 2);
            testCase.verifyTrue(all(diff_face < 1e-6), ...
                'Face frame should be right-handed: N × T1 = T2');
            
            % Vertex frame
            cross_Nv_T1v = cross(fr.Vertex.N, fr.Vertex.T1, 2);
            diff_vertex = vecnorm(cross_Nv_T1v - fr.Vertex.T2, 2, 2);
            testCase.verifyTrue(all(diff_vertex < 1e-6), ...
                'Vertex frame should be right-handed: N × T1 = T2');
        end
        
        function testCacheHits(testCase)
            % Verify second call retrieves from cache
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % First call
            fr1 = bct.manifold.frame(M);
            
            % Second call should use cache
            fr2 = bct.manifold.frame(M);
            
            % Verify data is identical
            testCase.verifyEqual(fr1.Face.N, fr2.Face.N, ...
                'Cached Face.N should match');
            testCase.verifyEqual(fr1.Vertex.N, fr2.Vertex.N, ...
                'Cached Vertex.N should match');
            testCase.verifyEqual(fr1.Meta.Hash, fr2.Meta.Hash, ...
                'Hash should match');
        end
        
        function testCacheInvalidation(testCase)
            % Verify cache invalidates on geometry change
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Get original frame and hash
            fr1 = bct.manifold.frame(M);
            original_hash = fr1.Meta.Hash;
            
            % Create new Manifold with modified geometry
            V_modified = V;
            V_modified(1,:) = V_modified(1,:) + [100, 0, 0];
            M_modified = bct.Manifold(V_modified, F);
            
            % Get modified frame
            fr_modified = bct.manifold.frame(M_modified);
            new_hash = fr_modified.Meta.Hash;
            
            % Hash should differ
            testCase.verifyNotEqual(original_hash, new_hash, ...
                'Hash should change when geometry changes');
            
            % Frames should differ
            testCase.verifyNotEqual(fr1.Face.N, fr_modified.Face.N, ...
                'Frames should recompute after geometry change');
        end
        
        function testSimpleTriangleCorrectness(testCase)
            % Verify correctness on known simple triangle
            V_tri = [0 0 0; 1 0 0; 0 1 0];
            F_tri = [1 2 3];
            M_tri = bct.Manifold(V_tri, F_tri);
            
            fr_tri = bct.manifold.frame(M_tri);
            
            % Face frame (triangle in XY plane)
            expected_N = [0, 0, 1];
            expected_T1 = [1, 0, 0];
            expected_T2 = [0, 1, 0];
            
            testCase.verifyEqual(fr_tri.Face.N, expected_N, 'AbsTol', 1e-6, ...
                'Triangle face normal should be [0,0,1]');
            testCase.verifyEqual(fr_tri.Face.T1, expected_T1, 'AbsTol', 1e-6, ...
                'Triangle T1 should be [1,0,0]');
            testCase.verifyEqual(fr_tri.Face.T2, expected_T2, 'AbsTol', 1e-6, ...
                'Triangle T2 should be [0,1,0]');
            
            % All vertex normals should point in +Z
            testCase.verifyTrue(all(abs(fr_tri.Vertex.N(:,3) - 1) < 1e-6), ...
                'Vertex normals should point in +Z');
        end
    end
end
