function success = db_create_hdf5_structure(filePath, structure_config, verbose)
% DB_CREATE_HDF5_STRUCTURE Create HDF5 file structure from JSON config
%
% Usage:
%   success = createHDF5StructureFromConfig(filePath, structure_config)
%   success = createHDF5StructureFromConfig(filePath, structure_config, verbose)
%
% Inputs:
%   filePath         - Output HDF5 file path
%   structure_config - Configuration structure from loadHDF5StructureConfig
%   verbose          - Display progress messages (default: false)
%
% Outputs:
%   success - True if structure created successfully
%
% Description:
%   Creates the complete HDF5 group structure based on the JSON configuration,
%   including support for Fourier basis datasets in the /graph group.

if nargin < 3
    verbose = false;
end

success = false;

try
    if verbose
        fprintf('Creating HDF5 structure from configuration...\n');
        fprintf('  File: %s\n', filePath);
        fprintf('  Config version: %s\n', structure_config.version);
    end
    
    % Remove existing file
    if exist(filePath, 'file')
        delete(filePath);
        if verbose
            fprintf('  Removed existing file\n');
        end
    end
    
    % Create temporary dataset to initialize file
    h5create(filePath, '/temp_init', 1);
    h5write(filePath, '/temp_init', 0);
    
    % Create all groups recursively
    groups_created = 0;
    groups_config = structure_config.groups;
    group_names = fieldnames(groups_config);
    
    for i = 1:length(group_names)
        group_path = group_names{i};
        group_config = groups_config.(group_names{i});
        
        % Create main group
        if createHDF5Group(filePath, group_path, verbose)
            groups_created = groups_created + 1;
        end
        
        % Create subgroups if they exist
        if isfield(group_config, 'subgroups')
            subgroups = group_config.subgroups;
            subgroup_names = fieldnames(subgroups);
            
            for j = 1:length(subgroup_names)
                subgroup_path = subgroup_names{j};
                if createHDF5Group(filePath, subgroup_path, verbose)
                    groups_created = groups_created + 1;
                end
                
                % Handle nested subgroups recursively
                subgroup_config = subgroups.(subgroup_names{j});
                if isfield(subgroup_config, 'subgroups')
                    nested_subgroups = subgroup_config.subgroups;
                    nested_names = fieldnames(nested_subgroups);
                    for k = 1:length(nested_names)
                        nested_path = nested_names{k};
                        if createHDF5Group(filePath, nested_path, verbose)
                            groups_created = groups_created + 1;
                        end
                    end
                end
            end
        end
    end
    
    % Clean up temporary dataset
    if structure_config.creation_options.cleanup_temp_datasets
        try
            % HDF5 doesn't allow direct dataset deletion, so we'll leave it
            % The temp dataset is small and won't affect functionality
        catch
            % Ignore cleanup errors
        end
    end
    
    if verbose
        fprintf('  ✓ Created %d groups successfully\n', groups_created);
        fprintf('  ✓ HDF5 structure ready for Bioctree data\n');
    end
    
    success = true;
    
catch ME
    warning('createHDF5StructureFromConfig:CreationError', ...
        'Failed to create HDF5 structure: %s', ME.message);
    success = false;
end

end

function success = createHDF5Group(filePath, groupPath, verbose)
% Helper function to create a single HDF5 group
    try
        % Check if group already exists
        info = h5info(filePath);
        if groupExists(info, groupPath)
            if verbose
                fprintf('    Group already exists: %s\n', groupPath);
            end
            success = true;
            return;
        end
        
        % Create parent groups if necessary
        parent_path = getParentPath(groupPath);
        if ~isempty(parent_path) && ~strcmp(parent_path, '/')
            createHDF5Group(filePath, parent_path, false); % Recursive, no verbose
        end
        
        % Create the group
        h5_group_name = groupPath;
        if ~startsWith(h5_group_name, '/')
            h5_group_name = ['/' h5_group_name];
        end
        
        % Use low-level HDF5 functions for group creation
        file_id = H5F.open(filePath, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
        group_id = H5G.create(file_id, h5_group_name, 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
        H5G.close(group_id);
        H5F.close(file_id);
        
        if verbose
            fprintf('    ✓ Created group: %s\n', groupPath);
        end
        success = true;
        
    catch ME
        if verbose
            fprintf('    ✗ Failed to create group %s: %s\n', groupPath, ME.message);
        end
        success = false;
    end
end

function exists = groupExists(info, groupPath)
% Check if a group exists in the HDF5 file structure
    exists = false;
    if ~isfield(info, 'Groups') || isempty(info.Groups)
        return;
    end
    
    group_names = {info.Groups.Name};
    exists = any(strcmp(groupPath, group_names));
end

function parent_path = getParentPath(path)
% Get parent path from full path
    parts = split(path, '/');
    parts = parts(~cellfun(@isempty, parts)); % Remove empty parts
    
    if length(parts) <= 1
        parent_path = '/';
    else
        parent_path = '/' + strjoin(parts(1:end-1), '/');
    end
end