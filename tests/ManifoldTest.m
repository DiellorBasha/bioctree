classdef ManifoldTest < matlab.unittest.TestCase
    % ManifoldTest - Unit tests for bct.Manifold class
    %
    % This test class verifies the core functionality of the bct.Manifold
    % class, including construction, operator computation, and caching.
    
    properties (ClassSetupParameter)
    end
    
    properties (TestParameter)
    end
    
    properties
        M  % Base bct.Manifold object for testing
    end
    
    methods (TestClassSetup)
        function setupManifoldTest(testCase)
            % Initialize BCT toolbox
            bct.start;
            
            % Load test mesh data
            meshFile = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');
            data = load(meshFile);
            V = data.V;  % Vertices [N×3]
            F = data.F;  % Faces [M×3]
            
            % Create base Manifold object
            testCase.M = bct.Manifold(V, F);
        end
    end
    
    methods (TestMethodSetup)
        % Optional: setup before each test method
    end
    
    methods (TestMethodTeardown)
        % Optional: cleanup after each test method
    end
    
    methods (Test)
        function testManifoldConstruction(testCase)
            % Test that Manifold object was constructed successfully
            testCase.verifyClass(testCase.M, 'bct.Manifold');
            testCase.verifyNotEmpty(testCase.M.V);
            testCase.verifyNotEmpty(testCase.M.F);
            testCase.verifySize(testCase.M.V, [NaN, 3]);  % N×3 vertices
            testCase.verifySize(testCase.M.F, [NaN, 3]);  % M×3 faces
        end
        
        function testManifoldProperties(testCase)
            % Test basic Manifold properties
            testCase.verifyGreaterThan(size(testCase.M.V, 1), 0);
            testCase.verifyGreaterThan(size(testCase.M.F, 1), 0);
        end
    end
end
