function report = uninstall(varargin)
%UNINSTALL Remove BCT dependency configuration and optionally files
%
% Remove dependency configuration from MATLAB preferences and optionally
% delete dependency folders.
%
% Syntax:
%   report = bct.install.uninstall(...)
%
% Name-Value Parameters:
%   'delete'         - Delete dependency folders (default: false)
%   'root'           - Explicit root (default: auto-resolved)
%   'removeFromPath' - Remove from current session (default: true)
%   'quiet'          - Suppress output (default: false)
%
% Returns:
%   report - struct with uninstall details
%
% Example:
%   % Remove configuration only (keep files)
%   bct.install.uninstall
%
%   % Remove configuration and delete files
%   bct.install.uninstall('delete', true)
%
% See also: bct.install.deps, bct.install.configure

% Parse inputs
p = inputParser;
p.addParameter('delete', false, @islogical);
p.addParameter('root', '', @ischar);
p.addParameter('removeFromPath', true, @islogical);
p.addParameter('quiet', false, @islogical);
p.parse(varargin{:});
opts = p.Results;

% Resolve root
[depsRoot, rootSource] = bct.install.internal.resolveRoot(opts.root);

if ~opts.quiet
    fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
    fprintf('║     BCT Dependency Uninstall                             ║\n');
    fprintf('╚══════════════════════════════════════════════════════════╝\n\n');
    fprintf('Dependencies root: %s\n', depsRoot);
    fprintf('Root source: %s\n\n', rootSource);
end

% Read manifest
manifest = bct.install.internal.readManifest();
depNames = fieldnames(manifest);

% Remove from path if requested
if opts.removeFromPath
    if ~opts.quiet
        fprintf('Removing dependencies from path...\n');
    end
    
    for i = 1:numel(depNames)
        depMeta = manifest.(depNames{i});
        depPath = fullfile(depsRoot, depMeta.folder);
        
        if ~exist(depPath, 'dir')
            continue;
        end
        
        try
            % Use safe removal that only removes known paths
            bct.install.internal.safeRmpath(depPath);
            
            if ~opts.quiet
                fprintf('  ✓ Removed %s from path\n', depMeta.name);
            end
        catch ME
            if ~opts.quiet
                warning('Failed to remove %s from path: %s', depMeta.name, ME.message);
            end
        end
    end
    
    if ~opts.quiet
        fprintf('\n');
    end
end

% Remove preference
if ispref('bct', 'depsRoot')
    rmpref('bct', 'depsRoot');
    
    if ~opts.quiet
        fprintf('✓ Removed depsRoot preference\n\n');
    end
end

% Delete files if requested
deletedItems = {};
if opts.delete
    if ~opts.quiet
        fprintf('Deleting dependency folders...\n');
    end
    
    % Delete each dependency folder
    for i = 1:numel(depNames)
        depMeta = manifest.(depNames{i});
        depPath = fullfile(depsRoot, depMeta.folder);
        
        if exist(depPath, 'dir')
            try
                rmdir(depPath, 's');
                deletedItems{end+1} = depMeta.name; %#ok<AGROW>
                
                if ~opts.quiet
                    fprintf('  ✓ Deleted %s\n', depPath);
                end
            catch ME
                if ~opts.quiet
                    warning('Failed to delete %s: %s', depPath, ME.message);
                end
            end
        end
    end
    
    % Delete lock file if present
    lockFile = fullfile(depsRoot, 'deps.lock.json');
    if exist(lockFile, 'file')
        try
            delete(lockFile);
            if ~opts.quiet
                fprintf('  ✓ Deleted lock file\n');
            end
        catch
            % Ignore
        end
    end
    
    % Try to remove root directory if empty
    try
        if exist(depsRoot, 'dir')
            contents = dir(depsRoot);
            contents = contents(~ismember({contents.name}, {'.', '..'}));
            if isempty(contents)
                rmdir(depsRoot);
                if ~opts.quiet
                    fprintf('  ✓ Removed empty root directory\n');
                end
            end
        end
    catch
        % Ignore
    end
    
    if ~opts.quiet
        fprintf('\n');
    end
end

% Build report
report = struct(...
    'depsRoot', depsRoot, ...
    'removedFromPath', opts.removeFromPath, ...
    'deletedFiles', opts.delete, ...
    'deletedItems', {deletedItems});

if ~opts.quiet
    fprintf('✓ Uninstall complete\n\n');
    
    if opts.delete
        fprintf('Deleted %d dependency folder(s).\n', numel(deletedItems));
    else
        fprintf('Configuration removed. Files preserved at:\n');
        fprintf('  %s\n', depsRoot);
    end
    
    fprintf('\n');
end

end
