function info = bioctree_data_info(varargin)
% BIOCTREE_DATA_INFO Get information about Bioctree data files and storage
%
% This function provides comprehensive information about the Bioctree data
% storage system, including file inventory, disk usage, and system status.
%
% Usage:
%   info = bioctree_data_info()              % Complete information
%   info = bioctree_data_info('summary')     % Summary only
%   info = bioctree_data_info('files')       % File inventory only
%   info = bioctree_data_info('path', dir)   % Specific directory info
%
% Parameters:
%   'summary'     - Return only summary statistics
%   'files'       - Return detailed file inventory  
%   'cleanup'     - Perform cleanup of temporary files
%   'path', dir   - Analyze specific directory path
%   'verbose'     - Display detailed output
%
% Output:
%   info - Structure containing:
%     .config       - Current Bioctree configuration
%     .summary      - Storage summary statistics
%     .files        - Detailed file inventory
%     .directories  - Directory status and sizes
%     .performance  - Performance metrics and recommendations
%     .cleanup      - Cleanup suggestions and results
%
% Examples:
%   % Get complete system information
%   info = bioctree_data_info();
%
%   % Quick summary
%   summary = bioctree_data_info('summary');
%   fprintf('Total files: %d, Size: %.1f MB\n', summary.total_files, summary.total_size_mb);
%
%   % Clean up temporary files and get info
%   info = bioctree_data_info('cleanup', 'verbose');
%
% See also: bioctree_config, outbct, inbct

% Parse input arguments
p = inputParser;
addOptional(p, 'mode', 'all', @(x) ischar(x) || isstring(x));
addParameter(p, 'path', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'verbose', false, @islogical);
addParameter(p, 'cleanup', false, @islogical);
parse(p, varargin{:});

mode = lower(p.Results.mode);
targetPath = p.Results.path;
verbose = p.Results.verbose;
doCleanup = p.Results.cleanup || strcmpi(mode, 'cleanup');

% Get current configuration
config = bioctree_config('all');

% Initialize output structure
info = struct();

if verbose
    fprintf('=== Bioctree Data Information ===\n\n');
end

% Always include configuration
info.config = config;

% Get summary information
if ismember(mode, {'all', 'summary'})
    if verbose
        fprintf('Gathering storage summary...\n');
    end
    info.summary = getSummaryInfo(config, verbose);
end

% Get detailed file information
if ismember(mode, {'all', 'files'})
    if verbose
        fprintf('Scanning files...\n');
    end
    info.files = getFileInfo(config, targetPath, verbose);
end

% Get directory information
if ismember(mode, {'all', 'directories'})
    if verbose
        fprintf('Analyzing directories...\n');
    end
    info.directories = getDirectoryInfo(config, verbose);
end

% Get performance information
if ismember(mode, {'all', 'performance'})
    if verbose
        fprintf('Analyzing performance...\n');
    end
    info.performance = getPerformanceInfo(config, verbose);
end

% Perform cleanup if requested
if doCleanup
    if verbose
        fprintf('Performing cleanup...\n');
    end
    info.cleanup = performCleanup(config, verbose);
end

% Display summary if verbose
if verbose
    displaySummary(info);
end

end

function summary = getSummaryInfo(config, verbose)
% Get high-level summary statistics
summary = struct();

