function structure_config = loadHDF5StructureConfig(config_file)
% LOADHDF5STRUCTURECONFIG Load HDF5 structure configuration from JSON
%
% Usage:
%   structure_config = loadHDF5StructureConfig()
%   structure_config = loadHDF5StructureConfig(config_file)
%
% Inputs:
%   config_file - Path to JSON configuration file (optional)
%                 Default: 'config/bioctree_hdf5_structure.json'
%
% Outputs:
%   structure_config - Parsed configuration structure
%
% Description:
%   This function loads the HDF5 structure specification from a JSON
%   configuration file, providing a centralized way to manage the
%   Bioctree HDF5 file format including Fourier basis support.

if nargin < 1 || isempty(config_file)
    % Use default config file path
    script_dir = fileparts(mfilename('fullpath'));
    project_root = fileparts(script_dir);
    config_file = fullfile(project_root, 'config', 'bioctree_hdf5_structure.json');
end

% Check if file exists
if ~exist(config_file, 'file')
    error('loadHDF5StructureConfig:FileNotFound', ...
        'Configuration file not found: %s', config_file);
end

try
    % Read and parse JSON file
    json_text = fileread(config_file);
    structure_config = jsondecode(json_text);
    
    % Validate basic structure
    if ~isfield(structure_config, 'bioctree_hdf5_structure')
        error('loadHDF5StructureConfig:InvalidFormat', ...
            'Configuration file missing "bioctree_hdf5_structure" root field');
    end
    
    % Extract the main configuration
    structure_config = structure_config.bioctree_hdf5_structure;
    
    % Validate required fields
    required_fields = {'version', 'groups', 'creation_options'};
    for i = 1:length(required_fields)
        if ~isfield(structure_config, required_fields{i})
            error('loadHDF5StructureConfig:MissingField', ...
                'Configuration missing required field: %s', required_fields{i});
        end
    end
    
    fprintf('HDF5 structure configuration loaded successfully\n');
    fprintf('  Version: %s\n', structure_config.version);
    fprintf('  Groups defined: %d\n', length(fieldnames(structure_config.groups)));
    if isfield(structure_config, 'description')
        fprintf('  Description: %s\n', structure_config.description);
    end
    
catch ME
    if strcmp(ME.identifier, 'MATLAB:invalidConversion')
        error('loadHDF5StructureConfig:JSONError', ...
            'Failed to parse JSON configuration file: %s\nError: %s', ...
            config_file, ME.message);
    else
        rethrow(ME);
    end
end

end