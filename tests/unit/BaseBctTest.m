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
            testsDir = fileparts(fileparts(testFile));
            rootPath = testsDir;
        end
        
        function cfg = getConfig()
            % Get BCT configuration
            cfg = bct_config();
        end
        
        function mesh = loadTestMesh(meshType)
            % Load a test mesh for testing
            % meshType: 'lh' or 'rh' (default: 'rh')
            
            arguments
                meshType (1,1) string {mustBeMember(meshType, ["lh", "rh"])} = "rh"
            end
            
            cfg = bct_config();
            if meshType == "lh"
                meshFile = cfg.mesh.fsaverage_lh_pial;
            else
                meshFile = cfg.mesh.fsaverage_rh_pial;
            end
            
            if ~exist(meshFile, 'file')
                error('BaseBctTest:MeshNotFound', ...
                    'Test mesh not found: %s', meshFile);
            end
            
            data = load(meshFile);
            mesh.V = data.V;
            mesh.F = data.F;
            
            if isfield(data, 'meta')
                mesh.meta = data.meta;
            end
        end
    end
end
