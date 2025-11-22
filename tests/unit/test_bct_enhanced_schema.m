function tests = test_bct_enhanced_schema
% test_bct_enhanced_schema - Test enhanced BCT schema features
% Tests: node descriptors, preprocessed signals, feature extraction metadata, subject info
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Add bioctree to path
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));
    
    % Setup temporary directory
    testCase.TestData.tempDir = fullfile(tempdir, 'bct_enhanced_tests');
    if ~exist(testCase.TestData.tempDir, 'dir')
        mkdir(testCase.TestData.tempDir);
    end
end

function teardownOnce(testCase)
    % Cleanup temporary directory
    if exist(testCase.TestData.tempDir, 'dir')
        rmdir(testCase.TestData.tempDir, 's');
    end
end

function test_subject_metadata(testCase)
    % Test: Subject-level metadata storage and retrieval
    testFile = fullfile(testCase.TestData.tempDir, 'subject_metadata.h5');
    
    % Create BCT file
    B = bct.bct.create(testFile);
    
    % Add subject metadata
    h5writeatt(testFile, '/', 'subject_name', 'SUBJ001');
    h5writeatt(testFile, '/', 'session_id', 'SES01');
    h5writeatt(testFile, '/', 'recording_date', '2025-11-05');
    
    % Verify metadata can be read
    subject = h5readatt(testFile, '/', 'subject_name');
    session = h5readatt(testFile, '/', 'session_id');
    date = h5readatt(testFile, '/', 'recording_date');
    
    verifyEqual(testCase, subject, 'SUBJ001', 'Subject name should match');
    verifyEqual(testCase, session, 'SES01', 'Session ID should match');
    verifyEqual(testCase, date, '2025-11-05', 'Recording date should match');
    
    % Cleanup
    delete(testFile);
end

