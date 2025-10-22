function data = inbct(filePath, varargin)
% INBCT Load Bioctree analysis results from HDF5 format
%
% This function provides efficient querying and loading of Bioctree HDF5 files
% with support for selective data loading by time, space, and frequency.
%
% Usage:
%   data = inbct(filePath)
%   data = inbct(filePath, 'param', value, ...)
%
% Inputs:
%   filePath - Path to Bioctree HDF5 file
%
% Parameters:
%   'TimeRange'     - [start, end] time indices or time values in seconds
%   'VertexRange'   - Vertex indices to load [vector] 
%   'FreqRange'     - Frequency range [f_min, f_max] in Hz
%   'FreqBands'     - Cell array of band names {'alpha', 'beta', ...}
%   'SpatialPatch'  - Spatial patch name or index
%   'DataTypes'     - Cell array of data types to load:
%                     {'raw', 'spectral', 'derived', 'analysis'}
%   'LoadMetadata'  - Load metadata and structure info (default: true)
%   'Precision'     - Output precision 'single' or 'double' (default: 'single')
%   'Verbose'       - Display loading progress (default: false)
%
% Output:
%   data - Structure containing requested data with fields:
%     .metadata     - File metadata and analysis parameters
%     .graph        - Graph structure (adjacency, coordinates, eigendecomposition)
%     .temporal     - Temporal information (time vector, sampling frequency)
%     .signal       - Raw time-vertex signal data (if requested)
%     .spectral     - Spectral analysis results (if requested) 
%     .derived      - Derived quantities (gradients, TV, etc.)
%     .analysis     - Analysis results (statistics, detections, etc.)
%     .indices      - Index information for efficient querying
%
% Query Examples:
%   % Load complete dataset
%   data = inbct('results.h5');
%
%   % Load only alpha band activity in posterior cortex
%   data = inbct('results.h5', ...
%       'FreqBands', {'alpha'}, ...
%       'SpatialPatch', 'posterior', ...
%       'DataTypes', {'raw', 'spectral'});
%
%   % Load specific time window for all vertices
%   data = inbct('results.h5', ...
%       'TimeRange', [2, 4], ...  % 2-4 seconds
%       'DataTypes', {'raw', 'derived'});
%
%   % Load only metadata and structure information
%   info = inbct('results.h5', ...
%       'DataTypes', {}, ...
%       'LoadMetadata', true);
%
% Returns:
%   data - Structure with loaded data according to specified parameters
%
% See also: outbct, h5read, h5info

% Input validation
p = inputParser;
addRequired(p, 'filePath', @(x) ischar(x) || isstring(x));
addParameter(p, 'TimeRange', [], @(x) isnumeric(x) && (isempty(x) || length(x) == 2));
addParameter(p, 'VertexRange', [], @(x) isnumeric(x) || isempty(x));
addParameter(p, 'FreqRange', [], @(x) isnumeric(x) && (isempty(x) || length(x) == 2));
addParameter(p, 'FreqBands', {}, @iscell);
addParameter(p, 'SpatialPatch', '', @(x) ischar(x) || isstring(x) || isnumeric(x));
addParameter(p, 'DataTypes', {'raw', 'spectral', 'derived', 'analysis'}, @iscell);
addParameter(p, 'LoadMetadata', true, @islogical);
addParameter(p, 'Precision', 'single', @(x) ismember(x, {'single', 'double'}));
addParameter(p, 'Verbose', false, @islogical);
parse(p, filePath, varargin{:});

opts = p.Results;

% Convert to string for consistency
filePath = char(filePath);

% Verify file exists
if ~exist(filePath, 'file')
    error('BioctreeHDF5:FileNotFound', 'HDF5 file not found: %s', filePath);
end

