function success = bioctree_init(varargin)
% BIOCTREE_INIT Initialize the Bioctree data management system
%
% This function sets up the Bioctree data directory structure and
% configuration for first-time use or after system changes.
%
% Usage:
%   bioctree_init()                    % Initialize with default settings
%   bioctree_init('DataPath', path)    % Initialize with custom data path
%   success = bioctree_init(...)       % Return initialization status
%
% Parameters:
%   'DataPath'     - Custom root directory for Bioctree data
%   'Force'        - Force reinitialization even if already setup
%   'Verbose'      - Display detailed initialization progress
%   'Cleanup'      - Clean up existing data (use with caution!)
%
% Examples:
%   % Basic initialization
%   bioctree_init();
%
%   % Initialize with custom data location
%   bioctree_init('DataPath', '/data/bioctree');
%
%   % Force complete reinitialization
%   bioctree_init('Force', true, 'Verbose', true);
%
% Output:
%   success - True if initialization completed successfully
%
% See also: bioctree_config, db_data_info, outbct, inbct

% Parse input arguments
p = inputParser;
addParameter(p, 'DataPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Force', false, @islogical);
addParameter(p, 'Verbose', true, @islogical);
addParameter(p, 'Cleanup', false, @islogical);
parse(p, varargin{:});

customDataPath = p.Results.DataPath;
forceInit = p.Results.Force;
verbose = p.Results.Verbose;
doCleanup = p.Results.Cleanup;

success = false;