try
    % Scan all Bioctree data directories
    paths = {
        config.BioctreeFilesPath, 'bioctree_files';
        config.RawPath, 'raw';
        config.ProcessedPath, 'processed';
        config.DerivativesPath, 'derivatives';
        config.TempPath, 'temp';
        config.CachePath, 'cache'
    };
    
    totalFiles = 0;
    totalSize = 0;
    bioctreeH5Files = 0;
    otherH5Files = 0;
    legacyBctFiles = 0;
    
    for i = 1:size(paths, 1)
        dirPath = paths{i, 1};
        
        if exist(dirPath, 'dir')
            % Get all files recursively
            allFiles = dir(fullfile(dirPath, '**', '*'));
            allFiles = allFiles(~[allFiles.isdir]); % Remove directories
            
            % Count by type
            for j = 1:length(allFiles)
                [~, ~, ext] = fileparts(allFiles(j).name);
                totalSize = totalSize + allFiles(j).bytes;
                
                switch lower(ext)
                    case '.bct'
                        legacyBctFiles = legacyBctFiles + 1;
                    case '.h5'
                        % Check if it's a Bioctree file by examining structure
                        try
                            h5info_data = h5info(fullfile(allFiles(j).folder, allFiles(j).name));
                            if any(strcmp({h5info_data.Groups.Name}, '/metadata'))
                                bioctreeH5Files = bioctreeH5Files + 1;
                            else
                                otherH5Files = otherH5Files + 1;
                            end
                        catch
                            otherH5Files = otherH5Files + 1;
                        end
                end
            end
            
            totalFiles = totalFiles + length(allFiles);
        end
    end
    
    summary.total_files = totalFiles;
    summary.total_size_bytes = totalSize;
    summary.total_size_mb = totalSize / (1024^2);
    summary.total_size_gb = totalSize / (1024^3);
    summary.bioctree_h5_files = bioctreeH5Files;
    summary.other_h5_files = otherH5Files;
    summary.legacy_bct_files = legacyBctFiles;
    summary.other_files = totalFiles - bioctreeH5Files - otherH5Files - legacyBctFiles;
    
    % Calculate average file size
    if totalFiles > 0
        summary.avg_file_size_mb = summary.total_size_mb / totalFiles;
    else
        summary.avg_file_size_mb = 0;
    end
    
    % Get oldest and newest files
    if totalFiles > 0
        allFiles = [];
        for i = 1:size(paths, 1)
            dirPath = paths{i, 1};
            if exist(dirPath, 'dir')
                files = dir(fullfile(dirPath, '**', '*.*'));
                files = files(~[files.isdir]);
                allFiles = [allFiles; files];
            end
        end
        
        if ~isempty(allFiles)
            dates = [allFiles.datenum];
            [~, oldestIdx] = min(dates);
            [~, newestIdx] = max(dates);
            
            summary.oldest_file = allFiles(oldestIdx).name;
            summary.oldest_date = datestr(dates(oldestIdx));
            summary.newest_file = allFiles(newestIdx).name;
            summary.newest_date = datestr(dates(newestIdx));
        end
    end
    
    summary.scan_time = datestr(now);
    
    if verbose
        fprintf('  Total files: %d (%.1f MB)\n', totalFiles, summary.total_size_mb);
        fprintf('  Bioctree files: %d .h5, %d legacy .bct, %d other .h5\n', ...
                bioctreeH5Files, legacyBctFiles, otherH5Files);
    end
    
catch ME
    if verbose
        fprintf('  Warning: Could not get complete summary: %s\n', ME.message);
    end
    summary.error = ME.message;
end
end

function files = getFileInfo(config, targetPath, verbose)
% Get detailed file inventory
files = struct();

if isempty(targetPath)
    searchPaths = {
        config.RawPath, 'raw';
        config.ProcessedPath, 'processed';
        config.DerivativesPath, 'derivatives'
    };
else
    searchPaths = {targetPath, 'custom'};
end

fileList = [];

for i = 1:size(searchPaths, 1)
    dirPath = searchPaths{i, 1};
    category = searchPaths{i, 2};
    
    if exist(dirPath, 'dir')
        % Get Bioctree files (prioritize .h5, include legacy .bct)
        h5Files = dir(fullfile(dirPath, '**', '*.h5'));
        bctFiles = dir(fullfile(dirPath, '**', '*.bct'));
        
        allFiles = [h5Files; bctFiles];
        
        for j = 1:length(allFiles)
            fileInfo = struct();
            fileInfo.name = allFiles(j).name;
            fileInfo.path = fullfile(allFiles(j).folder, allFiles(j).name);
            fileInfo.size_bytes = allFiles(j).bytes;
            fileInfo.size_mb = allFiles(j).bytes / (1024^2);
            fileInfo.date = allFiles(j).date;
            fileInfo.datenum = allFiles(j).datenum;
            fileInfo.category = category;
            
            [~, ~, ext] = fileparts(allFiles(j).name);
            fileInfo.type = lower(ext);
            
            % Try to get additional metadata for .h5/.bct files
            try
                if ismember(lower(ext), {'.h5', '.bct'})
                    h5info_data = h5info(fileInfo.path);
                    fileInfo.hdf5_groups = length(h5info_data.Groups);
                    fileInfo.hdf5_datasets = countDatasets(h5info_data);
                    
                    % Try to read basic metadata and identify file type
                    try
                        if any(strcmp({h5info_data.Groups.Name}, '/metadata'))
                            fileInfo.has_metadata = true;
                            fileInfo.is_bioctree = true;
                            if strcmpi(ext, '.bct')
                                fileInfo.needs_conversion = true;
                            end
                        else
                            fileInfo.has_metadata = false;
                            fileInfo.is_bioctree = false;
                        end
                    catch
                        fileInfo.has_metadata = false;
                        fileInfo.is_bioctree = false;
                    end
                end
            catch
                % File might be corrupted or inaccessible
                fileInfo.accessible = false;
            end
            
            if ~isfield(fileInfo, 'accessible')
                fileInfo.accessible = true;
            end
            
            fileList = [fileList; fileInfo];
        end
    end
