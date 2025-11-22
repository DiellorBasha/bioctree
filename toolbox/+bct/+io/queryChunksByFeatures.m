function [chunks, indices] = queryChunksByFeatures(h5_file, query, options)
% QUERYCHUNKSBYFEATURES Query and retrieve chunks based on feature criteria
%
% This function enables efficient retrieval of data chunks based on
% feature values, allowing for feature-based indexing and analysis.
%
% Usage:
%   chunks = queryChunksByFeatures(h5_file, query)
%   [chunks, indices] = queryChunksByFeatures(h5_file, query, options)
%
% Inputs:
%   h5_file - Path to H5 file with chunk descriptors
%   query   - Query struct or function handle defining selection criteria
%   options - Optional parameters struct
%
% Outputs:
%   chunks  - Cell array of selected chunk data
%   indices - Chunk indices that match the query
%
% Query Examples:
%   % High alpha activity chunks
%   query.feature = 'BandPower_Band3';
%   query.operator = '>';
%   query.threshold = 10;
%
%   % Custom function
%   query = @(chunk_desc) chunk_desc.BandPower_Band3 > 10 & ...
%                         strcmp(chunk_desc.channel_name, 'O1');

arguments
    h5_file char
    query
    options.chunkGroup char = '/chunks'
    options.featureGroup char = '/features'
    options.dataGroup char = '/preproc/F'
    options.returnData logical = true
    options.maxChunks double = inf
end

if ~exist(h5_file, 'file')
    error('H5 file not found: %s', h5_file);
end

fprintf('Querying chunks from: %s\n', h5_file);

%% ---- Load chunk descriptors ---------------------------------------------
fprintf('Loading chunk descriptors...\n');
chunk_descriptors = load_chunk_descriptors(h5_file, options.chunkGroup);
fprintf('Loaded %d chunk descriptors\n', length(chunk_descriptors));

%% ---- Apply query criteria ----------------------------------------------
fprintf('Applying query criteria...\n');

if isa(query, 'function_handle')
    % Custom function query
    selected_mask = false(length(chunk_descriptors), 1);
    for i = 1:length(chunk_descriptors)
        try
            selected_mask(i) = query(chunk_descriptors(i));
        catch ME
            warning('Query failed for chunk %d: %s', i, ME.message);
        end
    end
else
    % Struct-based query
    selected_mask = apply_struct_query(chunk_descriptors, query);
end

indices = find(selected_mask);
num_selected = length(indices);

if num_selected == 0
    warning('No chunks match the query criteria');
    chunks = {};
    return;
end

% Limit results if requested
if num_selected > options.maxChunks
    fprintf('Limiting results to %d chunks (from %d matches)\n', ...
        options.maxChunks, num_selected);
    indices = indices(1:options.maxChunks);
    num_selected = options.maxChunks;
end

fprintf('Found %d matching chunks\n', num_selected);

%% ---- Retrieve chunk data -----------------------------------------------
chunks = {};

if options.returnData
    fprintf('Retrieving chunk data...\n');
    chunks = cell(num_selected, 1);
    
    for i = 1:num_selected
        chunk_idx = indices(i);
        chunk_desc = chunk_descriptors(chunk_idx);
        
        try
            % Load the actual signal data for this chunk
            chunk_data = load_chunk_data(h5_file, chunk_desc, options.dataGroup);
            chunks{i} = struct('descriptor', chunk_desc, 'data', chunk_data);
        catch ME
            warning('Failed to load data for chunk %d: %s', chunk_idx, ME.message);
            chunks{i} = struct('descriptor', chunk_desc, 'data', []);
        end
    end
    
    fprintf('Successfully loaded %d chunks\n', num_selected);
else
    % Return only descriptors
    chunks = chunk_descriptors(indices);
end

end

%% ---- Helper Functions --------------------------------------------------

function chunk_descriptors = load_chunk_descriptors(h5_file, chunk_group)
% Load chunk descriptors from H5 file
    
    try
        % Get all datasets in the chunk group
        info = h5info(h5_file, chunk_group);
        
        % Initialize descriptor struct
        chunk_descriptors = struct();
        
        % Load each field
        for i = 1:length(info.Datasets)
            dataset_name = info.Datasets(i).Name;
            dataset_path = [chunk_group '/' dataset_name];
            
            data = h5read(h5_file, dataset_path);
            
            % Convert to appropriate format
            if isa(data, 'string')
                data = cellstr(data);
            end
            
            % Store in struct array format
            if i == 1
                num_chunks = length(data);
                chunk_descriptors(num_chunks).placeholder = [];
            end
            
            for j = 1:num_chunks
                if iscell(data)
                    chunk_descriptors(j).(dataset_name) = data{j};
                else
                    chunk_descriptors(j).(dataset_name) = data(j);
                end
            end
        end
        
        % Remove placeholder field
        if isfield(chunk_descriptors, 'placeholder')
            chunk_descriptors = rmfield(chunk_descriptors, 'placeholder');
        end
        
    catch ME
        error('Failed to load chunk descriptors: %s', ME.message);
    end
end