try
    if opts.Verbose
        fprintf('Loading Bioctree HDF5 file: %s\n', filePath);
    end
    
    % Initialize output structure
    data = struct();
    
    % Always load basic file info
    fileInfo = h5info(filePath);
    if opts.Verbose
        fprintf('  File contains %d groups and datasets\n', countTotalItems(fileInfo));
    end
    
    % Load metadata if requested
    if opts.LoadMetadata
        data.metadata = loadMetadata(filePath, opts.Verbose);
        
        % Extract dimensions from metadata
        if isfield(data.metadata, 'graph') && isfield(data.metadata.graph, 'num_vertices')
            N = data.metadata.graph.num_vertices;
        else
            % Fallback: read from a dataset
            try
                coords = h5read(filePath, '/graph/coordinates');
                N = size(coords, 1);
            catch
                N = [];
            end
        end
        
        if isfield(data.metadata, 'temporal') && isfield(data.metadata.temporal, 'num_timepoints')
            T = data.metadata.temporal.num_timepoints;
        else
            % Fallback: read from time vector
            try
                timeVec = h5read(filePath, '/temporal/time_vector');
                T = length(timeVec);
            catch
                T = [];
            end
        end
    else
        % Determine dimensions from datasets
        try
            coords = h5read(filePath, '/graph/coordinates');
            N = size(coords, 1);
        catch
            N = [];
        end
        
        try
            timeVec = h5read(filePath, '/temporal/time_vector');
            T = length(timeVec);
        catch
            T = [];
        end
    end
    
    % Determine indices for selective loading
    [timeIndices, vertexIndices, freqIndices] = determineIndices(filePath, opts, N, T);
    
    % Load graph structure
    if opts.LoadMetadata || ismember('graph', opts.DataTypes)
        data.graph = loadGraphData(filePath, opts, vertexIndices);
    end
    
    % Load temporal information
    if opts.LoadMetadata || any(ismember({'raw', 'spectral'}, opts.DataTypes))
        data.temporal = loadTemporalData(filePath, opts, timeIndices, freqIndices);
    end
    
    % Load raw signal data
    if ismember('raw', opts.DataTypes)
        data.signal = loadRawData(filePath, opts, vertexIndices, timeIndices);
    end
    
    % Load spectral data
    if ismember('spectral', opts.DataTypes)
        data.spectral = loadSpectralData(filePath, opts, vertexIndices, timeIndices, freqIndices);
    end
    
    % Load derived data
    if ismember('derived', opts.DataTypes)
        data.derived = loadDerivedData(filePath, opts, vertexIndices, timeIndices);
    end
    
    % Load analysis results
    if ismember('analysis', opts.DataTypes)
        data.analysis = loadAnalysisData(filePath, opts, vertexIndices, timeIndices);
    end
    
    % Load indices information
    if opts.LoadMetadata
        data.indices = loadIndicesData(filePath, opts);
    end
    
    if opts.Verbose
        fprintf('✅ Bioctree HDF5 loading completed\n');
        displayLoadedData(data);
    end
    
catch ME
    error('BioctreeHDF5:LoadFailed', 'Failed to load HDF5 file: %s\nError: %s', filePath, ME.message);
end

end

% Helper functions

function count = countTotalItems(info)
% Count total groups and datasets recursively
count = 0;
if isfield(info, 'Groups')
    count = count + length(info.Groups);
    for i = 1:length(info.Groups)
        count = count + countTotalItems(info.Groups(i));
    end
end
if isfield(info, 'Datasets')
    count = count + length(info.Datasets);
end
end

function metadata = loadMetadata(filePath, verbose)
% Load metadata from HDF5 file
metadata = struct();

if verbose
    fprintf('  Loading metadata...\n');
end

% Load analysis info
try
    metadata.analysis = loadAttributesAsStruct(filePath, '/metadata');
catch
    if verbose
        fprintf('    Warning: Could not load analysis metadata\n');
    end
end

% Load graph properties  
try
    metadata.graph = loadAttributesAsStruct(filePath, '/graph');
catch
    if verbose
        fprintf('    Warning: Could not load graph metadata\n');
    end
end

