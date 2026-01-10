classdef test_bct_start < BaseBctTest
    % TEST_BCT_START Unit tests for bct.start initialization
    %
    % Tests that bct.start properly initializes the BCT package:
    % - Adds required paths
    % - Loads external dependencies (DECLab, GSPBox, GPToolbox)
    % - Sets up configuration
    % - Makes package structure accessible
    
    methods (Test)
        %% Basic Initialization Tests
        function testBctStartCompletes(testCase)
            % Verify bct.start runs without error (idempotent)
            testCase.verifyWarningFree(@() bct.start(), ...
                'bct.start should run without warnings when called again');
        end
        
        function testBctPackageOnPath(testCase)
            % Verify +bct package is accessible
            testCase.verifyTrue(exist('bct.Manifold', 'class') == 8, ...
                'bct.Manifold class should be accessible');
            testCase.verifyTrue(exist('bct.Graph', 'class') == 8, ...
                'bct.Graph class should be accessible');
            testCase.verifyTrue(exist('bct.FEM', 'class') == 8, ...
                'bct.FEM class should be accessible');
            
            % Verify new operator system is callable
            try
                specs = bct.registry.operators.defs();
                testCase.verifyClass(specs, 'dictionary', ...
                    'bct.registry.operators.defs() should return a dictionary');
            catch ME
                testCase.verifyFail('bct.registry.operators.defs() should be callable');
            end
            
            try
                % Create simple context for testing
                [V, F] = testCase.getDefaultTestMesh();
                M = bct.Manifold(V, F);
                ctx = bct.runtime.context(M, 'DEC', false);
                ops = bct.runtime.operators.dictionary(ctx);
                testCase.verifyClass(ops, 'dictionary', ...
                    'bct.runtime.operators.dictionary() should return a dictionary');
            catch ME
                testCase.verifyFail('bct.runtime.operators.dictionary() should be callable');
            end
        end
        
        function testConfigAccessible(testCase)
            % Verify bct.config.load is accessible
            testCase.verifyTrue(exist('bct.config.load', 'file') > 0, ...
                'bct.config.load should be accessible');
            
            cfg = bct.config.load();
            testCase.verifyTrue(isstruct(cfg), ...
                'bct.config.load should return a struct');
        end
        
        %% Configuration Tests
        function testConfigHasRequiredFields(testCase)
            % Verify configuration has core fields
            cfg = bct.config.load();
            
            testCase.verifyTrue(isfield(cfg, 'root'), ...
                'Config should have root field');
            testCase.verifyTrue(isfield(cfg, 'packageRoot'), ...
                'Config should have packageRoot field');
            testCase.verifyTrue(isfield(cfg, 'configRoot'), ...
                'Config should have configRoot field');
            testCase.verifyTrue(isfield(cfg, 'depsManifest'), ...
                'Config should have depsManifest field');
        end
        
        function testConfigPathsAreAbsolute(testCase)
            % Verify paths are absolute
            cfg = bct.config.load();
            
            testCase.verifyTrue(isfolder(cfg.root), ...
                'Root path should exist');
            testCase.verifyTrue(isfolder(cfg.packageRoot), ...
                'Package root path should exist');
            testCase.verifyTrue(isfolder(cfg.configRoot), ...
                'Config root path should exist');
        end
        
        function testDepsManifestLoaded(testCase)
            % Verify deps manifest is loaded in config
            cfg = bct.config.load();
            
            testCase.verifyTrue(isstruct(cfg.depsManifest), ...
                'Config should have depsManifest struct');
            
            % Check for expected dependencies
            depNames = fieldnames(cfg.depsManifest);
            testCase.verifyTrue(ismember('declab', depNames), ...
                'DECLab should be in manifest');
            testCase.verifyTrue(ismember('gspbox', depNames), ...
                'GSPBox should be in manifest');
            testCase.verifyTrue(ismember('gptoolbox', depNames), ...
                'gptoolbox should be in manifest');
        end
        
        %% External Dependencies Tests
        function testDECLabLoaded(testCase)
            % Verify DECLab is loaded and functional
            testCase.verifyTrue(exist('DiscreteExteriorCalculus', 'class') == 8, ...
                'DiscreteExteriorCalculus class should be accessible');
        end
        
        function testGSPBoxLoaded(testCase)
            % Verify GSPBox is loaded and functional
            testCase.verifyTrue(exist('gsp_start', 'file') > 0, ...
                'GSPBox should be on path');
        end
        
        function testGPToolboxLoaded(testCase)
            % Verify GPToolbox is loaded and functional
            % Check for common GPToolbox functions
            hasGP = exist('cotmatrix', 'file') > 0 || ...
                    exist('massmatrix', 'file') > 0;
            testCase.verifyTrue(hasGP, ...
                'GPToolbox functions should be accessible');
        end
        
        %% Package Structure Tests
        function testCoreSubpackagesExist(testCase)
            % Verify core subpackages are accessible via bct namespace
            cfg = bct.config.load();
            toolbox_path = cfg.packageRoot;
            
            subpackages = {'kernel', 'filter', 'graph', 'fem', ...
                          'data', 'registry', 'runtime', 'eigenpairs'};
            
            for i = 1:numel(subpackages)
                pkg = subpackages{i};
                pkg_path = fullfile(toolbox_path, '+bct', ['+' pkg]);
                testCase.verifyTrue(exist(pkg_path, 'dir') > 0, ...
                    sprintf('+bct/+%s package should exist at %s', pkg, pkg_path));
            end
        end
        
        function testCoreClassesExist(testCase)
            % Verify core classes are accessible
            classes = {'Manifold', 'Graph', 'FEM', 'Eigenpairs'};
            
            for i = 1:numel(classes)
                cls = classes{i};
                testCase.verifyTrue(exist(sprintf('bct.%s', cls), 'class') == 8, ...
                    sprintf('bct.%s class should be accessible', cls));
            end
        end
        
        function testKeyFunctionsAccessible(testCase)
            % Verify key package functions are accessible by calling them
            % Kernel functions - test they exist by checking which
            testCase.verifyNotEmpty(which('bct.kernel.list'), ...
                'bct.kernel.list should be accessible');
            testCase.verifyNotEmpty(which('bct.kernel.get'), ...
                'bct.kernel.get should be accessible');
            testCase.verifyNotEmpty(which('bct.kernel.bind'), ...
                'bct.kernel.bind should be accessible');
            
            % Registry functions
            testCase.verifyNotEmpty(which('bct.registry.kernels'), ...
                'bct.registry.kernels should be accessible');
            
            % Data functions
            testCase.verifyNotEmpty(which('bct.data.load'), ...
                'bct.data.load should be accessible');
            testCase.verifyNotEmpty(which('bct.data.list'), ...
                'bct.data.list should be accessible');
        end
    end
end
