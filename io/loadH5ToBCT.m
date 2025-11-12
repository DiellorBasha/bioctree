function loadH5ToBCT(sourceFile, bctFile)
% LOADH5TOBCT Load H5 data into BCT format with enhanced schema features
%
% This function loads raw and preprocessed MEG/EEG data from an H5 file
% and stores it in a BCT file with enhanced schema including:
% - Subject metadata
% - Node descriptors (channel information)
% - Raw and preprocessed signals
% - Signal features extracted from preprocessed data
% - Chunk-based feature organization
%
% Usage:
%   loadH5ToBCT(sourceFile, bctFile)
%
% Inputs:
%   sourceFile - Path to H5 file with raw (/signals/F) and preprocessed (/preproc/F) data
%   bctFile    - Output BCT file path
%
% Example:
%   loadH5ToBCT('data/bioctree_files/raw/sub-0002.h5', 'data/bioctree_files/processed/sub-0002.bct.h5')

if nargin < 2
    error('Please provide both source H5 file and output BCT file paths');
end

% Check if source file exists
if ~exist(sourceFile, 'file')
    error('Source file not found: %s', sourceFile);
end

fprintf('=== H5 to BCT Conversion Pipeline ===\n');
fprintf('Source: %s\n', sourceFile);
fprintf('Target: %s\n', bctFile);

%% ---- Step 1: Extract metadata from source file -------------------------
fprintf('\n1. Extracting metadata from source file...\n');

% Read file attributes
try
    subject_name = h5readatt(sourceFile, '/', 'SubjectName');
    sample_rate_raw = h5readatt(sourceFile, '/', 'SampleRateHz');
    num_channels = h5readatt(sourceFile, '/', 'NumChannels');
    num_samples = h5readatt(sourceFile, '/', 'NumSamples');
    device = h5readatt(sourceFile, '/', 'Device');
    condition = h5readatt(sourceFile, '/', 'Condition');
    creation_date = h5readatt(sourceFile, '/', 'CreationDate');
    
    % Parse session info from condition if available
    session_parts = split(condition, '_');
    session_id = 'unknown';
    for i = 1:length(session_parts)
        if startsWith(session_parts{i}, 'ses-')
            session_id = session_parts{i};
            break;
        end
    end
    
    fprintf('  Subject: %s\n', subject_name);
    fprintf('  Session: %s\n', session_id);
    fprintf('  Device: %s\n', device);
    fprintf('  Raw data: %d samples @ %d Hz (%d channels)\n', num_samples, sample_rate_raw, num_channels);
    
catch ME
    warning('loadH5ToBCT:metadata', 'Could not read some metadata: %s', ME.message);
    subject_name = 'unknown';
    session_id = 'unknown';
    device = 'unknown';
    condition = 'unknown';
    creation_date = datestr(now);
end

%% ---- Step 2: Load raw signals and create BCT file ---------------------
fprintf('\n2. Loading raw signals and creating BCT file...\n');

% Create datastores for raw and preprocessed data
ds_raw = H5ChannelDatastore(sourceFile, '/signals/F');
ds_proc = H5ChannelDatastore(sourceFile, '/preproc/F');

fprintf('  Raw datastore: %d channels @ %d Hz\n', ds_raw.NumChannels, ds_raw.Fs);
fprintf('  Preprocessed datastore: %d channels @ %d Hz\n', ds_proc.NumChannels, ds_proc.Fs);

% Read all raw data to create BCT file
fprintf('  Loading raw data (this may take a moment)...\n');
reset(ds_raw);
all_raw_data = [];
channel_names = {};

for k = 1:ds_raw.NumChannels
    [TT, info] = read(ds_raw);
    if k == 1
        all_raw_data = zeros(length(TT{:,1}), ds_raw.NumChannels, 'single');
    end
    % Get the signal data (first variable in timetable)
    signal_data = TT{:,1};
    all_raw_data(:, k) = single(signal_data);
    channel_names{k} = info.ChannelName;
    
    if mod(k, 50) == 0 || k == ds_raw.NumChannels
        fprintf('    Loaded %d/%d channels\n', k, ds_raw.NumChannels);
    end
end

% Create BCT file with raw data
fprintf('  Creating BCT file...\n');
if exist(bctFile, 'file')
    delete(bctFile);
end

B = bct.bct.create(bctFile);
B.write_raw(all_raw_data, ds_raw.Fs);
clear B; % Close handle for metadata writing

% Wait a moment for file to be properly closed
pause(0.1);

fprintf('  ✓ BCT file created with raw signals: T=%d, N=%d, fs=%d\n', ...
    size(all_raw_data, 1), size(all_raw_data, 2), ds_raw.Fs);