% Load temporal info
try
    metadata.temporal = loadAttributesAsStruct(filePath, '/temporal');
catch
    if verbose
        fprintf('    Warning: Could not load temporal metadata\n');
    end
end

end

function attrStruct = loadAttributesAsStruct(filePath, groupPath)
% Load HDF5 attributes as MATLAB struct
attrStruct = struct();

try
    info = h5info(filePath, groupPath);
    if isfield(info, 'Attributes')
        for i = 1:length(info.Attributes)
            attrName = info.Attributes(i).Name;
            attrValue = h5readatt(filePath, groupPath, attrName);
            
            % Convert to appropriate MATLAB type
            if ischar(attrValue)
                attrStruct.(attrName) = attrValue;
            else
                attrStruct.(attrName) = double(attrValue);
            end
        end
    end
catch
    % Return empty struct if no attributes or group doesn't exist
end

end

function [timeIndices, vertexIndices, freqIndices] = determineIndices(filePath, opts, ~, T)
% Determine which indices to load based on query parameters

% Time indices
if isempty(opts.TimeRange)
    timeIndices = [];
else
    if ~isempty(T)
        % Check if TimeRange is in seconds or indices
        if max(opts.TimeRange) <= T && min(opts.TimeRange) >= 1
            % Assume indices
            timeIndices = opts.TimeRange(1):opts.TimeRange(2);
        else
            % Assume seconds - convert to indices
            try
                timeVec = h5read(filePath, '/temporal/time_vector');
                timeIndices = find(timeVec >= opts.TimeRange(1) & timeVec <= opts.TimeRange(2));
            catch
                warning('BioctreeHDF5:TimeConversion', 'Could not convert time range to indices');
                timeIndices = [];
            end
        end
    else
        timeIndices = [];
    end
end

% Vertex indices
if isempty(opts.VertexRange)
    vertexIndices = [];
else
    vertexIndices = opts.VertexRange;
end

% Handle spatial patches
if ~isempty(opts.SpatialPatch)
    try
        if isnumeric(opts.SpatialPatch)
            patchDataset = sprintf('/indices/spatial_indices/patch_%d', opts.SpatialPatch);
        else
            % Search for patch by name
            patchDataset = findPatchByName(filePath, opts.SpatialPatch);
        end
        
        patchVertices = h5read(filePath, patchDataset);
        if isempty(vertexIndices)
            vertexIndices = patchVertices;
        else
            vertexIndices = intersect(vertexIndices, patchVertices);
        end
    catch
        warning('BioctreeHDF5:PatchNotFound', 'Spatial patch not found: %s', opts.SpatialPatch);
    end
end

% Frequency indices
freqIndices = [];
if ~isempty(opts.FreqRange) || ~isempty(opts.FreqBands)
    try
        freqVec = h5read(filePath, '/temporal/frequency_vector');
        
        if ~isempty(opts.FreqRange)
            freqIndices = find(freqVec >= opts.FreqRange(1) & freqVec <= opts.FreqRange(2));
        end
        
        if ~isempty(opts.FreqBands)
            try
                bandRanges = h5read(filePath, '/indices/frequency_indices/bands');
                bandInfo = h5info(filePath, '/indices/frequency_indices/bands');
                
                bandIndices = [];
                for i = 1:length(opts.FreqBands)
                    bandName = opts.FreqBands{i};
                    
                    % Find band by name in attributes
                    for j = 1:length(bandInfo.Attributes)
                        if contains(bandInfo.Attributes(j).Name, 'name') && ...
                           strcmp(bandInfo.Attributes(j).Value, bandName)
                            bandIdx = str2double(regexp(bandInfo.Attributes(j).Name, '\d+', 'match'));
                            bandRange = bandRanges(bandIdx, :);
                            
                            freqMask = freqVec >= bandRange(1) & freqVec <= bandRange(2);
                            bandIndices = [bandIndices; find(freqMask)];
                            break;
                        end
                    end
                end
                
                if isempty(freqIndices)
                    freqIndices = unique(bandIndices);
                else
                    freqIndices = intersect(freqIndices, unique(bandIndices));
                end
            catch
                warning('BioctreeHDF5:BandNotFound', 'Could not find frequency bands');
            end
        end
    catch
        warning('BioctreeHDF5:FrequencyConversion', 'Could not convert frequency range to indices');
    end
