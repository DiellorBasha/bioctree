classdef test_bct_data < matlab.unittest.TestCase
    % TEST_BCT_DATA Unit tests for bct.data package
    %
    % Tests data loading utilities including:
    % - index(): catalog management
    % - load(): default, ID-based, and attribute-based loading
    % - list(): asset discovery and filtering
    % - info(): asset introspection
    
    properties (TestParameter)
        % Test parameters for different loading scenarios
        ValidIDs = {"fsaverage6_hemi-lh_surf-pial", ...
                    "fsaverage6_hemi-rh_surf-pial"}
        ValidHemis = {"lh", "rh"}
    end
    
    methods (TestClassSetup)
        function initBct(testCase)
            % Initialize BCT package before tests
            if exist('bct.start', 'file')
                bct.start();
            end
        end
    end
    
    methods (Test)
        %% INDEX TESTS
        function testIndexReturnsCatalog(testCase)
            % Verify index returns non-empty struct array
            catalog = bct.data.index();
            testCase.verifyNotEmpty(catalog, ...
                'Catalog should not be empty');
            testCase.verifyTrue(isstruct(catalog), ...
                'Catalog should be a struct array');
        end
        
        function testIndexHasRequiredFields(testCase)
            % Verify catalog entries have all required fields
            catalog = bct.data.index();
            requiredFields = {'Id', 'Dataset', 'Hemi', 'Surface', ...
                             'Path', 'Default', 'Tags'};
            for i = 1:numel(catalog)
                for j = 1:numel(requiredFields)
                    testCase.verifyTrue(isfield(catalog, requiredFields{j}), ...
                        sprintf('Missing required field: %s', requiredFields{j}));
                end
            end
        end
        
        function testIndexHasDefaultAsset(testCase)
            % Verify at least one asset is marked as default
            catalog = bct.data.index();
            hasDefault = any([catalog.Default]);
            testCase.verifyTrue(hasDefault, ...
                'Catalog should have at least one default asset');
        end
        
        %% LOAD TESTS - Default
        function testLoadDefaultReturnsStruct(testCase)
            % Verify default load returns valid struct
            mesh = bct.data.load();
            testCase.verifyTrue(isstruct(mesh), ...
                'Default load should return struct');
        end
        
        function testLoadDefaultHasVerticesAndFaces(testCase)
            % Verify default load has required mesh fields
            mesh = bct.data.load();
            testCase.verifyTrue(isfield(mesh, 'Vertices'), ...
                'Mesh should have Vertices field');
            testCase.verifyTrue(isfield(mesh, 'Faces'), ...
                'Mesh should have Faces field');
            testCase.verifyTrue(isfield(mesh, 'V'), ...
                'Mesh should have V alias');
            testCase.verifyTrue(isfield(mesh, 'F'), ...
                'Mesh should have F alias');
        end
        
        function testLoadDefaultVerticesShape(testCase)
            % Verify vertices are N×3 double
            mesh = bct.data.load();
            testCase.verifySize(mesh.Vertices, [NaN, 3], ...
                'Vertices should be N×3');
            testCase.verifyClass(mesh.Vertices, 'double', ...
                'Vertices should be double');
        end
        
        function testLoadDefaultFacesShape(testCase)
            % Verify faces are M×3 integer
            mesh = bct.data.load();
            testCase.verifySize(mesh.Faces, [NaN, 3], ...
                'Faces should be M×3');
            testCase.verifyTrue(isnumeric(mesh.Faces), ...
                'Faces should be numeric');
        end
        
        %% LOAD TESTS - ID-based
        function testLoadByValidID(testCase, ValidIDs)
            % Verify loading by valid ID succeeds
            mesh = bct.data.load(ValidIDs);
            testCase.verifyNotEmpty(mesh, ...
                sprintf('Should load asset: %s', ValidIDs));
            testCase.verifyTrue(isfield(mesh, 'Vertices'), ...
                'Loaded mesh should have Vertices');
        end
        
        function testLoadByInvalidIDThrows(testCase)
            % Verify loading invalid ID throws error
            testCase.verifyError(...
                @() bct.data.load("invalid_id"), ...
                'bct:data:load:AssetNotFound');
        end
        
        %% LOAD TESTS - Attribute-based
        function testLoadByDataset(testCase)
            % Verify loading by dataset attribute
            mesh = bct.data.load(Dataset="fsaverage6");
            testCase.verifyNotEmpty(mesh, ...
                'Should load by dataset attribute');
        end
        
        function testLoadByHemi(testCase, ValidHemis)
            % Verify loading by hemisphere attribute
            mesh = bct.data.load(Hemi=ValidHemis);
            testCase.verifyNotEmpty(mesh, ...
                sprintf('Should load by hemi=%s', ValidHemis));
        end
        
        function testLoadByMultipleAttributes(testCase)
            % Verify loading by multiple attributes
            mesh = bct.data.load(Dataset="fsaverage6", Hemi="lh");
            testCase.verifyNotEmpty(mesh, ...
                'Should load by multiple attributes');
        end
        
        function testLoadNoMatchThrows(testCase)
            % Verify loading with no matching attributes throws
            testCase.verifyError(...
                @() bct.data.load(Dataset="nonexistent"), ...
                'bct:data:load:AssetNotFound');
        end
        
        %% LIST TESTS
        function testListReturnsStrings(testCase)
            % Verify list returns string array
            ids = bct.data.list();
            testCase.verifyClass(ids, 'string', ...
                'List should return string array');
            testCase.verifyNotEmpty(ids, ...
                'List should not be empty');
        end
        
        function testListFilterByHemi(testCase)
            % Verify list filtering by hemisphere
            lh_ids = bct.data.list(Hemi="lh");
            testCase.verifyTrue(all(contains(lh_ids, "hemi-lh")), ...
                'All IDs should contain hemi-lh');
        end
        
        function testListFilterByDataset(testCase)
            % Verify list filtering by dataset
            ids = bct.data.list(Dataset="fsaverage6");
            testCase.verifyTrue(all(startsWith(ids, "fsaverage6")), ...
                'All IDs should start with fsaverage6');
        end
        
        function testListFilterByTags(testCase)
            % Verify list filtering by tags
            ids = bct.data.list(Tags="pial");
            catalog = bct.data.index();
            for i = 1:numel(ids)
                entry = catalog(strcmp({catalog.Id}, ids(i)));
                testCase.verifyTrue(ismember("pial", entry.Tags), ...
                    sprintf('Asset %s should have pial tag', ids(i)));
            end
        end
        
        %% INFO TESTS
        function testInfoReturnsStruct(testCase)
            % Verify info returns struct
            info = bct.data.info("fsaverage6_hemi-lh_surf-pial");
            testCase.verifyTrue(isstruct(info), ...
                'Info should return struct');
        end
        
        function testInfoHasCatalogFields(testCase)
            % Verify info includes catalog metadata
            info = bct.data.info("fsaverage6_hemi-lh_surf-pial");
            testCase.verifyTrue(isfield(info, 'Id'), ...
                'Info should have Id field');
            testCase.verifyTrue(isfield(info, 'Dataset'), ...
                'Info should have Dataset field');
            testCase.verifyTrue(isfield(info, 'Path'), ...
                'Info should have Path field');
        end
        
        function testInfoHasFileStatus(testCase)
            % Verify info includes file existence check
            info = bct.data.info("fsaverage6_hemi-lh_surf-pial");
            testCase.verifyTrue(isfield(info, 'Exists'), ...
                'Info should have Exists field');
            testCase.verifyTrue(islogical(info.Exists), ...
                'Exists should be logical');
        end
        
        function testInfoForInvalidIDThrows(testCase)
            % Verify info for invalid ID throws
            testCase.verifyError(...
                @() bct.data.info("invalid_id"), ...
                'bct:data:info:AssetNotFound');
        end
        
        %% INTEGRATION TESTS
        function testLoadedMeshCreatesManifold(testCase)
            % Verify loaded mesh can construct Manifold
            mesh = bct.data.load();
            M = bct.Manifold(mesh.V, mesh.F);
            testCase.verifyNotEmpty(M, ...
                'Should create Manifold from loaded mesh');
            testCase.verifyEqual(M.NumVertices, size(mesh.V, 1), ...
                'Manifold should have correct vertex count');
        end
        
        function testAllCatalogedAssetsLoadable(testCase)
            % Verify all assets in catalog can be loaded
            catalog = bct.data.index();
            for i = 1:numel(catalog)
                if catalog(i).Exists
                    try
                        mesh = bct.data.load(catalog(i).Id);
                        testCase.verifyNotEmpty(mesh, ...
                            sprintf('Should load %s', catalog(i).Id));
                    catch ME
                        testCase.verifyFail(...
                            sprintf('Failed to load %s: %s', ...
                            catalog(i).Id, ME.message));
                    end
                end
            end
        end
    end
end
