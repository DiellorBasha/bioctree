function manifest = deps()
%DEPS Load BCT dependencies manifest
%
% Returns the parsed deps.json manifest with pinned dependency information.
% This is the authoritative source for dependency metadata used by bct.install.
%
% Returns:
%   manifest - Struct with dependency specifications
%              Each dependency has: name, repo, folder, ref, requiredSymbols, zip
%
% Example:
%   manifest = bct.config.deps();
%   depNames = fieldnames(manifest);
%
% See also: bct.install.deps, bct.config.load

% Locate data directory relative to this function
thisFile = mfilename('fullpath');
configDir = fileparts(thisFile);
dataDir = fullfile(configDir, 'data');
depsFile = fullfile(dataDir, 'deps.json');

% Read and parse
manifest = bct.config.internal.readJson(depsFile);

end
