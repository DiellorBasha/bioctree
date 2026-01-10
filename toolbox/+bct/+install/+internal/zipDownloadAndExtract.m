function installedRef = zipDownloadAndExtract(depMeta, targetPath, requestedRef, overwrite, quiet)
%ZIPDOWNLOADANDEXTRACT Download and extract dependency from ZIP
%
% Inputs:
%   depMeta      - Dependency metadata from manifest
%   targetPath   - Target installation path
%   requestedRef - 'latest', SHA, or tag
%   overwrite    - Delete and reinstall
%   quiet        - Suppress output

% Check if target exists
exists = exist(targetPath, 'dir') == 7;

if exists && ~overwrite
    if ~quiet
        fprintf('      Already exists (use overwrite=true to reinstall)\n');
    end
    installedRef = requestedRef;  % Can't determine actual ref from zip
    return;
end

if exists && overwrite
    if ~quiet
        fprintf('      Removing existing installation...\n');
    end
    rmdir(targetPath, 's');
end

% Construct download URL
zipMeta = depMeta.zip;

if strcmp(requestedRef, 'latest')
    % Use default branch
    url = sprintf('https://github.com/%s/%s/archive/refs/heads/%s.zip', ...
        zipMeta.owner, zipMeta.repo, zipMeta.defaultBranch);
    installedRef = sprintf('latest (%s)', zipMeta.defaultBranch);
else
    % Use specific ref
    url = sprintf('https://github.com/%s/%s/archive/%s.zip', ...
        zipMeta.owner, zipMeta.repo, requestedRef);
    installedRef = requestedRef;
end

if ~quiet
    fprintf('      Downloading from GitHub...\n');
    fprintf('      URL: %s\n', url);
end

% Download to temporary file
tempDir = tempname;
mkdir(tempDir);
zipFile = fullfile(tempDir, 'dep.zip');

try
    % Download
    websave(zipFile, url);
    
    if ~quiet
        fprintf('      Extracting...\n');
    end
    
    % Extract
    unzip(zipFile, tempDir);
    
    % Find extracted folder (GitHub zips create folder named repo-ref)
    contents = dir(tempDir);
    contents = contents(~ismember({contents.name}, {'.', '..', 'dep.zip'}));
    extractedFolders = contents([contents.isdir]);
    
    if isempty(extractedFolders)
        error('bct:install:NoExtractedFolder', 'No folder found in ZIP archive');
    end
    
    % Move extracted folder to target
    extractedPath = fullfile(tempDir, extractedFolders(1).name);
    [success, msg] = movefile(extractedPath, targetPath);
    
    if ~success
        error('bct:install:MoveFailed', 'Failed to move extracted folder: %s', msg);
    end
    
    % Clean up
    rmdir(tempDir, 's');
    
catch ME
    % Clean up on error
    if exist(tempDir, 'dir')
        rmdir(tempDir, 's');
    end
    
    rethrow(ME);
end

end