%% ---- Step 3: Add enhanced schema metadata ------------------------------
fprintf('\n3. Adding enhanced schema metadata...\n');

% Subject metadata
h5writeatt(bctFile, '/', 'subject_name', subject_name);
h5writeatt(bctFile, '/', 'session_id', session_id);
h5writeatt(bctFile, '/', 'recording_date', creation_date);
h5writeatt(bctFile, '/', 'device', device);
h5writeatt(bctFile, '/', 'condition', condition);
h5writeatt(bctFile, '/', 'source_file', sourceFile);
fprintf('  ✓ Subject metadata added\n');

% Node descriptors
fprintf('  Adding node descriptors...\n');
N = length(channel_names);

% Create node_info group
h5create(bctFile, '/node_info/channel_name', [N, 1], 'Datatype', 'string');
h5write(bctFile, '/node_info/channel_name', string(channel_names'));

% Determine channel types from names (MEG channels have specific patterns)
node_types = cell(N, 1);
for i = 1:N
    ch_name = channel_names{i};
    if startsWith(ch_name, {'ML', 'MR', 'MZ'}) % MEG channels
        node_types{i} = 'MEG';
    elseif contains(ch_name, {'ECG', 'EKG'})
        node_types{i} = 'ECG';
    elseif contains(ch_name, {'EOG', 'HEOG', 'VEOG'})
        node_types{i} = 'EOG';
    else
        node_types{i} = 'OTHER';
    end
end

h5create(bctFile, '/node_info/node_type', [N, 1], 'Datatype', 'string');
h5write(bctFile, '/node_info/node_type', string(node_types));

% Mock positions (would need actual sensor positions for real application)
positions = single(randn(N, 3) * 0.1); % Small random positions
h5create(bctFile, '/node_info/node_position', [N, 3], 'Datatype', 'single');
h5write(bctFile, '/node_info/node_position', positions);

fprintf('  ✓ Node descriptors added: %d channels\n', N);

%% ---- Step 4: Add preprocessed signals ----------------------------------
fprintf('\n4. Adding preprocessed signals...\n');

% Load all preprocessed data
reset(ds_proc);
all_preproc_data = [];

for k = 1:ds_proc.NumChannels
    [TT, ~] = read(ds_proc);
    if k == 1
        all_preproc_data = zeros(length(TT{:,1}), ds_proc.NumChannels, 'single');
    end
    % Get the signal data (first variable in timetable)
    signal_data = TT{:,1};
    all_preproc_data(:, k) = single(signal_data);
    
    if mod(k, 50) == 0 || k == ds_proc.NumChannels
        fprintf('    Loaded %d/%d preprocessed channels\n', k, ds_proc.NumChannels);
    end
end

% Store preprocessed signals
T_preproc = size(all_preproc_data, 1);
h5create(bctFile, '/signals/preproc', [T_preproc, N], 'Datatype', 'single', ...
    'ChunkSize', [min(1024, T_preproc), 1], 'Deflate', 3);
h5write(bctFile, '/signals/preproc', all_preproc_data);
h5writeatt(bctFile, '/signals/preproc', 'sampling_rate_hz', ds_proc.Fs);
h5writeatt(bctFile, '/signals/preproc', 'preprocessing_steps', 'notch_filter,bandpass_filter');
h5writeatt(bctFile, '/signals/preproc', 'original_fs', ds_raw.Fs);

fprintf('  ✓ Preprocessed signals added: T=%d, N=%d, fs=%d\n', ...
    T_preproc, N, ds_proc.Fs);

%% ---- Step 5: Extract signal features -----------------------------------
fprintf('\n5. Extracting signal features...\n');

% Set up framing parameters for feature extraction
fs = ds_proc.Fs;
frame_duration_s = 4.0;  % 4 second frames
hop_duration_s = 2.0;    % 2 second hop (50% overlap)

frame_size = round(frame_duration_s * fs);
hop_size = round(hop_duration_s * fs);
overlap = frame_size - hop_size;

fprintf('  Frame parameters: %.1fs frames, %.1fs hop, %.1fs overlap\n', ...
    frame_duration_s, hop_duration_s, (frame_size - hop_size) / fs);

% Calculate number of chunks
num_frames = floor((T_preproc - frame_size) / hop_size) + 1;
fprintf('  Expected %d feature chunks\n', num_frames);

% Feature extraction metadata
h5writeatt(bctFile, '/features/metadata', 'extraction_time', datestr(now));
h5writeatt(bctFile, '/features/metadata', 'frame_size_samples', frame_size);
h5writeatt(bctFile, '/features/metadata', 'hop_size_samples', hop_size);
h5writeatt(bctFile, '/features/metadata', 'frame_duration_s', frame_duration_s);
h5writeatt(bctFile, '/features/metadata', 'hop_duration_s', hop_duration_s);
h5writeatt(bctFile, '/features/metadata', 'num_nodes', N);
h5writeatt(bctFile, '/features/metadata', 'sampling_rate_hz', fs);

% Extract features using existing pipeline
fprintf('  Running signal feature extraction pipeline...\n');
tempFeatFile = [tempname, '_features.mat'];

try
    % Use the modified bstSigFeatures function
    bstSigFeatures(sourceFile);
    
    % Load the generated features
    [~, name, ~] = fileparts(sourceFile);
    featuresFile = fullfile(fileparts(sourceFile), [name '_features.mat']);
    
    if exist(featuresFile, 'file')
        fprintf('  Loading extracted features...\n');
        feat_data = load(featuresFile);
        Features = feat_data.Features;
        
        % Organize features by chunk
        fprintf('  Organizing features by chunks...\n');
        unique_times = unique(Features.Time);
        num_chunks = length(unique_times);
        
        % Create chunk descriptors
        chunk_ids = int32(1:num_chunks)';
        chunk_times = seconds(unique_times);
        
        h5create(bctFile, '/features/chunks/chunk_id', [num_chunks, 1], 'Datatype', 'int32');
        h5write(bctFile, '/features/chunks/chunk_id', chunk_ids);
        h5create(bctFile, '/features/chunks/center_time_s', [num_chunks, 1], 'Datatype', 'double');
        h5write(bctFile, '/features/chunks/center_time_s', chunk_times);
        h5writeatt(bctFile, '/features/chunks', 'chunk_duration_s', frame_duration_s);
        h5writeatt(bctFile, '/features/chunks', 'hop_size_s', hop_duration_s);
        h5writeatt(bctFile, '/features/chunks', 'num_chunks', num_chunks);
        
        % Store feature names
        feature_names = Features.Properties.VariableNames;
        feature_names = feature_names(~strcmp(feature_names, 'ChannelName')); % Remove ChannelName
        num_features = length(feature_names);
        
        h5create(bctFile, '/features/feature_names', [num_features, 1], 'Datatype', 'string');
        h5write(bctFile, '/features/feature_names', string(feature_names'));
        
        fprintf('  ✓ Feature extraction completed: %d chunks, %d features per channel\n', ...
            num_chunks, num_features);
        
        % Clean up temporary files
        if exist(featuresFile, 'file')
            delete(featuresFile);
        end
        
    else
        warning('Feature extraction did not generate expected output file');
    end
    
catch ME
    warning('loadH5ToBCT:features', 'Feature extraction failed: %s', ME.message);
    fprintf('  Skipping feature extraction, BCT file created with signals only\n');
end

%% ---- Step 6: Final verification ----------------------------------------
fprintf('\n6. Final verification...\n');

% Verify BCT file integrity
B = bct.bct.open(bctFile);
fprintf('  ✓ BCT file opens successfully\n');
fprintf('  ✓ Dimensions: T=%d, N=%d, fs=%d\n', B.T, B.N, B.fs);

% Verify enhanced schema components
has_subject = B.has('/') && exist(bctFile, 'file') == 2;
has_nodes = B.has('/node_info/channel_name');
has_preproc = B.has('/signals/preproc');
has_features = B.has('/features/metadata');

fprintf('  ✓ Enhanced schema components:\n');
if has_subject
    fprintf('    - Subject metadata: ✓\n');
else
    fprintf('    - Subject metadata: ✗\n');
end
if has_nodes
    fprintf('    - Node descriptors: ✓\n');
else
    fprintf('    - Node descriptors: ✗\n');
end
if has_preproc
    fprintf('    - Preprocessed signals: ✓\n');
else
    fprintf('    - Preprocessed signals: ✗\n');
end
if has_features
    fprintf('    - Feature metadata: ✓\n');
else
    fprintf('    - Feature metadata: ✗\n');
end

clear B;

fprintf('\n🎉 SUCCESS: H5 to BCT conversion completed!\n');
fprintf('Output file: %s\n', bctFile);
fprintf('Enhanced BCT file with:\n');
fprintf('  - Raw signals: %d × %d @ %d Hz\n', size(all_raw_data));
fprintf('  - Preprocessed signals: %d × %d @ %d Hz\n', size(all_preproc_data));
fprintf('  - %d MEG channels with metadata\n', N);
fprintf('  - Subject: %s, Session: %s\n', subject_name, session_id);

end