end

files.list = fileList;
files.count = length(fileList);

if ~isempty(fileList)
    files.total_size_mb = sum([fileList.size_mb]);
    files.avg_size_mb = mean([fileList.size_mb]);
    files.size_range_mb = [min([fileList.size_mb]), max([fileList.size_mb])];
    
    % Group by category
    categories = unique({fileList.category});
    for i = 1:length(categories)
        cat = categories{i};
        catFiles = fileList(strcmp({fileList.category}, cat));
        files.by_category.(cat) = struct(...
            'count', length(catFiles), ...
            'size_mb', sum([catFiles.size_mb]), ...
            'files', catFiles ...
        );
    end
else
    files.total_size_mb = 0;
    files.avg_size_mb = 0;
    files.size_range_mb = [0, 0];
    files.by_category = struct();
end

if verbose
    fprintf('  Found %d files (%.1f MB total)\n', files.count, files.total_size_mb);
    categories = fieldnames(files.by_category);
    for i = 1:length(categories)
        cat = categories{i};
        catData = files.by_category.(cat);
        fprintf('    %s: %d files (%.1f MB)\n', cat, catData.count, catData.size_mb);
    end
end
end

function dirs = getDirectoryInfo(config, verbose)
% Get information about directory structure and usage
dirs = struct();

dirPaths = {
    config.DataPath, 'root';
    config.BioctreeFilesPath, 'bioctree_files';
    config.RawPath, 'raw';
    config.ProcessedPath, 'processed'; 
    config.DerivativesPath, 'derivatives';
    config.TempPath, 'temp';
    config.CachePath, 'cache';
    config.ConfigPath, 'config'
};

for i = 1:size(dirPaths, 1)
    dirPath = dirPaths{i, 1};
    dirName = dirPaths{i, 2};
    
    dirInfo = struct();
    dirInfo.path = dirPath;
    dirInfo.exists = exist(dirPath, 'dir') > 0;
    
    if dirInfo.exists
        try
            % Get directory contents
            contents = dir(dirPath);
            contents = contents(~ismember({contents.name}, {'.', '..'}));
            
            dirInfo.total_items = length(contents);
            dirInfo.subdirs = sum([contents.isdir]);
            dirInfo.files = sum(~[contents.isdir]);
            
            % Calculate total size
            if dirInfo.files > 0
                filesOnly = contents(~[contents.isdir]);
                dirInfo.size_bytes = sum([filesOnly.bytes]);
                dirInfo.size_mb = dirInfo.size_bytes / (1024^2);
            else
                dirInfo.size_bytes = 0;
                dirInfo.size_mb = 0;
            end
            
            % Check write permissions
            try
                testFile = fullfile(dirPath, 'bioctree_test_write.tmp');
                fid = fopen(testFile, 'w');
                if fid > 0
                    fclose(fid);
                    delete(testFile);
                    dirInfo.writable = true;
                else
                    dirInfo.writable = false;
                end
            catch
                dirInfo.writable = false;
            end
            
        catch ME
            dirInfo.error = ME.message;
            dirInfo.accessible = false;
        end
    else
        dirInfo.total_items = 0;
        dirInfo.subdirs = 0;
        dirInfo.files = 0;
        dirInfo.size_bytes = 0;
        dirInfo.size_mb = 0;
        dirInfo.writable = false;
    end
    
    dirs.(dirName) = dirInfo;
end

if verbose
    fprintf('  Directory status:\n');
    dirNames = fieldnames(dirs);
    for i = 1:length(dirNames)
        dirName = dirNames{i};
        dirData = dirs.(dirName);
        
        if dirData.exists
            status = '✓';
            statusText = 'OK';
        else
            status = '✗';
            statusText = 'Missing';
        end
        
        if dirData.exists
            fprintf('    %s %-15s: %s (%d files, %.1f MB)\n', ...
                    status, dirName, statusText, dirData.files, dirData.size_mb);
        else
            fprintf('    %s %-15s: %s\n', status, dirName, statusText);
        end
    end
end
end

function perf = getPerformanceInfo(config, verbose)
% Get performance-related information and recommendations
perf = struct();

