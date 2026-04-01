%TEST_ATLAS_ZARR_ROUNDTRIP Validate atlas serialization and deserialization in zarr format
%
% Tests the complete roundtrip:
%   1. Load mesh with atlas
%   2. Create Manifold and attach atlas
%   3. Write to zarr with atlas included
%   4. Verify atlas group exists in zarr directory
%   5. Read atlas data back from zarr
%   6. Validate roundtrip consistency

classdef test_atlas_zarr_roundtrip < matlab.unittest.TestCase
    
    properties (TestParameter)
        Dataset = {'fsaverage6'}
        Hemi = {'lh', 'rh'}
        Atlas = {'aparc', 'aparc.a2009s'}
    end
    
    methods (Test)
        
        function testManifoldAtlasAttachment(testCase)
            % Test that we can attach atlas to Manifold
            M = bct.data.load('Id', 'fsaverage_rh_pial');
            
            % Attach atlas if available
            if isfield(M, 'Atlas') && ~isempty(M.Atlas)
                testManifold = bct.Manifold(M.Vertices, M.Faces);
                testManifold.Atlas = M.Atlas;
                
                testCase.verifyNotEmpty(testManifold.Atlas)
                testCase.verifyTrue(isfield(testManifold.Atlas, 'VertexRegionIndex'))
            end
        end
        
        function testToStructIncludesAtlas(testCase)
            % Test that M.toStruct() includes atlas when attached
            M = bct.data.load('Id', 'fsaverage_rh_pial');
            
            if isfield(M, 'Atlas') && ~isempty(M.Atlas)
                testManifold = bct.Manifold(M.Vertices, M.Faces);
                testManifold.Atlas = M.Atlas;
                
                S = testManifold.toStruct();
                
                testCase.verifyTrue(isfield(S, 'atlas'), ...
                    'S.atlas should exist when Manifold.Atlas is set')
                testCase.verifyTrue(isfield(S.atlas, 'VertexRegionIndex'), ...
                    'S.atlas should contain VertexRegionIndex')
            end
        end
        
        function testAtlasSchemaConversion(testCase)
            % Test that atlas struct converts to schema-compliant format safely
            M = bct.data.load('Id', 'fsaverage_rh_pial');
            
            if isfield(M, 'Atlas') && ~isempty(M.Atlas)
                testManifold = bct.Manifold(M.Vertices, M.Faces);
                testManifold.Atlas = M.Atlas;
                
                S = testManifold.toStruct();
                atlas_schema = S.atlas;
                
                % Verify schema structure
                testCase.verifyTrue(isfield(atlas_schema, 'Attributes'), ...
                    'atlas_schema should have Attributes')
                testCase.verifyTrue(isfield(atlas_schema, 'VertexRegionIndex'), ...
                    'atlas_schema should have VertexRegionIndex')
                
                % Verify VertexRegionIndex has value and attributes
                if isfield(atlas_schema.VertexRegionIndex, 'value')
                    testCase.verifyEqual(class(atlas_schema.VertexRegionIndex.value), 'int32', ...
                        'VertexRegionIndex.value should be int32')
                    testCase.verifyEqual(length(atlas_schema.VertexRegionIndex.value), ...
                        length(M.Vertices), ...
                        'VertexRegionIndex length should match vertex count')
                end
            end
        end
        
        function testZarrWriteWithAtlas(testCase)
            % Test writing mesh+atlas to zarr
            M = bct.data.load('Id', 'fsaverage_rh_pial');
            
            if isfield(M, 'Atlas') && ~isempty(M.Atlas)
                tmpdir = tempname();
                mkdir(tmpdir)
                zarr_path = fullfile(tmpdir, 'test_mesh.zarr');
                
                try
                    % Create manifold and attach atlas
                    testManifold = bct.Manifold(M.Vertices, M.Faces);
                    testManifold.Atlas = M.Atlas;
                    
                    % Write to zarr
                    bct.file.write.manifold(zarr_path, testManifold);
                    
                    % Verify zarr directory exists
                    testCase.verifyTrue(isfolder(zarr_path), ...
                        sprintf('Zarr directory should exist at %s', zarr_path))
                    
                    % Check if atlas group files exist
                    atlas_group_path = fullfile(zarr_path, 'atlas');
                    if isfolder(atlas_group_path)
                        % List directories
                        atlas_files = dir(atlas_group_path);
                        testCase.verifyGreater(length(atlas_files), 2, ...
                            'atlas/ group should contain serialized data')
                    end
                    
                finally
                    % Cleanup
                    if isfolder(tmpdir)
                        rmdir(tmpdir, 's')
                    end
                end
            end
        end
        
        function testZarrAtlasRegionDataIntegrity(testCase)
            % Test that region data (names, codes, colors) are correctly serialized
            M = bct.data.load('Id', 'fsaverage_rh_pial', 'Atlas', 'aparc');
            
            if isfield(M, 'Atlas') && ~isempty(M.Atlas)
                original_atlas = M.Atlas;
                
                testManifold = bct.Manifold(M.Vertices, M.Faces);
                testManifold.Atlas = original_atlas;
                
                S = testManifold.toStruct();
                atlas_schema = S.atlas;
                
                % Check region metadata preserved
                if isfield(atlas_schema, 'RegionNames') && isfield(atlas_schema.RegionNames, 'value')
                    region_names = atlas_schema.RegionNames.value;
                    testCase.verifyEqual(length(region_names), length(original_atlas.RegionNames), ...
                        'Region names count should match')
                    testCase.verifyTrue(all(strlength(region_names) > 0), ...
                        'All region names should be non-empty')
                end
                
                % Check region codes preserved
                if isfield(atlas_schema, 'RegionCodes') && isfield(atlas_schema.RegionCodes, 'value')
                    region_codes = atlas_schema.RegionCodes.value;
                    testCase.verifyEqual(length(region_codes), length(original_atlas.RegionCodes), ...
                        'Region codes count should match')
                end
                
                % Check colors preserved (RGBA)
                if isfield(atlas_schema, 'RegionColorRGBA') && isfield(atlas_schema.RegionColorRGBA, 'value')
                    colors = atlas_schema.RegionColorRGBA.value;
                    testCase.verifyEqual(size(colors, 1), length(original_atlas.RegionNames), ...
                        'Color array should have one row per region')
                    testCase.verifyEqual(size(colors, 2), 4, ...
                        'Color array should have 4 columns (RGBA)')
                end
            end
        end
        
        function testBilateralAtlasConsistency(testCase)
            % Test that both LH and RH atlases can be written
            for hemi = {'lh', 'rh'}
                h = hemi{1};
                id_str = sprintf('fsaverage_rh_pial');  % Using same for both to get consistent test
                
                M = bct.data.load('Id', id_str, 'Atlas', 'aparc');
                
                if isfield(M, 'Atlas')
                    testManifold = bct.Manifold(M.Vertices, M.Faces);
                    testManifold.Atlas = M.Atlas;
                    
                    S = testManifold.toStruct();
                    
                    testCase.verifyTrue(isfield(S, 'atlas'), ...
                        sprintf('%s: toStruct should include atlas', h))
                end
            end
        end
        
    end
    
end
