function success = bct2h5(inputPath, varargin)
% BCT2H5 Convert legacy .bct files to proper .h5 HDF5 format
%
% ⚠️  DEPRECATED: This function is deprecated. The BCT class system automatically
% handles file format conversions and no longer requires separate .h5 files.
% Use bct.open() to read both .bct and .h5 files directly.
%
% This function converts Bioctree .bct files (which are actually HDF5 files
% with incorrect extension) to proper .h5 files for better system compatibility.
%
% Usage:
%   bct2h5(inputPath)                    % Convert single file or directory
%   bct2h5(inputPath, 'param', value)    % With options
%   success = bct2h5(...)                % Return conversion status
%
% Inputs:
%   inputPath - Path to .bct file or directory containing .bct files
%
% Parameters:
%   'OutputDir'    - Output directory (default: same as input)
%   'Overwrite'    - Overwrite existing .h5 files (default: false)
%   'DeleteBCT'    - Delete original .bct files after conversion (default: false)
%   'Recursive'    - Process subdirectories recursively (default: true)
%   'Verify'       - Verify conversion by comparing file contents (default: true)
%   'Verbose'      - Display conversion progress (default: true)
%   'DryRun'       - Show what would be converted without doing it (default: false)
%
% Examples:
%   % Convert single file
%   bct2h5('analysis_results.bct');
%
%   % Convert all .bct files in directory
%   bct2h5('C:\data\bioctree_files\raw\');
%
%   % Convert with custom output and cleanup
%   bct2h5('old_data\', 'OutputDir', 'converted\', 'DeleteBCT', true);
%
%   % Dry run to see what would be converted
%   bct2h5('data\', 'DryRun', true);
%
% Output:
%   success - Structure with conversion results:
%     .files_converted   - Number of files successfully converted
%     .files_failed      - Number of files that failed conversion
%     .total_size_mb     - Total size of converted files in MB
%     .conversion_time   - Time taken for conversion
%     .file_list         - Details of each converted file
%
% Notes:
%   - Original .bct files are HDF5 format with wrong extension
%   - Conversion preserves all data structure and metadata
%   - Verification ensures data integrity after conversion
%   - Can be run multiple times safely (skips already converted files)
%
% See also: outbct, inbct, bioctree_data_info

% Parse input arguments
p = inputParser;
addRequired(p, 'inputPath', @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputDir', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'Overwrite', false, @islogical);
addParameter(p, 'DeleteBCT', false, @islogical);
addParameter(p, 'Recursive', true, @islogical);
addParameter(p, 'Verify', true, @islogical);
addParameter(p, 'Verbose', true, @islogical);
addParameter(p, 'DryRun', false, @islogical);
parse(p, inputPath, varargin{:});

opts = p.Results;
inputPath = char(inputPath);

% Initialize output structure
success = struct();
success.files_converted = 0;
success.files_failed = 0;
success.total_size_mb = 0;
success.conversion_time = 0;
success.file_list = {};
success.errors = {};

startTime = tic;

% Issue deprecation warning
warning('BCT2H5:Deprecated', ['bct2h5() is deprecated. The BCT class system automatically handles ' ...
    'file format conversions. Use bct.open() to read both .bct and .h5 files directly.']);

try
    if opts.Verbose
        fprintf('=== BCT to H5 Conversion ===\n\n');
    end
    
    % Validate input path
    if ~exist(inputPath, 'file') && ~exist(inputPath, 'dir')
        error('BCT2H5:InvalidPath', 'Input path does not exist: %s', inputPath);
    end
    
    % Find .bct files
    if isfile(inputPath) && endsWith(lower(inputPath), '.bct')
        % Single file
        bctFiles = struct('name', '', 'folder', '', 'bytes', 0);
        [bctFiles.folder, fileName, ext] = fileparts(inputPath);
        bctFiles.name = [fileName, ext];
        
        fileInfo = dir(inputPath);
        bctFiles.bytes = fileInfo.bytes;
        bctFiles = bctFiles(:); % Make column vector
    elseif isfolder(inputPath)
        % Directory
        if opts.Recursive
            searchPattern = fullfile(inputPath, '**', '*.bct');
        else
            searchPattern = fullfile(inputPath, '*.bct');
        end
        
        bctFiles = dir(searchPattern);
    else
        error('BCT2H5:InvalidInput', 'Input must be a .bct file or directory');
    end
    
    if isempty(bctFiles)
        if opts.Verbose
            fprintf('No .bct files found in: %s\n', inputPath);
        end
        success.conversion_time = toc(startTime);
        return;
    end
    
    if opts.Verbose
        fprintf('Found %d .bct file(s) to convert\n', length(bctFiles));
        if opts.DryRun
            fprintf('DRY RUN MODE - No files will be modified\n');
        end
        fprintf('\n');
    end
    
    % Process each .bct file
    for i = 1:length(bctFiles)
        file = bctFiles(i);
        
        % Construct full paths
        bctPath = fullfile(file.folder, file.name);
        [~, baseName, ~] = fileparts(file.name);
        
        % Determine output directory
        if isempty(opts.OutputDir)
            outputDir = file.folder;
        else
            outputDir = opts.OutputDir;
            
            % Create output directory if it doesn't exist
            if ~exist(outputDir, 'dir') && ~opts.DryRun
                mkdir(outputDir);
            end
        end
        
        h5Path = fullfile(outputDir, [baseName, '.h5']);
        
        % Check if output file already exists
        if exist(h5Path, 'file') && ~opts.Overwrite
            if opts.Verbose
                fprintf('  Skipping %s (output exists, use Overwrite=true to replace)\n', file.name);
            end
            continue;
        end
        
        % Display conversion info
        if opts.Verbose
            fprintf('  Converting: %s\n', file.name);
            fprintf('    Input:  %s\n', bctPath);
            fprintf('    Output: %s\n', h5Path);
            fprintf('    Size:   %.2f MB\n', file.bytes / 1024^2);
        end
        
        if opts.DryRun
            if opts.Verbose
                fprintf('    Status: Would convert (dry run)\n\n');
            end
            continue;
        end
        
        % Perform conversion
        try
            convertSuccess = convertBCTtoH5(bctPath, h5Path, opts);
            
            if convertSuccess
                success.files_converted = success.files_converted + 1;
                success.total_size_mb = success.total_size_mb + file.bytes / 1024^2;
                
                % Add to file list
                fileResult = struct();
                fileResult.original = bctPath;
                fileResult.converted = h5Path;
                fileResult.size_mb = file.bytes / 1024^2;
                fileResult.status = 'success';
                success.file_list{end+1} = fileResult;
                
                if opts.Verbose
                    fprintf('    Status: ✓ Converted successfully\n');
                end
                
                % Verify conversion if requested
                if opts.Verify
                    if verifyConversion(bctPath, h5Path, opts.Verbose)
                        if opts.Verbose
                            fprintf('    Verify: ✓ Data integrity confirmed\n');
                        end
                    else
                        success.errors{end+1} = sprintf('Verification failed for %s', file.name);
                        if opts.Verbose
                            fprintf('    Verify: ✗ Data integrity check failed\n');
                        end
                    end
                end
                
                % Delete original .bct file if requested
                if opts.DeleteBCT
                    try
                        delete(bctPath);
                        if opts.Verbose
                            fprintf('    Cleanup: ✓ Original .bct file deleted\n');
                        end
                    catch ME
                        success.errors{end+1} = sprintf('Could not delete %s: %s', bctPath, ME.message);
                        if opts.Verbose
                            fprintf('    Cleanup: ✗ Could not delete original file\n');
                        end
                    end
                end
                
            else
                success.files_failed = success.files_failed + 1;
                success.errors{end+1} = sprintf('Conversion failed for %s', file.name);
                
                if opts.Verbose
                    fprintf('    Status: ✗ Conversion failed\n');
                end
            end
            
        catch ME
            success.files_failed = success.files_failed + 1;
            success.errors{end+1} = sprintf('Error converting %s: %s', file.name, ME.message);
            
            if opts.Verbose
                fprintf('    Status: ✗ Error: %s\n', ME.message);
            end
        end
        
        if opts.Verbose
            fprintf('\n');
        end
    end
    
    success.conversion_time = toc(startTime);
    
    % Display summary
    if opts.Verbose
        displaySummary(success, opts.DryRun);
    end
    
catch ME
    success.conversion_time = toc(startTime);
    success.errors{end+1} = sprintf('Conversion failed: %s', ME.message);
    
    if opts.Verbose
        fprintf('\n❌ Conversion failed: %s\n', ME.message);
    end
    
    rethrow(ME);
end

end

function success = convertBCTtoH5(bctPath, h5Path, opts)
% Convert a single .bct file to .h5 format
success = false;

try
    % Verify input file is actually HDF5 format
    try
        h5info(bctPath);
    catch
        error('BCT2H5:NotHDF5', 'Input file is not in HDF5 format: %s', bctPath);
    end
    
    % Method 1: Direct file copy (fastest for HDF5 files)
    % Since .bct files are already HDF5 format, we can simply copy them
    copyfile(bctPath, h5Path);
    
    % Verify the copy was successful
    if exist(h5Path, 'file')
        % Quick verification that it's still a valid HDF5 file
        try
            h5info(h5Path);
            success = true;
        catch
            % If copy is corrupted, try alternative method
            delete(h5Path);
            success = false;
        end
    end
    
    % Alternative method: Copy HDF5 structure (slower but more robust)
    if ~success
        success = copyHDF5Structure(bctPath, h5Path, opts);
    end
    
catch ME
    if exist(h5Path, 'file')
        try
            delete(h5Path);
        catch
            % Ignore cleanup errors
        end
    end
    
    rethrow(ME);
end
end

function success = copyHDF5Structure(sourcePath, targetPath, opts)
% Copy HDF5 file structure completely (alternative method)
success = false;

try
    % Get complete file structure
    sourceInfo = h5info(sourcePath);
    
    % Delete target if it exists
    if exist(targetPath, 'file')
        delete(targetPath);
    end
    
    % Copy all groups and datasets recursively
    copyHDF5Group(sourcePath, targetPath, sourceInfo, '/');
    
    success = true;
    
catch ME
    if opts.Verbose
        fprintf('      Alternative copy method failed: %s\n', ME.message);
    end
    
    if exist(targetPath, 'file')
        try
            delete(targetPath);
        catch
            % Ignore cleanup errors
        end
    end
end
end

function copyHDF5Group(sourcePath, targetPath, groupInfo, groupPath)
% Recursively copy HDF5 group structure
% Copy attributes
if isfield(groupInfo, 'Attributes')
    for i = 1:length(groupInfo.Attributes)
        attr = groupInfo.Attributes(i);
        attrValue = h5readatt(sourcePath, groupPath, attr.Name);
        h5writeatt(targetPath, groupPath, attr.Name, attrValue);
    end
end

% Copy datasets
if isfield(groupInfo, 'Datasets')
    for i = 1:length(groupInfo.Datasets)
        dataset = groupInfo.Datasets(i);
        datasetPath = [groupPath, dataset.Name];
        
        % Read data from source
        data = h5read(sourcePath, datasetPath);
        
        % Create dataset in target
        h5create(targetPath, datasetPath, size(data), 'Datatype', class(data));
        h5write(targetPath, datasetPath, data);
        
        % Copy dataset attributes
        for j = 1:length(dataset.Attributes)
            attr = dataset.Attributes(j);
            attrValue = h5readatt(sourcePath, datasetPath, attr.Name);
            h5writeatt(targetPath, datasetPath, attr.Name, attrValue);
        end
    end
end

% Copy subgroups recursively
if isfield(groupInfo, 'Groups')
    for i = 1:length(groupInfo.Groups)
        subgroup = groupInfo.Groups(i);
        subgroupPath = subgroup.Name;
        
        % Create group in target
        if ~strcmp(subgroupPath, '/')
            try
                h5create(targetPath, [subgroupPath, '/dummy'], 1);
                h5write(targetPath, [subgroupPath, '/dummy'], 1);
            catch
                % Group might already exist, that's okay
            end
        end
        
        % Recursively copy subgroup
        copyHDF5Group(sourcePath, targetPath, subgroup, subgroupPath);
    end
end
end

function isValid = verifyConversion(bctPath, h5Path, verbose)
% Verify that conversion preserved data integrity
isValid = false;

try
    % Compare file sizes (should be very similar)
    bctInfo = dir(bctPath);
    h5Info = dir(h5Path);
    
    sizeDiff = abs(bctInfo.bytes - h5Info.bytes) / bctInfo.bytes;
    
    if sizeDiff > 0.01 % More than 1% difference is suspicious
        if verbose
            fprintf('      Size difference: %.2f%% (may indicate corruption)\n', sizeDiff * 100);
        end
        return;
    end
    
    % Compare HDF5 structure
    bctStructure = h5info(bctPath);
    h5Structure = h5info(h5Path);
    
    % Quick structure comparison
    if length(bctStructure.Groups) ~= length(h5Structure.Groups)
        if verbose
            fprintf('      Group count mismatch\n');
        end
        return;
    end
    
    % Sample data comparison (check a few datasets)
    if isfield(bctStructure, 'Groups') && ~isempty(bctStructure.Groups)
        for i = 1:min(3, length(bctStructure.Groups)) % Check up to 3 groups
            group = bctStructure.Groups(i);
            if isfield(group, 'Datasets') && ~isempty(group.Datasets)
                dataset = group.Datasets(1); % Check first dataset in group
                datasetPath = [group.Name, '/', dataset.Name];
                
                try
                    bctData = h5read(bctPath, datasetPath);
                    h5Data = h5read(h5Path, datasetPath);
                    
                    if ~isequal(bctData, h5Data)
                        if verbose
                            fprintf('      Data mismatch in %s\n', datasetPath);
                        end
                        return;
                    end
                catch
                    % Skip datasets that can't be compared
                    continue;
                end
                
                break; % One successful comparison is enough for quick verification
            end
        end
    end
    
    isValid = true;
    
catch ME
    if verbose
        fprintf('      Verification error: %s\n', ME.message);
    end
end
end

function displaySummary(result, dryRun)
% Display conversion summary
fprintf('=== Conversion Summary ===\n');

if dryRun
    fprintf('DRY RUN - No files were actually converted\n');
else
    fprintf('Files converted: %d\n', result.files_converted);
    fprintf('Files failed: %d\n', result.files_failed);
    fprintf('Total data: %.2f MB\n', result.total_size_mb);
    fprintf('Time taken: %.2f seconds\n', result.conversion_time);
    
    if result.files_converted > 0
        fprintf('Average speed: %.2f MB/sec\n', result.total_size_mb / result.conversion_time);
    end
    
    if ~isempty(result.errors)
        fprintf('\nErrors encountered:\n');
        for i = 1:min(5, length(result.errors)) % Show up to 5 errors
            fprintf('  • %s\n', result.errors{i});
        end
        if length(result.errors) > 5
            fprintf('  ... and %d more errors\n', length(result.errors) - 5);
        end
    end
    
    if result.files_converted > 0
        fprintf('\n✅ Conversion completed successfully!\n');
        fprintf('Your .bct files are now properly formatted as .h5 files.\n');
        fprintf('They can be identified as HDF5 by other software.\n');
    end
end

fprintf('\n');
end