% Check disk space
try
    if ispc
        [~, ~] = system(['dir "' config.DataPath '" /-c']);
        % Parse Windows dir output for free space (this is simplified)
        perf.disk_space_available = 'Unknown (Windows)';
    else
        [status, diskInfo] = system(['df -h "' config.DataPath '"']);
        if status == 0
            perf.disk_info = diskInfo;
        else
            perf.disk_space_available = 'Unknown';
        end
    end
catch
    perf.disk_space_available = 'Cannot determine';
end

% Check I/O performance with a simple test
try
    testFile = fullfile(config.TempPath, 'bioctree_io_test.tmp');
    testData = rand(100, 100); % Small test matrix
    
    % Test write performance
    tic;
    save(testFile, 'testData', '-v7.3');
    writeTime = toc;
    
    % Test read performance  
    tic;
    load(testFile, 'testData');
    readTime = toc;
    
    % Cleanup
    if exist(testFile, 'file')
        delete(testFile);
    end
    
    perf.io_test = struct(...
        'write_time_sec', writeTime, ...
        'read_time_sec', readTime, ...
        'data_size_kb', numel(testData) * 8 / 1024 ...
    );
    
    % Performance assessment
    if writeTime < 0.1 && readTime < 0.05
        perf.io_performance = 'Excellent';
    elseif writeTime < 0.5 && readTime < 0.1
        perf.io_performance = 'Good';
    elseif writeTime < 1.0 && readTime < 0.2
        perf.io_performance = 'Fair';
    else
        perf.io_performance = 'Poor';
    end
    
catch ME
    perf.io_test_error = ME.message;
    perf.io_performance = 'Unknown';
end

% Memory usage recommendations
try
    memInfo = memory;
    availableGB = memInfo.MemAvailableAllArrays / 1024^3;
    
    perf.available_memory_gb = availableGB;
    
    if availableGB > 8
        perf.memory_recommendation = 'Sufficient for large datasets';
    elseif availableGB > 4
        perf.memory_recommendation = 'Good for medium datasets';
    elseif availableGB > 2
        perf.memory_recommendation = 'Limited - use single precision';
    else
        perf.memory_recommendation = 'Very limited - consider chunking';
    end
catch
    perf.memory_recommendation = 'Cannot determine';
end

% Configuration recommendations
perf.recommendations = {};

if config.Compression < 6
    perf.recommendations{end+1} = 'Consider increasing compression level for better storage efficiency';
end

if config.MaxCacheSize > 2000
    perf.recommendations{end+1} = 'Large cache size may impact memory usage';
end

if ~exist(config.DataPath, 'dir') || ~exist(config.TempPath, 'dir')
    perf.recommendations{end+1} = 'Some data directories are missing - run bioctree_config to create them';
end

if verbose
    fprintf('  I/O Performance: %s\n', perf.io_performance);
    if isfield(perf, 'available_memory_gb')
        fprintf('  Available Memory: %.1f GB - %s\n', ...
                perf.available_memory_gb, perf.memory_recommendation);
    end
    
    if ~isempty(perf.recommendations)
        fprintf('  Recommendations:\n');
        for i = 1:length(perf.recommendations)
            fprintf('    • %s\n', perf.recommendations{i});
        end
    end
end
end

function cleanup = performCleanup(config, verbose)
% Perform cleanup of temporary files and cache
cleanup = struct();

if verbose
    fprintf('  Cleaning up temporary files...\n');
end

% Clean temporary directory
tempCleaned = cleanDirectory(config.TempPath, config.CleanupInterval, verbose);
cleanup.temp = tempCleaned;

% Clean cache if it's too large
cacheInfo = getDirSize(config.CachePath);
if cacheInfo.size_mb > config.MaxCacheSize
    if verbose
        fprintf('  Cache exceeds limit (%.1f > %.1f MB), cleaning oldest files...\n', ...
                cacheInfo.size_mb, config.MaxCacheSize);
    end
    cacheCleaned = cleanCacheBySize(config.CachePath, config.MaxCacheSize, verbose);
    cleanup.cache = cacheCleaned;
else
    cleanup.cache = struct('files_removed', 0, 'space_freed_mb', 0);
end

cleanup.total_files_removed = cleanup.temp.files_removed + cleanup.cache.files_removed;
cleanup.total_space_freed_mb = cleanup.temp.space_freed_mb + cleanup.cache.space_freed_mb;

if verbose
    fprintf('  Cleanup complete: %d files removed, %.1f MB freed\n', ...
            cleanup.total_files_removed, cleanup.total_space_freed_mb);
