function varargout = bioctree_config(varargin)
% BIOCTREE_CONFIG Configure and manage Bioctree data paths and settings
%
% This function manages the configuration of Bioctree data storage paths,
% cache settings, and other system-wide parameters.
%
% Usage:
%   bioctree_config()                     % Display current configuration
%   bioctree_config('param', value)       % Set configuration parameter
%   value = bioctree_config('param')      % Get configuration parameter
%   config = bioctree_config('all')       % Get all configuration
%
% Parameters:
%   'DataPath'        - Root directory for Bioctree data files
%   'TempPath'        - Directory for temporary processing files  
%   'CachePath'       - Directory for cached computations
%   'ConfigPath'      - Directory for configuration files
%   'DefaultPrecision'- Default numeric precision ('single' or 'double')
%   'Compression'     - HDF5 compression level (0-9, default: 6)
%   'ChunkSize'       - Default HDF5 chunk size for datasets
%   'MaxCacheSize'    - Maximum cache size in MB (default: 1000)
%   'CleanupInterval' - Hours between automatic temp cleanup (default: 24)
%   'Verbose'         - Default verbosity for operations (true/false)
%
% Examples:
%   % Set custom data directory
%   bioctree_config('DataPath', '/data/bioctree');
%
%   % Configure for high-performance setup
%   bioctree_config('Compression', 9, 'ChunkSize', [100, 100], 'MaxCacheSize', 5000);
%
%   % Get current data path
%   dataPath = bioctree_config('DataPath');
%
%   % Display all settings
%   bioctree_config();
%
% Output:
%   If called with output arguments, returns the requested configuration values
%
% See also: outbct, inbct, bioctree_data_info

% Get the directory where this function is located (bioctree root)
bioctreeRoot = fileparts(mfilename('fullpath'));
defaultDataPath = fullfile(bioctreeRoot, 'data');

% Configuration file path
configFile = fullfile(defaultDataPath, 'config', 'bioctree_config.mat');

% Default configuration
defaultConfig = struct(...
    'DataPath', defaultDataPath, ...
    'TempPath', fullfile(defaultDataPath, 'temp'), ...
    'CachePath', fullfile(defaultDataPath, 'cache'), ...
    'ConfigPath', fullfile(defaultDataPath, 'config'), ...
    'BioctreeFilesPath', fullfile(defaultDataPath, 'bioctree_files'), ...
    'RawPath', fullfile(defaultDataPath, 'bioctree_files', 'raw'), ...
    'ProcessedPath', fullfile(defaultDataPath, 'bioctree_files', 'processed'), ...
    'DerivativesPath', fullfile(defaultDataPath, 'bioctree_files', 'derivatives'), ...
    'DefaultPrecision', 'single', ...
    'Compression', 6, ...
    'ChunkSize', [50, 50], ...
    'MaxCacheSize', 1000, ...
    'CleanupInterval', 24, ...
    'Verbose', false, ...
    'Version', '1.0', ...
    'LastModified', datestr(now) ...
);

% Load existing configuration or create default
if exist(configFile, 'file')
    try
        loadedData = load(configFile);
        config = loadedData.config;
        
        % Merge with defaults for any missing fields
        defaultFields = fieldnames(defaultConfig);
        for i = 1:length(defaultFields)
            if ~isfield(config, defaultFields{i})
                config.(defaultFields{i}) = defaultConfig.(defaultFields{i});
            end
        end
    catch
        warning('BioctreeConfig:LoadFailed', 'Could not load config file, using defaults');
        config = defaultConfig;
    end
else
    config = defaultConfig;
    
    % Ensure config directory exists
    configDir = fileparts(configFile);
    if ~exist(configDir, 'dir')
        mkdir(configDir);
    end
    
    % Save default configuration
    try
        save(configFile, 'config', '-v7.3');
    catch
        warning('BioctreeConfig:SaveFailed', 'Could not save default configuration');
    end
end

