%% Quick Enhanced BCT Schema Verification
% This script performs a quick check to ensure the BCT class works 
% correctly with the enhanced schema features

clear; clc;

fprintf('=== Quick Enhanced BCT Schema Verification ===\n\n');

% Add bioctree to path
addpath(genpath('.'));

% Create test file
test_file = fullfile(tempdir, 'quick_enhanced_test.h5');
if exist(test_file, 'file')
    delete(test_file);
end

try
    fprintf('1. Creating BCT file with enhanced schema...\n');
    
    % Create BCT object
    B = bct.bct.create(test_file);
    
    % Basic signal data
    T = 50; N = 6; fs = 200;
    X = single(randn(T, N));
    
    fprintf('   - Writing raw signals (%dx%d at %d Hz)...\n', T, N, fs);
    B.write_raw(X, fs);
    
    % Enhanced schema features
    fprintf('2. Adding enhanced schema features...\n');
    
    % Subject metadata
    fprintf('   - Adding subject metadata...\n');
    h5writeatt(test_file, '/', 'subject_name', 'QUICK_TEST_SUBJ');
    h5writeatt(test_file, '/', 'session_id', 'QUICK_SES');
    h5writeatt(test_file, '/', 'recording_date', '2025-11-05');
    
    % Node descriptors
    fprintf('   - Adding node descriptors...\n');
    channel_names = string(compose("CH%02d", 1:N));
    node_types = repmat("EEG", N, 1);
    positions = single(randn(N, 3));
    
    h5create(test_file, '/node_info/channel_name', [N, 1], 'Datatype', 'string');
    h5write(test_file, '/node_info/channel_name', channel_names');
    
    h5create(test_file, '/node_info/node_type', [N, 1], 'Datatype', 'string');
    h5write(test_file, '/node_info/node_type', node_types);
    
    h5create(test_file, '/node_info/node_position', [N, 3], 'Datatype', 'single');
    h5write(test_file, '/node_info/node_position', positions);
    
    % Preprocessed signals
    fprintf('   - Adding preprocessed signals...\n');
    X_preproc = single(0.85 * X + 0.1 * randn(T, N));
    h5create(test_file, '/signals/preproc', [T, N], 'Datatype', 'single');
    h5write(test_file, '/signals/preproc', X_preproc);
    h5writeatt(test_file, '/signals/preproc', 'sampling_rate_hz', fs);
    h5writeatt(test_file, '/signals/preproc', 'preprocessing_steps', 'bandpass:1-100Hz,notch:60Hz');
    
    % Feature extraction metadata
    fprintf('   - Adding feature extraction metadata...\n');
    h5writeatt(test_file, '/features/metadata', 'extraction_time', datestr(now));
    h5writeatt(test_file, '/features/metadata', 'frame_size_samples', 800);  % 4s at 200Hz
    h5writeatt(test_file, '/features/metadata', 'hop_size_samples', 400);    % 2s at 200Hz
    h5writeatt(test_file, '/features/metadata', 'num_nodes', N);
    
    % Mock chunk descriptors
    num_chunks = 8;
    chunk_ids = int32(1:num_chunks)';
    chunk_times = (0:num_chunks-1)' * 2.0 + 2.0;  % Every 2 seconds, centered at 2s
    
    h5create(test_file, '/features/chunks/chunk_id', size(chunk_ids), 'Datatype', 'int32');
    h5write(test_file, '/features/chunks/chunk_id', chunk_ids);
    h5create(test_file, '/features/chunks/center_time_s', size(chunk_times), 'Datatype', 'double');
    h5write(test_file, '/features/chunks/center_time_s', chunk_times);
    h5writeatt(test_file, '/features/chunks', 'chunk_duration_s', 4.0);
    h5writeatt(test_file, '/features/chunks', 'hop_size_s', 2.0);
    
    fprintf('3. Verifying BCT class compatibility...\n');
    
    % Test BCT methods still work
    fprintf('   - Testing BCT properties...\n');
    assert(B.T == T, 'BCT T property failed');
    assert(B.N == N, 'BCT N property failed');
    assert(B.fs == fs, 'BCT fs property failed');
    
    fprintf('   - Testing axis reading...\n');
    time_axis = B.read_axis('time_s');
    node_axis = B.read_axis('node_id');
    assert(length(time_axis) == T, 'Time axis length incorrect');
    assert(length(node_axis) == N, 'Node axis length incorrect');
    
    fprintf('   - Testing path checking...\n');
    assert(B.has('/signals/raw'), 'Raw signals not detected');
    assert(B.has('/axes/time_s'), 'Time axis not detected');
    assert(B.has('/axes/node_id'), 'Node axis not detected');
    assert(B.has('/node_info/channel_name'), 'Channel names not detected');
    assert(B.has('/signals/preproc'), 'Preprocessed signals not detected');
    
    fprintf('4. Verifying enhanced features...\n');
    
    % Read back enhanced features
    fprintf('   - Reading subject metadata...\n');
    subject = h5readatt(test_file, '/', 'subject_name');
    session = h5readatt(test_file, '/', 'session_id');
    date = h5readatt(test_file, '/', 'recording_date');
    
    fprintf('     Subject: %s, Session: %s, Date: %s\n', subject, session, date);
    
    fprintf('   - Reading node descriptors...\n');
    channels_read = h5read(test_file, '/node_info/channel_name');
    types_read = h5read(test_file, '/node_info/node_type');
    positions_read = h5read(test_file, '/node_info/node_position');
    
    fprintf('     Channels: %s\n', strjoin(channels_read', ', '));
    fprintf('     Types: %s (all %s)\n', strjoin(unique(types_read)', ', '), types_read{1});
    fprintf('     Positions: %dx%d matrix\n', size(positions_read));
    
    fprintf('   - Reading preprocessed signals...\n');
    preproc_data = h5read(test_file, '/signals/preproc');
    preproc_fs = h5readatt(test_file, '/signals/preproc', 'sampling_rate_hz');
    preproc_steps = h5readatt(test_file, '/signals/preproc', 'preprocessing_steps');
    
    fprintf('     Preprocessed data: %dx%d at %d Hz\n', size(preproc_data), preproc_fs);
    fprintf('     Processing: %s\n', preproc_steps);
    
    fprintf('   - Reading feature metadata...\n');
    extraction_time = h5readatt(test_file, '/features/metadata', 'extraction_time');
    frame_size = h5readatt(test_file, '/features/metadata', 'frame_size_samples');
    num_nodes_meta = h5readatt(test_file, '/features/metadata', 'num_nodes');
    
    fprintf('     Extraction time: %s\n', extraction_time);
    fprintf('     Frame size: %d samples\n', frame_size);
    fprintf('     Nodes in metadata: %d\n', num_nodes_meta);
    
    fprintf('   - Reading chunk descriptors...\n');
    chunks_read = h5read(test_file, '/features/chunks/chunk_id');
    times_read = h5read(test_file, '/features/chunks/center_time_s');
    duration = h5readatt(test_file, '/features/chunks', 'chunk_duration_s');
    hop = h5readatt(test_file, '/features/chunks', 'hop_size_s');
    
    fprintf('     Chunks: %d total\n', length(chunks_read));
    fprintf('     Time range: %.1f - %.1f seconds\n', min(times_read), max(times_read));
    fprintf('     Chunk parameters: %.1fs duration, %.1fs hop\n', duration, hop);
    
    fprintf('5. Dimension consistency check...\n');
    
    % Verify all dimensions are consistent
    raw_size = size(h5read(test_file, '/signals/raw'));
    preproc_size = size(preproc_data);
    time_len = length(time_axis);
    node_len = length(node_axis);
    channel_len = length(channels_read);
    
    fprintf('   - Raw signals: %dx%d\n', raw_size);
    fprintf('   - Preprocessed signals: %dx%d\n', preproc_size);
    fprintf('   - Time axis: %d points\n', time_len);
    fprintf('   - Node axis: %d points\n', node_len);
    fprintf('   - Channel descriptors: %d channels\n', channel_len);
    
    % Check consistency
    assert(isequal(raw_size, preproc_size), 'Raw and preprocessed signal dimensions mismatch');
    assert(raw_size(1) == time_len, 'Signal time dimension vs time axis mismatch');
    assert(raw_size(2) == node_len, 'Signal node dimension vs node axis mismatch');
    assert(node_len == channel_len, 'Node axis vs channel descriptor count mismatch');
    assert(num_nodes_meta == N, 'Metadata node count vs actual node count mismatch');
    
    fprintf('   ✓ All dimensions consistent!\n');
    
    fprintf('\n🎉 SUCCESS: Enhanced BCT schema verification completed!\n');
    fprintf('✓ BCT class works correctly with enhanced schema\n');
    fprintf('✓ All enhanced features accessible\n');
    fprintf('✓ Dimension constraints satisfied\n');
    fprintf('✓ Backward compatibility maintained\n');
    
catch ME
    fprintf('\n❌ ERROR during verification:\n');
    fprintf('Message: %s\n', ME.message);
    fprintf('Location: %s at line %d\n', ME.stack(1).name, ME.stack(1).line);
    
    if length(ME.stack) > 1
        fprintf('Stack trace:\n');
        for i = 1:min(3, length(ME.stack))
            fprintf('  %s at line %d in %s\n', ME.stack(i).name, ME.stack(i).line, ME.stack(i).file);
        end
    end
    
    rethrow(ME);
end

% Cleanup
if exist(test_file, 'file')
    delete(test_file);
    fprintf('\nCleanup: Test file deleted\n');
end

fprintf('\nQuick verification complete!\n');