function report = status()
%STATUS Report BCT dependency installation status
%
% Check whether dependencies are installed and symbols are available.
%
% Syntax:
%   report = bct.install.status()
%
% Returns:
%   report - struct with fields:
%     depsRoot      - Resolved dependency root
%     rootSource    - Where root came from
%     allPresent    - All folders exist
%     readyForStart - All symbols available
%     items         - Array of per-dependency status
%
% Example:
%   s = bct.install.status();
%   if ~s.readyForStart
%       bct.install.deps
%   end
%
% See also: bct.install.deps, bct.install.require

% Resolve root
[depsRoot, rootSource] = bct.install.internal.resolveRoot('');

% Load manifest
manifest = bct.install.internal.readManifest();

% Check each dependency
depNames = fieldnames(manifest);
items = struct([]);

for i = 1:numel(depNames)
    depName = depNames{i};
    depMeta = manifest.(depName);
    
    % Check folder exists
    targetPath = fullfile(depsRoot, depMeta.folder);
    folderExists = exist(targetPath, 'dir') == 7;
    
    % Check symbols available
    symbolsOk = false;
    installedRef = '';
    
    if folderExists
        % Try to detect symbols (requires path)
        symbolsOk = bct.install.internal.detectSymbols(depMeta);
        
        % Try to get git ref
        try
            gitDir = fullfile(targetPath, '.git');
            if exist(gitDir, 'dir')
                [status, result] = system(sprintf('git -C "%s" rev-parse HEAD', targetPath));
                if status == 0
                    installedRef = strtrim(result);
                end
            end
        catch
            % Git not available or not a git repo
        end
    end
    
    item = struct(...
        'name', depMeta.name, ...
        'folder', depMeta.folder, ...
        'installedPath', targetPath, ...
        'folderExists', folderExists, ...
        'symbolsOk', symbolsOk, ...
        'installedRef', installedRef);
    
    if isempty(items)
        items = item;
    else
        items(end+1) = item;
    end
end

% Determine overall status
allPresent = all([items.folderExists]);
readyForStart = all([items.symbolsOk]);

% Build report
report = struct(...
    'depsRoot', depsRoot, ...
    'rootSource', rootSource, ...
    'allPresent', allPresent, ...
    'readyForStart', readyForStart, ...
    'items', items);

% Print status
fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
fprintf('║     BCT Dependency Status                                ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

fprintf('Dependencies root: %s\n', depsRoot);
fprintf('Root source: %s\n\n', rootSource);

for i = 1:numel(items)
    item = items(i);
    
    fprintf('%s:\n', item.name);
    fprintf('  Folder: %s ', iif(item.folderExists, '✓', '✗'));
    fprintf('(%s)\n', item.installedPath);
    fprintf('  Symbols: %s\n', iif(item.symbolsOk, '✓ Available', '✗ Not found'));
    
    if ~isempty(item.installedRef)
        fprintf('  Git ref: %s\n', item.installedRef);
    end
    
    fprintf('\n');
end

fprintf('Overall status:\n');
fprintf('  All folders present: %s\n', iif(allPresent, '✓ Yes', '✗ No'));
fprintf('  Ready for bct.start: %s\n\n', iif(readyForStart, '✓ Yes', '✗ No'));

if ~readyForStart
    fprintf('To install dependencies, run:\n');
    fprintf('  bct.install.deps\n\n');
end

end

function out = iif(cond, trueVal, falseVal)
    if cond
        out = trueVal;
    else
        out = falseVal;
    end
end
