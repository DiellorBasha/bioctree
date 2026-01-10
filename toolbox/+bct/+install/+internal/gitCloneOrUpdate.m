function installedRef = gitCloneOrUpdate(depMeta, targetPath, requestedRef, update, overwrite, quiet)
%GITCLONEORUPDATE Clone or update a Git repository
%
% Inputs:
%   depMeta      - Dependency metadata from manifest
%   targetPath   - Target installation path
%   requestedRef - 'latest', SHA, or tag
%   update       - Update existing repo
%   overwrite    - Delete and reinstall
%   quiet        - Suppress output

% Check if target exists
exists = exist(targetPath, 'dir') == 7;

if exists && overwrite
    if ~quiet
        fprintf('      Removing existing installation...\n');
    end
    rmdir(targetPath, 's');
    exists = false;
end

if exists && ~update
    % Already exists, skip
    if ~quiet
        fprintf('      Already exists (use update=true or overwrite=true to reinstall)\n');
    end
    installedRef = getCurrentRef(targetPath);
    return;
end

% Clone if doesn't exist
if ~exists
    if ~quiet
        fprintf('      Cloning repository...\n');
    end
    
    % Clone with depth 1 for speed
    cmd = sprintf('git clone --depth 1 "%s" "%s"', depMeta.repo, targetPath);
    [status, result] = system(cmd);
    
    if status ~= 0
        error('bct:install:GitCloneFailed', 'Git clone failed: %s', result);
    end
end

% Fetch and checkout requested ref
if ~strcmp(requestedRef, 'latest')
    if ~quiet
        fprintf('      Checking out ref: %s...\n', requestedRef);
    end
    
    % Unshallow if needed (shallow clones can't fetch specific commits)
    gitDir = fullfile(targetPath, '.git', 'shallow');
    if exist(gitDir, 'file')
        cmd = sprintf('git -C "%s" fetch --unshallow', targetPath);
        system(cmd);
    end
    
    % Fetch specific ref
    cmd = sprintf('git -C "%s" fetch origin %s', targetPath, requestedRef);
    [status, result] = system(cmd);
    
    if status ~= 0
        % Try fetching all refs
        cmd = sprintf('git -C "%s" fetch --all', targetPath);
        [status2, result2] = system(cmd);
        if status2 ~= 0
            error('bct:install:GitFetchFailed', 'Git fetch failed: %s', result);
        end
    end
    
    % Checkout
    cmd = sprintf('git -C "%s" checkout %s', targetPath, requestedRef);
    [status, result] = system(cmd);
    
    if status ~= 0
        error('bct:install:GitCheckoutFailed', 'Git checkout failed: %s', result);
    end
elseif update
    % Pull latest
    if ~quiet
        fprintf('      Pulling latest changes...\n');
    end
    
    cmd = sprintf('git -C "%s" pull', targetPath);
    [status, result] = system(cmd);
    
    if status ~= 0
        warning('bct:install:GitPullFailed', 'Git pull failed: %s', result);
    end
end

% Get installed ref
installedRef = getCurrentRef(targetPath);

end

function ref = getCurrentRef(repoPath)
%GETCURRENTREF Get current Git commit SHA

[status, result] = system(sprintf('git -C "%s" rev-parse HEAD', repoPath));

if status == 0
    ref = strtrim(result);
else
    ref = 'unknown';
end

end
