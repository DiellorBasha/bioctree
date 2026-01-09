classdef test_geometry_migration_equivalence < matlab.unittest.TestCase
    %TEST_GEOMETRY_MIGRATION_EQUIVALENCE Verify bct.geometry.* matches bct.manifold.*
    %
    % This test suite validates that the new bct.geometry package produces
    % identical results to the original bct.manifold geometry functions.
    %
    % Test coverage:
    %   - centroids: Face geometric centers
    %   - normals: Face and vertex normal vectors
    %   - tangents: Face and vertex tangent frames
    %   - frame: Cached orthonormal coordinate frames
    %
    % Tolerance: < 1e-12 for all numeric comparisons
    
    properties
        TestMesh      % Small test mesh (Manifold object)
        SphereMesh    % Sphere test mesh (Manifold object)
    end
    
    methods (TestClassSetup)
        function createTestMeshes(testCase)
            % Create small synthetic mesh (two triangles forming a square)
            V = [0 0 0; 1 0 0; 1 1 0; 0 1 0];
            F = [1 2 3; 1 3 4];
            testCase.TestMesh = bct.Manifold(V, F);
            
            % Create sphere mesh if available
            try
                [V_sphere, F_sphere] = icosphere(2);
                testCase.SphereMesh = bct.Manifold(V_sphere, F_sphere);
            catch
                % Icosphere not available - use simple octahedron instead
                V_sphere = [1 0 0; 0 1 0; -1 0 0; 0 -1 0; 0 0 1; 0 0 -1];
                F_sphere = [1 2 5; 2 3 5; 3 4 5; 4 1 5; ...
                            2 1 6; 3 2 6; 4 3 6; 1 4 6];
                testCase.SphereMesh = bct.Manifold(V_sphere, F_sphere);
            end
        end
    end
    
    methods (Test)
        %% Centroids Tests
        
        function testCentroidsFromManifold(testCase)
            % Test centroids from Manifold object
            C_old = bct.manifold.centroids(testCase.TestMesh);
            C_new = bct.geometry.centroids(testCase.TestMesh);
            
            testCase.verifyEqual(size(C_old), size(C_new), ...
                'Centroid output sizes must match');
            testCase.verifyLessThan(max(abs(C_old(:) - C_new(:))), 1e-12, ...
                'Centroids from Manifold must match within tolerance');
        end
        
        function testCentroidsFromVF(testCase)
            % Test centroids from V, F directly
            V = testCase.TestMesh.Vertices;
            F = testCase.TestMesh.Faces;
            
            C_old = bct.manifold.centroids(V, F);
            C_new = bct.geometry.centroids(V, F);
            
            testCase.verifyEqual(size(C_old), size(C_new), ...
                'Centroid output sizes must match');
            testCase.verifyLessThan(max(abs(C_old(:) - C_new(:))), 1e-12, ...
                'Centroids from V,F must match within tolerance');
        end
        
        function testCentroidsSphere(testCase)
            % Test centroids on sphere mesh
            C_old = bct.manifold.centroids(testCase.SphereMesh);
            C_new = bct.geometry.centroids(testCase.SphereMesh);
            
            testCase.verifyLessThan(max(abs(C_old(:) - C_new(:))), 1e-12, ...
                'Sphere centroids must match within tolerance');
        end
        
        %% Normals Tests
        
        function testVertexNormalsFromManifold(testCase)
            % Test vertex normals from Manifold object
            N_old = bct.manifold.normals(testCase.TestMesh, 'Vertex');
            N_new = bct.geometry.normals(testCase.TestMesh, 'Vertex');
            
            testCase.verifyEqual(size(N_old), size(N_new), ...
                'Vertex normal output sizes must match');
            testCase.verifyLessThan(max(abs(N_old(:) - N_new(:))), 1e-12, ...
                'Vertex normals from Manifold must match within tolerance');
        end
        
        function testFaceNormalsFromManifold(testCase)
            % Test face normals from Manifold object
            N_old = bct.manifold.normals(testCase.TestMesh, 'Face');
            N_new = bct.geometry.normals(testCase.TestMesh, 'Face');
            
            testCase.verifyEqual(size(N_old), size(N_new), ...
                'Face normal output sizes must match');
            testCase.verifyLessThan(max(abs(N_old(:) - N_new(:))), 1e-12, ...
                'Face normals from Manifold must match within tolerance');
        end
        
        function testVertexNormalsFromVF(testCase)
            % Test vertex normals from V, F directly
            V = testCase.TestMesh.Vertices;
            F = testCase.TestMesh.Faces;
            
            N_old = bct.manifold.normals(V, F, 'Vertex');
            N_new = bct.geometry.normals(V, F, 'Vertex');
            
            testCase.verifyLessThan(max(abs(N_old(:) - N_new(:))), 1e-12, ...
                'Vertex normals from V,F must match within tolerance');
        end
        
        function testFaceNormalsFromVF(testCase)
            % Test face normals from V, F directly
            V = testCase.TestMesh.Vertices;
            F = testCase.TestMesh.Faces;
            
            N_old = bct.manifold.normals(V, F, 'Face');
            N_new = bct.geometry.normals(V, F, 'Face');
            
            testCase.verifyLessThan(max(abs(N_old(:) - N_new(:))), 1e-12, ...
                'Face normals from V,F must match within tolerance');
        end
        
        %% Tangents Tests
        
        function testFaceTangentsFromManifold(testCase)
            % Test face tangents from Manifold object
            [N_old, e1_old, e2_old] = bct.manifold.tangents(testCase.TestMesh, 'Domain', 'face');
            [N_new, e1_new, e2_new] = bct.geometry.tangents(testCase.TestMesh, 'Domain', 'face');
            
            testCase.verifyEqual(size(N_old), size(N_new), ...
                'Face tangent normal sizes must match');
            testCase.verifyLessThan(max(abs(N_old(:) - N_new(:))), 1e-12, ...
                'Face tangent normals must match within tolerance');
            testCase.verifyLessThan(max(abs(e1_old(:) - e1_new(:))), 1e-12, ...
                'Face tangent e1 must match within tolerance');
            testCase.verifyLessThan(max(abs(e2_old(:) - e2_new(:))), 1e-12, ...
                'Face tangent e2 must match within tolerance');
        end
        
        function testVertexTangentsFromManifold(testCase)
            % Test vertex tangents from Manifold object
            [N_old, e1_old, e2_old] = bct.manifold.tangents(testCase.TestMesh, 'Domain', 'vertex');
            [N_new, e1_new, e2_new] = bct.geometry.tangents(testCase.TestMesh, 'Domain', 'vertex');
            
            testCase.verifyEqual(size(N_old), size(N_new), ...
                'Vertex tangent normal sizes must match');
            testCase.verifyLessThan(max(abs(N_old(:) - N_new(:))), 1e-12, ...
                'Vertex tangent normals must match within tolerance');
            testCase.verifyLessThan(max(abs(e1_old(:) - e1_new(:))), 1e-12, ...
                'Vertex tangent e1 must match within tolerance');
            testCase.verifyLessThan(max(abs(e2_old(:) - e2_new(:))), 1e-12, ...
                'Vertex tangent e2 must match within tolerance');
        end
        
        function testFaceTangentsFromVF(testCase)
            % Test face tangents from V, F directly
            V = testCase.TestMesh.Vertices;
            F = testCase.TestMesh.Faces;
            
            [N_old, e1_old, e2_old] = bct.manifold.tangents(V, F, 'Domain', 'face');
            [N_new, e1_new, e2_new] = bct.geometry.tangents(V, F, 'Domain', 'face');
            
            testCase.verifyLessThan(max(abs(N_old(:) - N_new(:))), 1e-12, ...
                'Face tangents from V,F: normals must match');
            testCase.verifyLessThan(max(abs(e1_old(:) - e1_new(:))), 1e-12, ...
                'Face tangents from V,F: e1 must match');
            testCase.verifyLessThan(max(abs(e2_old(:) - e2_new(:))), 1e-12, ...
                'Face tangents from V,F: e2 must match');
        end
        
        function testVertexTangentsFromVF(testCase)
            % Test vertex tangents from V, F directly
            V = testCase.TestMesh.Vertices;
            F = testCase.TestMesh.Faces;
            
            [N_old, e1_old, e2_old] = bct.manifold.tangents(V, F, 'Domain', 'vertex');
            [N_new, e1_new, e2_new] = bct.geometry.tangents(V, F, 'Domain', 'vertex');
            
            testCase.verifyLessThan(max(abs(N_old(:) - N_new(:))), 1e-12, ...
                'Vertex tangents from V,F: normals must match');
            testCase.verifyLessThan(max(abs(e1_old(:) - e1_new(:))), 1e-12, ...
                'Vertex tangents from V,F: e1 must match');
            testCase.verifyLessThan(max(abs(e2_old(:) - e2_new(:))), 1e-12, ...
                'Vertex tangents from V,F: e2 must match');
        end
        
        %% Frame Tests
        
        function testFrameCache(testCase)
            % Test cached frame computation
            fr_old = bct.manifold.frame(testCase.TestMesh);
            fr_new = bct.geometry.frame(testCase.TestMesh);
            
            % Compare face frames
            testCase.verifyLessThan(max(abs(fr_old.Face.N(:) - fr_new.Face.N(:))), 1e-12, ...
                'Frame face normals must match');
            testCase.verifyLessThan(max(abs(fr_old.Face.T1(:) - fr_new.Face.T1(:))), 1e-12, ...
                'Frame face T1 must match');
            testCase.verifyLessThan(max(abs(fr_old.Face.T2(:) - fr_new.Face.T2(:))), 1e-12, ...
                'Frame face T2 must match');
            
            % Compare vertex frames
            testCase.verifyLessThan(max(abs(fr_old.Vertex.N(:) - fr_new.Vertex.N(:))), 1e-12, ...
                'Frame vertex normals must match');
            testCase.verifyLessThan(max(abs(fr_old.Vertex.T1(:) - fr_new.Vertex.T1(:))), 1e-12, ...
                'Frame vertex T1 must match');
            testCase.verifyLessThan(max(abs(fr_old.Vertex.T2(:) - fr_new.Vertex.T2(:))), 1e-12, ...
                'Frame vertex T2 must match');
        end
        
        function testFrameSphereMesh(testCase)
            % Test frame on sphere mesh
            fr_old = bct.manifold.frame(testCase.SphereMesh);
            fr_new = bct.geometry.frame(testCase.SphereMesh);
            
            testCase.verifyLessThan(max(abs(fr_old.Face.N(:) - fr_new.Face.N(:))), 1e-12, ...
                'Sphere frame face normals must match');
            testCase.verifyLessThan(max(abs(fr_old.Vertex.N(:) - fr_new.Vertex.N(:))), 1e-12, ...
                'Sphere frame vertex normals must match');
        end
    end
end
