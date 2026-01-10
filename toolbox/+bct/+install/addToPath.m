function addToPath(cfg)
%ADDTOPATH Add dependencies to MATLAB path (no downloads)
%
% Called by bct.start to add dependency paths for the current session.
% Does not download or install anything.
%
% Syntax:
%   bct.install.addToPath(cfg)
%
% Inputs:
%   cfg - BCT configuration struct from bct.config.load
%
% Root Resolution Precedence:
%   1. Environment variable BCT_DEPS_ROOT
%   2. MATLAB preference 'bct'/'depsRoot'
%   3. cfg.external (developer fallback)
%   4. Default <userpath>/ThirdParty/bct (no creation)
%
% See also: bct.install.require, bct.start

% Resolve root using precedence
depsRoot = '';

% 1. Environment variable
envRoot = getenv('BCT_DEPS_ROOT');
if ~isempty(envRoot) && exist(envRoot, 'dir')
    depsRoot = envRoot;
end

% 2. Preference
if isempty(depsRoot) && ispref('bct', 'depsRoot')
    prefRoot = getpref('bct', 'depsRoot');
    if ~isempty(prefRoot) && exist(prefRoot, 'dir')
        depsRoot = prefRoot;
    end
end

% 3. Developer fallback (cfg.external)
if isempty(depsRoot) && nargin > 0 && isfield(cfg, 'external')
    if exist(cfg.external, 'dir')
        depsRoot = cfg.external;
    end
end

% 4. Default userpath location (don't create)
if isempty(depsRoot)
    try
        up = bct.install.internal.normalizeUserpath();
        defaultRoot = fullfile(up, 'ThirdParty', 'bct');
        if exist(defaultRoot, 'dir')
            depsRoot = defaultRoot;
        end
    catch
        % Userpath not available
    end
end

% If no root found, return silently (require() will catch this)
if isempty(depsRoot)
    return;
end

% Read manifest
try
    manifest = bct.install.internal.readManifest();
catch
    % Manifest not available (shouldn't happen in packaged toolbox)
    return;
end

% Add each dependency to path
depNames = fieldnames(manifest);

for i = 1:numel(depNames)
    depMeta = manifest.(depNames{i});
    depPath = fullfile(depsRoot, depMeta.folder);
    
    if ~exist(depPath, 'dir')
        continue;
    end
    
    try
        if strcmp(depMeta.folder, 'gptoolbox')
            % gptoolbox: add only mesh subfolder
            meshPath = fullfile(depPath, 'mesh');
            if exist(meshPath, 'dir')
                addpath(genpath(meshPath));
            end
        else
            % DECLab and GSPBox: add everything
            addpath(genpath(depPath));
        end
    catch
        % Path add failed, continue
    end
end

% Initialize GSPBox if present
gspPath = fullfile(depsRoot, 'gspbox');
if exist(gspPath, 'dir') && exist('gsp_start', 'file')
    try
        gsp_start();
    catch
        % GSPBox init failed, continue (require will catch)
    end
end

end