% Parse input arguments
if nargin == 0
    % Display current configuration
    displayConfig(config);
    if nargout > 0
        varargout{1} = config;
    end
    return;
elseif nargin == 1
    param = varargin{1};
    
    if strcmpi(param, 'all')
        varargout{1} = config;
        return;
    elseif isfield(config, param)
        varargout{1} = config.(param);
        return;
    else
        error('BioctreeConfig:UnknownParameter', 'Unknown parameter: %s', param);
    end
elseif mod(nargin, 2) == 0
    % Set parameter-value pairs
    for i = 1:2:nargin
        param = varargin{i};
        value = varargin{i+1};
        
        if ~ischar(param) && ~isstring(param)
            error('BioctreeConfig:InvalidParameter', 'Parameter names must be strings');
        end
        
        % Validate and set parameter
        config = setConfigParameter(config, param, value);
    end
    
    % Update modification time
    config.LastModified = datestr(now);
    
    % Ensure all directories exist
    ensureDirectoriesExist(config);
    
    % Save updated configuration
    try
        save(configFile, 'config', '-v7.3');
    catch
        warning('BioctreeConfig:SaveFailed', 'Could not save configuration');
    end
    
    if nargout > 0
        varargout{1} = config;
    end
else
    error('BioctreeConfig:InvalidArguments', 'Arguments must be parameter-value pairs');
end

end

function displayConfig(config)
% Display current configuration in a readable format
fprintf('=== Bioctree Configuration ===\n\n');

fprintf('Data Paths:\n');
fprintf('  Root Data Path:    %s\n', config.DataPath);
fprintf('  Bioctree Files:    %s\n', config.BioctreeFilesPath);
fprintf('  Raw Data:          %s\n', config.RawPath);
fprintf('  Processed Data:    %s\n', config.ProcessedPath);
fprintf('  Derivatives:       %s\n', config.DerivativesPath);
fprintf('  Temporary Files:   %s\n', config.TempPath);
fprintf('  Cache:             %s\n', config.CachePath);
fprintf('  Configuration:     %s\n', config.ConfigPath);

fprintf('\nProcessing Settings:\n');
fprintf('  Default Precision: %s\n', config.DefaultPrecision);
fprintf('  HDF5 Compression:  %d\n', config.Compression);
fprintf('  Chunk Size:        [%s]\n', num2str(config.ChunkSize));
fprintf('  Max Cache Size:    %d MB\n', config.MaxCacheSize);
fprintf('  Cleanup Interval:  %d hours\n', config.CleanupInterval);
fprintf('  Verbose Output:    %s\n', mat2str(config.Verbose));

fprintf('\nSystem Info:\n');
fprintf('  Config Version:    %s\n', config.Version);
fprintf('  Last Modified:     %s\n', config.LastModified);

% Check directory status
fprintf('\nDirectory Status:\n');
paths = {config.DataPath, config.BioctreeFilesPath, config.TempPath, ...
         config.CachePath, config.ConfigPath};
pathNames = {'Data', 'Bioctree Files', 'Temp', 'Cache', 'Config'};

for i = 1:length(paths)
    if exist(paths{i}, 'dir')
        fprintf('  %-15s: ✓ Exists\n', pathNames{i});
    else
        fprintf('  %-15s: ✗ Missing\n', pathNames{i});
    end
end

