function cfg = bioctree_config()
% BIOCTREE_CONFIG Load Bioctree configuration from JSON manifests
%
% Loads path configuration from bioctree_paths.json and dependency
% information from bioctree_dependencies.json.
%
% Usage:
%   cfg = bioctree_config()
%
% Output:
%   cfg - Structure with fields:
%         root       - Bioctree root directory
%         toolbox    - Toolbox directory path
%         package    - +bct package directory path
%         external   - External dependencies directory
%         app_code   - Application code directory
%         test_data  - Test data directory
%         examples   - Examples directory
%         apps       - Applications directory
%         scripts    - Scripts directory
%         deps       - Dependency manifest structure
%
% See also: bioctree_start

    % Get config directory (where this file is located)
    root = fileparts(fileparts(mfilename('fullpath')));

    % Load paths JSON
    paths_file = fullfile(fileparts(mfilename('fullpath')), 'bioctree_paths.json');
    if ~exist(paths_file, 'file')
        error('bioctree:ConfigNotFound', 'Configuration file not found: %s', paths_file);
    end
    paths = jsondecode(fileread(paths_file));

    % Build absolute paths
    cfg.root      = root;
    cfg.toolbox   = fullfile(root, paths.toolbox);
    cfg.package   = fullfile(root, paths.package);
    cfg.external  = fullfile(root, paths.external);
    cfg.app_code  = fullfile(root, paths.app_code);
    cfg.test_data = fullfile(root, paths.test_data);
    cfg.examples  = fullfile(root, paths.examples);
    cfg.apps      = fullfile(root, paths.apps);
    cfg.scripts   = fullfile(root, paths.scripts);

    % Load dependency manifest
    deps_file = fullfile(fileparts(mfilename('fullpath')), 'bioctree_dependencies.json');
    if exist(deps_file, 'file')
        cfg.deps = jsondecode(fileread(deps_file));
    else
        warning('bioctree:DepsNotFound', 'Dependency manifest not found: %s', deps_file);
        cfg.deps = struct();
    end

    % Ensure critical folders exist
    critical_paths = {'toolbox', 'package', 'external'};
    for k = 1:numel(critical_paths)
        path_field = critical_paths{k};
        path_value = cfg.(path_field);
        if ~exist(path_value, 'dir')
            warning('bioctree:PathMissing', 'Creating missing directory: %s', path_value);
            mkdir(path_value);
        end
    end
end
