function configure(root, varargin)
%CONFIGURE Point BCT to an existing dependency installation
%
% Use this to configure BCT to use dependencies installed by a lab admin
% or in a shared location.
%
% Syntax:
%   bct.install.configure(root)
%   bct.install.configure(root, 'addToPath', true)
%
% Inputs:
%   root - Path to directory containing DECLab, gspbox, gptoolbox folders
%
% Name-Value Parameters:
%   'addToPath' - Add to current session path (default: true)
%   'savepath'  - Persist path changes (default: false)
%
% Example:
%   % Point to shared lab installation
%   bct.install.configure('\\server\share\MATLAB_Deps\bct')
%
%   % Configure and save path
%   bct.install.configure('/opt/matlab_deps/bct', 'savepath', true)
%
% See also: bct.install.deps, bct.install.status

% Parse inputs
p = inputParser;
p.addRequired('root', @ischar);
p.addParameter('addToPath', true, @islogical);
p.addParameter('savepath', false, @islogical);
p.parse(root, varargin{:});
opts = p.Results;

% Validate root exists
if ~exist(root, 'dir')
    error('bct:install:RootNotFound', ...
        'Dependency root does not exist: %s', root);
end

% Read manifest to check for expected folders
manifest = bct.install.internal.readManifest();
depNames = fieldnames(manifest);

% Check that expected folders exist
missingFolders = {};
for i = 1:numel(depNames)
    depMeta = manifest.(depNames{i});
    depPath = fullfile(root, depMeta.folder);
    if ~exist(depPath, 'dir')
        missingFolders{end+1} = depMeta.folder; %#ok<AGROW>
    end
end

if ~isempty(missingFolders)
    warning('bct:install:MissingDeps', ...
        'Expected dependency folders not found: %s\nRoot: %s', ...
        strjoin(missingFolders, ', '), root);
end

% Set preference
setpref('bct', 'depsRoot', root);

fprintf('\n✓ BCT dependency root configured:\n');
fprintf('  %s\n\n', root);

% Add to path if requested
if opts.addToPath
    fprintf('Adding dependencies to path...\n');
    
    for i = 1:numel(depNames)
        depMeta = manifest.(depNames{i});
        depPath = fullfile(root, depMeta.folder);
        
        if ~exist(depPath, 'dir')
            continue;
        end
        
        if strcmp(depMeta.folder, 'gptoolbox')
            % gptoolbox: add only mesh subfolder
            meshPath = fullfile(depPath, 'mesh');
            if exist(meshPath, 'dir')
                addpath(genpath(meshPath));
                fprintf('  ✓ %s/mesh\n', depMeta.name);
            end
        else
            % DECLab and GSPBox: add everything
            addpath(genpath(depPath));
            fprintf('  ✓ %s\n', depMeta.name);
        end
    end
    
    % Initialize GSPBox if present
    gspPath = fullfile(root, 'gspbox');
    if exist(gspPath, 'dir') && exist('gsp_start', 'file')
        fprintf('\nInitializing GSPBox...\n');
        try
            gsp_start();
            fprintf('  ✓ GSPBox initialized\n');
        catch ME
            warning('bct:install:GSPStartFailed', ...
                'GSPBox initialization failed: %s', ME.message);
        end
    end
    
    fprintf('\n');
end

% Save path if requested
if opts.savepath
    try
        savepath;
        fprintf('✓ Path changes saved to pathdef.m\n\n');
    catch ME
        warning('bct:install:SavepathFailed', ...
            'Failed to save path: %s', ME.message);
    end
end

fprintf('Configuration complete.\n\n');

end
