function setup()
% SETUP Initialize MEG-GSP toolbox environment
% 
% This script adds necessary paths and checks dependencies for the MEG-GSP
% toolbox. Run this after installation to set up the environment.
%
% Usage:
%   setup()  % Run from the meg-gsp-toolbox root directory

% Get the root directory of the toolbox
toolbox_root = fileparts(mfilename('fullpath'));

% Add main package to path
addpath(toolbox_root);

% Add external dependencies
gspbox_path = fullfile(toolbox_root, 'external', 'gspbox');
if exist(gspbox_path, 'dir')
    fprintf('Adding GSPBOX to path: %s\n', gspbox_path);
    addpath(genpath(gspbox_path));
    
    % Initialize GSPBOX
    try
        gsp_start();
        fprintf('GSPBOX initialized successfully.\n');
    catch ME
        warning('Failed to initialize GSPBOX: %s', ME.message);
    end
else
    warning('GSPBOX not found. Please initialize the git submodule:\n  git submodule update --init --recursive');
end

% Add thirdparty tools if available
thirdparty_path = fullfile(toolbox_root, 'external', '+thirdparty');
if exist(thirdparty_path, 'dir')
    addpath(genpath(thirdparty_path));
    fprintf('Added thirdparty tools to path.\n');
end

% Check MATLAB version
matlab_version = version('-release');
matlab_year = str2double(matlab_version(1:4));
if matlab_year < 2022
    warning('MEG-GSP toolbox requires MATLAB R2022b or later. Current version: %s', matlab_version);
end

% Check for required toolboxes
required_toolboxes = {
    'Signal Processing Toolbox', 'signal'
    'Statistics and Machine Learning Toolbox', 'stats'
};

fprintf('\nChecking for required toolboxes:\n');
for i = 1:size(required_toolboxes, 1)
    tb_name = required_toolboxes{i, 1};
    tb_dir = required_toolboxes{i, 2};
    
    if license('test', tb_dir) && ~isempty(ver(tb_dir))
        fprintf('  ✓ %s\n', tb_name);
    else
        fprintf('  ✗ %s (optional but recommended)\n', tb_name);
    end
end

% Save path for future MATLAB sessions
fprintf('\nSetup complete! Consider saving the path for future sessions:\n');
fprintf('  savepath\n\n');

fprintf('Run the following to test the installation:\n');
fprintf('  run scripts/demo_alphaband_analysis.m\n');

end