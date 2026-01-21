function start()
%START Initialize BCT (Bioctree) package
%
% Main entry point for BCT initialization. This function:
%   - Loads configuration from JSON manifests
%   - Adds all necessary paths to MATLAB path
%   - Initializes external dependencies (DECLab, GSPBox, GPToolbox)
%   - Validates the +bct package
%   - Prints diagnostic information
%
% Usage:
%   bct.start()  % Can be called from anywhere
%
% External Dependencies:
%   - DECLab:    Discrete Exterior Calculus (required for bct.DEC)
%   - GSPBox:    Graph Signal Processing (required for spectral ops)
%   - GPToolbox: Geometry Processing (FEM mesh operations)
%   - Zarr:      MATLAB support for Zarr files (required for zarr export)
%
% See also: bct.config.load, bct.install.deps

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║          BCT Package Initialization                      ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

%% 1. Load Configuration
fprintf('[1/5] Loading configuration...\n');

try
    cfg = bct.config.load();
    fprintf('      ✓ Config loaded\n');
    fprintf('      ✓ Root: %s\n', cfg.root);
catch ME
    error('bct:ConfigFailed', 'Failed to load configuration: %s', ME.message);
end

%% 2. Add Core Paths
fprintf('\n[2/5] Adding core paths...\n');
try
    % Add toolbox (brings +bct package into scope)
    addpath(cfg.packageRoot);
    fprintf('      ✓ Toolbox: %s\n', cfg.packageRoot);
    
    % Add data directory
    if isfield(cfg, 'dataRoot') && exist(cfg.dataRoot, 'dir')
        addpath(cfg.dataRoot);
        fprintf('      ✓ Data: %s\n', cfg.dataRoot);
    end
    
    % Add examples directory
    if isfield(cfg, 'examplesRoot') && exist(cfg.examplesRoot, 'dir')
        addpath(cfg.examplesRoot);
        fprintf('      ✓ Examples: %s\n', cfg.examplesRoot);
    end
    
    % Add tests directory
    if isfield(cfg, 'testsRoot') && exist(cfg.testsRoot, 'dir')
        addpath(genpath(cfg.testsRoot));
        fprintf('      ✓ Tests: %s\n', cfg.testsRoot);
    end
    
    % Add docs directory
    if isfield(cfg, 'docsRoot') && exist(cfg.docsRoot, 'dir')
        addpath(cfg.docsRoot);
        fprintf('      ✓ Docs: %s\n', cfg.docsRoot);
    end
    
catch ME
    error('bct:PathSetup', 'Failed to add core paths: %s', ME.message);
end

%% 3. Initialize External Dependencies
fprintf('\n[3/5] Initializing external dependencies...\n');

try
    % Add dependencies to path (no downloads)
    bct.install.addToPath(cfg);
    
    % Validate dependencies are available
    bct.install.require();
    
    fprintf('      ✓ External dependencies ready\n');
catch ME
    if strcmp(ME.identifier, 'bct:DepsMissing')
        fprintf('\n%s\n', ME.message);
        error('bct:start:DepsNotInstalled', 'Dependencies not installed. See message above.');
    else
        rethrow(ME);
    end
end

%% 4. Validate BCT Package
fprintf('\n[4/5] Validating +bct package...\n');

% Check core classes
key_classes = {
    'bct.Manifold', 'bct.Operator'
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
    'bct.manifold', 'bct.manifold.query', ...
    'bct.registry', 'bct.runtime'
};

for i = 1:numel(key_packages)
    pkg_parts = strsplit(key_packages{i}, '.');
    pkg_path = fullfile(cfg.packageRoot, ['+bct'], ['+' pkg_parts{2}]);
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
