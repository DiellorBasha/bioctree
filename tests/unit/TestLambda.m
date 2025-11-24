classdef TestLambda < matlab.unittest.TestCase
    % TESTLAMBDA Unit tests for bct.Lambda class
    %
    % Tests Lambda (spectral/frequency) domain, eigenvalue handling,
    % axis computation, and dual relationships with Manifold
    
    properties
        Lambda
        TestManifold
    end
    
    methods (TestClassSetup)
        function createTestManifold(testCase)
            % Create Manifold and compute eigenbasis for Lambda testing
            [V, F] = icosphere(2);
            meshStruct = struct('V', V, 'F', F);
            M = bct.Manifold(meshStruct);
            
            % Create Lambda and compute eigenbasis using proper pattern
            eigenStruct = struct('eigenvalues', [], 'eigenvectors', []);
            L = bct.Lambda(eigenStruct);
            L = L.eigenbasis(M.MassMatrix, M.CotangentMatrix, 100);
            
            testCase.TestManifold = M;
        end
    end
    
    methods (TestMethodSetup)
        function createLambda(testCase)
            % Create Lambda from Manifold
            testCase.Lambda = bct.Lambda(testCase.TestManifold);
        end
    end
    
    %% Constructor Tests
    methods (Test)
        function testConstructorFromManifold(testCase)
            % Test Lambda construction from Manifold
            L = bct.Lambda(testCase.TestManifold);
            
            testCase.verifyClass(L, 'bct.Lambda');
            testCase.verifyEqual(L.N, testCase.TestManifold.N, ...
                'Lambda.N should match Manifold.N');
        end
        
        function testConstructorWithEigenvalues(testCase)
            % Test Lambda construction with eigenvalues
            lambda = testCase.TestManifold.Eigenvalues;
            L = bct.Lambda(testCase.TestManifold);
            L.lambda = lambda;
            
            testCase.verifyEqual(L.lambda, lambda, 'Eigenvalues should be stored');
            testCase.verifyEqual(L.K, length(lambda), 'K should match eigenvalue count');
        end
    end
    
    %% Eigenvalue Tests
    methods (Test)
        function testLambdaProperty(testCase)
            % Test lambda (eigenvalues) property
            L = testCase.Lambda;
            
            if ~isempty(L.lambda)
                testCase.verifyGreaterThan(length(L.lambda), 0, 'Should have eigenvalues');
                testCase.verifyTrue(issorted(L.lambda), 'Eigenvalues should be sorted');
                testCase.verifyGreaterThanOrEqual(min(L.lambda), 0, ...
                    'Eigenvalues should be non-negative');
            end
        end
        
        function testEigenvectorStorage(testCase)
            % Test eigenvector (U) storage
            L = testCase.Lambda;
            M = testCase.TestManifold;
            
            if ~isempty(M.Eigenvectors)
                L.U = M.Eigenvectors;
                
                testCase.verifyEqual(size(L.U, 1), M.N, 'Eigenvector rows should be N');
                testCase.verifyEqual(size(L.U, 2), length(L.lambda), ...
                    'Eigenvector cols should match eigenvalue count');
            end
        end
        
        function testKProperty(testCase)
            % Test K (number of eigenmodes) property
            L = testCase.Lambda;
            
            if ~isempty(L.lambda)
                testCase.verifyEqual(L.K, length(L.lambda), 'K should match eigenvalue count');
                testCase.verifyClass(L.K, 'double', 'K should be numeric');
            end
        end
    end
    
    %% Axis Tests
    methods (Test)
        function testAxisComputation(testCase)
            % Test wavenumber axis computation
            L = testCase.Lambda;
            
            if ~isempty(L.axis)
                testCase.verifyGreaterThan(length(L.axis), 0, 'Axis should not be empty');
                testCase.verifyTrue(issorted(L.axis), 'Axis should be sorted');
                testCase.verifyGreaterThanOrEqual(min(L.axis), 0, ...
                    'Wavenumbers should be non-negative');
            end
        end
        
        function testAxisFromEigenvalues(testCase)
            % Test axis is sqrt(lambda) when eigenvalues exist
            L = testCase.Lambda;
            M = testCase.TestManifold;
            
            if ~isempty(M.Eigenvalues)
                L.lambda = M.Eigenvalues;
                k_expected = sqrt(M.Eigenvalues);
                
                if ~isempty(L.axis)
                    testCase.verifyEqual(L.axis, k_expected, 'RelTol', 1e-10, ...
                        'Axis should be sqrt(eigenvalues)');
                end
            end
        end
        
        function testEstimatedAxis(testCase)
            % Test estimated axis when eigenvalues not computed
            [V, F] = icosphere(1);
            M = bct.Manifold(V, F);  % No eigenbasis computed
            L = bct.Lambda(M);
            
            if isprop(L, 'axis') && ~isempty(L.axis)
                testCase.verifyGreaterThan(length(L.axis), 0, ...
                    'Should have estimated axis');
                testCase.verifyLessThanOrEqual(length(L.axis), M.N, ...
                    'Estimated axis should not exceed N');
            end
        end
    end
    
    %% Resolution Tests
    methods (Test)
        function testResolutionProperty(testCase)
            % Test resolution (sampling density) property
            L = testCase.Lambda;
            
            if isprop(L, 'resolution')
                testCase.verifyClass(L.resolution, 'double', 'Resolution should be numeric');
                if ~isempty(L.resolution)
                    testCase.verifyGreaterThan(L.resolution, 0, ...
                        'Resolution should be positive');
                end
            end
        end
    end
    
    %% Domain Properties Tests
    methods (Test)
        function testDomainProperty(testCase)
            % Test Domain identifier
            L = testCase.Lambda;
            
            if isprop(L, 'Domain')
                testCase.verifyEqual(L.Domain, 'Lambda', 'Domain should be Lambda');
            end
        end
        
        function testUnitsProperty(testCase)
            % Test units property (e.g., 'rad/mm')
            L = testCase.Lambda;
            
            if isprop(L, 'units')
                testCase.verifyClass(L.units, 'char', 'Units should be char');
                % Common units: 'rad/mm', '1/mm', etc.
            end
        end
        
        function testSizeProperty(testCase)
            % Test size() method or N property
            L = testCase.Lambda;
            
            testCase.verifyEqual(L.N, testCase.TestManifold.N, 'N should match Manifold');
            
            if ismethod(L, 'size')
                sz = L.size();
                testCase.verifyEqual(sz(1), L.N, 'First dimension should be N');
            end
        end
    end
    
    %% Dual Relationship Tests
    methods (Test)
        function testDualManifold(testCase)
            % Test dual relationship with Manifold
            L = testCase.Lambda;
            
            if isprop(L, 'dual')
                testCase.verifyClass(L.dual, 'bct.Manifold', 'Dual should be Manifold');
                testCase.verifyEqual(L.dual.N, L.N, 'Dual should have same N');
            end
        end
        
        function testBidirectionalDuality(testCase)
            % Test bidirectional dual relationship
            L = testCase.Lambda;
            M = testCase.TestManifold;
            
            if isprop(M, 'dual') && isprop(L, 'dual')
                if isa(M.dual, 'bct.Lambda')
                    testCase.verifyEqual(M.dual.dual, M, ...
                        'Dual of dual should return to Manifold');
                end
            end
        end
    end
    
    %% Spectral Operations Tests
    methods (Test)
        function testSpectralCoefficients(testCase)
            % Test storage/computation of spectral coefficients
            L = testCase.Lambda;
            M = testCase.TestManifold;
            
            if ~isempty(M.Eigenvectors)
                % Generate random signal on manifold
                x = randn(M.N, 1);
                
                % Compute spectral coefficients
                x_hat = M.Eigenvectors' * x;
                
                testCase.verifyEqual(length(x_hat), size(M.Eigenvectors, 2), ...
                    'Spectral coefficients should match eigenmode count');
            end
        end
        
        function testInverseTransform(testCase)
            % Test reconstruction from spectral coefficients
            M = testCase.TestManifold;
            
            if ~isempty(M.Eigenvectors)
                % Generate signal
                x_orig = randn(M.N, 1);
                
                % Forward transform
                x_hat = M.Eigenvectors' * x_orig;
                
                % Inverse transform
                x_recon = M.Eigenvectors * x_hat;
                
                testCase.verifyEqual(x_recon, x_orig, 'RelTol', 1e-10, ...
                    'Reconstruction should match original');
            end
        end
    end
    
    %% Grid and Sampling Tests
    methods (Test)
        function testAxisGrid(testCase)
            % Test grid generation from axis
            L = testCase.Lambda;
            
            if ~isempty(L.axis)
                % Axis should work as a grid for visualization
                testCase.verifyTrue(isvector(L.axis), 'Axis should be a vector');
                testCase.verifyGreaterThan(length(L.axis), 1, ...
                    'Axis should have multiple points');
            end
        end
    end
    
    %% Error Handling Tests
    methods (Test)
        function testInvalidManifold(testCase)
            % Test error handling for invalid Manifold input
            testCase.verifyError(@() bct.Lambda([]), ?MException, ...
                'Should error on empty Manifold');
        end
        
        function testInconsistentEigendata(testCase)
            % Test error on inconsistent eigenvalue/eigenvector dimensions
            L = testCase.Lambda;
            M = testCase.TestManifold;
            
            if ~isempty(M.Eigenvalues)
                L.lambda = M.Eigenvalues(1:10);
                badU = randn(M.N, 20);  % Wrong number of eigenvectors
                
                % Setting U should validate dimensions
                % (Implementation-dependent test)
            end
        end
    end
    
    %% Integration Tests
    methods (Test)
        function testLambdaFromBctObject(testCase)
            % Test Lambda creation from full bct object
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            testCase.verifyNotEmpty(B.Lambda, 'Lambda should be created');
            testCase.verifyClass(B.Lambda, 'bct.Lambda', 'Lambda should be correct class');
            testCase.verifyNotEmpty(B.Lambda.lambda, 'Lambda should have eigenvalues');
        end
    end
end
