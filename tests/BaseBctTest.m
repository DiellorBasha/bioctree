classdef BaseBctTest < matlab.unittest.TestCase
    % BASEBCTTEST Base class for all Bioctree unit tests
    %
    % This class provides common setup and teardown for all bct tests:
    % - Initializes bioctree environment (runs bioctree_start once)
    % - Loads configuration
    % - Provides access to standard test meshes
    %
    % Usage:
    %   classdef MyTest < BaseBctTest
    %       methods (Test)
    %           function testSomething(testCase)
    %               % Use testCase.Config for configuration
    %               % Use testCase.StandardMesh for common test data
    %           end
    %       end
    %   end
    
    properties (ClassSetupParameter)
    end
    
    properties
        Config          % Bioctree configuration structure
        StandardMesh    % Standard fsaverage left hemisphere mesh
    end
    
    methods (TestClassSetup)
        function setupBioctree(testCase)
            % Initialize bioctree environment once per test class
            
            % Get bioctree root directory
            test_file = mfilename('fullpath');
            test_dir = fileparts(test_file);
            % Navigate up from tests/ or tests/unit/ to bioctree root
            if contains(test_dir, fullfile('tests', 'unit'))
                bioctree_root = fileparts(fileparts(test_dir));
            elseif contains(test_dir, 'tests')
                bioctree_root = fileparts(test_dir);
            else
                bioctree_root = test_dir;
            end
            
            % Add config directory first
            config_dir = fullfile(bioctree_root, 'config');
            if exist(config_dir, 'dir')
                addpath(config_dir);
            end
            
            % Check if bioctree is already initialized
            if ~exist('bct.bct', 'class')
                % Try to run bioctree_start
                bioctree_start_file = fullfile(bioctree_root, 'bioctree_start.m');
                if exist(bioctree_start_file, 'file')
                    try
                        % Change to bioctree root and run startup
                        old_dir = cd(bioctree_root);
                        try
                            bioctree_start();
                        catch
                            cd(old_dir);
                            rethrow(lasterror); %#ok<LERR>
                        end
                        cd(old_dir);
                    catch ME
                        warning('BaseBctTest:SetupFailed', ...
                            'bioctree_start failed: %s. Attempting manual setup.', ME.message);
                        
                        % Manual setup fallback
                        toolbox_dir = fullfile(bioctree_root, 'toolbox');
                        if exist(toolbox_dir, 'dir')
                            addpath(toolbox_dir);
                        end
                        
                        external_dir = fullfile(bioctree_root, 'external');
                        if exist(external_dir, 'dir')
                            addpath(genpath(external_dir));
                        end
                    end
                else
                    % Manual setup
                    toolbox_dir = fullfile(bioctree_root, 'toolbox');
                    if exist(toolbox_dir, 'dir')
                        addpath(toolbox_dir);
                    end
                    
                    external_dir = fullfile(bioctree_root, 'external');
                    if exist(external_dir, 'dir')
                        addpath(genpath(external_dir));
                    end
                end
            end
            
            % Load configuration
            try
                testCase.Config = bioctree_config();
            catch ME
                error('BaseBctTest:ConfigLoadFailed', ...
                    'Failed to load bioctree configuration: %s', ME.message);
            end
            
            % Load standard test mesh (fsaverage left hemisphere)
            try
                mesh_data = load(testCase.Config.mesh.fsaverage_lh_pial);
                testCase.StandardMesh = struct('V', mesh_data.V, 'F', mesh_data.F);
            catch ME
                error('BaseBctTest:MeshLoadFailed', ...
                    'Failed to load standard mesh: %s', ME.message);
            end
        end
    end
    
    methods (TestClassTeardown)
        function teardownBioctree(testCase) %#ok<MANU>
            % Clean up after all tests in class complete
            % Currently no cleanup needed, but available for future use
        end
    end
    
    methods (TestMethodSetup)
        function setupTest(testCase) %#ok<MANU>
            % Setup before each test method
            % Override in subclasses if needed
        end
    end
    
    methods (TestMethodTeardown)
        function teardownTest(testCase) %#ok<MANU>
            % Cleanup after each test method
            % Override in subclasses if needed
        end
    end
    
    %% Helper Methods
    methods (Access = protected)
        function mesh = loadMesh(testCase, meshName)
            % Load a mesh from the standard mesh collection
            %
            % Parameters:
            %   meshName - 'fsaverage_lh_pial' or 'fsaverage_rh_pial'
            %
            % Returns:
            %   mesh - Struct with fields V (vertices) and F (faces)
            
            switch meshName
                case 'fsaverage_lh_pial'
                    mesh_path = testCase.Config.mesh.fsaverage_lh_pial;
                case 'fsaverage_rh_pial'
                    mesh_path = testCase.Config.mesh.fsaverage_rh_pial;
                otherwise
                    error('BaseBctTest:UnknownMesh', 'Unknown mesh: %s', meshName);
            end
            
            mesh_data = load(mesh_path);
            mesh = struct('V', mesh_data.V, 'F', mesh_data.F);
        end
        
        function M = createStandardManifold(testCase, varargin)
            % Create a Manifold from the standard test mesh
            %
            % Parameters:
            %   meshName (optional) - Mesh to use (default: fsaverage_lh_pial)
            %
            % Returns:
            %   M - bct.Manifold object
            
            if nargin > 1
                mesh = testCase.loadMesh(varargin{1});
            else
                mesh = testCase.StandardMesh;
            end
            
            M = bct.Manifold(mesh.V, mesh.F);
        end
    end
end