function test_node_descriptors(testCase)
    % Test: Node descriptor storage and consistency
    testFile = fullfile(testCase.TestData.tempDir, 'node_descriptors.h5');
    
    % Create BCT file with signal data
    B = bct.bct.create(testFile);
    T = 20; N = 5; fs = 100;
    X = single(randn(T, N));
    B.write_raw(X, fs);
    
    % Create node descriptors
    channel_names = ["Fp1", "C3", "C4", "O1", "O2"];
    node_types = ["EEG", "EEG", "EEG", "EEG", "EEG"];
    positions = single(randn(N, 3));  % Random 3D positions
    units = repmat("µV", N, 1);
    node_names = string(1:N);
    
    % Store node descriptors
    h5create(testFile, '/node_info/channel_name', [N, 1], 'Datatype', 'string');
    h5write(testFile, '/node_info/channel_name', channel_names');
    
    h5create(testFile, '/node_info/node_type', [N, 1], 'Datatype', 'string');
    h5write(testFile, '/node_info/node_type', node_types');
    
    h5create(testFile, '/node_info/node_position', [N, 3], 'Datatype', 'single');
    h5write(testFile, '/node_info/node_position', positions);
    
    h5create(testFile, '/node_info/node_units', [N, 1], 'Datatype', 'string');
    h5write(testFile, '/node_info/node_units', units);
    
    h5create(testFile, '/node_info/node_name', [N, 1], 'Datatype', 'string');
    h5write(testFile, '/node_info/node_name', node_names');
    
    % Verify node descriptors can be read
    channels_read = h5read(testFile, '/node_info/channel_name');
    types_read = h5read(testFile, '/node_info/node_type');
    positions_read = h5read(testFile, '/node_info/node_position');
    units_read = h5read(testFile, '/node_info/node_units');
    names_read = h5read(testFile, '/node_info/node_name');
    
    % Verify data integrity
    verifyEqual(testCase, channels_read, channel_names', 'Channel names should match');
    verifyEqual(testCase, types_read, node_types', 'Node types should match');
    verifyEqual(testCase, positions_read, positions, 'Positions should match');
    verifyEqual(testCase, units_read, units, 'Units should match');
    verifyEqual(testCase, names_read, node_names', 'Node names should match');
    
    % Verify dimension consistency with signal data
    verifyEqual(testCase, length(channels_read), N, 'Channel count should match signal N');
    verifyEqual(testCase, size(positions_read, 1), N, 'Position count should match signal N');
    
    % Cleanup
    delete(testFile);
end

function test_preprocessed_signals(testCase)
    % Test: Preprocessed signal storage with metadata
    testFile = fullfile(testCase.TestData.tempDir, 'preproc_signals.h5');
    
    % Create BCT file with raw signals
    B = bct.bct.create(testFile);
    T = 30; N = 8; fs = 256;
    X_raw = single(randn(T, N));
    B.write_raw(X_raw, fs);
    
    % Create preprocessed signals (e.g., filtered)
    X_preproc = single(0.8 * X_raw + 0.1 * randn(T, N));  % Simulated preprocessing
    
    % Store preprocessed signals
    h5create(testFile, '/signals/preproc', [T, N], 'Datatype', 'single', ...
        'ChunkSize', [min(T, 2048), min(N, 256)], 'Deflate', 5, 'Shuffle', true);
    h5write(testFile, '/signals/preproc', X_preproc);
    h5writeatt(testFile, '/signals/preproc', 'sampling_rate_hz', fs);
    h5writeatt(testFile, '/signals/preproc', 'preprocessing_steps', ...
        'bandpass_filter:1-50Hz,notch_filter:60Hz,artifact_removal');
    
    % Attach dimension scales
    bct.internal.DimScale.attach(testFile, '/signals/preproc', ...
        {'/axes/time_s', '/axes/node_id'}, {'time_s', 'node_id'});
    
    % Verify preprocessed signals exist and have correct attributes
    verifyTrue(testCase, logical(exist_h5_dataset(testFile, '/signals/preproc')), ...
        'Preprocessed signals should exist');
    
    % Read back and verify
    X_preproc_read = h5read(testFile, '/signals/preproc');
    fs_preproc = h5readatt(testFile, '/signals/preproc', 'sampling_rate_hz');
    preproc_steps = h5readatt(testFile, '/signals/preproc', 'preprocessing_steps');
    
    verifyEqual(testCase, X_preproc_read, X_preproc, 'Preprocessed data should match');
    verifyEqual(testCase, fs_preproc, fs, 'Sampling rate should match');
    verifyEqual(testCase, preproc_steps, 'bandpass_filter:1-50Hz,notch_filter:60Hz,artifact_removal', ...
        'Preprocessing steps should match');
    
    % Verify dimensions match raw signals
    X_raw_read = h5read(testFile, '/signals/raw');
    verifyEqual(testCase, size(X_preproc_read), size(X_raw_read), ...
        'Preprocessed and raw signals should have same dimensions');
    
    % Cleanup
    delete(testFile);
end

function test_chunk_descriptors(testCase)
    % Test: Feature extraction chunk descriptors
    testFile = fullfile(testCase.TestData.tempDir, 'chunk_descriptors.h5');
    
    % Create BCT file with signals
    B = bct.bct.create(testFile);
    T = 100; N = 4; fs = 100;
    X = single(randn(T, N));
    B.write_raw(X, fs);
    
    % Create chunk descriptors for 4-second chunks with 50% overlap
    chunk_duration_s = 4.0;
    hop_size_s = 2.0;
    frame_size_samples = round(chunk_duration_s * fs);
    hop_size_samples = round(hop_size_s * fs);
    
    % Calculate number of chunks per channel
    num_chunks_per_channel = floor((T - frame_size_samples) / hop_size_samples) + 1;
    total_chunks = num_chunks_per_channel * N;
    
    % Create chunk descriptor data
    chunk_ids = int32(1:total_chunks)';
    node_ids = int32(repmat(0:N-1, num_chunks_per_channel, 1)');  % 0-based
    
    start_times = zeros(total_chunks, 1);
    end_times = zeros(total_chunks, 1);
    center_times = zeros(total_chunks, 1);
    sample_starts = int32(zeros(total_chunks, 1));
    sample_ends = int32(zeros(total_chunks, 1));
    
    idx = 1;
    for node = 1:N
        for chunk = 1:num_chunks_per_channel
            start_time = (chunk - 1) * hop_size_s;
            end_time = start_time + chunk_duration_s;
            center_time = start_time + chunk_duration_s / 2;
            
            start_times(idx) = start_time;
            end_times(idx) = end_time;
            center_times(idx) = center_time;
            sample_starts(idx) = round(start_time * fs) + 1;  % 1-based
            sample_ends(idx) = round(end_time * fs);
            
            idx = idx + 1;
        end
    end
    
    % Store chunk descriptors
    h5create(testFile, '/features/chunks/chunk_id', size(chunk_ids), 'Datatype', 'int32');
    h5write(testFile, '/features/chunks/chunk_id', chunk_ids);
    
    h5create(testFile, '/features/chunks/node_id', size(node_ids), 'Datatype', 'int32');
    h5write(testFile, '/features/chunks/node_id', node_ids);
    
    h5create(testFile, '/features/chunks/start_time_s', size(start_times), 'Datatype', 'double');
    h5write(testFile, '/features/chunks/start_time_s', start_times);
    
    h5create(testFile, '/features/chunks/end_time_s', size(end_times), 'Datatype', 'double');
    h5write(testFile, '/features/chunks/end_time_s', end_times);
    
    h5create(testFile, '/features/chunks/center_time_s', size(center_times), 'Datatype', 'double');
    h5write(testFile, '/features/chunks/center_time_s', center_times);
    
    h5create(testFile, '/features/chunks/sample_start', size(sample_starts), 'Datatype', 'int32');
    h5write(testFile, '/features/chunks/sample_start', sample_starts);
    
    h5create(testFile, '/features/chunks/sample_end', size(sample_ends), 'Datatype', 'int32');
    h5write(testFile, '/features/chunks/sample_end', sample_ends);
    
    % Add chunk attributes
    h5writeatt(testFile, '/features/chunks', 'chunk_duration_s', chunk_duration_s);
    h5writeatt(testFile, '/features/chunks', 'hop_size_s', hop_size_s);
    h5writeatt(testFile, '/features/chunks', 'sampling_rate_hz', fs);
    h5writeatt(testFile, '/features/chunks', 'frame_size_samples', frame_size_samples);
    h5writeatt(testFile, '/features/chunks', 'overlap_samples', frame_size_samples - hop_size_samples);
    
    % Verify chunk descriptors
    chunk_ids_read = h5read(testFile, '/features/chunks/chunk_id');
    node_ids_read = h5read(testFile, '/features/chunks/node_id');
    center_times_read = h5read(testFile, '/features/chunks/center_time_s');
    
    verifyEqual(testCase, chunk_ids_read, chunk_ids, 'Chunk IDs should match');
    verifyEqual(testCase, node_ids_read, node_ids, 'Node IDs should match');
    verifyEqual(testCase, length(center_times_read), total_chunks, 'Should have correct number of chunks');
    
    % Verify chunk timing is correct
    verifyEqual(testCase, center_times_read(1), chunk_duration_s/2, 'First chunk center should be correct');
    verifyEqual(testCase, center_times_read(2), chunk_duration_s/2 + hop_size_s, 'Second chunk center should be correct');
    
    % Verify attributes
    duration_attr = h5readatt(testFile, '/features/chunks', 'chunk_duration_s');
    hop_attr = h5readatt(testFile, '/features/chunks', 'hop_size_s');
    fs_attr = h5readatt(testFile, '/features/chunks', 'sampling_rate_hz');
    
    verifyEqual(testCase, duration_attr, chunk_duration_s, 'Duration attribute should match');
    verifyEqual(testCase, hop_attr, hop_size_s, 'Hop size attribute should match');
    verifyEqual(testCase, fs_attr, fs, 'Sampling rate attribute should match');
    
    % Cleanup
    delete(testFile);
end

function test_feature_matrix(testCase)
    % Test: Feature matrix storage and alignment with chunks
    testFile = fullfile(testCase.TestData.tempDir, 'feature_matrix.h5');
    
    % Create BCT file with basic structure
    B = bct.bct.create(testFile);
    T = 50; N = 3; fs = 100;
    X = single(randn(T, N));
    B.write_raw(X, fs);
    
    % Create mock feature matrix
    num_chunks = 20;
    num_features = 8;
    feature_matrix = single(randn(num_chunks, num_features));
    feature_names = ["RMS", "PeakValue", "SpectralCentroid", "AlphaPower", ...
                     "BetaPower", "GammaPower", "SpectralEntropy", "AlphaBetaRatio"];
    chunk_ids = int32(1:num_chunks)';
    
    % Store feature matrix
    h5create(testFile, '/features/matrix/feature_matrix', size(feature_matrix), 'Datatype', 'single');
    h5write(testFile, '/features/matrix/feature_matrix', feature_matrix);
    
    h5create(testFile, '/features/matrix/feature_names', [num_features, 1], 'Datatype', 'string');
    h5write(testFile, '/features/matrix/feature_names', feature_names');
    
    h5create(testFile, '/features/matrix/chunk_ids', size(chunk_ids), 'Datatype', 'int32');
    h5write(testFile, '/features/matrix/chunk_ids', chunk_ids);
    
    % Add attributes
    h5writeatt(testFile, '/features/matrix', 'num_features', num_features);
    h5writeatt(testFile, '/features/matrix', 'extraction_method', 'MATLAB_signalFeatureExtractor');
    
    % Verify feature matrix
    features_read = h5read(testFile, '/features/matrix/feature_matrix');
    names_read = h5read(testFile, '/features/matrix/feature_names');
    ids_read = h5read(testFile, '/features/matrix/chunk_ids');
    
    verifyEqual(testCase, features_read, feature_matrix, 'Feature matrix should match');
    verifyEqual(testCase, names_read, feature_names', 'Feature names should match');
    verifyEqual(testCase, ids_read, chunk_ids, 'Chunk IDs should match');
    
    % Verify dimensions are correct
    verifyEqual(testCase, size(features_read), [num_chunks, num_features], ...
        'Feature matrix should have correct dimensions');
    verifyEqual(testCase, length(names_read), num_features, ...
        'Feature names should match number of features');
    verifyEqual(testCase, length(ids_read), num_chunks, ...
        'Chunk IDs should match number of chunks');
    
    % Cleanup
    delete(testFile);
end

function test_extraction_metadata(testCase)
    % Test: Feature extraction metadata storage
    testFile = fullfile(testCase.TestData.tempDir, 'extraction_metadata.h5');
    
    % Create BCT file
    B = bct.bct.create(testFile);
    T = 40; N = 6; fs = 200;
    X = single(randn(T, N));
    B.write_raw(X, fs);
    
    % Store extraction metadata
    h5writeatt(testFile, '/features/metadata', 'extraction_time', datestr(now));
    h5writeatt(testFile, '/features/metadata', 'extraction_software', 'MATLAB_R2025b');
    h5writeatt(testFile, '/features/metadata', 'frame_size_samples', 800);  % 4s at 200Hz
    h5writeatt(testFile, '/features/metadata', 'hop_size_samples', 400);    % 2s at 200Hz
    h5writeatt(testFile, '/features/metadata', 'num_nodes', N);
    h5writeatt(testFile, '/features/metadata', 'feature_extractor_version', '1.0.0');
    
    % Store frequency band definitions
    freq_bands = single([1, 4; 4, 8; 8, 12; 12, 30; 30, 60]);  % Delta, Theta, Alpha, Beta, Gamma
    h5create(testFile, '/features/metadata/frequency_bands', size(freq_bands), 'Datatype', 'single');
    h5write(testFile, '/features/metadata/frequency_bands', freq_bands);
    
    % Store feature descriptions
    descriptions = ["Root mean square amplitude", "Peak amplitude value", ...
                   "Spectral centroid frequency", "Alpha band power (8-12 Hz)", ...
                   "Beta band power (12-30 Hz)", "Gamma band power (30-60 Hz)"];
    h5create(testFile, '/features/metadata/feature_descriptions', [length(descriptions), 1], 'Datatype', 'string');
    h5write(testFile, '/features/metadata/feature_descriptions', descriptions');
    
    % Verify metadata
    extraction_time = h5readatt(testFile, '/features/metadata', 'extraction_time');
    software = h5readatt(testFile, '/features/metadata', 'extraction_software');
    frame_size = h5readatt(testFile, '/features/metadata', 'frame_size_samples');
    num_nodes = h5readatt(testFile, '/features/metadata', 'num_nodes');
    
    verifyClass(testCase, extraction_time, 'char', 'Extraction time should be string');
    verifyEqual(testCase, software, 'MATLAB_R2025b', 'Software should match');
    verifyEqual(testCase, frame_size, 800, 'Frame size should match');
    verifyEqual(testCase, num_nodes, N, 'Number of nodes should match');
    
    % Verify frequency bands
    bands_read = h5read(testFile, '/features/metadata/frequency_bands');
    verifyEqual(testCase, bands_read, freq_bands, 'Frequency bands should match');
    verifyEqual(testCase, size(bands_read), [5, 2], 'Should have 5 frequency bands with low/high limits');
    
    % Verify feature descriptions
    desc_read = h5read(testFile, '/features/metadata/feature_descriptions');
    verifyEqual(testCase, desc_read, descriptions', 'Feature descriptions should match');
    
    % Cleanup
    delete(testFile);
end

function test_schema_dimension_constraints(testCase)
    % Test: Dimension consistency constraints from enhanced schema
    testFile = fullfile(testCase.TestData.tempDir, 'dimension_constraints.h5');
    
    % Create BCT file with signals
    B = bct.bct.create(testFile);
    T = 25; N = 7; fs = 150;
    X_raw = single(randn(T, N));
    B.write_raw(X_raw, fs);
    
    % Add node descriptors with correct dimensions
    channel_names = string(compose("CH%02d", 1:N));
    h5create(testFile, '/node_info/channel_name', [N, 1], 'Datatype', 'string');
    h5write(testFile, '/node_info/channel_name', channel_names');
    
    % Add preprocessed signals with same dimensions
    X_preproc = single(0.9 * X_raw);
    h5create(testFile, '/signals/preproc', [T, N], 'Datatype', 'single');
    h5write(testFile, '/signals/preproc', X_preproc);
    h5writeatt(testFile, '/signals/preproc', 'sampling_rate_hz', fs);
    
    % Verify dimension consistency
    time_axis = B.read_axis('time_s');
    node_axis = B.read_axis('node_id');
    channels_read = h5read(testFile, '/node_info/channel_name');
    preproc_read = h5read(testFile, '/signals/preproc');
    raw_read = h5read(testFile, '/signals/raw');
    
    % Check all dimension constraints from schema
    verifyEqual(testCase, length(time_axis), size(raw_read, 1), ...
        'Time axis should match raw signal time dimension');
    verifyEqual(testCase, length(node_axis), size(raw_read, 2), ...
        'Node axis should match raw signal node dimension');
    verifyEqual(testCase, length(channels_read), length(node_axis), ...
        'Channel names should match node axis length');
    verifyEqual(testCase, size(preproc_read), size(raw_read), ...
        'Preprocessed signals should match raw signal dimensions');
    
    % Test that inconsistent dimensions would be caught (conceptually)
    % In practice, this would be enforced by validation code
    verifyEqual(testCase, length(node_axis), N, 'Node axis should have correct length');
    verifyEqual(testCase, length(time_axis), T, 'Time axis should have correct length');
    
    % Cleanup
    delete(testFile);
end

function test_enhanced_schema_integration(testCase)
    % Test: Full integration of all enhanced schema features
    testFile = fullfile(testCase.TestData.tempDir, 'full_integration.h5');
    
    % Create BCT file with all enhanced features
    B = bct.bct.create(testFile);
    T = 60; N = 8; fs = 256;
    
    % Add subject metadata
    h5writeatt(testFile, '/', 'subject_name', 'SUBJ999');
    h5writeatt(testFile, '/', 'session_id', 'SES02');
    h5writeatt(testFile, '/', 'recording_date', '2025-11-05');
    
    % Add signals
    X_raw = single(randn(T, N));
    B.write_raw(X_raw, fs);
    
    X_preproc = single(0.85 * X_raw + 0.05 * randn(T, N));
    h5create(testFile, '/signals/preproc', [T, N], 'Datatype', 'single');
    h5write(testFile, '/signals/preproc', X_preproc);
    h5writeatt(testFile, '/signals/preproc', 'sampling_rate_hz', fs);
    h5writeatt(testFile, '/signals/preproc', 'preprocessing_steps', 'bandpass:0.5-100Hz');
    
    % Add node descriptors
    channel_names = ["Fp1", "Fp2", "F3", "F4", "C3", "C4", "O1", "O2"];
    node_types = repmat("EEG", N, 1);
    positions = single(randn(N, 3));
    
    h5create(testFile, '/node_info/channel_name', [N, 1], 'Datatype', 'string');
    h5write(testFile, '/node_info/channel_name', channel_names');
    h5create(testFile, '/node_info/node_type', [N, 1], 'Datatype', 'string');
    h5write(testFile, '/node_info/node_type', node_types);
    h5create(testFile, '/node_info/node_position', [N, 3], 'Datatype', 'single');
    h5write(testFile, '/node_info/node_position', positions);
    
    % Add feature extraction components
    num_chunks = 20;
    num_features = 10;
    
    % Chunk descriptors
    chunk_ids = int32(1:num_chunks)';
    h5create(testFile, '/features/chunks/chunk_id', size(chunk_ids), 'Datatype', 'int32');
    h5write(testFile, '/features/chunks/chunk_id', chunk_ids);
    h5writeatt(testFile, '/features/chunks', 'chunk_duration_s', 4.0);
    h5writeatt(testFile, '/features/chunks', 'hop_size_s', 2.0);
    
    % Feature matrix
    features = single(randn(num_chunks, num_features));
    feature_names = string(compose("Feature%02d", 1:num_features));
    h5create(testFile, '/features/matrix/feature_matrix', size(features), 'Datatype', 'single');
    h5write(testFile, '/features/matrix/feature_matrix', features);
    h5create(testFile, '/features/matrix/feature_names', [num_features, 1], 'Datatype', 'string');
    h5write(testFile, '/features/matrix/feature_names', feature_names');
    
    % Extraction metadata
    h5writeatt(testFile, '/features/metadata', 'extraction_time', datestr(now));
    h5writeatt(testFile, '/features/metadata', 'num_nodes', N);
    
    % Verify complete integration
    % Subject metadata
    subject = h5readatt(testFile, '/', 'subject_name');
    verifyEqual(testCase, subject, 'SUBJ999', 'Subject should be accessible');
    
    % Signal data
    verifyTrue(testCase, logical(exist_h5_dataset(testFile, '/signals/raw')), 'Raw signals should exist');
    verifyTrue(testCase, logical(exist_h5_dataset(testFile, '/signals/preproc')), 'Preprocessed signals should exist');
    
    % Node descriptors
    channels_read = h5read(testFile, '/node_info/channel_name');
    verifyEqual(testCase, length(channels_read), N, 'Channels should match node count');
    
    % Feature extraction
    chunks_read = h5read(testFile, '/features/chunks/chunk_id');
    features_read = h5read(testFile, '/features/matrix/feature_matrix');
    verifyEqual(testCase, length(chunks_read), num_chunks, 'Should have correct chunk count');
    verifyEqual(testCase, size(features_read), [num_chunks, num_features], 'Feature matrix should have correct size');
    
    % BCT object should still work with enhanced file
    verifyEqual(testCase, B.T, T, 'BCT should correctly read time dimension');
    verifyEqual(testCase, B.N, N, 'BCT should correctly read node dimension');
    verifyEqual(testCase, B.fs, fs, 'BCT should correctly read sampling rate');
    
    fprintf('Enhanced schema integration test passed!\n');
    
    % Cleanup
    delete(testFile);
end

%% Helper Functions

function exists = exist_h5_dataset(filename, dataset_path)
    % Check if H5 dataset exists
    try
        h5info(filename, dataset_path);
        exists = true;
    catch
        exists = false;
    end
end
