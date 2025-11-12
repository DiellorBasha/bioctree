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
    fprintf('GSPBOX not found. Attempting to clone from GitHub...\n');
    external_dir = fullfile(bioctree_root, 'external');
    if ~exist(external_dir, 'dir')
        mkdir(external_dir);
    end
    
    % Change to external directory and clone GSPBOX
    current_dir = pwd;
    try
        cd(external_dir);
        fprintf('  Cloning GSPBOX from https://github.com/epfl-lts2/gspbox.git...\n');
        [status, cmdout] = system('git clone https://github.com/epfl-lts2/gspbox.git gspbox');
        
        if status == 0
            fprintf('  ✓ GSPBOX cloned successfully\n');
            
            % Add to path and initialize
            addpath(genpath(gspbox_path));
            try
                gsp_start();
                fprintf('  ✓ GSPBOX initialized successfully\n');
            catch ME
                warning('BIOCTREE:GSPBOXInit', 'Failed to initialize GSPBOX: %s', ME.message);
                fprintf('  ✗ GSPBOX initialization failed\n');
            end
        else
            warning('BIOCTREE:GSPBOXClone', 'Failed to clone GSPBOX:\n%s', cmdout);
            fprintf('  ✗ GSPBOX clone failed. Please manually clone:\n');
            fprintf('    git clone https://github.com/epfl-lts2/gspbox.git external/gspbox\n');
        end
    catch ME
        warning('BIOCTREE:GSPBOXSetup', 'Error during GSPBOX setup: %s', ME.message);
    end
    cd(current_dir);
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

% Initialize Bioctree data management system
fprintf('\n=== Initializing Bioctree Data System ===\n');
try
    bioctree_init('Verbose', false);
    fprintf('✓ Data system initialized\n');
    
    % Display data configuration
    config = bioctree_config('all');
    fprintf('Data location: %s\n', config.DataPath);
catch ME
    fprintf('⚠ Data system initialization failed: %s\n', ME.message);
    fprintf('  You can initialize manually with: bioctree_init()\n');
end

% Ensure BCT class package is on path
addpath(fullfile(bioctree_root,'toolbox'));  % brings +bct package into scope
addpath(fullfile(bioctree_root,'workflows'), fullfile(bioctree_root,'io'), ...
        fullfile(bioctree_root,'plotlib'), fullfile(bioctree_root,'demo'), ...
        fullfile(bioctree_root,'tests'), fullfile(bioctree_root,'db'));

% Verify BCT class availability
if exist('bct.bct', 'class')
    fprintf('[bioctree] ✓ BCT class system available\n');
else
    fprintf('[bioctree] ⚠ BCT class system not found\n');
end

fprintf('[bioctree] Paths added. Data root: %s\n', fullfile(bioctree_root,'data'));


% Display available functionality
fprintf('\n=== Available Functionality ===\n');
fprintf('BCT Object-Oriented Data Engine:\n');
fprintf('  • bct.create() - Create new BCT files with schema validation\n');
fprintf('  • bct.open() - Open existing BCT files with automatic validation\n');
fprintf('  • Multi-layer signals, time-frequency analysis, hyperslab queries\n');
fprintf('  • bioctree_config() - Configure data paths and system settings\n');
fprintf('  • db_data_info() - System status and cleanup operations\n');
fprintf('\nLegacy I/O Functions (being phased out):\n');
fprintf('  • outbct() - Export analysis results (use bct.create() + write methods)\n');
fprintf('  • inbct() - Load data (use bct.open() + read methods)\n');

fprintf('\nCore Analysis Modules:\n');
fprintf('  • Graph Signal Processing (toolbox/graphs/, toolbox/operators/)\n');
fprintf('  • Compression algorithms (compression/)\n');
fprintf('  • Spatiotemporal analysis (toolbox/frequency/, toolbox/simulations/)\n');
fprintf('  • Brainstorm integration (io/)\n');
fprintf('  • Visualization tools (plotlib/)\n');

fprintf('\nQuick start with BCT Class:\n');
fprintf('  • Create: obj = bct.create(''my_dataset'')\n');
fprintf('  • Write: obj.write_raw(signal_data, sampling_rate)\n');
fprintf('  • Read: obj = bct.open(''dataset.h5''); data = obj.read_raw()''\n');
fprintf('  • Try demo: demo_bioctree_hdf5\n');
fprintf('  • Explore workflows: scripts in workflows/\n');
fprintf('  • Configure system: bioctree_config()\n');
fprintf('  • Documentation: see COPILOT_INSTRUCTIONS.md\n');

fprintf('\n=== Bioctree ready for spatiotemporal graph analysis! ===\n\n');

end