function selected_mask = apply_struct_query(chunk_descriptors, query)
% Apply struct-based query to chunk descriptors
    
    selected_mask = true(length(chunk_descriptors), 1);
    
    if isfield(query, 'feature') && isfield(query, 'operator') && isfield(query, 'threshold')
        % Simple feature-based query
        feature_name = query.feature;
        operator = query.operator;
        threshold = query.threshold;
        
        if ~isfield(chunk_descriptors, feature_name)
            error('Feature %s not found in chunk descriptors', feature_name);
        end
        
        feature_values = [chunk_descriptors.(feature_name)];
        
        switch operator
            case '>'
                selected_mask = feature_values > threshold;
            case '>='
                selected_mask = feature_values >= threshold;
            case '<'
                selected_mask = feature_values < threshold;
            case '<='
                selected_mask = feature_values <= threshold;
            case '=='
                selected_mask = feature_values == threshold;
            case '~='
                selected_mask = feature_values ~= threshold;
            otherwise
                error('Unsupported operator: %s', operator);
        end
    end
    
    % Add channel filter if specified
    if isfield(query, 'channel')
        channel_names = {chunk_descriptors.channel_name};
        if iscell(query.channel)
            channel_mask = ismember(channel_names, query.channel);
        else
            channel_mask = strcmp(channel_names, query.channel);
        end
        selected_mask = selected_mask & channel_mask;
    end
    
    % Add time range filter if specified
    if isfield(query, 'time_range')
        center_times = [chunk_descriptors.center_time];
        time_mask = center_times >= query.time_range(1) & ...
                   center_times <= query.time_range(2);
        selected_mask = selected_mask & time_mask;
    end
    
    % Add multiple feature criteria
    if isfield(query, 'criteria')
        for c = 1:length(query.criteria)
            criterion = query.criteria(c);
            feature_values = [chunk_descriptors.(criterion.feature)];
            
            switch criterion.operator
                case '>'
                    crit_mask = feature_values > criterion.threshold;
                case '>='
                    crit_mask = feature_values >= criterion.threshold;
                case '<'
                    crit_mask = feature_values < criterion.threshold;
                case '<='
                    crit_mask = feature_values <= criterion.threshold;
                case '=='
                    crit_mask = feature_values == criterion.threshold;
                case '~='
                    crit_mask = feature_values ~= criterion.threshold;
                otherwise
                    error('Unsupported operator: %s', criterion.operator);
            end
            
            selected_mask = selected_mask & crit_mask;
        end
    end
end

function chunk_data = load_chunk_data(h5_file, chunk_desc, data_group)
% Load actual signal data for a chunk
    
    % Construct dataset path
    dataset_path = [data_group '/' chunk_desc.channel_name];
    
    % Read the full channel data
    full_data = h5read(h5_file, dataset_path);
    
    % Extract the chunk samples
    start_sample = max(1, chunk_desc.sample_start);
    end_sample = min(length(full_data), chunk_desc.sample_end);
    
    chunk_data = full_data(start_sample:end_sample);
    
    % Create metadata
    chunk_data_struct = struct();
    chunk_data_struct.signal = chunk_data;
    chunk_data_struct.time_vector = (0:length(chunk_data)-1) / ...
        h5readatt(h5_file, dataset_path, 'SampleRate') + chunk_desc.start_time;
    chunk_data_struct.sample_rate = h5readatt(h5_file, dataset_path, 'SampleRate');
    chunk_data_struct.duration = length(chunk_data) / chunk_data_struct.sample_rate;
    
    chunk_data = chunk_data_struct;
end

%% ---- Example Query Functions -------------------------------------------

function chunks = findHighAlphaChunks(h5_file, threshold, channels)
% Find chunks with high alpha activity
%
% Usage:
%   chunks = findHighAlphaChunks('data.h5', 15, {'O1', 'O2'});

    if nargin < 3, channels = {}; end
    
    query = struct();
    query.feature = 'BandPower_Band3';  % Alpha band
    query.operator = '>';
    query.threshold = threshold;
    
    if ~isempty(channels)
        query.channel = channels;
    end
    
    chunks = queryChunksByFeatures(h5_file, query);
end

function chunks = findArtifactChunks(h5_file, channels)
% Find chunks likely containing artifacts (high amplitude)
%
% Usage:
%   chunks = findArtifactChunks('data.h5', {'Fp1', 'Fp2'});

    if nargin < 2, channels = {}; end
    
    % Define multiple criteria for artifact detection
    query = struct();
    query.criteria = [
        struct('feature', 'PeakValue', 'operator', '>', 'threshold', 100); ... % High amplitude
        struct('feature', 'StandardDeviation', 'operator', '>', 'threshold', 20) ... % High variance
    ];
    
    if ~isempty(channels)
        query.channel = channels;
    end
    
    chunks = queryChunksByFeatures(h5_file, query);
end

function chunks = findEventRelatedChunks(h5_file, event_times, window)
% Find chunks around specific event times
%
% Usage:
%   chunks = findEventRelatedChunks('data.h5', [10, 25, 40], 2);

    if nargin < 3, window = 1; end  % 1 second window
    
    all_chunks = [];
    
    for i = 1:length(event_times)
        query = struct();
        query.time_range = [event_times(i) - window, event_times(i) + window];
        
        event_chunks = queryChunksByFeatures(h5_file, query);
        all_chunks = [all_chunks; event_chunks];
    end
    
    chunks = all_chunks;
end