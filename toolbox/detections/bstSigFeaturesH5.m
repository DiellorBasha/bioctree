function bstSigFeaturesH5(outFile, options)
% BSTSIGFEATURESH5 Signal feature extraction with H5 chunk descriptor storage
%
% This function extracts features from preprocessed H5 data and stores them
% as chunk descriptors in the same H5 file, enabling efficient chunk-based
% indexing and retrieval.
%
% Usage:
%   bstSigFeaturesH5(outFile)
%   bstSigFeaturesH5(outFile, options)
%
% Inputs:
%   outFile - Path to H5 file containing preprocessed data at '/preproc/F'
%   options - Optional struct with fields:
%             .frameSize - Frame size in seconds (default: 4)
%             .hopSize - Hop size in seconds (default: 2) % 50% overlap
%             .chunkGroup - H5 group for chunk descriptors (default: '/chunks')
%             .featureGroup - H5 group for features (default: '/features')
%             .overwrite - Overwrite existing features (default: false)

arguments
    outFile char
    options.frameSize (1,1) double = 4    % 4 seconds
    options.hopSize (1,1) double = 2      % 2 seconds (50% overlap)
    options.chunkGroup char = '/chunks'
    options.featureGroup char = '/features'
    options.overwrite logical = false
end

if ~exist(outFile, 'file')
    error('File not found: %s', outFile);
end

fprintf('Starting H5-based signal feature extraction pipeline...\n');
fprintf('Input file: %s\n', outFile);

%% ---- Load preprocessed data ---------------------------------------------
fprintf('Loading preprocessed data...\n');
ds_proc = H5ChannelDatastore(outFile, '/preproc/F');
[TT, info] = read(ds_proc);

% Get sampling parameters
Fs = ds_proc.Fs;
frame = round(options.frameSize * Fs);
hop = round(options.hopSize * Fs);
overlap = frame - hop;

fprintf('Framing parameters:\n');
fprintf('  Sampling rate: %d Hz\n', Fs);
fprintf('  Frame size: %d samples (%.1f s)\n', frame, frame/Fs);
fprintf('  Hop size: %d samples (%.1f s)\n', hop, hop/Fs);
fprintf('  Overlap: %.1f%%\n', (overlap/frame)*100);

%% ---- Check if features already exist -----------------------------------
if ~options.overwrite && h5_group_exists(outFile, options.featureGroup)
    fprintf('Features already exist. Use options.overwrite=true to recreate.\n');
    return;
end

%% ---- Setup feature extractors ------------------------------------------
fprintf('Setting up feature extractors...\n');

% Time-domain features
timeFE = signalTimeFeatureExtractor( ...
    'SampleRate', Fs, ...
    'FrameSize', frame, ...
    'FrameOverlapLength', overlap, ...
    'RMS', true, ...
    'PeakValue', true, ...
    'MeanLevel', true, ...
    'StandardDeviation', true);

% Frequency-domain features  
freqFE = signalFrequencyFeatureExtractor( ...
    'SampleRate', Fs, ...
    'FrameSize', frame, ...
    'FrameOverlapLength', overlap, ...
    'SpectralCentroid', true, ...
    'SpectralRolloffPoint', true, ...
    'SpectralEntropy', true);

% Band power extractor with canonical EEG/MEG bands
freqFE = setExtractorParameters(freqFE, 'BandPower', ...
    'FrequencyBands', [1 4; 4 8; 8 12; 12 30; 30 min(60, Fs/2-1)], ...
    'Enabled', true);

%% ---- Process all channels and create chunk descriptors ----------------
fprintf('Processing channels and creating chunk descriptors...\n');
reset(ds_proc);

% Initialize chunk tracking
chunk_id = 1;
chunk_descriptors = [];
all_features = [];

% Get channel list
channel_names = ds_proc.Files;