end

end

function patchDataset = findPatchByName(filePath, patchName)
% Find spatial patch dataset by name
info = h5info(filePath, '/indices/spatial_indices');

for i = 1:length(info.Datasets)
    datasetName = info.Datasets(i).Name;
    if startsWith(datasetName, 'patch_')
        datasetPath = ['/indices/spatial_indices/' datasetName];
        try
            nameAttr = h5readatt(filePath, datasetPath, 'patch_name');
            if strcmp(nameAttr, patchName)
                patchDataset = datasetPath;
                return;
            end
        catch
            continue;
        end
    end
end

error('BioctreeHDF5:PatchNotFound', 'Spatial patch not found: %s', patchName);
end

function graphData = loadGraphData(filePath, opts, vertexIndices)
% Load graph structure data
graphData = struct();

% Load adjacency matrix (sparse format)
try
    adj_i = h5read(filePath, '/graph/adjacency_i');
    adj_j = h5read(filePath, '/graph/adjacency_j');
    adj_vals = h5read(filePath, '/graph/adjacency_values');
    
    % Get matrix size from attributes
    info = h5info(filePath, '/graph/adjacency_i');
    matSize = [];
    for i = 1:length(info.Attributes)
        if strcmp(info.Attributes(i).Name, 'matrix_size')
            matSize = info.Attributes(i).Value;
            break;
        end
    end
    
    if ~isempty(matSize)
        W = sparse(adj_i, adj_j, adj_vals, matSize(1), matSize(2));
        
        % Subset if vertex indices specified
        if ~isempty(vertexIndices)
            W = W(vertexIndices, vertexIndices);
        end
        
        graphData.W = W;
    end
catch
    % Adjacency matrix not available
end

% Load coordinates
try
    coords = h5read(filePath, '/graph/coordinates');
    if strcmp(opts.Precision, 'single')
        coords = single(coords);
    end
    
    if ~isempty(vertexIndices)
        coords = coords(vertexIndices, :);
    end
    
    graphData.coords = coords;
catch
    % Coordinates not available
end

% Load eigendecomposition
try
    eigenvals = h5read(filePath, '/graph/eigenvalues');
    eigenvecs = h5read(filePath, '/graph/eigenvectors');
    
    if strcmp(opts.Precision, 'single')
        eigenvals = single(eigenvals);
        eigenvecs = single(eigenvecs);
    end
    
    if ~isempty(vertexIndices)
        eigenvecs = eigenvecs(vertexIndices, :);
    end
    
    graphData.e = eigenvals;
    graphData.U = eigenvecs;
catch
    % Eigendecomposition not available
end

end

function temporalData = loadTemporalData(filePath, opts, timeIndices, freqIndices)
% Load temporal information
temporalData = struct();

% Load time vector
try
    timeVec = h5read(filePath, '/temporal/time_vector');
    if strcmp(opts.Precision, 'single')
        timeVec = single(timeVec);
    end
    
    if ~isempty(timeIndices)
        timeVec = timeVec(timeIndices);
    end
    
    temporalData.time_vector = timeVec;
catch
    % Time vector not available
end

% Load sampling frequency
try
    fs = h5read(filePath, '/temporal/sampling_frequency');
    temporalData.fs = double(fs);
catch
    % Sampling frequency not available
end

% Load frequency vector
try
    freqVec = h5read(filePath, '/temporal/frequency_vector');
    if strcmp(opts.Precision, 'single')
        freqVec = single(freqVec);
    end
    
    if ~isempty(freqIndices)
        freqVec = freqVec(freqIndices);
    end
    
    temporalData.frequency_vector = freqVec;
