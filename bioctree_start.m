function bioctree_start()
% BIOCTREE_START Initialize Bioctree toolbox environment
%
% Main entry point for Bioctree initialization. This function:
%   - Loads configuration from JSON manifests
%   - Adds all necessary paths to MATLAB path
%   - Downloads and validates external dependencies
%   - Initializes the +bct package
%   - Validates the environment
%   - Prints diagnostic information
%
% Usage:
%   bioctree_start()  % Run from anywhere after navigating to bioctree root
%
% See also: bioctree_config

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║          Bioctree Toolbox Initialization                ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

%% 0. Add Config Directory to Path
% Get the bioctree root directory (where this script is located)
bioctree_root = fileparts(mfilename('fullpath'));
config_dir = fullfile(bioctree_root, 'config');

% Add config directory to path so bioctree_config() can be found
if exist(config_dir, 'dir')
    addpath(config_dir);
else
    error('bioctree:ConfigDirNotFound', 'Config directory not found: %s', config_dir);
end

%% 1. Load Configuration
fprintf('[1/6] Loading configuration...\n');
try
    cfg = bioctree_config();
    fprintf('      ✓ Config loaded from: %s\n', fullfile(cfg.root, 'config'));
    fprintf('      ✓ Root directory: %s\n', cfg.root);
catch ME
    error('bioctree:ConfigFailed', 'Failed to load configuration: %s', ME.message);
end

%% 2. Add Paths
fprintf('\n[2/6] Adding paths to MATLAB...\n');
try
    % Add toolbox (brings +bct package into scope)
    addpath(cfg.toolbox);
    fprintf('      ✓ Toolbox: %s\n', cfg.toolbox);
    
    % Add specific external subdirectories only
    if exist(cfg.external, 'dir')
        % Add gspbox
        gspbox_path = fullfile(cfg.external, 'gspbox');
        if exist(gspbox_path, 'dir')
            addpath(genpath(gspbox_path));
            fprintf('      ✓ External: %s\n', gspbox_path);
        end
        
        % Add gptoolbox/mesh only
        gptoolbox_mesh_path = fullfile(cfg.external, 'gptoolbox', 'mesh');
        if exist(gptoolbox_mesh_path, 'dir')
            addpath(genpath(gptoolbox_mesh_path));
            fprintf('      ✓ External: %s\n', gptoolbox_mesh_path);
        end
        
        % Add DECLab
        declab_path = fullfile(cfg.external, 'DECLab');
        if exist(declab_path, 'dir')
            addpath(genpath(declab_path));
            fprintf('      ✓ External: %s\n', declab_path);
        end
    end
    
    % Add data directory
    if exist(cfg.data, 'dir')
        addpath(cfg.data);
        fprintf('      ✓ Data: %s\n', cfg.data);
    end
    
    % Add apps directory
    if exist(cfg.apps, 'dir')
        addpath(cfg.apps);
        fprintf('      ✓ Apps: %s\n', cfg.apps);
    end
    
    % Add app_code directory
    if exist(cfg.app_code, 'dir')
        addpath(cfg.app_code);
        fprintf('      ✓ App code: %s\n', cfg.app_code);
    end
    
    % Add examples directory
    if exist(cfg.examples, 'dir')
        addpath(cfg.examples);
        fprintf('      ✓ Examples: %s\n', cfg.examples);
    end
    
    % Add scripts directory
    if exist(cfg.scripts, 'dir')
        addpath(cfg.scripts);
        fprintf('      ✓ Scripts: %s\n', cfg.scripts);
    end
    
    % Add tests directory
    tests_dir = fullfile(cfg.root, 'tests');
    if exist(tests_dir, 'dir')
        addpath(genpath(tests_dir));
        fprintf('      ✓ Tests: %s\n', tests_dir);
    end
    
    % Add docs directory for reference
    docs_dir = fullfile(cfg.root, 'docs');
    if exist(docs_dir, 'dir')
        addpath(docs_dir);
        fprintf('      ✓ Docs: %s\n', docs_dir);
    end


    % Add docs directory for reference
addpath(genpath('apps'))
    
catch ME
    error('bioctree:PathSetup', 'Failed to add paths: %s', ME.message);
end

%% 3. Check and Download Dependencies
fprintf('\n[3/6] Checking external dependencies...\n');
deps = fieldnames(cfg.deps);
missing_deps = {};

for i = 1:numel(deps)
    dep_name = deps{i};
    dep_info = cfg.deps.(dep_name);
    dep_path = fullfile(cfg.external, dep_name);
    
    if exist(dep_path, 'dir')
        fprintf('      ✓ %s: Found\n', dep_name);
        % Add to path
        addpath(genpath(dep_path));
    else
        fprintf('      ✗ %s: Missing\n', dep_name);
        missing_deps{end+1} = dep_name; %#ok<AGROW>
        
        % Attempt to download
        fprintf('        Attempting to clone from %s...\n', dep_info.repo);
        try
            [status, ~] = system(sprintf('git clone %s "%s"', dep_info.repo, dep_path));
            if status == 0
                fprintf('        ✓ Cloned successfully\n');
                addpath(genpath(dep_path));
            else
                fprintf('        ✗ Clone failed\n');
            end
        catch
            fprintf('        ✗ Clone failed (git not available or network issue)\n');
        end
    end
