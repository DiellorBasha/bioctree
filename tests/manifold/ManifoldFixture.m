classdef ManifoldFixture < matlab.unittest.fixtures.Fixture
    % ManifoldFixture
    % Initializes BCT toolbox and loads the default fsaverage mesh once per test session.
    %
    % This fixture:
    %   1. Runs bct.start to add all necessary paths
    %   2. Loads the default fsaverage_rh_pial mesh
    %   3. Creates a bct.Manifold object
    %   4. Exposes V, F, and M properties for test use
    %
    % Example usage:
    %   function setupOnce(testCase)
    %       fixture = testCase.applyFixture(ManifoldFixture());
    %       V = fixture.V;
    %       F = fixture.F;
    %       M = fixture.M;
    %   end

    properties (SetAccess = private)
        V double      % Vertices [N×3]
        F double      % Faces [M×3]
        M             % bct.Manifold object
    end

    properties (Access = private)
        OriginalPath
    end

    methods
        function setup(fixture)
            % Store original path
            fixture.OriginalPath = path;
            
            % Initialize BCT toolbox
            bct.start;
            
            % Load default mesh
            meshFile = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');
            meshFileResolved = fixture.resolveMeshPath(meshFile);
            
            if ~isfile(meshFileResolved)
                error("Mesh file not found: %s\nPlease ensure the data folder is available.", meshFileResolved);
            end
            
            data = load(meshFileResolved);
            
            % Defensive checks: MAT must contain V and F
            if ~isfield(data, "V") || ~isfield(data, "F")
                error("Mesh MAT file must contain variables V and F. Found: %s", strjoin(fieldnames(data), ", "));
            end
            
            fixture.V = data.V;
            fixture.F = data.F;
            
            % Create Manifold object
            fixture.M = bct.Manifold(fixture.V, fixture.F);
        end

        function teardown(fixture)
            % Optional: restore original path for clean test isolation
            % path(fixture.OriginalPath);
        end
    end

    methods (Access = private)
        function p = resolveMeshPath(~, meshFile)
            % Resolve relative path to mesh file from project root
            
            if isfile(meshFile)
                p = string(meshFile);
                return;
            end
            
            % Resolve relative to the folder containing this fixture file
            here = fileparts(mfilename("fullpath"));
            % Fixture is in: tests/manifold/ManifoldFixture.m
            % Tests root is one level up:
            testsRoot = fileparts(here);
            % Project root is one more level up:
            projectRoot = fileparts(testsRoot);
            
            p = string(fullfile(projectRoot, meshFile));
        end
    end
end