catch
    % Frequency vector not available
end

end

function signalData = loadRawData(filePath, opts, vertexIndices, timeIndices)
% Load raw signal data
signalData = struct();

% Load main signal matrix
try
    if isempty(vertexIndices) && isempty(timeIndices)
        % Load entire dataset
        signal = h5read(filePath, '/data/raw/signal');
    else
        % Load subset
        info = h5info(filePath, '/data/raw/signal');
        dataSize = info.Dataspace.Size;
        
        if isempty(vertexIndices)
            vertexIndices = 1:dataSize(1);
        end
        if isempty(timeIndices)
            timeIndices = 1:dataSize(2);
        end
        
        signal = h5read(filePath, '/data/raw/signal', ...
                       [vertexIndices(1), timeIndices(1)], ...
                       [length(vertexIndices), length(timeIndices)]);
    end
    
    if strcmp(opts.Precision, 'single')
        signal = single(signal);
    end
    
    signalData.signal = signal;
catch
    % Raw signal not available
end

end

function spectralData = loadSpectralData(filePath, opts, vertexIndices, timeIndices, freqIndices)
% Load spectral analysis data
spectralData = struct();

% Load GFT coefficients
try
    if isempty(vertexIndices) && isempty(timeIndices)
        gftCoeffs = h5read(filePath, '/data/spectral/gft_coeffs');
    else
        info = h5info(filePath, '/data/spectral/gft_coeffs');
        dataSize = info.Dataspace.Size;
        
        if isempty(vertexIndices)
            vertexIndices = 1:dataSize(1);
        end
        if isempty(timeIndices)
            timeIndices = 1:dataSize(2);
        end
        
        gftCoeffs = h5read(filePath, '/data/spectral/gft_coeffs', ...
                          [vertexIndices(1), timeIndices(1)], ...
                          [length(vertexIndices), length(timeIndices)]);
    end
    
    if strcmp(opts.Precision, 'single')
        gftCoeffs = single(gftCoeffs);
    end
    
    spectralData.gft_coeffs = gftCoeffs;
catch
    % GFT coefficients not available
end

% Load joint spectrum
try
    if isempty(freqIndices)
        jointSpec = h5read(filePath, '/data/spectral/joint_spectrum');
    else
        info = h5info(filePath, '/data/spectral/joint_spectrum');
        dataSize = info.Dataspace.Size;
        
        jointSpec = h5read(filePath, '/data/spectral/joint_spectrum', ...
                          [1, freqIndices(1)], ...
                          [dataSize(1), length(freqIndices)]);
    end
    
    if strcmp(opts.Precision, 'single')
        jointSpec = single(jointSpec);
    end
    
    spectralData.joint_spectrum = jointSpec;
catch
    % Joint spectrum not available
end

end

function derivedData = loadDerivedData(filePath, opts, vertexIndices, timeIndices)
% Load derived analysis data
derivedData = struct();

% Load gradients
try
    if isempty(timeIndices)
        gradients = h5read(filePath, '/data/derived/gradients');
    else
        info = h5info(filePath, '/data/derived/gradients');
        dataSize = info.Dataspace.Size;
        
        gradients = h5read(filePath, '/data/derived/gradients', ...
                          [1, timeIndices(1)], ...
                          [dataSize(1), length(timeIndices)]);
    end
    
    if strcmp(opts.Precision, 'single')
        gradients = single(gradients);
    end
    
    derivedData.gradients = gradients;
catch
    % Gradients not available
end

