classdef TestManifold < BaseBctTest
    % TESTMANIFOLD Unit tests for bct.Manifold class
    %
    % Tests manifold creation, properties, Laplacian computation,
    % and eigendecomposition based on current Manifold API
    
    properties (TestParameter)
        LaplacianType = {'cotangent', 'cotangent-normalized'}
    end
    
    properties
        Manifold
    end
    
    methods (TestMethodSetup)
        function createManifold(testCase)
            % Create fresh Manifold for each test using standard mesh
            testCase.Manifold = bct.Manifold(testCase.StandardMesh);
        end
    end
    
    %% Constructor Tests
    methods (Test)
        function testConstructorWithMesh(testCase)
            % Test Manifold construction from mesh struct
            M = bct.Manifold(testCase.StandardMesh);
            
            testCase.verifyClass(M, 'bct.Manifold');
            testCase.verifyEqual(size(M.Vertices, 2), 3, 'Vertices should be 3D');
            testCase.verifyGreaterThan(size(M.Vertices, 1), 0, 'Should have vertices');
            testCase.verifyGreaterThan(size(M.Faces, 1), 0, 'Should have faces');
        end
        
        function testConstructorWithLaplacianType(testCase, LaplacianType)
            % Test Manifold construction with different Laplacian types
            M = bct.Manifold(testCase.StandardMesh, LaplacianType);
            
            testCase.verifyEqual(M.LaplacianType, LaplacianType);
            testCase.verifyNotEmpty(M.Laplacian, 'Laplacian should be computed');
        end
        
        function testConstructorWithRightHemisphere(testCase)
            % Test with right hemisphere fsaverage mesh
            mesh = testCase.loadMesh('fsaverage_rh_pial');
            M = bct.Manifold(mesh);
            
            testCase.verifyGreaterThan(size(M.Vertices, 1), 1000, 'Should have sufficient vertices');
            testCase.verifyNotEmpty(M.Laplacian);
        end
        
        function testInvalidMeshStruct(testCase)
            % Test that invalid mesh struct throws error
            invalid_mesh = struct('InvalidField', []);
            testCase.verifyError(@() bct.Manifold(invalid_mesh), 'bct:Manifold:MissingVertices');
        end
        
        function testMissingFaces(testCase)
            % Test that mesh without faces throws error
            invalid_mesh = struct('V', rand(10, 3));
            testCase.verifyError(@() bct.Manifold(invalid_mesh), 'bct:Manifold:MissingFaces');
        end
    end
    
    %% Property Tests
    methods (Test)
        function testVerticesProperty(testCase)
            % Test Vertices property
            M = testCase.Manifold;
            
            testCase.verifyEqual(size(M.Vertices, 2), 3, 'Vertices should be Nx3');
            testCase.verifyClass(M.Vertices, 'double');
            testCase.verifyTrue(all(isfinite(M.Vertices(:))), 'All vertices should be finite');
        end
        
        function testFacesProperty(testCase)
            % Test Faces property
            M = testCase.Manifold;
            
            testCase.verifyEqual(size(M.Faces, 2), 3, 'Faces should be Mx3');
            testCase.verifyGreaterThan(min(M.Faces(:)), 0, 'Face indices should be positive');
            testCase.verifyLessThanOrEqual(max(M.Faces(:)), size(M.Vertices, 1), ...
                'Face indices should not exceed number of vertices');
        end
        
        function testNameProperty(testCase)
            % Test inherited name property from Domain
            M = testCase.Manifold;
            
            testCase.verifyEqual(M.name, "Manifold");
        end
        
        function testUnitsProperty(testCase)
            % Test inherited units property from Domain
            M = testCase.Manifold;
            
            testCase.verifyEqual(M.units, "vertex");
        end
        
        function testAxisProperty(testCase)
            % Test that axis is vertex indices
            M = testCase.Manifold;
            
            testCase.verifyNotEmpty(M.axis, 'Axis should not be empty');
            testCase.verifyEqual(length(M.axis), size(M.Vertices, 1), ...
                'Axis length should match number of vertices');
            testCase.verifyEqual(M.axis, (1:size(M.Vertices, 1))', ...
                'Axis should be vertex indices 1:N');
        end
        
        function testNProperty(testCase)
            % Test N (dependent property - number of vertices)
            M = testCase.Manifold;
            
            testCase.verifyEqual(M.N, size(M.Vertices, 1), 'N should equal number of vertices');
            testCase.verifyGreaterThan(M.N, 0, 'N should be positive');
        end
    end
    
    %% Laplacian Tests
    methods (Test)
        function testLaplacianComputed(testCase)
            % Test that Laplacian is computed during construction
            M = testCase.Manifold;
            
            testCase.verifyNotEmpty(M.Laplacian, 'Laplacian should be computed');
            testCase.verifyEqual(size(M.Laplacian), [M.N, M.N], 'Laplacian should be NxN');
            testCase.verifyTrue(issparse(M.Laplacian), 'Laplacian should be sparse');
        end
        
        function testLaplacianSymmetric(testCase)
            % Test that Laplacian is symmetric
            M = testCase.Manifold;
            
            % For large matrices, check a subset to avoid memory issues
            if M.N > 1000
                % Check symmetry via norm of difference
                diff_norm = norm(M.Laplacian - M.Laplacian', 'fro');
                testCase.verifyLessThan(diff_norm, 1e-10, 'Laplacian should be symmetric');
            else
                testCase.verifyEqual(M.Laplacian, M.Laplacian', 'AbsTol', 1e-10, ...
                    'Laplacian should be symmetric');
            end
        end
        
        function testMassMatrixComputed(testCase)
            % Test that MassMatrix is computed
            M = testCase.Manifold;
            
            testCase.verifyNotEmpty(M.MassMatrix, 'MassMatrix should be computed');
            testCase.verifyEqual(size(M.MassMatrix), [M.N, M.N], 'MassMatrix should be NxN');
            testCase.verifyTrue(issparse(M.MassMatrix), 'MassMatrix should be sparse');
        end
        
        function testMassMatrixDiagonal(testCase)
            % Test that MassMatrix is diagonal
            M = testCase.Manifold;
            
            % For diagonal matrix, nnz should equal N
            testCase.verifyEqual(nnz(M.MassMatrix), M.N, ...
                'MassMatrix should be diagonal (nnz = N)');
        end
        
        function testMassMatrixPositive(testCase)
            % Test that MassMatrix has positive diagonal entries
            M = testCase.Manifold;
            
            diag_vals = full(diag(M.MassMatrix));
            testCase.verifyGreaterThan(min(diag_vals), 0, ...
                'MassMatrix diagonal should be positive');
        end
        
        function testCotangentMatrixComputed(testCase)
            % Test that CotangentMatrix is computed
            M = testCase.Manifold;
            
            testCase.verifyNotEmpty(M.CotangentMatrix, 'CotangentMatrix should be computed');
            testCase.verifyTrue(issparse(M.CotangentMatrix), 'CotangentMatrix should be sparse');
        end
        
        function testComputeLaplacianMethod(testCase)
            % Test computeLaplacian method
            M = testCase.Manifold;
            
            % Store original
            L_orig = M.Laplacian;
            
            % Recompute
            M = M.computeLaplacian();
            
            testCase.verifyNotEmpty(M.Laplacian);
            testCase.verifyEqual(M.Laplacian, L_orig, 'Recomputed Laplacian should match original');
        end
    end
    
    %% Method Tests
    methods (Test)
        function testNumVertices(testCase)
            % Test numVertices method
            M = testCase.Manifold;
            
            N = M.numVertices();
            testCase.verifyEqual(N, size(M.Vertices, 1));
            testCase.verifyEqual(N, M.N);
        end
        
        function testNumFaces(testCase)
            % Test numFaces method
            M = testCase.Manifold;
            
            F = M.numFaces();
            testCase.verifyEqual(F, size(M.Faces, 1));
            testCase.verifyGreaterThan(F, 0);
        end
        
        function testMAliasMethod(testCase)
            % Test M() method (alias for MassMatrix)
            M_obj = testCase.Manifold;
            
            M_mat = M_obj.M();
            testCase.verifyEqual(M_mat, M_obj.MassMatrix, ...
                'M() should return MassMatrix');
        end
        
        function testBuildAxisMethod(testCase)
            % Test buildAxis method
            M = testCase.Manifold;
            
            original_axis = M.axis;
            M = M.buildAxis();
            
            testCase.verifyEqual(M.axis, original_axis, ...
                'buildAxis should produce consistent axis');
        end
    end
    
    %% Domain Interface Tests
    methods (Test)
        function testDomainInheritance(testCase)
            % Test that Manifold inherits from Domain
            M = testCase.Manifold;
            
            testCase.verifyTrue(isa(M, 'bct.Domain'), ...
                'Manifold should inherit from Domain');
        end
        
        function testResolutionMode(testCase)
            % Test resolutionMode property
            M = testCase.Manifold;
            
            testCase.verifyNotEmpty(M.resolutionMode);
            testCase.verifyEqual(M.resolutionMode, bct.enum.ResolutionMode.Full);
        end
        
        function testDisplayCoordinateMode(testCase)
            % Test displayCoordinateMode property
            M = testCase.Manifold;
            
            testCase.verifyNotEmpty(M.displayCoordinateMode);
            testCase.verifyEqual(M.displayCoordinateMode, bct.enum.CoordinateMode.Vertex);
        end
        
        function testMetadataProperty(testCase)
            % Test metadata property
            M = testCase.Manifold;
            
            testCase.verifyClass(M.metadata, 'struct');
            
            % Test adding metadata
            M.metadata.test_field = 'test_value';
            testCase.verifyEqual(M.metadata.test_field, 'test_value');
        end
    end
end
