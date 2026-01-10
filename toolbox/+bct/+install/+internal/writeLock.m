function writeLock(depsRoot, report)
%WRITELOCK Write installation lock file
%
% Inputs:
%   depsRoot - Dependency root directory
%   report   - Installation report struct

lockPath = fullfile(depsRoot, 'deps.lock.json');

% Build lock data
lockData = struct();
lockData.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
lockData.depsRoot = depsRoot;
lockData.methodUsed = report.methodUsed;
lockData.requestedPin = report.requestedPin;

% Add dependency details
lockData.dependencies = struct();

for i = 1:numel(report.items)
    item = report.items(i);
    
    % Create safe field name
    fieldName = lower(strrep(item.name, ' ', '_'));
    
    lockData.dependencies.(fieldName) = struct(...
        'name', item.name, ...
        'requestedRef', item.requestedRef, ...
        'installedRef', item.installedRef, ...
        'installedPath', item.installedPath);
end

% Get BCT version if available
try
    bctRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    versionFile = fullfile(bctRoot, 'VERSION');
    if exist(versionFile, 'file')
        lockData.bctVersion = strtrim(fileread(versionFile));
    end
catch
    % Version not available
end

% Write JSON
try
    jsonText = jsonencode(lockData);
    
    % Pretty print (MATLAB R2020b+)
    if exist('jsonencode', 'file')
        fid = fopen(lockPath, 'w');
        fprintf(fid, '%s', jsonText);
        fclose(fid);
    end
catch ME
    warning('bct:install:LockWriteFailed', ...
        'Failed to write lock file: %s', ME.message);
end

end
