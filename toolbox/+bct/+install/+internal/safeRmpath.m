function safeRmpath(depPath)
%SAFERMPATH Safely remove dependency paths from MATLAB path
%
% Only removes paths that are under the specified dependency folder.

% Get all paths under depPath
if exist(depPath, 'dir')
    % Get current path
    currentPath = path;
    
    if ispc
        sep = ';';
    else
        sep = ':';
    end
    
    pathEntries = strsplit(currentPath, sep);
    
    % Find entries that start with depPath
    depPathNorm = fullfile(depPath, '');  % Ensure trailing separator
    
    for i = 1:numel(pathEntries)
        entry = pathEntries{i};
        if ~isempty(entry) && startsWith(entry, depPath)
            try
                rmpath(entry);
            catch
                % Continue on error
            end
        end
    end
end

end
