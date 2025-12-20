classdef BaseBctTest < matlab.unittest.TestCase
    % BASEBCTTEST Base class for all BCT unit tests
    %
    % This class provides common setup for all BCT tests including:
    % - Running bct_start to initialize the package
    % - Setting up test fixtures
    % - Common test utilities
    
    methods (TestClassSetup)
        function initializeBct(testCase)
            % Initialize BCT package before running tests
            try
                % Get BCT root and add to path if bct_start not found
                if ~exist('bct_start', 'file')
                    bctRoot = testCase.getBctRoot();
                    addpath(bctRoot);
                end
                
                % Initialize BCT
                bct_start();
            catch ME
                testCase.verifyFail(sprintf('Failed to initialize BCT: %s', ME.message));
            end
        end
    end
    
    methods (Static)
        function rootPath = getBctRoot()
            % Get BCT root directory
            testFile = mfilename('fullpath');
            testsUnitDir = fileparts(testFile);
            testsDir = fileparts(testsUnitDir);
            rootPath = fileparts(testsDir);
        end
        
        function cfg = getConfig()
            % Get BCT configuration
            cfg = bct_config();
        end
        
        function mesh = loadTestMesh(meshType)
            % Load a test mesh for testing using bct.data.load
            % meshType: 'lh' or 'rh' (default: uses bct.data.load default)
            %
            % Returns struct with:
            %   V or Vertices - [N×3] vertex coordinates
            %   F or Faces    - [M×3] face connectivity
            %   Meta          - metadata (if available)
            
            arguments
                meshType (1,1) string {mustBeMember(meshType, ["lh", "rh", "default"])} = "default"
            end
            
            if meshType == "default"
                % Use bct.data.load() default
                mesh = bct.data.load();
            else
                % Load specific hemisphere - need to provide empty id string
                mesh = bct.data.load("", Hemi=meshType);
            end
            
            % Ensure both V/F and Vertices/Faces are available
            if ~isfield(mesh, 'V')
                mesh.V = mesh.Vertices;
            end
            if ~isfield(mesh, 'F')
                mesh.F = mesh.Faces;
            end
        end
        
        function [V, F] = getDefaultTestMesh()
            % Get default test mesh vertices and faces
            % Convenience method for quick access to V, F arrays
            mesh = bct.data.load();
            V = mesh.Vertices;
            F = mesh.Faces;
        end
    end
end