end
end

function result = cleanDirectory(dirPath, maxAgeHours, verbose)
% Clean files older than specified age
result = struct('files_removed', 0, 'space_freed_mb', 0, 'errors', {});

if ~exist(dirPath, 'dir')
    return;
end

try
    files = dir(fullfile(dirPath, '*'));
    files = files(~[files.isdir]); % Only files, not directories
    
    cutoffTime = now - maxAgeHours/24;
    
    for i = 1:length(files)
        if files(i).datenum < cutoffTime
            filePath = fullfile(files(i).folder, files(i).name);
            try
                delete(filePath);
                result.files_removed = result.files_removed + 1;
                result.space_freed_mb = result.space_freed_mb + files(i).bytes / (1024^2);
                
                if verbose && result.files_removed <= 5 % Don't spam with too many messages
                    fprintf('    Removed: %s\n', files(i).name);
                end
            catch ME
                result.errors{end+1} = sprintf('Could not delete %s: %s', files(i).name, ME.message);
            end
        end
    end
    
catch ME
    result.errors{end+1} = sprintf('Error cleaning directory: %s', ME.message);
end
end

function result = cleanCacheBySize(cachePath, maxSizeMB, verbose)
% Remove oldest cache files until under size limit
result = struct('files_removed', 0, 'space_freed_mb', 0, 'errors', {});

if ~exist(cachePath, 'dir')
    return;
end

try
    files = dir(fullfile(cachePath, '**', '*'));
    files = files(~[files.isdir]);
    
    if isempty(files)
        return;
    end
    
    % Sort by date (oldest first)
    [~, sortIdx] = sort([files.datenum]);
    files = files(sortIdx);
    
    currentSize = sum([files.bytes]) / (1024^2);
    
    i = 1;
    while currentSize > maxSizeMB && i <= length(files)
        filePath = fullfile(files(i).folder, files(i).name);
        fileSize = files(i).bytes / (1024^2);
        
        try
            delete(filePath);
            result.files_removed = result.files_removed + 1;
            result.space_freed_mb = result.space_freed_mb + fileSize;
            currentSize = currentSize - fileSize;
            
            if verbose && result.files_removed <= 5
                fprintf('    Removed cache file: %s\n', files(i).name);
            end
        catch ME
            result.errors{end+1} = sprintf('Could not delete %s: %s', files(i).name, ME.message);
        end
        
        i = i + 1;
    end
    
catch ME
    result.errors{end+1} = sprintf('Error cleaning cache: %s', ME.message);
end
end

function dirSize = getDirSize(dirPath)
% Get total size of directory
dirSize = struct('size_bytes', 0, 'size_mb', 0, 'file_count', 0);

if exist(dirPath, 'dir')
    files = dir(fullfile(dirPath, '**', '*'));
    files = files(~[files.isdir]);
    
    dirSize.file_count = length(files);
    if ~isempty(files)
        dirSize.size_bytes = sum([files.bytes]);
        dirSize.size_mb = dirSize.size_bytes / (1024^2);
    end
end
end

function count = countDatasets(h5info_struct)
% Recursively count HDF5 datasets
count = 0;

if isfield(h5info_struct, 'Datasets')
    count = count + length(h5info_struct.Datasets);
end

if isfield(h5info_struct, 'Groups')
    for i = 1:length(h5info_struct.Groups)
        count = count + countDatasets(h5info_struct.Groups(i));
    end
end
end

function displaySummary(info)
% Display comprehensive summary
fprintf('\n=== Summary ===\n');

if isfield(info, 'summary')
    s = info.summary;
    fprintf('Storage: %d files, %.1f MB total\n', s.total_files, s.total_size_mb);
    fprintf('Types: %d .bct, %d .h5, %d other\n', s.bct_files, s.h5_files, s.other_files);
    
    if isfield(s, 'oldest_date')
        fprintf('Date range: %s to %s\n', s.oldest_date, s.newest_date);
    end
end

if isfield(info, 'performance')
    p = info.performance;
    fprintf('Performance: %s I/O', p.io_performance);
    if isfield(p, 'available_memory_gb')
        fprintf(', %.1f GB RAM available\n', p.available_memory_gb);
    else
        fprintf('\n');
    end
end

if isfield(info, 'cleanup')
    c = info.cleanup;
    if c.total_files_removed > 0
        fprintf('Cleanup: %d files removed, %.1f MB freed\n', ...
                c.total_files_removed, c.total_space_freed_mb);
    end
end

fprintf('\n');
end