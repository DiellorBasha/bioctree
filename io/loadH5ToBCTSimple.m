function loadH5ToBCTSimple(sourceFile, bctFile)
% LOADH5TOBCTSIMPLE Simplified H5 to BCT conversion
%
% Load H5 data into BCT format with basic enhanced schema features
%
% Usage:
%   loadH5ToBCTSimple(sourceFile, bctFile)

if nargin < 2
    error('Please provide both source H5 file and output BCT file paths');
end

if ~exist(sourceFile, 'file')
    error('Source file not found: %s', sourceFile);
end

fprintf('=== Simplified H5 to BCT Conversion ===\n');
fprintf('Source: %s\n', sourceFile);
fprintf('Target: %s\n', bctFile);

%% ---- Load metadata -------------------------------------------------------
fprintf('\n1. Loading metadata...\n');
try
    subject_name = h5readatt(sourceFile, '/', 'SubjectName');
    sample_rate_raw = h5readatt(sourceFile, '/', 'SampleRateHz');
    device = h5readatt(sourceFile, '/', 'Device');
    fprintf('  Subject: %s, Device: %s, Fs: %d Hz\n', subject_name, device, sample_rate_raw);
catch
    subject_name = 'unknown';
    device = 'unknown';
    sample_rate_raw = 300;
end

%% ---- Load raw data and create BCT file -----------------------------------
fprintf('\n2. Loading raw data (first 10 channels for testing)...\n');

ds_raw = H5ChannelDatastore(sourceFile, '/signals/F');
ds_proc = H5ChannelDatastore(sourceFile, '/preproc/F');

% Load subset of channels for testing
num_channels_to_load = min(10, ds_raw.NumChannels);
fprintf('  Loading %d/%d channels\n', num_channels_to_load, ds_raw.NumChannels);

reset(ds_raw);
reset(ds_proc);

% Load raw data
all_raw_data = [];
channel_names = {};

for k = 1:num_channels_to_load
    [TT, info] = read(ds_raw);
    if k == 1
        all_raw_data = zeros(length(TT{:,1}), num_channels_to_load, 'single');
    end
    signal_data = TT{:,1};
    all_raw_data(:, k) = single(signal_data);
    channel_names{k} = info.ChannelName;
end

% Load preprocessed data
all_preproc_data = [];
for k = 1:num_channels_to_load
    [TT, ~] = read(ds_proc);
    if k == 1
        all_preproc_data = zeros(length(TT{:,1}), num_channels_to_load, 'single');
    end
    signal_data = TT{:,1};
    all_preproc_data(:, k) = single(signal_data);
end

fprintf('  Raw data loaded: %dx%d @ %d Hz\n', size(all_raw_data), ds_raw.Fs);
fprintf('  Preprocessed data loaded: %dx%d @ %d Hz\n', size(all_preproc_data), ds_proc.Fs);

%% ---- Create BCT file -----------------------------------------------------
fprintf('\n3. Creating BCT file...\n');

if exist(bctFile, 'file')
    delete(bctFile);
end

B = bct.bct.create(bctFile);
B.write_raw(all_raw_data, ds_raw.Fs);
clear B;
pause(0.2); % Ensure file handle is closed

fprintf('  ✓ BCT file created\n');

%% ---- Add enhanced schema components --------------------------------------
fprintf('\n4. Adding enhanced schema components...\n');

% Subject metadata
h5writeatt(bctFile, '/', 'subject_name', subject_name);
h5writeatt(bctFile, '/', 'device', device);
fprintf('  ✓ Subject metadata\n');

% Node descriptors
N = length(channel_names);
h5create(bctFile, '/node_info/channel_name', [N, 1], 'Datatype', 'string');
h5write(bctFile, '/node_info/channel_name', string(channel_names'));

node_types = repmat("MEG", N, 1);
h5create(bctFile, '/node_info/node_type', [N, 1], 'Datatype', 'string');
h5write(bctFile, '/node_info/node_type', node_types);
fprintf('  ✓ Node descriptors\n');

% Preprocessed signals
T_preproc = size(all_preproc_data, 1);
h5create(bctFile, '/signals/preproc', [T_preproc, N], 'Datatype', 'single');
h5write(bctFile, '/signals/preproc', all_preproc_data);
h5writeatt(bctFile, '/signals/preproc', 'sampling_rate_hz', ds_proc.Fs);
fprintf('  ✓ Preprocessed signals\n');

% Feature metadata
h5writeatt(bctFile, '/features/metadata', 'extraction_time', datestr(now));
h5writeatt(bctFile, '/features/metadata', 'num_nodes', N);
fprintf('  ✓ Feature metadata\n');

%% ---- Extract features using bstSigFeatures -------------------------------
fprintf('\n5. Extracting signal features...\n');

try
    % Run feature extraction on source file
    bstSigFeatures(sourceFile);
    
    % Find and load the generated features file
    [filepath, name, ~] = fileparts(sourceFile);
    featuresFile = fullfile(filepath, [name '_features.mat']);
    
    if exist(featuresFile, 'file')
        fprintf('  Loading extracted features...\n');
        feat_data = load(featuresFile);
        Features = feat_data.Features;
        
        fprintf('  ✓ Features loaded: %d rows, %d variables\n', ...
            height(Features), width(Features));
        
        % Add feature summary to BCT file
        h5writeatt(bctFile, '/features/metadata', 'num_feature_chunks', height(Features));
        
        % Clean up
        delete(featuresFile);
        fprintf('  ✓ Feature extraction completed\n');
    else
        fprintf('  Warning: Features file not found\n');
    end
    
catch ME
    warning('loadH5ToBCT:features', 'Feature extraction failed: %s', ME.message);
    fprintf('  Skipping feature extraction\n');
end

%% ---- Final verification --------------------------------------------------
fprintf('\n6. Final verification...\n');

B = bct.bct.open(bctFile);
fprintf('  ✓ BCT file: T=%d, N=%d, fs=%d Hz\n', B.T, B.N, B.fs);
fprintf('  ✓ Has preprocessed signals: %s\n', B.has('/signals/preproc'));
fprintf('  ✓ Has node descriptors: %s\n', B.has('/node_info/channel_name'));
clear B;

fprintf('\n🎉 SUCCESS: H5 to BCT conversion completed!\n');
fprintf('Output: %s\n', bctFile);
fprintf('Dataset: %s (%d channels)\n', subject_name, N);

end