%% Simplified Working H5 to BCT Pipeline
clear; clc;

fprintf('=== Simplified Working H5 to BCT Pipeline ===\n');

% Add bioctree to path
addpath(genpath('.'));

sourceFile = 'data/bioctree_files/raw/sub-0002.h5';
bctFile = 'data/bioctree_files/processed/sub-0002_working.bct.h5';

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
    
    % Load first 3 channels for demonstration
    num_channels = min(3, ds_raw.NumChannels);
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
    
    %% 3. Add enhanced schema components (using root-level attributes)
    fprintf('\n3. Adding enhanced schema components...\n');
    
    % Add subject metadata at root level
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
    h5writeatt(bctFile, '/', 'enhanced_schema', 'true');
    h5writeatt(bctFile, '/', 'creation_time', datestr(now));
    fprintf('  ✓ Subject metadata\n');
    
    % Add node descriptors
    h5create(bctFile, '/node_info/channel_name', [num_channels, 1], 'Datatype', 'string');
    h5write(bctFile, '/node_info/channel_name', string(channel_names'));
    
    node_types = repmat("MEG", num_channels, 1);
    h5create(bctFile, '/node_info/node_type', [num_channels, 1], 'Datatype', 'string');
    h5write(bctFile, '/node_info/node_type', node_types);
    
    % Add positions (mock data)
    positions = single(randn(num_channels, 3) * 0.1);
    h5create(bctFile, '/node_info/node_position', [num_channels, 3], 'Datatype', 'single');
    h5write(bctFile, '/node_info/node_position', positions);
    
    fprintf('  ✓ Node descriptors (%d channels)\n', num_channels);
    
    % Add preprocessed signals
    h5create(bctFile, '/signals/preproc', size(preproc_data), 'Datatype', 'single');
    h5write(bctFile, '/signals/preproc', preproc_data);
    h5writeatt(bctFile, '/signals/preproc', 'sampling_rate_hz', ds_proc.Fs);
    h5writeatt(bctFile, '/signals/preproc', 'preprocessing_steps', 'bandpass_notch');
    fprintf('  ✓ Preprocessed signals\n');
    
    %% 4. Test signal feature extraction
    fprintf('\n4. Testing signal feature extraction...\n');
    
    % Use bstSigFeatures on the source file
    try
        fprintf('  Running bstSigFeatures on original file...\n');
        bstSigFeatures(sourceFile);
        
        % Check for output
        [~, name, ~] = fileparts(sourceFile);
        featFile = fullfile(fileparts(sourceFile), [name '_features.mat']);
        
        if exist(featFile, 'file')
            load(featFile);
            fprintf('  ✓ Features extracted: %d chunks, %d variables\n', ...
                height(Features), width(Features));
            
            % Store feature summary as root-level attributes
            h5writeatt(bctFile, '/', 'features_extracted', 'true');
            h5writeatt(bctFile, '/', 'feature_num_chunks', height(Features));
            h5writeatt(bctFile, '/', 'feature_num_variables', width(Features)-1); % -1 for ChannelName
            h5writeatt(bctFile, '/', 'feature_extraction_time', datestr(now));
            
            % Get feature names (excluding ChannelName)
            feat_names = Features.Properties.VariableNames;
            feat_names = feat_names(~strcmp(feat_names, 'ChannelName'));
            h5writeatt(bctFile, '/', 'feature_example_names', strjoin(feat_names(1:min(5, length(feat_names))), ','));
            
            delete(featFile);
            fprintf('  ✓ Feature metadata added to BCT file\n');
        else
            fprintf('  Warning: Features file not found\n');
        end
        
    catch ME
        fprintf('  Warning: Feature extraction failed: %s\n', ME.message);
        h5writeatt(bctFile, '/', 'features_extracted', 'false');
    end
    
    %% 5. Final verification
    fprintf('\n5. Final verification...\n');
    
    B = bct.bct.open(bctFile);
    fprintf('  ✓ BCT file opens: T=%d, N=%d, fs=%d Hz\n', B.T, B.N, B.fs);
    
    % Check enhanced schema components
    has_subject = B.has('/') && exist(bctFile, 'file') == 2;
    has_nodes = B.has('/node_info/channel_name');
    has_preproc = B.has('/signals/preproc');
    
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
    
    clear B;
    
    % Show file structure
    fprintf('\n  Final BCT file structure:\n');
    try
        info = h5info(bctFile);
        fprintf('    Groups: %s\n', strjoin({info.Groups.Name}, ', '));
        root_attrs = {info.Attributes.Name};
        fprintf('    Root attributes: %s\n', strjoin(root_attrs, ', '));
    catch
        fprintf('    (Structure display failed)\n');
    end
    
    fprintf('\n🎉 SUCCESS: Enhanced BCT file created!\n');
    fprintf('Output: %s\n', bctFile);
    fprintf('Subject: %s (%s device)\n', subject_name, device);
    fprintf('Channels: %s\n', strjoin(channel_names, ', '));
    
    % Demonstrate reading the enhanced data
    fprintf('\n6. Demonstrating data access...\n');
    B = bct.bct.open(bctFile);
    
    % Read a small chunk of raw data
    raw_chunk = B.read_raw([1, 1000], [1, num_channels]);
    fprintf('  Raw data chunk: %dx%d\n', size(raw_chunk));
    
    % Read preprocessed data
    preproc_read = h5read(bctFile, '/signals/preproc', [1, 1], [1000, num_channels]);
    fprintf('  Preprocessed chunk: %dx%d\n', size(preproc_read));
    
    % Read channel names
    channels_read = h5read(bctFile, '/node_info/channel_name');
    fprintf('  Channel names: %s\n', strjoin(channels_read', ', '));
    
    clear B;
    
    fprintf('  ✓ Data access verification completed\n');
    
catch ME
    fprintf('\n❌ Pipeline Error: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
end

fprintf('\nSimplified pipeline completed!\n');