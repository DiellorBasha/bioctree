function bct_start()
%BCT_START Initialize BCT (Brain Connectivity Toolbox) package
%
% Main entry point for BCT initialization. This function:
%   - Loads configuration from JSON manifests
%   - Adds all necessary paths to MATLAB path
%   - Initializes external dependencies (DECLab, GSPBox, GPToolbox)
%   - Validates the +bct package
%   - Prints diagnostic information
%
% Usage:
%   bct_start()  % Run from BCT root directory
%
% External Dependencies:
%   - DECLab:    Discrete Exterior Calculus (required for bct.DEC)
%   - GSPBox:    Graph Signal Processing (required for spectral ops)
%   - GPToolbox: Geometry Processing (FEM mesh operations)
%
% See also: bct_config

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║          BCT Package Initialization                      ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

%% 1. Load Configuration
fprintf('[1/5] Loading configuration...\n');
bct_root = fileparts(mfilename('fullpath'));
config_dir = fullfile(bct_root, 'config');

% Add config to path temporarily
if exist(config_dir, 'dir')
    addpath(config_dir);
else
    error('bct:ConfigDirNotFound', 'Config directory not found: %s', config_dir);
end

try
    cfg = bct_config();
    fprintf('      ✓ Config loaded: %s\n', config_dir);
    fprintf('      ✓ Root: %s\n', cfg.root);
catch ME
    error('bct:ConfigFailed', 'Failed to load configuration: %s', ME.message);
end

%% 2. Add Core Paths
fprintf('\n[2/5] Adding core paths...\n');
try
    % Add toolbox (brings +bct package into scope)
    addpath(cfg.toolbox);
    fprintf('      ✓ Toolbox: %s\n', cfg.toolbox);
    
    % Add data directory
    if exist(cfg.data, 'dir')
        addpath(cfg.data);
        fprintf('      ✓ Data: %s\n', cfg.data);
    end
    
    % Add examples directory
    if exist(cfg.examples, 'dir')
        addpath(cfg.examples);
        fprintf('      ✓ Examples: %s\n', cfg.examples);
    end
    
    % Add tests directory
    tests_dir = fullfile(cfg.root, 'tests');
    if exist(tests_dir, 'dir')
        addpath(genpath(tests_dir));
        fprintf('      ✓ Tests: %s\n', tests_dir);
    end
    
    % Add docs directory
    docs_dir = fullfile(cfg.root, 'docs');
    if exist(docs_dir, 'dir')
        addpath(docs_dir);
        fprintf('      ✓ Docs: %s\n', docs_dir);
    end
    
catch ME
    error('bct:PathSetup', 'Failed to add core paths: %s', ME.message);
end

%% 3. Initialize External Dependencies
fprintf('\n[3/5] Initializing external dependencies...\n');

% DECLab (required for bct.DEC)
declab_path = fullfile(cfg.external, 'DECLab');
if exist(declab_path, 'dir')
    addpath(genpath(declab_path));
    fprintf('      ✓ DECLab: %s\n', declab_path);
else
    fprintf('      ⚠ DECLab not found (bct.DEC will not work)\n');
    fprintf('        Clone from: https://github.com/DillonCislo/DECLab\n');
end

% GSPBox (required for spectral operations)
gspbox_path = fullfile(cfg.external, 'gspbox');
if exist(gspbox_path, 'dir')
    addpath(genpath(gspbox_path));
    fprintf('      ✓ GSPBox: %s\n', gspbox_path);
    
    % Initialize GSPBox
    try
        gsp_start();
        fprintf('      ✓ GSPBox initialized\n');
    catch
        fprintf('      ⚠ GSPBox found but initialization failed\n');
    end
else
    fprintf('      ⚠ GSPBox not found (spectral ops limited)\n');
    fprintf('        Clone from: https://github.com/epfl-lts2/gspbox\n');
end

% GPToolbox (required for FEM mesh operations)
gptoolbox_path = fullfile(cfg.external, 'gptoolbox', 'mesh');
if exist(gptoolbox_path, 'dir')
    addpath(genpath(gptoolbox_path));
    fprintf('      ✓ GPToolbox/mesh: %s\n', gptoolbox_path);
else
    fprintf('      ⚠ GPToolbox not found (FEM ops limited)\n');
    fprintf('        Clone from: https://github.com/alecjacobson/gptoolbox\n');
end

%% 4. Validate BCT Package
fprintf('\n[4/5] Validating +bct package...\n');

% Check core classes
key_classes = {
    'bct.Manifold', 'bct.FEM', 'bct.Graph', 'bct.Eigenpairs'
};

all_found = true;
for i = 1:numel(key_classes)
    if exist(key_classes{i}, 'class')
        fprintf('      ✓ %s\n', key_classes{i});
    else
        fprintf('      ✗ %s (missing)\n', key_classes{i});
        all_found = false;
    end
end

% Check key packages
key_packages = {
    'bct.fem', 'bct.graph', 'bct.eigenpairs', ...
    'bct.registry', 'bct.runtime'
};

for i = 1:numel(key_packages)
    pkg_parts = strsplit(key_packages{i}, '.');
    pkg_path = fullfile(cfg.package, ['+bct'], ['+' pkg_parts{2}]);
    if exist(pkg_path, 'dir')
        fprintf('      ✓ %s package\n', key_packages{i});
    else
        fprintf('      ✗ %s package (missing)\n', key_packages{i});
        all_found = false;
    end
end

if all_found
    fprintf('      ✓ All core components validated\n');
else
    warning('bct:MissingComponents', 'Some BCT components are missing');
end

%% 5. System Diagnostics
fprintf('\n[5/5] System diagnostics:\n');

% MATLAB version
matlab_version = version('-release');
matlab_year = str2double(matlab_version(1:4));
if matlab_year >= 2020
    fprintf('      ✓ MATLAB %s (compatible)\n', matlab_version);
else
    fprintf('      ⚠ MATLAB %s (R2020a+ recommended)\n', matlab_version);
end

% Check for recommended toolboxes
fprintf('      Optional toolboxes:\n');
toolboxes = {
    'Signal Processing Toolbox', 'signal';
    'Statistics and Machine Learning Toolbox', 'stats';
    'Optimization Toolbox', 'optim'
};

for i = 1:size(toolboxes, 1)
    if license('test', toolboxes{i,2}) && ~isempty(ver(toolboxes{i,2}))
        fprintf('        ✓ %s\n', toolboxes{i,1});
    else
        fprintf('        - %s (not installed)\n', toolboxes{i,1});
    end
end

%% Summary
fprintf('\n✓ BCT initialization complete!\n\n');

end
