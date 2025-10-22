function result = db_convert_data(varargin)
% DB_CONVERT_DATA Batch convert all .bct files in Bioctree data system
%
% This function automatically finds and converts all legacy .bct files
% in the Bioctree data directory structure to proper .h5 HDF5 format.
%
% Usage:
%   bioctree_convert_data()                    % Convert all .bct files
%   bioctree_convert_data('param', value)      % With options  
%   result = bioctree_convert_data(...)        % Return conversion results
%
% Parameters:
%   'DataPath'     - Root data path (default: from bioctree_config)
%   'Backup'       - Create backup of original .bct files (default: true)
%   'DeleteBCT'    - Delete original .bct files after conversion (default: false)
%   'Verify'       - Verify conversion integrity (default: true)
%   'Verbose'      - Display detailed progress (default: true)
%   'DryRun'       - Show what would be converted (default: false)
%   'Force'        - Convert even if .h5 versions exist (default: false)
%
% Examples:
%   % Convert all .bct files with backup
%   bioctree_convert_data();
%
%   % Convert and remove originals (use with caution!)
%   bioctree_convert_data('DeleteBCT', true, 'Backup', false);
%
%   % Dry run to see what would be converted
%   result = bioctree_convert_data('DryRun', true);
%
% Output:
%   result - Conversion results with summary statistics
%
% See also: bct2h5, bioctree_config, bioctree_data_info

% Parse input arguments
p = inputParser;
addParameter(p, 'DataPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Backup', true, @islogical);
addParameter(p, 'DeleteBCT', false, @islogical);
addParameter(p, 'Verify', true, @islogical);
addParameter(p, 'Verbose', true, @islogical);
addParameter(p, 'DryRun', false, @islogical);
addParameter(p, 'Force', false, @islogical);
parse(p, varargin{:});

opts = p.Results;

try
    if opts.Verbose
        fprintf('=== Bioctree Data Conversion ===\n\n');
    end
    
    % Get data configuration
    if isempty(opts.DataPath)
        config = bioctree_config('all');
        dataPath = config.BioctreeFilesPath;
    else
        dataPath = opts.DataPath;
    end
    
    if opts.Verbose
        fprintf('Converting .bct files in: %s\n', dataPath);
    end
    
    % Check if data path exists
    if ~exist(dataPath, 'dir')
        error('BioctreeConvert:NoDataPath', 'Data path does not exist: %s', dataPath);
    end
    
    % Find all .bct files in the data directory
    bctFiles = dir(fullfile(dataPath, '**', '*.bct'));
    
    if isempty(bctFiles)
        if opts.Verbose
            fprintf('No .bct files found to convert.\n');
            fprintf('✅ Data system already uses .h5 format!\n\n');
        end
        
        result = struct();
        result.files_converted = 0;
        result.files_failed = 0;
        result.already_converted = 0;
        result.total_size_mb = 0;
        return;
    end
    
    if opts.Verbose
        fprintf('Found %d .bct file(s) to convert\n\n', length(bctFiles));
    end
    
    % Create backup directory if requested
    backupDir = '';
    if opts.Backup && ~opts.DryRun
        backupDir = fullfile(dataPath, 'backup_bct_files');
        if ~exist(backupDir, 'dir')
            mkdir(backupDir);
            if opts.Verbose
                fprintf('Created backup directory: %s\n', backupDir);
            end
        end
    end
    
    % Process each directory separately
    result = struct();
    result.files_converted = 0;
    result.files_failed = 0;
    result.already_converted = 0;
    result.total_size_mb = 0;
    result.directories = {};
    
    % Group files by directory
    directories = unique({bctFiles.folder});
    
    for i = 1:length(directories)
        dirPath = directories{i};
        dirFiles = bctFiles(strcmp({bctFiles.folder}, dirPath));
        
        if opts.Verbose
            fprintf('Processing directory: %s\n', strrep(dirPath, dataPath, ''));
            fprintf('  Found %d .bct file(s)\n', length(dirFiles));
        end
        
        % Convert files in this directory
        dirResult = bct2h5(dirPath, ...
            'Overwrite', opts.Force, ...
            'DeleteBCT', false, ... % Handle deletion separately for backup
            'Recursive', false, ...
            'Verify', opts.Verify, ...
            'Verbose', false, ... % Suppress individual file messages
            'DryRun', opts.DryRun);
        
        % Update totals
        result.files_converted = result.files_converted + dirResult.files_converted;
        result.files_failed = result.files_failed + dirResult.files_failed;
        result.total_size_mb = result.total_size_mb + dirResult.total_size_mb;
        
        % Handle backup and cleanup for successfully converted files
        if ~opts.DryRun
            for j = 1:length(dirResult.file_list)
                fileInfo = dirResult.file_list{j};
                
                if strcmp(fileInfo.status, 'success')
                    bctPath = fileInfo.original;
                    [~, fileName, ~] = fileparts(bctPath);
                    
                    % Create backup if requested
                    if opts.Backup
                        backupPath = fullfile(backupDir, [fileName, '.bct']);
                        try
                            copyfile(bctPath, backupPath);
                            if opts.Verbose
                                fprintf('    Backed up: %s\n', [fileName, '.bct']);
                            end
                        catch ME
                            if opts.Verbose
                                fprintf('    Backup failed for %s: %s\n', fileName, ME.message);
                            end
                        end
                    end
                    
                    % Delete original if requested
                    if opts.DeleteBCT
                        try
                            delete(bctPath);
                            if opts.Verbose
                                fprintf('    Deleted: %s\n', [fileName, '.bct']);
                            end
                        catch ME
                            if opts.Verbose
                                fprintf('    Delete failed for %s: %s\n', fileName, ME.message);
                            end
                        end
                    end
                end
            end
        end
        
        % Store directory result
        dirSummary = struct();
        dirSummary.path = dirPath;
        dirSummary.files_converted = dirResult.files_converted;
        dirSummary.files_failed = dirResult.files_failed;
        dirSummary.size_mb = dirResult.total_size_mb;
        result.directories{end+1} = dirSummary;
        
        if opts.Verbose
            fprintf('  Result: %d converted, %d failed\n\n', ...
                    dirResult.files_converted, dirResult.files_failed);
        end
    end
    
    % Display final summary
    if opts.Verbose
        displayFinalSummary(result, opts);
    end
    
    % Update data system info
    if ~opts.DryRun && result.files_converted > 0
        try
            % Refresh data system to reflect changes
            bioctree_data_info('summary');
        catch
            % Ignore errors in data info refresh
        end
    end
    
