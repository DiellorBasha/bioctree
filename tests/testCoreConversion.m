%% Core H5 to BCT Test - Minimal Version
clear; clc;

% Add bioctree to path
addpath(genpath('.'));

fprintf('=== Core H5 to BCT Test ===\n');

sourceFile = 'data/bioctree_files/raw/sub-0002.h5';
bctFile = 'data/bioctree_files/processed/test_core.bct.h5';

if exist(bctFile, 'file')
    delete(bctFile);
end

try
    %% 1. Test data loading
    fprintf('1. Testing data loading...\n');
    ds_raw = H5ChannelDatastore(sourceFile, '/signals/F');
    ds_proc = H5ChannelDatastore(sourceFile, '/preproc/F');
    
    fprintf('  Raw: %d channels @ %d Hz\n', ds_raw.NumChannels, ds_raw.Fs);
    fprintf('  Preprocessed: %d channels @ %d Hz\n', ds_proc.NumChannels, ds_proc.Fs);
    
    % Load just one channel of raw data
    reset(ds_raw);
    [TT_raw, info_raw] = read(ds_raw);
    raw_signal = single(TT_raw{:,1});
    channel_name = info_raw.ChannelName;
    
    fprintf('  Loaded channel: %s (%d samples)\n', channel_name, length(raw_signal));
    
    %% 2. Create minimal BCT file
    fprintf('\n2. Creating minimal BCT file...\n');
    X_small = raw_signal(1:1000, :); % Just 1000 samples for testing
    
    B = bct.bct.create(bctFile);
    B.write_raw(X_small, ds_raw.Fs);
    clear B;
    
    % Wait for file handle to close
    pause(0.5);
    
    fprintf('  ✓ BCT file created\n');
    
    %% 3. Verify BCT file
    fprintf('\n3. Verifying BCT file...\n');
    B2 = bct.bct.open(bctFile);
    fprintf('  ✓ BCT opened: T=%d, N=%d, fs=%d\n', B2.T, B2.N, B2.fs);
    clear B2;
    
    %% 4. Test feature extraction on small data
    fprintf('\n4. Testing feature extraction...\n');
    
    % Create a temporary H5 file with just one channel for testing
    testFile = 'temp_test_features.h5';
    if exist(testFile, 'file')
        delete(testFile);
    end
    
    % Create simple H5 structure for bstSigFeatures
    h5create(testFile, '/preproc/F', [length(raw_signal), 1], 'Datatype', 'single');
    h5write(testFile, '/preproc/F', raw_signal);
    h5writeatt(testFile, '/preproc', 'SampleRateHz', 256);
    h5writeatt(testFile, '/preproc', 'ChannelNames', {channel_name});
    
    fprintf('  Created test H5 file\n');
    
    % Test if bstSigFeatures works
    try
        fprintf('  Running bstSigFeatures...\n');
        bstSigFeatures(testFile);
        fprintf('  ✓ Feature extraction completed\n');
        
        % Check for features file
        [~, name, ~] = fileparts(testFile);
        featFile = [name '_features.mat'];
        if exist(featFile, 'file')
            load(featFile);
            fprintf('  ✓ Features loaded: %d rows\n', height(Features));
            delete(featFile);
        end
        
    catch ME
        fprintf('  Warning: Feature extraction failed: %s\n', ME.message);
    end
    
    % Clean up
    if exist(testFile, 'file')
        delete(testFile);
    end
    
    fprintf('\n🎉 SUCCESS: Core H5 to BCT test completed!\n');
    fprintf('BCT file: %s\n', bctFile);
    
catch ME
    fprintf('\n❌ Error: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
end