for ch_idx = 1:length(channel_names)
    fprintf('Processing channel %d/%d: %s\n', ch_idx, length(channel_names), channel_names{ch_idx});
    
    % Read channel data
    [TT_ch, ~] = ds_proc.readByName(channel_names{ch_idx});
    
    % Extract features for this channel
    FTT = extract_channel_features(TT_ch, timeFE, freqFE, Fs, frame, hop);
    
    % Create chunk descriptors for this channel
    for feat_idx = 1:height(FTT)
        % Calculate chunk time bounds
        chunk_start_time = FTT.Time(feat_idx) - seconds(options.frameSize/2);
        chunk_end_time = FTT.Time(feat_idx) + seconds(options.frameSize/2);
        
        % Create chunk descriptor
        chunk_desc = struct();
        chunk_desc.chunk_id = chunk_id;
        chunk_desc.channel_name = channel_names{ch_idx};
        chunk_desc.start_time = seconds(chunk_start_time);
        chunk_desc.end_time = seconds(chunk_end_time);
        chunk_desc.center_time = seconds(FTT.Time(feat_idx));
        chunk_desc.duration = options.frameSize;
        chunk_desc.sample_start = round(chunk_desc.start_time * Fs) + 1;
        chunk_desc.sample_end = round(chunk_desc.end_time * Fs);
        
        % Add feature values to chunk descriptor
        feature_names = FTT.Properties.VariableNames;
        for f = 1:length(feature_names)
            if ~strcmp(feature_names{f}, 'Time')
                chunk_desc.(feature_names{f}) = FTT{feat_idx, feature_names{f}};
            end
        end
        
        chunk_descriptors = [chunk_descriptors; chunk_desc];
        chunk_id = chunk_id + 1;
    end
    
    % Add channel name to features
    FTT.ChannelName = repmat({channel_names{ch_idx}}, height(FTT), 1);
    all_features = [all_features; FTT];
end

%% ---- Store features and chunk descriptors in H5 file ------------------
fprintf('Storing features and chunk descriptors in H5 file...\n');

% Remove existing feature groups if overwriting
if options.overwrite
    try
        h5_delete_group(outFile, options.featureGroup);
        h5_delete_group(outFile, options.chunkGroup);
    catch
        % Groups may not exist
    end
end

% Store chunk descriptors
store_chunk_descriptors(outFile, options.chunkGroup, chunk_descriptors);

% Store feature matrix for efficient access
store_feature_matrix(outFile, options.featureGroup, all_features, chunk_descriptors);

% Store metadata
store_extraction_metadata(outFile, options, Fs, frame, hop, channel_names);

fprintf('Feature extraction completed!\n');
fprintf('Total chunks created: %d\n', length(chunk_descriptors));
fprintf('Chunk descriptors stored at: %s\n', options.chunkGroup);
fprintf('Feature matrix stored at: %s\n', options.featureGroup);

% Create index for fast lookup
create_chunk_index(outFile, options.chunkGroup, chunk_descriptors);

fprintf('Chunk index created for fast feature-based lookup\n');

end

%% ---- Helper Functions --------------------------------------------------

function FTT = extract_channel_features(TT, timeFE, freqFE, Fs, frame, hop)
% Extract features from single channel timetable
    try
        x = TT.x;
        
        % Extract time-domain features
        timeFT = extract(timeFE, x);
        
        % Extract frequency-domain features  
        freqFT = extract(freqFE, x);
        
        % Combine features
        FT = [timeFT, freqFT];
        
        % Create time vector for frames
        num_frames = size(FT, 1);
        frame_times = (0:num_frames-1) * (hop/Fs);
        frame_times = frame_times + (frame/2)/Fs; % Center time of each frame
        
        % Convert to timetable
        FTT = array2timetable(FT, 'RowTimes', seconds(frame_times));
        
    catch ME
        warning('%s', ['Feature extraction failed: ' ME.message]);
        FTT = timetable();
    end
end

function store_chunk_descriptors(filename, group_path, chunk_descriptors)
% Store chunk descriptors as structured H5 data
    
    % Create group
    try
        h5create_group(filename, group_path);
    catch
        % Group may already exist
    end
    
    % Convert struct array to individual datasets
    fields = fieldnames(chunk_descriptors);
    
    for f = 1:length(fields)
        field_name = fields{f};
        field_data = {chunk_descriptors.(field_name)};
        
        dataset_path = [group_path '/' field_name];
        
        if isnumeric(field_data{1})
            % Numeric data
            data_array = cell2mat(field_data);
            h5create(filename, dataset_path, size(data_array), 'Datatype', 'double');
            h5write(filename, dataset_path, data_array);
        else
            % String data
            h5create(filename, dataset_path, [length(field_data), 1], ...
                'Datatype', 'string');
            h5write(filename, dataset_path, string(field_data));
        end
    end
    
    % Add attributes
    h5writeatt(filename, group_path, 'Description', ...
        'Chunk descriptors for feature-based indexing');
    h5writeatt(filename, group_path, 'CreationTime', datestr(now));
end

