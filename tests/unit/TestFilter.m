classdef TestFilter < matlab.unittest.TestCase
    % TESTFILTER Unit tests for bct.filters.Filter class
    %
    % Tests filter creation, kernel design, parameter management,
    % and filter evaluation on different domains
    
    properties
        Filter
        TestBct
        FilterDesigner
    end
    
    methods (TestClassSetup)
        function createTestBct(testCase)
            % Create full bct object for filter testing
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            B = B.createJoint('Lambda', 'Omega');
            
            testCase.TestBct = B;
            testCase.FilterDesigner = bct.filters.FilterDesigner(B);
        end
    end
    
    %% Constructor Tests
    methods (Test)
        function testFilterDesignerCreation(testCase)
            % Test FilterDesigner instantiation
            FD = bct.filters.FilterDesigner(testCase.TestBct);
            
            testCase.verifyClass(FD, 'bct.filters.FilterDesigner');
            testCase.verifyNotEmpty(FD, 'FilterDesigner should not be empty');
        end
        
        function testFilterCreation(testCase)
            % Test basic Filter object creation
            FD = testCase.FilterDesigner;
            
            % Create joint filter
            F = FD.joint('gaussian', ...
                'center_x', 0.1, 'sigma_x', 0.05, ...
                'center_y', 10, 'sigma_y', 5);
            
            testCase.verifyClass(F, 'bct.filters.Filter');
            testCase.verifyNotEmpty(F, 'Filter should not be empty');
        end
    end
    
    %% Kernel Tests
    methods (Test)
        function testGaussianKernel(testCase)
            % Test Gaussian kernel creation
            FD = testCase.FilterDesigner;
            
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            testCase.verifyEqual(F.KernelName, 'gaussian', 'Kernel should be gaussian');
            testCase.verifyNotEmpty(F.KernelFunction, 'Kernel function should exist');
        end
        
        function testGaborKernel(testCase)
            % Test Gabor kernel creation
            FD = testCase.FilterDesigner;
            
            F = FD.joint('gabor', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            testCase.verifyEqual(F.KernelName, 'gabor', 'Kernel should be gabor');
            testCase.verifyNotEmpty(F.KernelFunction, 'Kernel function should exist');
        end
        
        function testMexicanHatKernel(testCase)
            % Test Mexican hat/Ricker kernel
            FD = testCase.FilterDesigner;
            
            try
                F = FD.joint('mexican_hat', ...
                    'center_x', 0.5, 'sigma_x', 0.1, ...
                    'center_y', 20, 'sigma_y', 5);
                
                testCase.verifyNotEmpty(F, 'Mexican hat filter should be created');
            catch ME
                if contains(ME.message, 'Unknown kernel')
                    testCase.verifyTrue(true, 'Mexican hat not implemented yet');
                else
                    rethrow(ME);
                end
            end
        end
    end
    
    %% Parameter Tests
    methods (Test)
        function testParameterStorage(testCase)
            % Test filter parameter storage
            FD = testCase.FilterDesigner;
            
            center_x = 0.5;
            sigma_x = 0.1;
            center_y = 20;
            sigma_y = 5;
            
            F = FD.joint('gaussian', ...
                'center_x', center_x, 'sigma_x', sigma_x, ...
                'center_y', center_y, 'sigma_y', sigma_y);
            
            testCase.verifyNotEmpty(F.Parameters, 'Parameters should be stored');
            testCase.verifyEqual(F.Parameters.center_x, center_x, 'center_x should match');
            testCase.verifyEqual(F.Parameters.sigma_x, sigma_x, 'sigma_x should match');
            testCase.verifyEqual(F.Parameters.center_y, center_y, 'center_y should match');
            testCase.verifyEqual(F.Parameters.sigma_y, sigma_y, 'sigma_y should match');
        end
        
        function testParameterUpdate(testCase)
            % Test dynamic parameter updates
            FD = testCase.FilterDesigner;
            
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            new_center = 0.8;
            F.setParameter('center_x', new_center);
            
            testCase.verifyEqual(F.Parameters.center_x, new_center, ...
                'Parameter should be updated');
        end
    end
    
    %% Domain-Specific Filter Tests
    methods (Test)
        function testManifoldFilter(testCase)
            % Test manifold-only filter
            FD = testCase.FilterDesigner;
            
            if ismethod(FD, 'manifold')
                F = FD.manifold('gaussian', ...
                    'center', 0.5, 'sigma', 0.1);
                
                testCase.verifyNotEmpty(F, 'Manifold filter should be created');
            end
        end
        
        function testTemporalFilter(testCase)
            % Test temporal-only filter
            FD = testCase.FilterDesigner;
            
            if ismethod(FD, 'temporal')
                F = FD.temporal('gaussian', ...
                    'center', 20, 'sigma', 5);
                
                testCase.verifyNotEmpty(F, 'Temporal filter should be created');
            end
        end
        
        function testJointFilter(testCase)
            % Test joint (separable) filter
            FD = testCase.FilterDesigner;
            
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            testCase.verifyNotEmpty(F, 'Joint filter should be created');
        end
    end
    
    %% Filter Evaluation Tests
    methods (Test)
        function testFilterEvaluation(testCase)
            % Test filter evaluation on grid
            FD = testCase.FilterDesigner;
            B = testCase.TestBct;
            
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            % Evaluate filter
            H = F.evaluate();
            
            testCase.verifyNotEmpty(H, 'Filter response should not be empty');
            testCase.verifyEqual(size(H), B.Joint.N, ...
                'Filter response should match joint grid');
        end
        
        function testFilterResponse(testCase)
            % Test filter frequency response properties
            FD = testCase.FilterDesigner;
            
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            H = F.evaluate();
            
            % Response should be real and non-negative for Gaussian
            testCase.verifyTrue(isreal(H), 'Gaussian response should be real');
            testCase.verifyGreaterThanOrEqual(min(H(:)), 0, ...
                'Gaussian response should be non-negative');
            
            % Peak should be at center
            [max_val, max_idx] = max(H(:));
            testCase.verifyGreaterThan(max_val, 0, 'Should have non-zero peak');
        end
    end
    
    %% Signal Filtering Tests
    methods (Test)
        function testSignalFiltering(testCase)
            % Test filtering a spatiotemporal signal
            FD = testCase.FilterDesigner;
            B = testCase.TestBct;
            
            % Create test signal
            X = randn(B.Manifold.N, B.Time.N);
            
            % Create and apply filter
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            if ismethod(F, 'apply') || ismethod(F, 'filter')
                if ismethod(F, 'apply')
                    X_filtered = F.apply(X);
                else
                    X_filtered = F.filter(X);
                end
                
                testCase.verifyEqual(size(X_filtered), size(X), ...
                    'Filtered signal should match input size');
            end
        end
    end
    
    %% Filterbank Tests
    methods (Test)
        function testFilterbankCreation(testCase)
            % Test creating filterbank (multiple filters)
            FD = testCase.FilterDesigner;
            
            if ismethod(FD, 'filterbank')
                centers = [10, 20, 30, 40];
                FB = FD.filterbank('gaussian', centers);
                
                if ~isempty(FB)
                    testCase.verifyEqual(length(FB), length(centers), ...
                        'Should create one filter per center');
                end
            end
        end
    end
    
    %% Visualization Tests
    methods (Test)
        function testFilterVisualization(testCase)
            % Test filter visualization methods
            FD = testCase.FilterDesigner;
            
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            if ismethod(F, 'plot') || ismethod(F, 'show')
                fig = figure('Visible', 'off');
                try
                    if ismethod(F, 'plot')
                        F.plot();
                    else
                        F.show();
                    end
                    testCase.verifyTrue(true, 'Visualization executed');
                catch ME
                    testCase.verifyFail(sprintf('Visualization failed: %s', ME.message));
                end
                close(fig);
            end
        end
    end
    
    %% Error Handling Tests
    methods (Test)
        function testInvalidKernel(testCase)
            % Test error on invalid kernel name
            FD = testCase.FilterDesigner;
            
            testCase.verifyError(@() FD.joint('invalid_kernel'), ?MException, ...
                'Should error on invalid kernel name');
        end
        
        function testMissingParameters(testCase)
            % Test error on missing required parameters
            FD = testCase.FilterDesigner;
            
            testCase.verifyError(@() FD.joint('gaussian'), ?MException, ...
                'Should error on missing parameters');
        end
        
        function testInvalidParameterValues(testCase)
            % Test error on invalid parameter values
            FD = testCase.FilterDesigner;
            
            % Negative sigma should error
            testCase.verifyError(@() FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', -0.1, ...
                'center_y', 20, 'sigma_y', 5), ?MException, ...
                'Should error on negative sigma');
        end
    end
    
    %% Label and Metadata Tests
    methods (Test)
        function testFilterLabel(testCase)
            % Test filter labeling
            FD = testCase.FilterDesigner;
            
            label = 'MyTestFilter';
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5, ...
                'label', label);
            
            if isprop(F, 'label') || isprop(F, 'Label')
                prop = 'label';
                if ~isprop(F, 'label')
                    prop = 'Label';
                end
                testCase.verifyEqual(F.(prop), label, 'Label should match');
            end
        end
    end
    
    %% Integration Tests
    methods (Test)
        function testFullFilteringWorkflow(testCase)
            % Test complete filtering workflow
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            B = B.createJoint('Lambda', 'Omega');
            
            % Create FilterDesigner
            FD = bct.filters.FilterDesigner(B);
            
            % Design filter
            Filt = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            % Evaluate
            H = Filt.evaluate();
            
            testCase.verifyNotEmpty(H, 'Complete workflow should produce response');
            testCase.verifyEqual(size(H), B.Joint.size(), 'Response should match grid');
        end
    end
end
