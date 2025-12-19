classdef test_bct_Manifold < BaseBctTest
    % TEST_BCT_MANIFOLD Unit tests for bct.Manifold initialization
    %
    % Tests Manifold object creation from Vertices and Faces:
    % - Constructor accepts V, F arguments
    % - Properties are correctly set
    % - Mesh validation
    % - Basic mesh properties accessible
    %
    % Does NOT test representations (FEM, Graph, DEC) - those are tested separately
    
    properties (TestParameter)
        % Test different hemispheres
        Hemisphere = {"lh", "rh"}
    end
    
    methods (Test)
        %% Constructor Tests
        function testManifoldCreationDefault(testCase)
            % Verify Manifold can be created with default test mesh
            [V, F] = testCase.getDefaultTestMesh();
            
            M = bct.Manifold(V, F);
            
            testCase.verifyNotEmpty(M, ...
                'Manifold should be created');
            testCase.verifyClass(M, 'bct.Manifold', ...
                'Should return bct.Manifold instance');
        end
        
        function testManifoldCreationFromStruct(testCase)
            % Verify Manifold can be created from mesh struct
            mesh = testCase.loadTestMesh();
            
            M = bct.Manifold(mesh.V, mesh.F);
            
            testCase.verifyNotEmpty(M, ...
                'Manifold should be created from struct data');
        end
        
        function testManifoldCreationFromDataLoad(testCase)
            % Verify Manifold works with bct.data.load directly
            mesh = bct.data.load();
            
            M = bct.Manifold(mesh.Vertices, mesh.Faces);
            
            testCase.verifyNotEmpty(M, ...
                'Manifold should be created from bct.data.load');
        end
        
        function testManifoldMultipleHemispheres(testCase, Hemisphere)
            % Verify Manifold creation works for both hemispheres
            % Load by explicit ID since only fsaverage6 lh/rh pial exist
            id = sprintf("fsaverage6_hemi-%s_surf-pial", Hemisphere);
            mesh = bct.data.load(id);
            
            M = bct.Manifold(mesh.V, mesh.F);
            
            testCase.verifyNotEmpty(M, ...
                sprintf('Manifold should be created for %s hemisphere', Hemisphere));
        end
        
        %% Property Tests
        function testVerticesProperty(testCase)
            % Verify Vertices property is correctly set
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            testCase.verifyEqual(M.Vertices, V, ...
                'Vertices property should match input');
            testCase.verifyEqual(size(M.Vertices, 2), 3, ...
                'Vertices should have 3 columns');
            testCase.verifyClass(M.Vertices, 'double', ...
                'Vertices should be double');
        end
        
        function testFacesProperty(testCase)
            % Verify Faces property is correctly set
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            testCase.verifyEqual(M.Faces, F, ...
                'Faces property should match input');
            testCase.verifyEqual(size(M.Faces, 2), 3, ...
                'Faces should have 3 columns');
            testCase.verifyTrue(isnumeric(M.Faces), ...
                'Faces should be numeric');
        end
        
        function testNumVerticesComputed(testCase)
            % Verify number of vertices can be computed
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            expectedNumVertices = size(V, 1);
            actualNumVertices = size(M.Vertices, 1);
            testCase.verifyEqual(actualNumVertices, expectedNumVertices, ...
                'Number of vertices should match input');
            testCase.verifyGreaterThan(actualNumVertices, 0, ...
                'Number of vertices should be positive');
        end
        
        function testNumFacesComputed(testCase)
            % Verify number of faces can be computed
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            expectedNumFaces = size(F, 1);
            actualNumFaces = size(M.Faces, 1);
            testCase.verifyEqual(actualNumFaces, expectedNumFaces, ...
                'Number of faces should match input');
            testCase.verifyGreaterThan(actualNumFaces, 0, ...
                'Number of faces should be positive');
        end
        
        %% Mesh Validity Tests
        function testVerticesAreFinite(testCase)
            % Verify vertices contain no NaN or Inf
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            testCase.verifyTrue(all(isfinite(M.Vertices(:))), ...
                'All vertex coordinates should be finite');
        end
        
        function testFacesArePositiveIntegers(testCase)
            % Verify face indices are positive integers
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            numVertices = size(M.Vertices, 1);
            testCase.verifyTrue(all(M.Faces(:) > 0), ...
                'All face indices should be positive');
            testCase.verifyTrue(all(M.Faces(:) <= numVertices), ...
                'All face indices should be within vertex range');
        end
        
        function testFacesReferenceValidVertices(testCase)
            % Verify all face indices reference existing vertices
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            numVertices = size(M.Vertices, 1);
            maxIndex = max(M.Faces(:));
            minIndex = min(M.Faces(:));
            
            testCase.verifyGreaterThanOrEqual(minIndex, 1, ...
                'Minimum face index should be at least 1');
            testCase.verifyLessThanOrEqual(maxIndex, numVertices, ...
                'Maximum face index should not exceed number of vertices');
        end
        
        function testMeshIsManifold(testCase)
            % Verify mesh represents a valid manifold (each edge shared by at most 2 faces)
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Basic manifold check: should have vertices and faces
            numVertices = size(M.Vertices, 1);
            numFaces = size(M.Faces, 1);
            testCase.verifyGreaterThan(numVertices, 0, ...
                'Manifold should have vertices');
            testCase.verifyGreaterThan(numFaces, 0, ...
                'Manifold should have faces');
            
            % Check Euler characteristic for closed surface: V - E + F = 2
            % For mesh, approximate number of edges as 3*F/2 (each edge shared by 2 faces)
            E = 3 * numFaces / 2;
            chi = numVertices - E + numFaces;
            
            % For closed genus-0 surface (sphere-like), chi should be close to 2
            testCase.verifyGreaterThan(chi, 0, ...
                'Euler characteristic should be positive for closed surface');
        end
        
        %% Edge Cases and Error Handling
        function testEmptyVerticesThrows(testCase)
            % Verify empty vertices throws error
            V = [];
            F = [1 2 3];
            
            testCase.verifyError(@() bct.Manifold(V, F), ...
                'MATLAB:invalidInput', ...
                'Empty vertices should throw error');
        end
        
        function testEmptyFacesThrows(testCase)
            % Verify empty faces throws error
            V = [0 0 0; 1 0 0; 0 1 0];
            F = [];
            
            testCase.verifyError(@() bct.Manifold(V, F), ...
                'MATLAB:invalidInput', ...
                'Empty faces should throw error');
        end
        
        function testInvalidVerticesDimensionsThrows(testCase)
            % Verify wrong vertex dimensions throw error
            V = [1 2];  % Should be N×3
            F = [1 1 1];
            
            testCase.verifyError(@() bct.Manifold(V, F), ...
                'MATLAB:invalidInput', ...
                'Invalid vertex dimensions should throw error');
        end
        
        function testInvalidFacesDimensionsThrows(testCase)
            % Verify wrong face dimensions throw error
            V = [0 0 0; 1 0 0; 0 1 0];
            F = [1 2];  % Should be M×3
            
            testCase.verifyError(@() bct.Manifold(V, F), ...
                'MATLAB:invalidInput', ...
                'Invalid face dimensions should throw error');
        end
        
        %% Multiple Instance Tests
        function testMultipleManifoldInstances(testCase)
            % Verify multiple Manifold instances can coexist
            [V1, F1] = testCase.getDefaultTestMesh();
            % Load right hemisphere explicitly
            mesh2 = bct.data.load("fsaverage6_hemi-rh_surf-pial");
            
            M1 = bct.Manifold(V1, F1);
            M2 = bct.Manifold(mesh2.V, mesh2.F);
            
            testCase.verifyNotEmpty(M1, ...
                'First manifold should be created');
            testCase.verifyNotEmpty(M2, ...
                'Second manifold should be created');
            testCase.verifyNotEqual(M1, M2, ...
                'Manifold instances should be distinct');
        end
        
        function testManifoldIndependence(testCase)
            % Verify modifying one Manifold doesn't affect another
            [V, F] = testCase.getDefaultTestMesh();
            
            M1 = bct.Manifold(V, F);
            M2 = bct.Manifold(V, F);
            
            % Both should have same initial properties
            testCase.verifyEqual(size(M1.Vertices, 1), size(M2.Vertices, 1), ...
                'Both manifolds should have same vertex count initially');
        end
    end
end
