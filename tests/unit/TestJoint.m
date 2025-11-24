classdef TestJoint < matlab.unittest.TestCase
    % TESTJOINT Unit tests for bct.Joint class
    %
    % Tests joint domain creation, grid generation, dual domain products,
    % and spatiotemporal operations
    
    properties
        Joint
        TestBct
        TestManifold
        TestTime
    end
    
    methods (TestClassSetup)
        function createTestBct(testCase)
            % Create full bct object with all domains for testing
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            % Add Time domain
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            
            testCase.TestBct = B;
            testCase.TestManifold = B.Manifold;
            testCase.TestTime = B.Time;
        end
    end
    
    methods (TestMethodSetup)
        function createJoint(testCase)
            % Create fresh Joint domain for each test
            B = testCase.TestBct;
            B = B.createJoint('Lambda', 'Omega');
            testCase.Joint = B.Joint;
        end
    end
    
    %% Constructor Tests
    methods (Test)
        function testConstructorLambdaOmega(testCase)
            % Test Joint construction from Lambda and Omega
            B = testCase.TestBct;
            J = bct.Joint(B.Lambda, B.Omega);
            
            testCase.verifyClass(J, 'bct.Joint');
            testCase.verifyNotEmpty(J, 'Joint should not be empty');
        end
        
        function testConstructorFromBct(testCase)
            % Test Joint creation via bct.createJoint
            B = testCase.TestBct;
            B = B.createJoint('Lambda', 'Omega');
            
            testCase.verifyNotEmpty(B.Joint, 'Joint should be created');
            testCase.verifyClass(B.Joint, 'bct.Joint', 'Joint should be correct class');
        end
        
        function testConstructorManifoldTime(testCase)
            % Test Joint from Manifold-Time pair
            B = testCase.TestBct;
            
            if ismethod(B, 'createJoint')
                B = B.createJoint('Manifold', 'Time');
                
                if ~isempty(B.Joint)
                    testCase.verifyClass(B.Joint, 'bct.Joint');
                end
            end
        end
    end
    
    %% Domain Pair Tests
    methods (Test)
        function testDomainAProperty(testCase)
            % Test Domain A (first domain, e.g., Lambda)
            J = testCase.Joint;
            
            if isprop(J, 'A') || isprop(J, 'DomainA')
                prop = 'A';
                if ~isprop(J, 'A')
                    prop = 'DomainA';
                end
                
                testCase.verifyNotEmpty(J.(prop), 'Domain A should not be empty');
                % Should be Lambda for Lambda×Omega joint
                testCase.verifyClass(J.(prop), 'bct.Lambda');
            end
        end
        
        function testDomainBProperty(testCase)
            % Test Domain B (second domain, e.g., Omega)
            J = testCase.Joint;
            
            if isprop(J, 'B') || isprop(J, 'DomainB')
                prop = 'B';
                if ~isprop(J, 'B')
                    prop = 'DomainB';
                end
                
                testCase.verifyNotEmpty(J.(prop), 'Domain B should not be empty');
                % Should be Omega for Lambda×Omega joint
                testCase.verifyClass(J.(prop), 'bct.Omega');
            end
        end
        
        function testDomainNames(testCase)
            % Test domain name identification
            J = testCase.Joint;
            
            if isprop(J, 'Domain')
                % Should be something like 'Lambda-Omega' or 'Joint'
                testCase.verifyClass(J.Domain, 'char', 'Domain should be string');
            end
        end
    end
    
    %% Grid Tests
    methods (Test)
        function testGridGeneration(testCase)
            % Test 2D grid generation
            J = testCase.Joint;
            
            if isprop(J, 'A_grid') && isprop(J, 'B_grid')
                testCase.verifyNotEmpty(J.A_grid, 'A_grid should not be empty');
                testCase.verifyNotEmpty(J.B_grid, 'B_grid should not be empty');
                
                % Grids should have same size
                testCase.verifyEqual(size(J.A_grid), size(J.B_grid), ...
                    'A_grid and B_grid should have same dimensions');
                
                % Should be 2D
                testCase.verifyEqual(ndims(J.A_grid), 2, 'Grid should be 2D');
            end
        end
        
        function testGridDimensions(testCase)
            % Test grid dimensions match domain axes
            J = testCase.Joint;
            B = testCase.TestBct;
            
            if isprop(J, 'A_grid')
                % Grid rows should match Omega axis length
                % Grid cols should match Lambda axis length
                expected_size = [length(B.Omega.axis), length(B.Lambda.axis)];
                testCase.verifyEqual(size(J.A_grid), expected_size, ...
                    'Grid size should match domain axes');
            end
        end
        
        function testMeshgridPattern(testCase)
            % Test grid follows meshgrid pattern
            J = testCase.Joint;
            B = testCase.TestBct;
            
            if isprop(J, 'A_grid') && isprop(J, 'B_grid')
                % For Lambda×Omega: [Omega_grid, Lambda_grid] = meshgrid(lambda, omega)
                % Each column of A_grid should be constant
                % Each row of B_grid should be constant
                
                if size(J.A_grid, 2) > 1
                    col1 = J.A_grid(:, 1);
                    col2 = J.A_grid(:, 2);
                    testCase.verifyEqual(col1, col2, ...
                        'A_grid columns should be constant (meshgrid pattern)');
                end
                
                if size(J.B_grid, 1) > 1
                    row1 = J.B_grid(1, :);
                    row2 = J.B_grid(2, :);
                    testCase.verifyEqual(row1, row2, ...
                        'B_grid rows should be constant (meshgrid pattern)');
                end
            end
        end
    end
    
    %% Size Tests
    methods (Test)
        function testSizeMethod(testCase)
            % Test size() method returns grid dimensions
            J = testCase.Joint;
            
            if ismethod(J, 'size')
                sz = J.size();
                testCase.verifyEqual(length(sz), 2, 'Size should be 2D');
                testCase.verifyGreaterThan(sz(1), 0, 'First dimension should be positive');
                testCase.verifyGreaterThan(sz(2), 0, 'Second dimension should be positive');
            end
        end
        
        function testNProperty(testCase)
            % Test N property (total grid points)
            J = testCase.Joint;
            
            if isprop(J, 'N')
                if ismethod(J, 'size')
                    sz = J.size();
                    expected_N = sz(1) * sz(2);
                    testCase.verifyEqual(J.N, expected_N, 'N should equal grid size product');
                end
            end
        end
    end
    
    %% Units Tests
    methods (Test)
        function testUnitsProperty(testCase)
            % Test units for joint domain
            J = testCase.Joint;
            
            if isprop(J, 'units')
                testCase.verifyClass(J.units, 'char', 'Units should be char');
                % For Lambda×Omega: units might be 'rad/mm × rad/s' or similar
            end
        end
    end
    
    %% Data Storage Tests
    methods (Test)
        function testDataStorage(testCase)
            % Test joint domain data storage
            J = testCase.Joint;
            
            if isprop(J, 'data') || isprop(J, 'coefficients')
                prop = 'data';
                if ~isprop(J, 'data')
                    prop = 'coefficients';
                end
                
                % Create test data matching grid size
                if ismethod(J, 'size')
                    sz = J.size();
                    test_data = randn(sz);
                    J.(prop) = test_data;
                    
                    testCase.verifyEqual(size(J.(prop)), sz, ...
                        'Data should match grid dimensions');
                end
            end
        end
        
        function testMultibandData(testCase)
            % Test multiband (3D) data storage
            J = testCase.Joint;
            
            if isprop(J, 'data') && ismethod(J, 'size')
                sz = J.size();
                n_bands = 5;
                
                % Create 3D data: [omega, lambda, bands]
                test_data = randn([sz, n_bands]);
                J.data = test_data;
                
                testCase.verifyEqual(size(J.data, 3), n_bands, ...
                    'Should preserve band count');
            end
        end
    end
    
    %% Transform Tests
    methods (Test)
        function testJointTransform(testCase)
            % Test joint transform operation
            J = testCase.Joint;
            B = testCase.TestBct;
            
            if ismethod(J, 'transform') || ismethod(B, 'jointTransform')
                % Create spatiotemporal signal
                X = randn(B.Manifold.N, B.Time.N);
                
                if ismethod(J, 'transform')
                    X_joint = J.transform(X);
                else
                    X_joint = B.jointTransform(X);
                end
                
                if ~isempty(X_joint)
                    testCase.verifyEqual(size(X_joint), J.size(), ...
                        'Transformed data should match joint grid');
                end
            end
        end
        
        function testInverseTransform(testCase)
            % Test inverse joint transform
            J = testCase.Joint;
            B = testCase.TestBct;
            
            if ismethod(J, 'inverse') || ismethod(B, 'jointInverse')
                % Create joint domain data
                if ismethod(J, 'size')
                    sz = J.size();
                    X_joint = randn(sz);
                    
                    if ismethod(J, 'inverse')
                        X_recon = J.inverse(X_joint);
                    else
                        X_recon = B.jointInverse(X_joint);
                    end
                    
                    if ~isempty(X_recon)
                        expected_size = [B.Manifold.N, B.Time.N];
                        testCase.verifyEqual(size(X_recon), expected_size, ...
                            'Reconstructed signal should have original dimensions');
                    end
                end
            end
        end
    end
    
    %% Visualization Tests
    methods (Test)
        function testAxisLabels(testCase)
            % Test axis labels for visualization
            J = testCase.Joint;
            
            if isprop(J, 'xlabel') || isprop(J, 'ylabel')
                if isprop(J, 'xlabel')
                    testCase.verifyClass(J.xlabel, 'char', 'xlabel should be char');
                end
                if isprop(J, 'ylabel')
                    testCase.verifyClass(J.ylabel, 'char', 'ylabel should be char');
                end
            end
        end
    end
    
    %% Filtering Tests
    methods (Test)
        function testJointFiltering(testCase)
            % Test filtering in joint domain
            J = testCase.Joint;
            
            if ismethod(J, 'filter') && ismethod(J, 'size')
                sz = J.size();
                
                % Create filter kernel (2D Gaussian)
                center_k = sz(2) / 2;
                center_omega = sz(1) / 2;
                sigma = 5;
                
                [Omega_grid, K_grid] = meshgrid(1:sz(2), 1:sz(1));
                kernel = exp(-((K_grid - center_k).^2 + (Omega_grid - center_omega).^2) / (2*sigma^2));
                
                % Create test data
                data = randn(sz);
                
                % Apply filter
                filtered = J.filter(data, kernel);
                
                testCase.verifyEqual(size(filtered), sz, ...
                    'Filtered data should match input size');
            end
        end
    end
    
    %% Error Handling Tests
    methods (Test)
        function testIncompatibleDomains(testCase)
            % Test error on incompatible domain sizes
            B = testCase.TestBct;
            
            % Create mismatched domains
            [V2, F2] = icosphere(1);  % Different size
            meshStruct2 = struct('V', V2, 'F', F2);
            M2 = bct.Manifold(meshStruct2);
            
            % Create Lambda and compute eigenbasis
            eigenStruct = struct('eigenvalues', [], 'eigenvectors', []);
            L2 = bct.Lambda(eigenStruct);
            L2 = L2.eigenbasis(M2.MassMatrix, M2.CotangentMatrix, 30);
            
            % Should error on size mismatch
            testCase.verifyError(@() bct.Joint(L2, B.Omega), ?MException, ...
                'Should error on incompatible domain sizes');
        end
        
        function testInvalidDomainType(testCase)
            % Test error on invalid domain types
            testCase.verifyError(@() bct.Joint([], []), ?MException, ...
                'Should error on empty domains');
        end
    end
    
    %% Integration Tests
    methods (Test)
        function testJointInWorkflow(testCase)
            % Test full workflow with joint domain
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            % Add time
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            
            % Create joint
            B = B.createJoint('Lambda', 'Omega');
            
            testCase.verifyNotEmpty(B.Joint, 'Joint should be created');
            testCase.verifyClass(B.Joint, 'bct.Joint');
            
            % Verify all domains present
            testCase.verifyNotEmpty(B.Manifold, 'Manifold should exist');
            testCase.verifyNotEmpty(B.Lambda, 'Lambda should exist');
            testCase.verifyNotEmpty(B.Time, 'Time should exist');
            testCase.verifyNotEmpty(B.Omega, 'Omega should exist');
            testCase.verifyNotEmpty(B.Joint, 'Joint should exist');
        end
        
        function testMultipleJointDomains(testCase)
            % Test creating different joint domain pairs
            B = testCase.TestBct;
            
            % Lambda × Omega
            B = B.createJoint('Lambda', 'Omega');
            J1 = B.Joint;
            testCase.verifyClass(J1, 'bct.Joint');
            
            % Could test Manifold × Time if supported
            % B = B.createJoint('Manifold', 'Time');
            % testCase.verifyNotEmpty(B.Joint);
        end
    end
end
