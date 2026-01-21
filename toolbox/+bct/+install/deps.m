function report = deps(varargin)
%DEPS Install and configure BCT dependencies
%
% Install DECLab, GSPBox, and gptoolbox with pinned commits for reproducible builds.
%
% Syntax:
%   report = bct.install.deps(...)
%
% Name-Value Parameters:
%   'root'      - Installation root (default: auto-resolved)
%   'method'    - 'auto' (default), 'git', or 'zip'
%   'pin'       - 'tested' (default), 'latest', or explicit SHA/tag
%   'update'    - Update existing (default: false)
%   'overwrite' - Delete and reinstall (default: false)
%   'quiet'     - Suppress output (default: false)
%   'writeLock' - Write lock file (default: true)
%   'savepath'  - Persist path changes (default: false)
%
% Returns:
%   report - struct with installation details
%
% Example:
%   % Install with tested/pinned commits
%   bct.install.deps
%
%   % Force reinstall
%   bct.install.deps('overwrite', true)
%
%   % Install to custom location
%   bct.install.deps('root', 'C:\MyDeps\bct')
%
% See also: bct.install.status, bct.install.configure, bct.start

% Parse inputs
p = inputParser;
p.addParameter('root', '', @ischar);
p.addParameter('method', 'auto', @(x) ismember(x, {'auto', 'git', 'zip'}));
p.addParameter('pin', 'tested', @ischar);
p.addParameter('update', false, @islogical);
p.addParameter('overwrite', false, @islogical);
p.addParameter('quiet', false, @islogical);
p.addParameter('writeLock', true, @islogical);
p.addParameter('savepath', false, @islogical);
p.parse(varargin{:});
opts = p.Results;

% Resolve installation root
[depsRoot, rootSource] = bct.install.internal.resolveRoot(opts.root);

% Print header
if ~opts.quiet
    fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
    fprintf('║     BCT Dependency Installation                          ║\n');
    fprintf('╚══════════════════════════════════════════════════════════╝\n\n');
    fprintf('Installation root: %s\n', depsRoot);
    fprintf('Root source: %s\n\n', rootSource);
end

% Read dependency manifest
manifest = bct.install.internal.readManifest();

% Determine installation method
gitAvailable = bct.install.internal.hasGit();
if strcmp(opts.method, 'auto')
    if gitAvailable
        methodUsed = 'git';
    else
        methodUsed = 'zip';
    end
else
    methodUsed = opts.method;
end

% Validate method
if strcmp(methodUsed, 'git') && ~gitAvailable
    error('bct:install:GitNotFound', ...
        'Git is not available. Install Git or use method="zip".');
end

if ~opts.quiet
    fprintf('Installation method: %s\n', methodUsed);
    fprintf('Pin mode: %s\n\n', opts.pin);
end

% Create root directory if needed
if ~exist(depsRoot, 'dir')
    [success, msg] = mkdir(depsRoot);
    if ~success
        error('bct:install:CannotCreateRoot', ...
            'Failed to create %s: %s', depsRoot, msg);
    end
end

% Install each dependency
depNames = fieldnames(manifest);
items = struct([]);