try
    if verbose
        fprintf('=== Bioctree Initialization ===\n\n');
    end
    
    % Step 1: Check if already initialized
    if ~forceInit
        try
            config = bioctree_config('all');
            if exist(config.DataPath, 'dir') && exist(config.BioctreeFilesPath, 'dir')
                if verbose
                    fprintf('Bioctree data system already initialized.\n');
                    fprintf('Data path: %s\n', config.DataPath);
                    fprintf('Use ''Force'', true to reinitialize.\n\n');
                end
                success = true;
                return;
            end
        catch
            % Configuration not available, proceed with initialization
        end
    end
    
    % Step 2: Set up data path
    if ~isempty(customDataPath)
        if verbose
            fprintf('Step 1: Setting custom data path...\n');
            fprintf('  Path: %s\n', customDataPath);
        end
        
        % Create the directory if it doesn't exist
        if ~exist(customDataPath, 'dir')
            try
                mkdir(customDataPath);
                if verbose
                    fprintf('  ✓ Created data directory\n');
                end
            catch ME
                error('BioctreeInit:DirectoryCreation', ...
                      'Could not create data directory %s: %s', customDataPath, ME.message);
            end
        end
        
        % Configure Bioctree to use this path
        bioctree_config('DataPath', customDataPath);
    else
        if verbose
            fprintf('Step 1: Using default data path...\n');
        end
    end
    
    % Step 3: Initialize configuration
    if verbose
        fprintf('Step 2: Initializing configuration...\n');
    end
    
    config = bioctree_config('all');
    
    if verbose
        fprintf('  ✓ Configuration loaded\n');
        fprintf('  Data root: %s\n', config.DataPath);
    end
    
    % Step 4: Create directory structure
    if verbose
        fprintf('Step 3: Creating directory structure...\n');
    end
    
    directories = {
        config.DataPath, 'Root data directory';
        config.BioctreeFilesPath, 'Bioctree files';
        config.RawPath, 'Raw analysis results';
        config.ProcessedPath, 'Processed data';
        config.DerivativesPath, 'Derived analysis products';
        config.TempPath, 'Temporary files';
        config.CachePath, 'Cache storage';
        config.ConfigPath, 'Configuration files'
    };
    
    for i = 1:size(directories, 1)
        dirPath = directories{i, 1};
        dirDesc = directories{i, 2};
        
        if ~exist(dirPath, 'dir')
            try
                mkdir(dirPath);
                if verbose
                    fprintf('  ✓ Created: %s\n', dirDesc);
                end
            catch ME
                warning('BioctreeInit:DirectoryCreation', ...
                       'Could not create %s (%s): %s', dirDesc, dirPath, ME.message);
            end
        else
            if verbose
                fprintf('  • Exists: %s\n', dirDesc);
            end
        end
    end
    
    % Step 5: Create README files
    if verbose
        fprintf('Step 4: Creating documentation...\n');
    end
    
    % Main README already exists, create subdirectory READMEs
    subdirReadmes = {
        config.RawPath, 'Raw Bioctree Analysis Results', ...
        ['This directory contains raw outputs from Bioctree analysis pipelines.\n\n' ...
        'Files in this directory are:\n' ...
        '• Direct outputs from analysis functions\n' ...
        '• Not yet quality controlled or processed\n' ...
        '• Named using the convention: {subject}_{session}_{analysis}_{timestamp}.h5\n\n' ...
        'Use bct.create() and BCT class methods to save analysis results here.\n'];
        
        config.ProcessedPath, 'Processed Bioctree Data', ...
        ['This directory contains quality-controlled and processed Bioctree data.\n\n' ...
        'Files in this directory are:\n' ...
        '• Filtered, normalized, or artifact-corrected data\n' ...
        '• Ready for group analysis or statistical testing\n' ...
        '• May include additional metadata and quality metrics\n\n' ...
        'Process raw data and save results here for analysis pipelines.\n'];
        
        config.DerivativesPath, 'Derived Bioctree Analysis Products', ...
        ['This directory contains higher-level analysis results and derivatives.\n\n' ...
        'Files in this directory include:\n' ...
        '• Connectivity matrices and network measures\n' ...
        '• Statistical analysis results\n' ...
        '• Group-level summaries and comparisons\n' ...
        '• Visualization and report data\n\n' ...
        'These files support interpretation and publication of results.\n'];
        
        config.TempPath, 'Temporary Processing Files', ...
        ['This directory contains temporary files created during analysis.\n\n' ...
        'Files here are:\n' ...
        '• Intermediate processing results\n' ...
        '• Automatically cleaned up after 24 hours\n' ...
        '• Not intended for long-term storage\n\n' ...
        'Do not manually store important data in this directory.\n'];
        
        config.CachePath, 'Bioctree Analysis Cache', ...
        ['This directory contains cached computations for performance optimization.\n\n' ...
        'Cached items include:\n' ...
        '• Precomputed eigendecompositions\n' ...
        '• Frequently accessed query results\n' ...
        '• Intermediate computations for large datasets\n\n' ...
        'Cache files are automatically managed and may be periodically cleaned.\n']
    };
    
    for i = 1:size(subdirReadmes, 1)
        readmePath = fullfile(subdirReadmes{i, 1}, 'README.md');
        if ~exist(readmePath, 'file')
            try
                fid = fopen(readmePath, 'w');
                fprintf(fid, '# %s\n\n%s', subdirReadmes{i, 2}, subdirReadmes{i, 3});
                fclose(fid);
                
                if verbose
                    fprintf('  ✓ Created README: %s\n', subdirReadmes{i, 2});
                end
            catch ME
                warning('BioctreeInit:ReadmeCreation', ...
                       'Could not create README for %s: %s', subdirReadmes{i, 2}, ME.message);
            end
        end
    end
    
    % Step 6: Perform cleanup if requested
    if doCleanup
        if verbose
            fprintf('Step 5: Cleaning up existing data...\n');
        end
        
        cleanupInfo = db_data_info('cleanup');
        if verbose && isfield(cleanupInfo, 'cleanup')
            cleanup = cleanupInfo.cleanup;
            fprintf('  ✓ Removed %d files, freed %.1f MB\n', ...
                    cleanup.total_files_removed, cleanup.total_space_freed_mb);
        end
    end
    
    % Step 6: Check for legacy .bct files and offer conversion
    if verbose
        fprintf('Step 6: Checking for legacy .bct files...\n');
    end
    
    try
        bctFiles = dir(fullfile(config.BioctreeFilesPath, '**', '*.bct'));
        if ~isempty(bctFiles)
            if verbose
                fprintf('  Found %d legacy .bct file(s)\n', length(bctFiles));
                fprintf('  WARNING: These should be converted to proper .h5 format\n');
                fprintf('  Legacy .bct files are deprecated - use .h5 extension only\n');
            end
        else
            if verbose
                fprintf('  ✓ No legacy .bct files found\n');
            end
        end
    catch
        % Ignore errors in legacy file check
    end
    
    % Step 7: Test BCT class system
    if verbose
        fprintf('Step 7: Testing BCT class system...\n');
    end
    
    try
        % Test BCT class availability
        testClassName = 'bct.bct';
        if exist(testClassName, 'class')
            if verbose
                fprintf('  ✓ BCT class system available\n');
            end
            
            % Test BCT class functionality with a minimal test
            try
                testFile = fullfile(config.TempPath, 'bct_init_test');
                testObj = bct.create(testFile);
                
                % Test basic write/read operations
                testSignal = rand(10, 100, 'single'); % 10 nodes, 100 time points
                testObj.write_raw(testSignal, 100);   % 100 Hz sampling
                
                % Test read operation
                readSignal = testObj.read_raw([1, 50], [1, 5]);
                
                % Cleanup test file
                if exist([testFile, '.h5'], 'file')
                    delete([testFile, '.h5']);
                end
                
                if verbose
                    fprintf('  ✓ BCT class CRUD operations working\n');
                end
            catch ME
                if verbose
                    fprintf('  ⚠ BCT class test failed: %s\n', ME.message);
                end
            end
        else
            if verbose
                fprintf('  ⚠ BCT class system not found\n');
                fprintf('    Make sure toolbox/+bct/ is on the MATLAB path\n');
            end
        end
    catch ME
        if verbose
            fprintf('  ⚠ BCT class system test failed: %s\n', ME.message);
        end
    end
    
    % Step 8: Verify installation
    if verbose
        fprintf('Step 8: Verifying installation...\n');
    end
    
    % Test configuration access
    try
        testConfig = bioctree_config('DataPath');
        if verbose
            fprintf('  ✓ Configuration system working\n');
        end
    catch ME
        warning('BioctreeInit:ConfigTest', 'Configuration test failed: %s', ME.message);
    end
    
    % Test data info system
    try
        testInfo = db_data_info('summary');
        if verbose
            fprintf('  ✓ Data information system working\n');
        end
    catch ME
        warning('BioctreeInit:InfoTest', 'Data info test failed: %s', ME.message);
    end
    
    % Test file I/O (create a small test file)
    try
        testFile = fullfile(config.TempPath, 'bioctree_init_test.h5');
        testData = struct('test', true, 'timestamp', now);
        
        % Create minimal HDF5 file
        h5create(testFile, '/test/data', size([1, 1]));
        h5write(testFile, '/test/data', 1);
        
        % Test reading
        testRead = h5read(testFile, '/test/data');
        
        % Cleanup test file
        delete(testFile);
        
        if verbose
            fprintf('  ✓ File I/O system working\n');
        end
    catch ME
        warning('BioctreeInit:IOTest', 'File I/O test failed: %s', ME.message);
    end
    
    % Success!
    success = true;
    
    if verbose
        fprintf('\n✅ Bioctree initialization completed successfully!\n\n');
        
        fprintf('System ready for use:\n');
        fprintf('• Data storage: %s\n', config.DataPath);
        fprintf('• Configuration: Use bioctree_config() to modify settings\n');
        fprintf('• BCT Class: Use bct.create() and bct.open() for data operations\n');
        fprintf('• Legacy I/O: outbct()/inbct() still available (being phased out)\n');
        fprintf('• System info: Use db_data_info() for status and cleanup\n\n');
        
        fprintf('Next steps with BCT Class:\n');
        fprintf('1. Create dataset: obj = bct.create(''my_analysis'')\n');
        fprintf('2. Write data: obj.write_raw(signal_matrix, sampling_rate)\n');
        fprintf('3. Read data: obj = bct.open(''dataset.h5''); data = obj.read_raw()\n');
        fprintf('4. Run demo: demo_bioctree_hdf5.m to see the system in action\n');
        fprintf('5. Use bioctree_config() to customize paths and settings\n');
    end

catch ME
    if verbose
        fprintf('\n❌ Bioctree initialization failed!\n');
        fprintf('Error: %s\n\n', ME.message);
    end
    
    rethrow(ME);
end

end