% Load total variation
try
    if isempty(vertexIndices) && isempty(timeIndices)
        tv = h5read(filePath, '/data/derived/total_variation');
    else
        info = h5info(filePath, '/data/derived/total_variation');
        dataSize = info.Dataspace.Size;
        
        if isempty(vertexIndices)
            vertexIndices = 1:dataSize(1);
        end
        if isempty(timeIndices)
            timeIndices = 1:dataSize(2);
        end
        
        tv = h5read(filePath, '/data/derived/total_variation', ...
                   [vertexIndices(1), timeIndices(1)], ...
                   [length(vertexIndices), length(timeIndices)]);
    end
    
    if strcmp(opts.Precision, 'single')
        tv = single(tv);
    end
    
    derivedData.total_variation = tv;
catch
    % Total variation not available
end

end

function analysisData = loadAnalysisData(filePath, opts, vertexIndices, ~)
% Load analysis results
analysisData = struct();

% Load signal statistics
try
    if isempty(vertexIndices)
        stats = h5read(filePath, '/analysis/statistics/signal_stats');
    else
        info = h5info(filePath, '/analysis/statistics/signal_stats');
        dataSize = info.Dataspace.Size;
        
        stats = h5read(filePath, '/analysis/statistics/signal_stats', ...
                      [vertexIndices(1), 1], ...
                      [length(vertexIndices), dataSize(2)]);
    end
    
    if strcmp(opts.Precision, 'single')
        stats = single(stats);
    end
    
    analysisData.signal_stats = stats;
catch
    % Signal statistics not available
end

% Load detection results
try
    events = h5read(filePath, '/analysis/detection/events');
    analysisData.events = events;
catch
    % Detection results not available
end

end

function indicesData = loadIndicesData(filePath, ~)
% Load indexing information
indicesData = struct();

% Load frequency band information
try
    bands = h5read(filePath, '/indices/frequency_indices/bands');
    indicesData.frequency_bands = bands;
    
    % Load band names from attributes
    info = h5info(filePath, '/indices/frequency_indices/bands');
    bandNames = {};
    for i = 1:length(info.Attributes)
        if contains(info.Attributes(i).Name, 'band_') && contains(info.Attributes(i).Name, 'name')
            bandIdx = str2double(regexp(info.Attributes(i).Name, '\d+', 'match'));
            bandNames{bandIdx} = info.Attributes(i).Value;
        end
    end
    indicesData.frequency_band_names = bandNames;
catch
    % Frequency band info not available
end

% Load spatial patch information
try
    patchInfo = h5info(filePath, '/indices/spatial_indices');
    patches = struct();
    
    for i = 1:length(patchInfo.Datasets)
        if startsWith(patchInfo.Datasets(i).Name, 'patch_')
            patchData = h5read(filePath, ['/indices/spatial_indices/' patchInfo.Datasets(i).Name]);
            
            % Get patch name from attributes
            try
                patchName = h5readatt(filePath, ['/indices/spatial_indices/' patchInfo.Datasets(i).Name], 'patch_name');
                patches.(patchName) = patchData;
            catch
                patches.(patchInfo.Datasets(i).Name) = patchData;
            end
        end
    end
    
    indicesData.spatial_patches = patches;
catch
    % Spatial patch info not available
end

end

function displayLoadedData(data)
% Display summary of loaded data
fprintf('  Loaded data summary:\n');

fields = fieldnames(data);
for i = 1:length(fields)
    fieldName = fields{i};
    fieldData = data.(fieldName);
    
    if isstruct(fieldData)
        subfields = fieldnames(fieldData);
        fprintf('    %s: %d subfields\n', fieldName, length(subfields));
        
        for j = 1:min(3, length(subfields)) % Show up to 3 subfields
            subfieldName = subfields{j};
            subfieldData = fieldData.(subfieldName);
            
            if isnumeric(subfieldData)
                fprintf('      %s: %s\n', subfieldName, mat2str(size(subfieldData)));
            end
        end
        
        if length(subfields) > 3
            fprintf('      ... and %d more\n', length(subfields) - 3);
        end
    else
        if isnumeric(fieldData)
            fprintf('    %s: %s\n', fieldName, mat2str(size(fieldData)));
        else
            fprintf('    %s: %s\n', fieldName, class(fieldData));
        end
    end
end

end