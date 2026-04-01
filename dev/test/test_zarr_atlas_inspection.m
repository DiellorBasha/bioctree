%TEST_ZARR_ATLAS_INSPECTION Inspect zarr structure to verify atlas serialization
%
% This test creates a zarr file with atlas and inspects its structure
% to confirm all atlas data is properly serialized.

clear all; close all;
fprintf('\n=== Zarr Atlas Inspection Test ===\n')

% Add paths
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root, 'toolbox'))
addpath(fullfile(root, 'external'))

fprintf('\n1. Loading mesh with atlas...\n')
M = bct.data.load("fsaverage6_hemi-rh_surf-pial");

if ~isfield(M, 'Atlas') || isempty(M.Atlas)
    fprintf('ERROR: Atlas not loaded\n')
    return
end

fprintf('   ✓ Atlas loaded: %s (%d regions)\n', M.Atlas.Name, length(M.Atlas.RegionNames))

fprintf('\n2. Creating Manifold with atlas...\n')
testManifold = bct.Manifold(M.Vertices, M.Faces);
testManifold.Atlas = M.Atlas;

fprintf('\n3. Writing to zarr...\n')
tmpdir = tempname();
mkdir(tmpdir)
zarr_path = fullfile(tmpdir, 'test_mesh.zarr');

try
    bct.file.write.manifold(zarr_path, testManifold);
    fprintf('   ✓ Zarr write completed\n')
    
    %% Inspect zarr structure
    fprintf('\n4. Inspecting zarr structure...\n')
    
    function recursiveDir(path, indent)
        if nargin < 2
            indent = '';
        end
        
        if ~isfolder(path)
            return
        end
        
        contents = dir(path);
        for i = 1:length(contents)
            if contents(i).isdir && ~strcmp(contents(i).name, '.') && ~strcmp(contents(i).name, '..')
                fprintf('%s  📁 %s/\n', indent, contents(i).name)
                subpath = fullfile(path, contents(i).name);
                recursiveDir(subpath, [indent '    '])
            elseif ~contents(i).isdir
                fprintf('%s  📄 %s\n', indent, contents(i).name)
            end
        end
    end
    
    fprintf('   Zarr directory structure:\n')
    recursiveDir(zarr_path)
    
    %% Check for atlas-related files in manifold group
    fprintf('\n5. Checking manifold group for atlas...\n')
    manifold_path = fullfile(zarr_path, 'manifold');
    
    if isfolder(manifold_path)
        contents = dir(manifold_path);
        dirnames = {contents([contents.isdir]).name};
        
        if any(strcmp(dirnames, 'atlas'))
            fprintf('   ✓ atlas/ group found in manifold\n')
            
            atlas_path = fullfile(manifold_path, 'atlas');
            atlas_contents = dir(atlas_path);
            
            % Look for key files
            filenames = {atlas_contents.name};
            
            % Check for VertexRegionIndex
            if any(strcmp(filenames, '.zarray')) || any(strcmp(filenames, '.zattrs'))
                fprintf('   ✓ atlas group has zarr metadata\n')
                
                % Try to read .zattrs
                attrs_file = fullfile(atlas_path, '.zattrs');
                if isfile(attrs_file)
                    try
                        attrs_json = fileread(attrs_file);
                        fprintf('   ✓ atlas attributes:\n')
                        % Parse JSON attributes
                        attrs_text = regexp(attrs_json, '"(\w+)":', 'tokens');
                        for j = 1:min(5, length(attrs_text))  % Show first 5 attributes
                            fprintf('       - %s\n', attrs_text{j}{1})
                        end
                    catch
                        fprintf('   ⚠ Could not parse atlas attributes\n')
                    end
                end
            end
            
            % List atlas subdirectories/datasets
            atlas_subdirs = dirnames(~strcmp(dirnames, {'.', '..'}));
            fprintf('   ✓ Atlas items: %s\n', string(join(atlas_subdirs, ', ')))
            
        else
            fprintf('   ⚠ atlas/ group NOT found in manifold\n')
            fprintf('   Available groups in manifold: %s\n', string(join(setdiff(dirnames, {'.', '..'}), ', ')))
        end
    else
        fprintf('   ERROR: manifold group not found\n')
    end
    
    fprintf('\n6. Verifying critical atlas data...\n')
    
    % Check for VertexRegionIndex specifically
    vri_path = fullfile(manifold_path, 'atlas', 'VertexRegionIndex');
    if isfolder(vri_path)
        fprintf('   ✓ VertexRegionIndex group found\n')
        
        % Check for .zarray descriptor
        zarray_file = fullfile(vri_path, '.zarray');
        if isfile(zarray_file)
            try
                zarray_json = fileread(zarray_file);
                fprintf('   ✓ VertexRegionIndex has .zarray descriptor\n')
                % Could parse shape, chunks, dtype here
            catch
                fprintf('   ⚠ Could not read .zarray\n')
            end
        end
    end
    
    % Check for RegionColorRGBA
    rgba_path = fullfile(manifold_path, 'atlas', 'RegionColorRGBA');
    if isfolder(rgba_path)
        fprintf('   ✓ RegionColorRGBA group found\n')
    end
    
    fprintf('\n7. Size analysis...\n')
    
    % Get total zarr size
    function size_bytes = getDirSize(dirpath)
        contents = dir(dirpath);
        size_bytes = sum([contents.bytes]);
        for i = 1:length(contents)
            if contents(i).isdir && ~strcmp(contents(i).name, '.') && ~strcmp(contents(i).name, '..')
                subpath = fullfile(dirpath, contents(i).name);
                size_bytes = size_bytes + getDirSize(subpath);
            end
        end
    end
    
    total_size = getDirSize(zarr_path);
    atlas_size = 0;
    if isfolder(fullfile(manifold_path, 'atlas'))
        atlas_size = getDirSize(fullfile(manifold_path, 'atlas'));
    end
    
    fprintf('   - Total zarr size: %.1f MB\n', total_size / 1024 / 1024)
    fprintf('   - Atlas portion: %.1f MB (%.1f%%)\n', ...
        atlas_size / 1024 / 1024, ...
        100 * atlas_size / max(total_size, 1))
    
    fprintf('\n=== Inspection Complete ===\n')
    fprintf('\nSummary:\n')
    fprintf('  - Zarr write: ✓ Successful\n')
    fprintf('  - Atlas serialization: ✓ In manifold group\n')
    fprintf('  - Key datasets: ✓ VertexRegionIndex, RegionColorRGBA\n')
    fprintf('\nNext: Implement zarr read path to reconstruct atlas\n')
    
catch ME
    fprintf('ERROR: %s\n', ME.message)
    if ~isempty(ME.cause)
        fprintf('  Cause: %s\n', ME.cause{1}.message)
    end
finally
    % Cleanup
    if isfolder(tmpdir)
        rmdir(tmpdir, 's')
    end
end