for i = 1:numel(depNames)
    depName = depNames{i};
    depMeta = manifest.(depName);
    
    if ~opts.quiet
        fprintf('[%d/%d] Installing %s...\n', i, numel(depNames), depMeta.name);
    end
    
    % Determine target folder
    targetPath = fullfile(depsRoot, depMeta.folder);
    
    % Determine requested ref based on pin mode
    if strcmp(opts.pin, 'tested')
        requestedRef = depMeta.ref;  % Use pinned SHA from manifest
    elseif strcmp(opts.pin, 'latest')
        requestedRef = 'latest';
    else
        requestedRef = opts.pin;  % Explicit SHA/tag
    end
    
    % Install the dependency
    try
        if strcmp(methodUsed, 'git')
            installedRef = bct.install.internal.gitCloneOrUpdate(...
                depMeta, targetPath, requestedRef, opts.update, opts.overwrite, opts.quiet);
        else
            installedRef = bct.install.internal.zipDownloadAndExtract(...
                depMeta, targetPath, requestedRef, opts.overwrite, opts.quiet);
        end
        
        % Add to path
        if ~opts.quiet
            fprintf('      Adding to path...\n');
        end
        
        if strcmp(depMeta.folder, 'gptoolbox')
            % gptoolbox: add only mesh subfolder
            meshPath = fullfile(targetPath, 'mesh');
            if exist(meshPath, 'dir')
                addpath(genpath(meshPath));
            else
                warning('bct:install:MeshFolderNotFound', ...
                    'gptoolbox/mesh folder not found at %s', meshPath);
            end
        elseif strcmp(depMeta.folder, 'MATLAB-support-for-Zarr-files')
            % Zarr: add root directory only (no subdirectories needed)
            addpath(targetPath);
        else
            % DECLab and GSPBox: add everything
            addpath(genpath(targetPath));
        end
        
        % Initialize GSPBox if this is GSPBox
        if strcmp(depMeta.folder, 'gspbox')
            if ~opts.quiet
                fprintf('      Initializing GSPBox...\n');
            end
            try
                gsp_start();
            catch ME
                error('bct:install:GSPStartFailed', ...
                    'GSPBox initialization failed: %s', ME.message);
            end
        end
        
        % Validate symbols
        if ~opts.quiet
            fprintf('      Validating symbols...\n');
        end
        symbolsOk = bct.install.internal.detectSymbols(depMeta);
        
        if symbolsOk
            status = '✓ OK';
        else
            status = '⚠ Symbols not detected';
        end
        
        if ~opts.quiet
            fprintf('      %s\n\n', status);
        end
        
        % Record result
        item = struct(...
            'name', depMeta.name, ...
            'repo', depMeta.repo, ...
            'requestedRef', requestedRef, ...
            'installedRef', installedRef, ...
            'installedPath', targetPath, ...
            'symbolsOk', symbolsOk, ...
            'notes', '');
        
        if isempty(items)
            items = item;
        else
            items(end+1) = item;
        end
        
    catch ME
        error('bct:install:InstallFailed', ...
            'Failed to install %s: %s\nConsider using overwrite=true or manually install to a custom location.', ...
            depMeta.name, ME.message);
    end
end

% Persist root to preferences
setpref('bct', 'depsRoot', depsRoot);

if ~opts.quiet
    fprintf('✓ Preference saved: depsRoot = %s\n\n', depsRoot);
end

% Write lock file
if opts.writeLock
    bct.install.internal.writeLock(depsRoot, struct(...
        'depsRoot', depsRoot, ...
        'methodUsed', methodUsed, ...
        'requestedPin', opts.pin, ...
        'items', items));
    
    if ~opts.quiet
        fprintf('✓ Lock file written: %s\n\n', fullfile(depsRoot, 'deps.lock.json'));
    end
end

% Save path if requested
if opts.savepath
    try
        savepath;
        if ~opts.quiet
            fprintf('✓ Path changes saved to pathdef.m\n\n');
        end
    catch ME
        warning('bct:install:SavepathFailed', ...
            'Failed to save path: %s', ME.message);
    end
end

% Build report
allOk = all([items.symbolsOk]);

report = struct(...
    'ok', allOk, ...
    'depsRoot', depsRoot, ...
    'rootSource', rootSource, ...
    'methodUsed', methodUsed, ...
    'gitAvailable', gitAvailable, ...
    'items', items);

% Print summary
if ~opts.quiet
    fprintf('╔══════════════════════════════════════════════════════════╗\n');
    fprintf('║     Installation Summary                                 ║\n');
    fprintf('╚══════════════════════════════════════════════════════════╝\n\n');
    
    for i = 1:numel(items)
        item = items(i);
        fprintf('%s:\n', item.name);
        fprintf('  Status: %s\n', iif(item.symbolsOk, 'OK', 'SYMBOLS NOT DETECTED'));
        fprintf('  Path: %s\n', item.installedPath);
        fprintf('  Ref: %s\n\n', item.installedRef);
    end
    
    if allOk
        fprintf('✓ All dependencies installed successfully!\n');
        fprintf('  Run bct.start to initialize BCT.\n\n');
    else
        fprintf('⚠ Some dependencies may not be fully functional.\n');
        fprintf('  Check the warnings above.\n\n');
    end
end

end

function out = iif(cond, trueVal, falseVal)
    if cond
        out = trueVal;
    else
        out = falseVal;
    end
end
