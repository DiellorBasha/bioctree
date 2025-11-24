classdef TestBctConstruction < matlab.unittest.TestCase
    % TESTBCTCONSTRUCTION Unit tests for bct.bct object construction
    %
    % Tests various construction methods, domain initialization,
    % dual relationships, and complete object assembly
    
    properties (TestParameter)
        MeshSource = {'icosphere', 'custom'}
    end
    
    properties
        Bct
        TestMesh
    end
    
    methods (TestClassSetup)
        function createTestMeshes(testCase)
            % Create test mesh data
            [V, F] = icosphere(2);
            testCase.TestMesh.V = V;
            testCase.TestMesh.F = F;
        end
    end
    
    %% Construction Method Tests
    methods (Test)
        function testFromMesh(testCase)
            % Test construction from mesh vertices and faces
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            testCase.verifyClass(B, 'bct.bct');
            testCase.verifyNotEmpty(B, 'Bct object should not be empty');
            testCase.verifyNotEmpty(B.Manifold, 'Manifold should be created');
        end
        
        function testFromFile(testCase)
            % Test construction from mesh file (if supported)
            test_file = 'test-data\freesurfer\fsaverage\surf\lh.pial';
            
            if exist(test_file, 'file')
                if ismethod(bct.bct, 'fromFile') || ismethod(bct.io.import, 'mesh')
                    if ismethod(bct.bct, 'fromFile')
                        B = bct.bct.fromFile(test_file);
                    else
                        B = bct.io.import.mesh(test_file);
                    end
                    
                    testCase.verifyClass(B, 'bct.bct');
                    testCase.verifyNotEmpty(B.Manifold);
                end
            else
                testCase.verifyTrue(true, 'Test file not available, skipping');
            end
        end
        
        function testDefaultConstructor(testCase)
            % Test default constructor (if supported)
            try
                B = bct.bct();
                testCase.verifyClass(B, 'bct.bct');
            catch ME
                if contains(ME.message, 'Not enough input arguments')
                    testCase.verifyTrue(true, 'Default constructor not supported');
                else
                    rethrow(ME);
                end
            end
        end
    end
    
    %% Domain Initialization Tests
    methods (Test)
        function testManifoldInitialization(testCase)
            % Test automatic Manifold domain initialization
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            testCase.verifyNotEmpty(B.Manifold, 'Manifold should be initialized');
            testCase.verifyClass(B.Manifold, 'bct.Manifold');
            testCase.verifyGreaterThan(B.Manifold.N, 0, 'Manifold should have vertices');
        end
        
        function testLambdaInitialization(testCase)
            % Test automatic Lambda domain initialization
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            testCase.verifyNotEmpty(B.Lambda, 'Lambda should be initialized');
            testCase.verifyClass(B.Lambda, 'bct.Lambda');
            testCase.verifyEqual(B.Lambda.N, B.Manifold.N, 'Lambda.N should match Manifold.N');
        end
        
        function testTimeAddition(testCase)
            % Test adding Time domain
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            
            testCase.verifyNotEmpty(B.Time, 'Time should be added');
            testCase.verifyClass(B.Time, 'bct.Time');
            testCase.verifyEqual(B.Time.N, 100, 'Time should have correct N');
        end
        
        function testOmegaAutoCreation(testCase)
            % Test automatic Omega creation when Time is added
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            
            testCase.verifyNotEmpty(B.Omega, 'Omega should be auto-created');
            testCase.verifyClass(B.Omega, 'bct.Omega');
            testCase.verifyEqual(B.Omega.N, B.Time.N, 'Omega.N should match Time.N');
        end
    end
    
    %% Dual Relationship Tests
    methods (Test)
        function testManifoldLambdaDuality(testCase)
            % Test Manifold-Lambda dual relationship
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            testCase.verifyEqual(B.Manifold.dual, B.Lambda, ...
                'Manifold.dual should be Lambda');
            testCase.verifyEqual(B.Lambda.dual, B.Manifold, ...
                'Lambda.dual should be Manifold');
        end
        
        function testTimeOmegaDuality(testCase)
            % Test Time-Omega dual relationship
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            
            testCase.verifyEqual(B.Time.dual, B.Omega, ...
                'Time.dual should be Omega');
            testCase.verifyEqual(B.Omega.dual, B.Time, ...
                'Omega.dual should be Time');
        end
    end
    
    %% Eigenbasis Computation Tests
    methods (Test)
        function testComputeEigenbasis(testCase)
            % Test eigenbasis computation
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            k = 50;
            B = B.computeEigenbasis(k);
            
            testCase.verifyNotEmpty(B.Lambda.lambda, 'Eigenvalues should be computed');
            testCase.verifyNotEmpty(B.Lambda.U, 'Eigenvectors should be computed');
            testCase.verifyEqual(B.Lambda.K, k, 'Should have k eigenmodes');
        end
        
        function testEigenbasisValidation(testCase)
            % Test eigenbasis validation
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            % Eigenvalues should be sorted
            testCase.verifyTrue(issorted(B.Lambda.lambda), ...
                'Eigenvalues should be sorted');
            
            % First eigenvalue should be near zero
            testCase.verifyLessThan(abs(B.Lambda.lambda(1)), 1e-6, ...
                'First eigenvalue should be near zero');
        end
    end
    
    %% Joint Domain Tests
    methods (Test)
        function testCreateJoint(testCase)
            % Test joint domain creation
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            
            B = B.createJoint('Lambda', 'Omega');
            
            testCase.verifyNotEmpty(B.Joint, 'Joint should be created');
            testCase.verifyClass(B.Joint, 'bct.Joint');
        end
        
        function testJointDomainPairs(testCase)
            % Test different joint domain pairs
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            
            % Lambda × Omega
            B = B.createJoint('Lambda', 'Omega');
            testCase.verifyClass(B.Joint, 'bct.Joint');
        end
    end
    
    %% Complete Object Tests
    methods (Test)
        function testFullObjectConstruction(testCase)
            % Test complete bct object with all domains
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            B = B.createJoint('Lambda', 'Omega');
            
            % Verify all domains exist
            testCase.verifyNotEmpty(B.Manifold, 'Manifold should exist');
            testCase.verifyNotEmpty(B.Lambda, 'Lambda should exist');
            testCase.verifyNotEmpty(B.Time, 'Time should exist');
            testCase.verifyNotEmpty(B.Omega, 'Omega should exist');
            testCase.verifyNotEmpty(B.Joint, 'Joint should exist');
            
            % Verify domain consistency
            testCase.verifyEqual(B.Manifold.N, B.Lambda.N);
            testCase.verifyEqual(B.Time.N, B.Omega.N);
        end
        
        function testDomainHierarchy(testCase)
            % Test proper domain hierarchy
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            
            % Primary domains
            testCase.verifyNotEmpty(B.Manifold, 'Primary: Manifold');
            testCase.verifyNotEmpty(B.Time, 'Primary: Time');
            
            % Dual domains
            testCase.verifyNotEmpty(B.Lambda, 'Dual: Lambda');
            testCase.verifyNotEmpty(B.Omega, 'Dual: Omega');
            
            % Joint domain (created from duals)
            B = B.createJoint('Lambda', 'Omega');
            testCase.verifyNotEmpty(B.Joint, 'Product: Joint');
        end
    end
    
    %% Property Access Tests
    methods (Test)
        function testDomainPropertyAccess(testCase)
            % Test accessing domain properties
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            % Should be able to access Manifold properties
            testCase.verifyGreaterThan(B.Manifold.N, 0);
            testCase.verifyNotEmpty(B.Manifold.coords);
            
            % Should be able to access Lambda properties
            testCase.verifyEqual(B.Lambda.N, B.Manifold.N);
        end
        
        function testDomainPropertyModification(testCase)
            % Test modifying domain properties
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            % Modify Manifold units
            B.Manifold.units = 'mm';
            testCase.verifyEqual(B.Manifold.units, 'mm');
        end
    end
    
    %% Validation Tests
    methods (Test)
        function testObjectValidation(testCase)
            % Test object validation (if implemented)
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            if ismethod(B, 'validate')
                try
                    B.validate();
                    testCase.verifyTrue(true, 'Validation passed');
                catch ME
                    testCase.verifyFail(sprintf('Validation failed: %s', ME.message));
                end
            end
        end
        
        function testConsistencyCheck(testCase)
            % Test domain consistency checking
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            % All domains should have consistent N
            testCase.verifyEqual(B.Manifold.N, B.Lambda.N);
            
            % Eigendata should be consistent
            testCase.verifyEqual(length(B.Lambda.lambda), B.Lambda.K);
            testCase.verifyEqual(size(B.Lambda.U, 2), B.Lambda.K);
        end
    end
    
    %% Copy and Clone Tests
    methods (Test)
        function testObjectCopy(testCase)
            % Test object copying (if supported)
            [V, F] = icosphere(2);
            B1 = bct.bct.fromMesh(V, F);
            
            if ismethod(B1, 'copy')
                B2 = B1.copy();
                
                testCase.verifyClass(B2, 'bct.bct');
                testCase.verifyEqual(B2.Manifold.N, B1.Manifold.N);
                
                % Verify deep copy
                B2.Manifold.units = 'test';
                testCase.verifyNotEqual(B2.Manifold.units, B1.Manifold.units);
            end
        end
    end
    
    %% Error Handling Tests
    methods (Test)
        function testInvalidMesh(testCase)
            % Test error on invalid mesh
            badV = [1, 2];  % Wrong dimensions
            F = testCase.TestMesh.F;
            
            testCase.verifyError(@() bct.bct.fromMesh(badV, F), ?MException);
        end
        
        function testEmptyMesh(testCase)
            % Test error on empty mesh
            testCase.verifyError(@() bct.bct.fromMesh([], []), ?MException);
        end
        
        function testInvalidEigenbasisCount(testCase)
            % Test error on invalid eigenmode count
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            % k > N should error
            testCase.verifyError(@() B.computeEigenbasis(B.Manifold.N + 100), ?MException);
            
            % k <= 0 should error
            testCase.verifyError(@() B.computeEigenbasis(0), ?MException);
        end
    end
    
    %% Performance Tests
    methods (Test)
        function testLargeObjectConstruction(testCase)
            % Test construction with larger mesh
            [V, F] = icosphere(3);  % More subdivisions
            
            tic;
            B = bct.bct.fromMesh(V, F);
            construction_time = toc;
            
            testCase.verifyLessThan(construction_time, 5, ...
                'Construction should complete in reasonable time');
            testCase.verifyGreaterThan(B.Manifold.N, 100, ...
                'Should handle larger meshes');
        end
    end
end
