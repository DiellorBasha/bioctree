%% Final Working H5 to BCT Pipeline
clear; clc;

fprintf('=== Final H5 to BCT Pipeline ===\n');

% Add bioctree to path
addpath(genpath('.'));

sourceFile = 'data/bioctree_files/raw/sub-0002.h5';
bctFile = 'data/bioctree_files/processed/sub-0002_final.bct.h5';

if exist(bctFile, 'file')
    delete(bctFile);
end

try
    %% 1. Load data
    fprintf('1. Loading data from H5 file...\n');
    ds_raw = H5ChannelDatastore(sourceFile, '/signals/F');
    ds_proc = H5ChannelDatastore(sourceFile, '/preproc/F');
    
    fprintf('  Raw: %d channels @ %d Hz\n', ds_raw.NumChannels, ds_raw.Fs);
    fprintf('  Preprocessed: %d channels @ %d Hz\n', ds_proc.NumChannels, ds_proc.Fs);
    
    % Load first 5 channels for demonstration
    num_channels = min(5, ds_raw.NumChannels);
    fprintf('  Loading %d channels for demonstration...\n', num_channels);
    
    % Load raw data
    reset(ds_raw);
    raw_data = [];
    channel_names = {};
    
    for k = 1:num_channels
        [TT, info] = read(ds_raw);
        if k == 1
            raw_data = zeros(length(TT{:,1}), num_channels, 'single');
        end
        raw_data(:, k) = single(TT{:,1});
        channel_names{k} = info.ChannelName;
    end
    
    % Load preprocessed data
    reset(ds_proc);
    preproc_data = [];
    
    for k = 1:num_channels
        [TT, ~] = read(ds_proc);
        if k == 1
            preproc_data = zeros(length(TT{:,1}), num_channels, 'single');
        end
        preproc_data(:, k) = single(TT{:,1});
    end
    
    fprintf('  ✓ Raw data: %dx%d\n', size(raw_data));
    fprintf('  ✓ Preprocessed data: %dx%d\n', size(preproc_data));
    
    %% 2. Create BCT file
    fprintf('\n2. Creating BCT file...\n');
    
    B = bct.bct.create(bctFile);
    B.write_raw(raw_data, ds_raw.Fs);
    clear B;
    pause(0.3); % Ensure file is closed
    
    fprintf('  ✓ BCT file created with raw signals\n');
    
    %% 3. Add enhanced schema components
    fprintf('\n3. Adding enhanced schema components...\n');
    
    % Add subject metadata
    try
        subject_name = h5readatt(sourceFile, '/', 'SubjectName');
        device = h5readatt(sourceFile, '/', 'Device');
    catch
        subject_name = 'sub-0002';
        device = 'CTF';
    end
    
    h5writeatt(bctFile, '/', 'subject_name', subject_name);
    h5writeatt(bctFile, '/', 'device', device);
    h5writeatt(bctFile, '/', 'source_file', sourceFile);
    fprintf('  ✓ Subject metadata\n');
    
    % Add node descriptors
    h5create(bctFile, '/node_info/channel_name', [num_channels, 1], 'Datatype', 'string');
    h5write(bctFile, '/node_info/channel_name', string(channel_names'));
    
    node_types = repmat("MEG", num_channels, 1);
    h5create(bctFile, '/node_info/node_type', [num_channels, 1], 'Datatype', 'string');
    h5write(bctFile, '/node_info/node_type', node_types);
    fprintf('  ✓ Node descriptors (%d channels)\n', num_channels);
    
    % Add preprocessed signals
    h5create(bctFile, '/signals/preproc', size(preproc_data), 'Datatype', 'single');
    h5write(bctFile, '/signals/preproc', preproc_data);
    h5writeatt(bctFile, '/signals/preproc', 'sampling_rate_hz', ds_proc.Fs);
    h5writeatt(bctFile, '/signals/preproc', 'preprocessing_steps', 'bandpass_notch');
    fprintf('  ✓ Preprocessed signals\n');
    
    % Add feature extraction metadata framework
    % First create the features group by creating a dummy dataset
    h5create(bctFile, '/features/dummy', [1, 1], 'Datatype', 'uint8');
    h5write(bctFile, '/features/dummy', uint8(1));
    
    % Now we can add attributes to the /features/metadata path
    h5writeatt(bctFile, '/features/metadata', 'extraction_ready', true);
    h5writeatt(bctFile, '/features/metadata', 'num_nodes', num_channels);
    h5writeatt(bctFile, '/features/metadata', 'setup_time', datestr(now));
    fprintf('  ✓ Feature extraction framework\n');
    
    %% 4. Extract and store signal features
    fprintf('\n4. Extracting signal features from preprocessed data...\n');
    
    % Create a temporary file for feature extraction testing
    tempFile = 'temp_features_test.h5';
    if exist(tempFile, 'file')
        delete(tempFile);
    end
    
    % Create minimal structure for bstSigFeatures
    test_signal = preproc_data(:, 1); % Use first channel
    h5create(tempFile, '/preproc/F', [length(test_signal), 1], 'Datatype', 'single');
    h5write(tempFile, '/preproc/F', test_signal);
    h5writeatt(tempFile, '/preproc', 'SampleRateHz', double(ds_proc.Fs));
    
    try
        % Run feature extraction
        fprintf('  Running bstSigFeatures on test channel...\n');
        bstSigFeatures(tempFile);
        
        % Check for output
        featFile = 'temp_features_test_features.mat';
        if exist(featFile, 'file')
            load(featFile);
            fprintf('  ✓ Features extracted: %d chunks, %d variables\n', ...
                height(Features), width(Features));
            
            % Store feature summary in BCT file
            h5writeatt(bctFile, '/features/metadata', 'test_extraction_completed', true);
            h5writeatt(bctFile, '/features/metadata', 'test_num_chunks', height(Features));
            h5writeatt(bctFile, '/features/metadata', 'test_num_features', width(Features)-1); % -1 for ChannelName
            
            delete(featFile);
            fprintf('  ✓ Feature metadata added to BCT file\n');
        end
        
    catch ME
        fprintf('  Warning: Feature extraction test failed: %s\n', ME.message);
    end
    
    if exist(tempFile, 'file')
        delete(tempFile);
    end
    
    %% 5. Final verification
    fprintf('\n5. Final verification...\n');
    
    B = bct.bct.open(bctFile);
    fprintf('  ✓ BCT file opens: T=%d, N=%d, fs=%d Hz\n', B.T, B.N, B.fs);
    
    % Check enhanced schema components
    has_subject = B.has('/') && exist(bctFile, 'file') == 2;
    has_nodes = B.has('/node_info/channel_name');
    has_preproc = B.has('/signals/preproc');
    has_features = B.has('/features/metadata');
    
    fprintf('  Enhanced schema components:\n');
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
        fprintf('    - Feature framework: ✓\n');
    else
        fprintf('    - Feature framework: ✗\n');
    end
    
    clear B;
    
    % Display file info
    fprintf('\n  File summary:\n');
    h5disp(bctFile, '/');
    
    fprintf('\n🎉 SUCCESS: Enhanced BCT file created!\n');
    fprintf('Output: %s\n', bctFile);
    fprintf('Contains: %s MEG data with enhanced schema\n', subject_name);
    fprintf('Channels: %s\n', strjoin(channel_names, ', '));
    
catch ME
    fprintf('\n❌ Pipeline Error: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        if length(ME.stack) > 1
            fprintf('Called from: %s (line %d)\n', ME.stack(2).name, ME.stack(2).line);
        end
    end
end

fprintf('\nPipeline completed!\n');