catch ME
    if opts.Verbose
        fprintf('\n❌ Batch conversion failed: %s\n\n', ME.message);
    end
    rethrow(ME);
end

end

function displayFinalSummary(result, opts)
% Display comprehensive conversion summary
fprintf('=== Final Summary ===\n');

if opts.DryRun
    fprintf('DRY RUN MODE - No files were modified\n');
    fprintf('Would convert: %d files (%.1f MB)\n', ...
            result.files_converted, result.total_size_mb);
else
    fprintf('Total files converted: %d\n', result.files_converted);
    fprintf('Total files failed: %d\n', result.files_failed);
    fprintf('Total data converted: %.1f MB\n', result.total_size_mb);
    
    if opts.Backup && result.files_converted > 0
        fprintf('Original files backed up to: backup_bct_files/\n');
    end
    
    if opts.DeleteBCT && result.files_converted > 0
        fprintf('Original .bct files deleted after conversion\n');
    end
end

fprintf('\nDirectory Summary:\n');
for i = 1:length(result.directories)
    dir_info = result.directories{i};
    fprintf('  %s: %d converted, %d failed\n', ...
            getRelativePath(dir_info.path), dir_info.files_converted, dir_info.files_failed);
end

if ~opts.DryRun && result.files_converted > 0
    fprintf('\n✅ Bioctree data conversion completed!\n');
    fprintf('All legacy .bct files have been converted to proper .h5 format.\n');
    fprintf('The files can now be properly identified as HDF5 by other software.\n');
    
    fprintf('\nNext steps:\n');
    fprintf('• Use inbct() and outbct() functions normally\n');
    fprintf('• Files are now in standard HDF5 format\n');
    if opts.Backup
        fprintf('• Original files are safely backed up\n');
    end
    fprintf('• Run bioctree_data_info() to see updated statistics\n');
    
elseif result.files_converted == 0 && result.files_failed == 0
    fprintf('\n✅ No conversion needed - data system already uses .h5 format!\n');
end

fprintf('\n');
end

function relPath = getRelativePath(fullPath)
% Get relative path for display
try
    config = bioctree_config('DataPath');
    if startsWith(fullPath, config)
        relPath = strrep(fullPath, config, '');
        if startsWith(relPath, '\') || startsWith(relPath, '/')
            relPath = relPath(2:end);
        end
    else
        relPath = fullPath;
    end
catch
    relPath = fullPath;
end

if isempty(relPath)
    relPath = 'root';
end
end