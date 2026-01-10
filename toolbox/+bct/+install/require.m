function require()
%REQUIRE Validate that required dependencies are available
%
% Fail fast if required dependencies are not installed or not on the path.
% Called by bct.start to ensure the toolbox can function.
%
% Throws:
%   bct:DepsMissing - If any required dependencies are unavailable
%
% Example:
%   try
%       bct.install.require()
%   catch ME
%       if strcmp(ME.identifier, 'bct:DepsMissing')
%           bct.install.deps
%       end
%   end
%
% See also: bct.install.status, bct.install.deps, bct.start

% Read manifest
try
    manifest = bct.install.internal.readManifest();
catch ME
    error('bct:DepsMissing', ...
        'Failed to read dependency manifest: %s\n\nReinstall BCT or check installation integrity.', ...
        ME.message);
end

% Check each dependency
depNames = fieldnames(manifest);
missing = {};
missingSymbols = {};

for i = 1:numel(depNames)
    depMeta = manifest.(depNames{i});
    
    % Check if symbols are available
    symbolsOk = bct.install.internal.detectSymbols(depMeta);
    
    if ~symbolsOk
        missing{end+1} = depMeta.name; %#ok<AGROW>
        missingSymbols{end+1} = strjoin(depMeta.requiredSymbols, ', '); %#ok<AGROW>
    end
end

% If any missing, throw consolidated error
if ~isempty(missing)
    % Try to determine where deps should be
    [depsRoot, rootSource] = bct.install.internal.resolveRoot('');
    
    % Build error message
    msg = sprintf('BCT dependencies are not available.\n\n');
    msg = sprintf('%sMissing dependencies:\n', msg);
    
    for i = 1:numel(missing)
        msg = sprintf('%s  - %s (symbols: %s)\n', msg, missing{i}, missingSymbols{i});
    end
    
    msg = sprintf('%s\nExpected location: %s\n', msg, depsRoot);
    msg = sprintf('%sRoot source: %s\n\n', msg, rootSource);
    
    msg = sprintf('%sTo install dependencies, run:\n', msg);
    msg = sprintf('%s  bct.install.deps\n\n', msg);
    
    msg = sprintf('%sAlternatively, if dependencies are installed elsewhere:\n', msg);
    msg = sprintf('%s  bct.install.configure(''path/to/deps'')\n', msg);
    
    error('bct:DepsMissing', '%s', msg);
end

end
