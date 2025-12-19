function cfg = bct_config()
%BCT_CONFIG Load BCT configuration from JSON manifests
%
% Reads bct_paths.json and bct_dependencies.json from the config directory
% and constructs an absolute path configuration structure.
%
% Returns:
%   cfg - Configuration struct with fields:
%       root        - BCT root directory
%       toolbox     - Toolbox directory (contains +bct package)
%       package     - Package directory (alias for toolbox)
%       external    - External dependencies directory
%       app_code    - App code directory
%       data        - Data directory
%       examples    - Examples directory
%       apps        - Apps directory
%       scripts     - Scripts directory
%       mesh        - Standard meshes struct
%       deps        - Dependencies manifest
%
% Usage:
%   cfg = bct_config();
%
% See also: bct_start

% Get BCT root (one level up from config/)
config_dir = fileparts(mfilename('fullpath'));
bct_root = fileparts(config_dir);

%% Load path configuration
paths_file = fullfile(config_dir, 'bct_paths.json');
if ~exist(paths_file, 'file')
    error('bct:PathsNotFound', 'Paths file not found: %s', paths_file);
end

try
    paths_text = fileread(paths_file);
    paths = jsondecode(paths_text);
catch ME
    error('bct:PathsInvalid', 'Failed to parse %s: %s', paths_file, ME.message);
end

%% Load dependencies manifest
deps_file = fullfile(config_dir, 'bct_dependencies.json');
if ~exist(deps_file, 'file')
    error('bct:DepsNotFound', 'Dependencies file not found: %s', deps_file);
end

try
    deps_text = fileread(deps_file);
    deps = jsondecode(deps_text);
catch ME
    error('bct:DepsInvalid', 'Failed to parse %s: %s', deps_file, ME.message);
end

%% Build configuration struct
cfg = struct();
cfg.root = bct_root;

% Core paths (make absolute)
cfg.toolbox = fullfile(bct_root, paths.toolbox);
cfg.package = cfg.toolbox;  % Alias
cfg.external = fullfile(bct_root, paths.external);
cfg.app_code = fullfile(bct_root, paths.app_code);
cfg.data = fullfile(bct_root, paths.data);
cfg.examples = fullfile(bct_root, paths.examples);
cfg.apps = fullfile(bct_root, paths.apps);
cfg.scripts = fullfile(bct_root, paths.scripts);

% Standard mesh paths
mesh_struct = struct();
mesh_fields = fieldnames(paths.standard_meshes);
for i = 1:numel(mesh_fields)
    field = mesh_fields{i};
    mesh_struct.(field) = fullfile(bct_root, paths.standard_meshes.(field));
end
cfg.mesh = mesh_struct;

% Dependencies manifest
cfg.deps = deps;

end