% Display disk usage if possible
try
    fprintf('\nDisk Usage:\n');
    
    % Get bioctree files size
    bctFiles = dir(fullfile(config.BioctreeFilesPath, '**', '*.bct'));
    h5Files = dir(fullfile(config.BioctreeFilesPath, '**', '*.h5'));
    
    totalSize = sum([bctFiles.bytes]) + sum([h5Files.bytes]);
    
    fprintf('  Bioctree Files:    %.2f MB (%d files)\n', ...
            totalSize / 1024^2, length(bctFiles) + length(h5Files));
    
    % Get cache size
    cacheFiles = dir(fullfile(config.CachePath, '**', '*'));
    cacheFiles = cacheFiles(~[cacheFiles.isdir]);
    cacheSize = sum([cacheFiles.bytes]);
    
    fprintf('  Cache:             %.2f MB (%d files)\n', ...
            cacheSize / 1024^2, length(cacheFiles));
    
    % Get temp size
    tempFiles = dir(fullfile(config.TempPath, '**', '*'));
    tempFiles = tempFiles(~[tempFiles.isdir]);
    tempSize = sum([tempFiles.bytes]);
    
    fprintf('  Temporary:         %.2f MB (%d files)\n', ...
            tempSize / 1024^2, length(tempFiles));
    
catch
    fprintf('  Could not determine disk usage\n');
end

fprintf('\n');
end

function config = setConfigParameter(config, param, value)
% Validate and set a configuration parameter
switch lower(param)
    case 'datapath'
        if ~ischar(value) && ~isstring(value)
            error('BioctreeConfig:InvalidValue', 'DataPath must be a string');
        end
        config.DataPath = char(value);
        
        % Update related paths
        config.TempPath = fullfile(config.DataPath, 'temp');
        config.CachePath = fullfile(config.DataPath, 'cache');
        config.ConfigPath = fullfile(config.DataPath, 'config');
        config.BioctreeFilesPath = fullfile(config.DataPath, 'bioctree_files');
        config.RawPath = fullfile(config.BioctreeFilesPath, 'raw');
        config.ProcessedPath = fullfile(config.BioctreeFilesPath, 'processed');
        config.DerivativesPath = fullfile(config.BioctreeFilesPath, 'derivatives');
        
    case {'temppath', 'cachepath', 'configpath', 'bioctreefilespath', ...
          'rawpath', 'processedpath', 'derivativespath'}
        if ~ischar(value) && ~isstring(value)
            error('BioctreeConfig:InvalidValue', 'Path must be a string');
        end
        config.(param) = char(value);
        
    case 'defaultprecision'
        if ~ismember(value, {'single', 'double'})
            error('BioctreeConfig:InvalidValue', 'DefaultPrecision must be ''single'' or ''double''');
        end
        config.DefaultPrecision = value;
        
    case 'compression'
        if ~isnumeric(value) || value < 0 || value > 9
            error('BioctreeConfig:InvalidValue', 'Compression must be an integer between 0 and 9');
        end
        config.Compression = round(value);
        
    case 'chunksize'
        if ~isnumeric(value) || length(value) > 3 || any(value <= 0)
            error('BioctreeConfig:InvalidValue', 'ChunkSize must be positive integers');
        end
        config.ChunkSize = round(value);
        
    case 'maxcachesize'
        if ~isnumeric(value) || value <= 0
            error('BioctreeConfig:InvalidValue', 'MaxCacheSize must be positive');
        end
        config.MaxCacheSize = value;
        
    case 'cleanupinterval'
        if ~isnumeric(value) || value <= 0
            error('BioctreeConfig:InvalidValue', 'CleanupInterval must be positive');
        end
        config.CleanupInterval = value;
        
    case 'verbose'
        if ~islogical(value)
            error('BioctreeConfig:InvalidValue', 'Verbose must be true or false');
        end
        config.Verbose = value;
        
    otherwise
        error('BioctreeConfig:UnknownParameter', 'Unknown parameter: %s', param);
end
end

function ensureDirectoriesExist(config)
% Create directories if they don't exist
paths = {config.DataPath, config.TempPath, config.CachePath, ...
         config.ConfigPath, config.BioctreeFilesPath, config.RawPath, ...
         config.ProcessedPath, config.DerivativesPath};

for i = 1:length(paths)
    if ~exist(paths{i}, 'dir')
        try
            mkdir(paths{i});
        catch ME
            warning('BioctreeConfig:DirectoryCreation', ...
                   'Could not create directory %s: %s', paths{i}, ME.message);
        end
    end
end
end