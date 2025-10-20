function bioctree_start()
% BIOCTREE_START Initialize Bioctree toolbox environment
%
% This function sets up the Bioctree toolbox for spatiotemporal signal processing
% and compression of electrophysiological signals on networks (graphs).
%
% Features initialized:
%   - Graph signal processing (GSP) tools
%   - Compression and subdivision algorithms  
%   - Time-vertex analysis capabilities
%   - Brainstorm integration for MEG/EEG data
%   - GSPBOX foundation for graph operations
%
% Usage:
%   bioctree_start()  % Run from the bioctree root directory

fprintf('=== Initializing Bioctree Toolbox ===\n');

% Get the root directory of the toolbox
bioctree_root = fileparts(mfilename('fullpath'));
if isempty(bioctree_root)
    bioctree_root = pwd;
end

fprintf('Bioctree root: %s\n', bioctree_root);

% Add main toolbox to path
fprintf('Adding Bioctree modules to path...\n');
addpath(bioctree_root);
addpath(genpath(fullfile(bioctree_root, 'compression')));
addpath(genpath(fullfile(bioctree_root, 'gsp')));
addpath(genpath(fullfile(bioctree_root, 'io')));
addpath(genpath(fullfile(bioctree_root, 'plotlib')));
addpath(genpath(fullfile(bioctree_root, 'toolbox')));
addpath(genpath(fullfile(bioctree_root, 'workflows')));

% Initialize GSPBOX
gspbox_path = fullfile(bioctree_root, 'external', 'gspbox');
if exist(gspbox_path, 'dir')
    fprintf('Initializing GSPBOX...\n');
    addpath(genpath(gspbox_path));
    
    try
        gsp_start();
        fprintf('  ✓ GSPBOX initialized successfully\n');
    catch ME
        warning('BIOCTREE:GSPBOXInit', 'Failed to initialize GSPBOX: %s', ME.message);
        fprintf('  ✗ GSPBOX initialization failed\n');
    end
else
    warning('GSPBOX not found at %s', gspbox_path);
    fprintf('  ! Clone GSPBOX: git clone https://github.com/epfl-lts2/gspbox.git external/gspbox\n');
end

% Add external utilities
external_path = fullfile(bioctree_root, 'external');
if exist(external_path, 'dir')
    addpath(external_path);
    fprintf('Added external utilities\n');
end

% Check MATLAB version and toolboxes
fprintf('\nSystem check:\n');
matlab_version = version('-release');
matlab_year = str2double(matlab_version(1:4));
if matlab_year >= 2020
    fprintf('  ✓ MATLAB %s (compatible)\n', matlab_version);
else
    fprintf('  ! MATLAB %s (older version, may have compatibility issues)\n', matlab_version);
end

% Check for recommended toolboxes
recommended_toolboxes = {
    'Signal Processing Toolbox', 'signal'
    'Statistics and Machine Learning Toolbox', 'stats'
    'Image Processing Toolbox', 'images'
};

for i = 1:size(recommended_toolboxes, 1)
    tb_name = recommended_toolboxes{i, 1};
    tb_dir = recommended_toolboxes{i, 2};
    
    if license('test', tb_dir) && ~isempty(ver(tb_dir))
        fprintf('  ✓ %s\n', tb_name);
    else
        fprintf('  - %s (optional)\n', tb_name);
    end
end

% Display available functionality
fprintf('\n=== Available Functionality ===\n');
fprintf('Core modules:\n');
fprintf('  • Graph Signal Processing (gsp/)\n');
fprintf('  • Compression algorithms (compression/)\n');
fprintf('  • Time-vertex analysis (gsp/transforms/, gsp/filters/)\n');
fprintf('  • Brainstorm integration (gsp/io/)\n');
fprintf('  • Visualization tools (plotlib/, gsp/viz/)\n');

fprintf('\nQuick start:\n');
fprintf('  • Demo workflows: run scripts in workflows/\n');
fprintf('  • Test data: explore test-data/ directory\n');
fprintf('  • Run tests: runtests(''tests'')\n');
fprintf('  • Documentation: see COPILOT_INSTRUCTIONS.md\n');

fprintf('\n=== Bioctree ready for use! ===\n\n');

end