function store_feature_matrix(filename, group_path, all_features, chunk_descriptors)
% Store feature matrix for efficient bulk access
    
    try
        h5create_group(filename, group_path);
    catch
        % Group may already exist
    end
    
    % Convert features to numeric matrix
    numeric_features = all_features(:, varfun(@isnumeric, all_features, 'OutputFormat', 'uniform'));
    feature_matrix = table2array(numeric_features);
    feature_names = numeric_features.Properties.VariableNames;
    
    % Store feature matrix
    matrix_path = [group_path '/feature_matrix'];
    h5create(filename, matrix_path, size(feature_matrix), 'Datatype', 'double');
    h5write(filename, matrix_path, feature_matrix);
    
    % Store feature names
    names_path = [group_path '/feature_names'];
    h5create(filename, names_path, [length(feature_names), 1], 'Datatype', 'string');
    h5write(filename, names_path, string(feature_names));
    
    % Store chunk IDs for alignment
    chunk_ids = [chunk_descriptors.chunk_id];
    ids_path = [group_path '/chunk_ids'];
    h5create(filename, ids_path, size(chunk_ids), 'Datatype', 'double');
    h5write(filename, ids_path, chunk_ids);
    
    % Add attributes
    h5writeatt(filename, group_path, 'Description', ...
        'Feature matrix aligned with chunk descriptors');
    h5writeatt(filename, group_path, 'NumChunks', length(chunk_descriptors));
    h5writeatt(filename, group_path, 'NumFeatures', length(feature_names));
end

function store_extraction_metadata(filename, options, Fs, frame, hop, channel_names)
% Store extraction parameters as metadata
    
    meta_group = '/extraction_metadata';
    try
        h5create_group(filename, meta_group);
    catch
        % Group may already exist
    end
    
    % Store parameters
    h5writeatt(filename, meta_group, 'SamplingRate', Fs);
    h5writeatt(filename, meta_group, 'FrameSize_samples', frame);
    h5writeatt(filename, meta_group, 'HopSize_samples', hop);
    h5writeatt(filename, meta_group, 'FrameSize_seconds', options.frameSize);
    h5writeatt(filename, meta_group, 'HopSize_seconds', options.hopSize);
    h5writeatt(filename, meta_group, 'OverlapPercent', ((frame-hop)/frame)*100);
    h5writeatt(filename, meta_group, 'NumChannels', length(channel_names));
    h5writeatt(filename, meta_group, 'ExtractionTime', datestr(now));
end

function create_chunk_index(filename, group_path, chunk_descriptors)
% Create indices for fast feature-based chunk lookup
    
    index_group = [group_path '/indices'];
    try
        h5create_group(filename, index_group);
    catch
        % Group may already exist
    end
    
    % Create time-based index
    times = [chunk_descriptors.center_time];
    time_path = [index_group '/time_index'];
    h5create(filename, time_path, size(times), 'Datatype', 'double');
    h5write(filename, time_path, times);
    
    % Create channel-based index
    channels = {chunk_descriptors.channel_name};
    unique_channels = unique(channels);
    
    for ch = 1:length(unique_channels)
        ch_name = unique_channels{ch};
        ch_indices = find(strcmp(channels, ch_name));
        
        ch_path = [index_group '/channel_' strrep(ch_name, ' ', '_')];
        h5create(filename, ch_path, size(ch_indices), 'Datatype', 'double');
        h5write(filename, ch_path, ch_indices);
    end
    
    h5writeatt(filename, index_group, 'Description', ...
        'Indices for fast chunk lookup by time and channel');
end

%% ---- Utility Functions -------------------------------------------------

function exists = h5_group_exists(filename, group_path)
% Check if H5 group exists
    try
        info = h5info(filename, group_path);
        exists = true;
    catch
        exists = false;
    end
end

function h5create_group(filename, group_path)
% Create H5 group, handling nested paths
    path_parts = strsplit(group_path, '/');
    path_parts = path_parts(~cellfun(@isempty, path_parts));
    
    current_path = '';
    for i = 1:length(path_parts)
        current_path = [current_path '/' path_parts{i}];
        try
            h5info(filename, current_path);
        catch
            % Group doesn't exist, create it
            if i == 1
                h5create(filename, current_path, [1 1], 'Datatype', 'double');
                h5write(filename, current_path, 0);
                % This creates a minimal dataset that acts as a group marker
            end
        end
    end
end

function h5_delete_group(filename, group_path)
% Delete H5 group (placeholder - H5 doesn't support group deletion easily)
    warning('H5 group deletion not implemented. Overwriting datasets instead.');
end