end

% Initialize GSPBOX if present
gspbox_path = fullfile(cfg.external, 'gspbox');
if exist(gspbox_path, 'dir')
    try
        gsp_start();
        fprintf('      ✓ GSPBOX initialized\n');
    catch
        fprintf('      ⚠ GSPBOX found but initialization failed\n');
    end
end

%% 4. Validate BCT Package
fprintf('\n[4/6] Validating +bct package...\n');
if exist('bct.bct', 'class')
    fprintf('      ✓ bct.bct class available\n');
    
    % Check for key classes
    key_classes = {'bct.Domain', 'bct.Lambda', 'bct.Omega', 'bct.Joint', ...
                   'bct.Manifold', 'bct.Signal', 'bct.Graph'};
    all_found = true;
    for i = 1:numel(key_classes)
        if exist(key_classes{i}, 'class')
            fprintf('      ✓ %s\n', key_classes{i});
        else
            fprintf('      ✗ %s (missing)\n', key_classes{i});
            all_found = false;
        end
    end
    
    if all_found
        fprintf('      ✓ All core classes validated\n');
    else
        warning('bioctree:MissingClasses', 'Some +bct classes are missing');
    end
else
    error('bioctree:BCTNotFound', 'bct.bct class not found. Package may be corrupted.');
end

%% 5. Environment Validation
fprintf('\n[5/6] Validating environment...\n');

% Check MATLAB version
matlab_version = version('-release');
matlab_year = str2double(matlab_version(1:4));
if matlab_year >= 2020
    fprintf('      ✓ MATLAB %s (compatible)\n', matlab_version);
else
    fprintf('      ⚠ MATLAB %s (older version, may have issues)\n', matlab_version);
end

% Check for recommended toolboxes
recommended_toolboxes = {
    'Signal Processing Toolbox', 'signal'
    'Statistics and Machine Learning Toolbox', 'stats'
    'Image Processing Toolbox', 'images'
};

fprintf('      Optional toolboxes:\n');
for i = 1:size(recommended_toolboxes, 1)
    tb_name = recommended_toolboxes{i, 1};
    tb_dir = recommended_toolboxes{i, 2};
    
    if license('test', tb_dir) && ~isempty(ver(tb_dir))
        fprintf('        ✓ %s\n', tb_name);
    else
        fprintf('        - %s (not installed)\n', tb_name);
    end
end

%% 6. Print Diagnostics
fprintf('\n[6/6] System diagnostics:\n');
fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  Configuration Summary                                   ║\n');
fprintf('╠══════════════════════════════════════════════════════════╣\n');
fprintf('║  Root:      %-45s ║\n', truncate_path(cfg.root, 45));
fprintf('║  Toolbox:   %-45s ║\n', truncate_path(cfg.toolbox, 45));
fprintf('║  Package:   %-45s ║\n', truncate_path(cfg.package, 45));
fprintf('║  External:  %-45s ║\n', truncate_path(cfg.external, 45));
fprintf('╠══════════════════════════════════════════════════════════╣\n');
fprintf('║  Dependencies                                            ║\n');
fprintf('╠══════════════════════════════════════════════════════════╣\n');

for i = 1:numel(deps)
    dep_name = deps{i};
    dep_path = fullfile(cfg.external, dep_name);
    if exist(dep_path, 'dir')
        status_str = '✓';
    else
        status_str = '✗';
    end
    fprintf('║  [%s] %-51s ║\n', status_str, dep_name);
end

fprintf('╚══════════════════════════════════════════════════════════╝\n');

% Print usage examples
fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  Quick Start Examples                                    ║\n');
fprintf('╠══════════════════════════════════════════════════════════╣\n');
fprintf('║  Create BCT object:                                      ║\n');
fprintf('║    obj = bct.bct()                                       ║\n');
fprintf('║                                                          ║\n');
fprintf('║  Create domains:                                         ║\n');
fprintf('║    lambda = bct.Lambda(manifold)                         ║\n');
fprintf('║    omega = bct.Omega(time_vector, sampling_rate)         ║\n');
fprintf('║                                                          ║\n');
fprintf('║  Create filters:                                         ║\n');
fprintf('║    filt = bct.filters.FilterDesigner.heat(lambda, tau)   ║\n');
fprintf('║                                                          ║\n');
fprintf('║  Run tests:                                              ║\n');
fprintf('║    cd tests; run_enhanced_bct_tests                      ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n');

if ~isempty(missing_deps)
    fprintf('\n⚠ Warning: Some dependencies are missing:\n');
    for i = 1:numel(missing_deps)
        fprintf('  - %s\n', missing_deps{i});
    end
    fprintf('  Run ''bioctree_start'' again or manually clone to external/\n');
end

fprintf('\n✓ Bioctree initialization complete!\n\n');
B=bct_fsaverage;
end

function s = truncate_path(path_str, max_len)
% Truncate path string to max_len characters
if length(path_str) <= max_len
    s = path_str;
else
    s = ['...' path_str(end-max_len+4:end)];
end
end
