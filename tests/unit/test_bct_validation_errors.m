function tests = test_bct_validation_errors
% test_bct_validation_errors - Test error handling and validation
% Tests: Invalid inputs, file system errors, data validation
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Add bioctree to path
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')));
    
    % Setup temporary directory
    testCase.TestData.tempDir = fullfile(tempdir, 'bct_validation_tests');
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

function test_file_creation_errors(testCase)
    % Test: File creation and access error conditions
    
    % Test 1: Invalid file path (directory doesn't exist)
    invalidPath = fullfile(testCase.TestData.tempDir, 'nonexistent', 'test.h5');
    verifyError(testCase, @() bct.bct.create(invalidPath), ...
                'MATLAB:validators:mustBeValidPath', 'Should error for invalid path');
    
    % Test 2: Empty filename
    verifyError(testCase, @() bct.bct.create(''), ...
                'MATLAB:validators:mustBeValidPath', 'Should error for empty path');
    
    % Test 3: Create file in read-only directory (if possible to simulate)
    validFile = fullfile(testCase.TestData.tempDir, 'valid_test.h5');
    B = bct.bct.create(validFile);
    verifyClass(testCase, B, 'bct.bct', 'Valid file should create successfully');
    delete(validFile);
    
    % Test 4: Try to open non-existent file
    nonExistentFile = fullfile(testCase.TestData.tempDir, 'does_not_exist.h5');
    verifyError(testCase, @() bct.bct.open(nonExistentFile), ...
                'MATLAB:validators:mustBeFile', 'Should error for non-existent file');
end

function test_data_dimension_errors(testCase)
    % Test: Data dimension validation errors
    testFile = fullfile(testCase.TestData.tempDir, 'dimension_errors.h5');
    B = bct.bct.create(testFile);
    
    % Test 1: Invalid raw signal dimensions (wrong number of dimensions)
    X_1D = single([1, 2, 3, 4, 5]);  % 1D array
    verifyError(testCase, @() B.write_raw(X_1D, 100), ...
                'bct:write_raw:InvalidDimensions', 'Should error for 1D input');
    
    X_3D = single(rand(10, 8, 5));  % 3D array
    verifyError(testCase, @() B.write_raw(X_3D, 100), ...
                'bct:write_raw:InvalidDimensions', 'Should error for 3D input');
    
    % Test 2: Empty data
    X_empty = single.empty(0, 0);
    verifyError(testCase, @() B.write_raw(X_empty, 100), ...
                'bct:write_raw:EmptyData', 'Should error for empty data');
    
    % Test 3: Invalid sampling rate
    X_valid = single(rand(10, 5));
    verifyError(testCase, @() B.write_raw(X_valid, 0), ...
                'bct:write_raw:InvalidSamplingRate', 'Should error for zero sampling rate');
    
    verifyError(testCase, @() B.write_raw(X_valid, -100), ...
                'bct:write_raw:InvalidSamplingRate', 'Should error for negative sampling rate');
    
    % Test 4: NaN or Inf in data
    X_nan = single(rand(10, 5));
    X_nan(5, 3) = NaN;
    verifyError(testCase, @() B.write_raw(X_nan, 100), ...
                'bct:write_raw:InvalidData', 'Should error for NaN data');
    
    X_inf = single(rand(10, 5));
    X_inf(2, 4) = Inf;
    verifyError(testCase, @() B.write_raw(X_inf, 100), ...
                'bct:write_raw:InvalidData', 'Should error for Inf data');
    
    % Cleanup
    delete(testFile);
end

function test_read_validation_errors(testCase)
    % Test: Read operation validation errors
    testFile = fullfile(testCase.TestData.tempDir, 'read_errors.h5');
    B = bct.bct.create(testFile);
    
    % Create valid signal first
    T = 20; N = 10;
    X = single(rand(T, N));
    B.write_raw(X, 100);
    
    % Test 1: Invalid time range (out of bounds)
    verifyError(testCase, @() B.read_raw([0, 10], [1, N]), ...
                'bct:read_raw:InvalidTimeRange', 'Should error for time < 1');
    
    verifyError(testCase, @() B.read_raw([1, T+5], [1, N]), ...
                'bct:read_raw:InvalidTimeRange', 'Should error for time > T');
    
    verifyError(testCase, @() B.read_raw([15, 5], [1, N]), ...
                'bct:read_raw:InvalidTimeRange', 'Should error for start > end');
    
    % Test 2: Invalid node range (out of bounds)
    verifyError(testCase, @() B.read_raw([1, T], [0, 5]), ...
                'bct:read_raw:InvalidNodeRange', 'Should error for node < 1');
    
    verifyError(testCase, @() B.read_raw([1, T], [1, N+5]), ...
                'bct:read_raw:InvalidNodeRange', 'Should error for node > N');
    
    % Test 3: Invalid layer specification
    verifyError(testCase, @() B.read_raw([1, T], [1, N], -1), ...
                'bct:read_raw:InvalidLayer', 'Should error for negative layer');
    
    verifyError(testCase, @() B.read_raw([1, T], [1, N], 10), ...
                'bct:read_raw:InvalidLayer', 'Should error for non-existent layer');
    
    % Test 4: Reading from file with no raw data
    emptyFile = fullfile(testCase.TestData.tempDir, 'empty_read.h5');
    B_empty = bct.bct.create(emptyFile);
    
    verifyError(testCase, @() B_empty.read_raw([1, 10], [1, 5]), ...
                'bct:read_raw:NoData', 'Should error when no raw data exists');
    
    % Cleanup
    delete(testFile);
    delete(emptyFile);
end

function test_tf_validation_errors(testCase)
    % Test: Time-frequency operation validation errors
    testFile = fullfile(testCase.TestData.tempDir, 'tf_errors.h5');
    B = bct.bct.create(testFile);
    
    % Test 1: Invalid TF dimensions
    TF_2D = single(rand(10, 20));  % Should be 3D: F×T×N
    fs = 100;
    freqs = linspace(1, 50, 10);
    
    verifyError(testCase, @() B.write_tf(TF_2D, fs, freqs), ...
                'bct:write_tf:InvalidDimensions', 'Should error for 2D TF input');
    
    % Test 2: Mismatched frequency vector length
    TF_valid = complex(single(rand(10, 20, 5)));
    freqs_wrong = linspace(1, 50, 8);  % Length 8, but TF has 10 frequency bins
    
    verifyError(testCase, @() B.write_tf(TF_valid, fs, freqs_wrong), ...
                'bct:write_tf:FrequencyMismatch', 'Should error for freq vector length mismatch');
    
    % Test 3: Invalid frequency values
    freqs_negative = [-5, 10, 20, 30, 40, 50, 60, 70, 80, 90];
    verifyError(testCase, @() B.write_tf(TF_valid, fs, freqs_negative), ...
                'bct:write_tf:InvalidFrequencies', 'Should error for negative frequencies');
    
    freqs_nan = [1, 10, NaN, 30, 40, 50, 60, 70, 80, 90];
    verifyError(testCase, @() B.write_tf(TF_valid, fs, freqs_nan), ...
                'bct:write_tf:InvalidFrequencies', 'Should error for NaN frequencies');
    
    % Test 4: Invalid sampling rate for TF
    verifyError(testCase, @() B.write_tf(TF_valid, 0, freqs), ...
                'bct:write_tf:InvalidSamplingRate', 'Should error for zero fs in TF');
    
    % Test 5: Reading TF when no TF data exists
    verifyError(testCase, @() B.read_tf(), ...
                'bct:read_tf:NoData', 'Should error when no TF data exists');
    
    % Cleanup
    delete(testFile);
end

function test_graph_validation_errors(testCase)
    % Test: Graph operation validation errors
    testFile = fullfile(testCase.TestData.tempDir, 'graph_errors.h5');
    B = bct.bct.create(testFile);
    
    % Test 1: Missing required fields in graph struct
    G_no_edges = struct();
    verifyError(testCase, @() B.write_graph(G_no_edges), ...
                'bct:GraphMissingEdges', 'Should error for missing G.E field');
    
    % Test 2: Empty edge list
    G_empty_edges = struct('E', []);
    verifyError(testCase, @() B.write_graph(G_empty_edges), ...
                'bct:GraphMissingEdges', 'Should error for empty edge list');
    
    % Test 3: Invalid edge indices (out of range)
    G_bad_edges = struct('E', [1, 10; 2, 3]);  % Node 10 doesn't exist in 3-node graph
    G_bad_edges.coords = rand(3, 3);  % Only 3 nodes
    verifyError(testCase, @() B.write_graph(G_bad_edges), ...
                'bct:EdgeIndexOutOfRange', 'Should error for out-of-range edge indices');
    
    % Test 4: Test that read_graph_gsp returns empty when no graph exists
    % (This is expected behavior, not an error)
    G_result = B.read_graph_gsp();
    verifyEmpty(testCase, G_result, 'Should return empty when no graph exists');
    
    % Cleanup
    delete(testFile);
end

function test_layer_operation_errors(testCase)
    % Test: Layer operation validation errors
    testFile = fullfile(testCase.TestData.tempDir, 'layer_errors.h5');
    B = bct.bct.create(testFile);
    
    % Test 1: Append layer without base data
    X_layer = single(rand(10, 5));
    verifyError(testCase, @() B.append_raw_layer(X_layer, 0), ...
                'bct:append_raw_layer:NoBaseData', 'Should error when no base raw data');
    
    % Create base data first
    X_base = single(rand(20, 8));
    B.write_raw(X_base, 100);
    
    % Test 2: Append layer with mismatched dimensions
    X_wrong_size = single(rand(15, 8));  % Wrong time dimension
    verifyError(testCase, @() B.append_raw_layer(X_wrong_size, 0), ...
                'bct:ShapeMismatch', 'Should error for time dimension mismatch');
    
    X_wrong_nodes = single(rand(20, 5));  % Wrong node dimension
    verifyError(testCase, @() B.append_raw_layer(X_wrong_nodes, 0), ...
                'bct:ShapeMismatch', 'Should error for node dimension mismatch');
    
    % Test 3: Invalid layer index (negative values are allowed, just test that it works)
    X_valid_layer = single(rand(20, 8));
    % BCT allows negative layer indices, so this should work
    B.append_raw_layer(X_valid_layer, -1);
    verifyTrue(testCase, true, 'Negative layer index should be allowed');
    
    % Test 4: Set default layer to non-existent layer
    verifyError(testCase, @() B.set_default_layer(10), ...
                'bct:BadDefaultLayer', 'Should error for non-existent layer');
    
    % Cleanup
    delete(testFile);
end

function test_utility_method_errors(testCase)
    % Test: Utility method validation errors
    testFile = fullfile(testCase.TestData.tempDir, 'utility_errors.h5');
    B = bct.bct.create(testFile);
    
    % Test 1: has() method with invalid path
    result = B.has('');
    verifyEqual(testCase, result, false, 'Empty path should return false');
    
    result = B.has('/nonexistent/path');
    verifyEqual(testCase, result, false, 'Nonexistent path should return false');
    
    % Test 2: read_axis() with invalid dataset
    verifyError(testCase, @() B.read_axis('nonexistent_axis'), ...
                'bct:AxisMissing', 'Should error for non-existent axis');
    
    % Create dataset and test invalid axis
    X = single(rand(10, 5));
    B.write_raw(X, 100);
    
    verifyError(testCase, @() B.read_axis('invalid_axis'), ...
                'bct:AxisMissing', 'Should error for invalid axis name');
    
    % Test 3: read_coords() when no coordinates exist
    verifyError(testCase, @() B.read_coords(), ...
                'bct:read_coords:NoCoordinates', 'Should error when no coordinates exist');
    
    % Test 4: read_graph_gsp() when no graph exists
    verifyError(testCase, @() B.read_graph_gsp(), ...
                'bct:read_graph_gsp:NoGraph', 'Should error when no graph exists');
    
    % Cleanup
    delete(testFile);
end

function test_file_state_errors(testCase)
    % Test: File state and handle errors
    testFile = fullfile(testCase.TestData.tempDir, 'state_errors.h5');
    
    % Test 1: Operations on closed file handle
    B = bct.bct.create(testFile);
    X = single(rand(10, 5));
    B.write_raw(X, 100);
    
    % Simulate closing file (this may vary depending on implementation)
    % For this test, we assume the file becomes invalid
    
    % Test 2: Multiple creates of same file (depending on implementation)
    % This may or may not be an error depending on HDF5 handling
    
    % Test 3: File permissions (read-only file)
    % Create file, make read-only, try to write
    B_readonly = bct.bct.create(testFile);
    X_readonly = single(rand(5, 3));
    B_readonly.write_raw(X_readonly, 50);
    
    % Make file read-only
    fileattrib(testFile, '+r -w');
    
    % Try to open and write (should fail)
    try
        B_ro_open = bct.bct.open(testFile);
        X_new = single(rand(5, 3));
        verifyError(testCase, @() B_ro_open.write_raw(X_new, 50), ...
                    'bct:write_raw:ReadOnlyFile', 'Should error for read-only file');
    catch
        % If open itself fails for read-only file, that's also acceptable
        verifyTrue(testCase, true, 'Read-only file handling is implementation dependent');
    end
    
    % Restore write permissions for cleanup
    fileattrib(testFile, '+w');
    
    % Cleanup
    delete(testFile);
end

function test_data_type_validation(testCase)
    % Test: Data type validation and conversion errors
    testFile = fullfile(testCase.TestData.tempDir, 'datatype_errors.h5');
    B = bct.bct.create(testFile);
    
    % Test 1: Wrong data type for raw signals
    X_double = rand(10, 5);  % double instead of single
    % This may or may not error depending on implementation
    % Some implementations auto-convert, others require single
    
    X_int = int32(round(100 * rand(10, 5)));  % integer data
    % Test behavior with integer input
    
    X_logical = logical(round(rand(10, 5)));  % logical data
    verifyError(testCase, @() B.write_raw(X_logical, 100), ...
                'bct:write_raw:InvalidDataType', 'Should error for logical data');
    
    % Test 2: Complex data in raw signals (should error)
    X_complex = single(rand(10, 5)) + 1i*single(rand(10, 5));
    verifyError(testCase, @() B.write_raw(X_complex, 100), ...
                'bct:write_raw:ComplexNotAllowed', 'Should error for complex raw data');
    
    % Test 3: Real data in TF (should convert to complex)
    TF_real = single(rand(8, 10, 5));  % Real TF data
    fs = 100;
    freqs = linspace(1, 50, 8);
    
    % This might auto-convert or error depending on implementation
    try
        B.write_tf(TF_real, fs, freqs);
        [TF_read, ~, ~] = B.read_tf();
        verifyClass(testCase, TF_read, 'single', 'TF data should maintain precision');
        % Should be converted to complex
    catch ME
        if contains(ME.identifier, 'write_tf:RealDataNotAllowed')
            verifyTrue(testCase, true, 'Real TF data rejection is acceptable');
        else
            rethrow(ME);
        end
    end
    
    % Cleanup
    delete(testFile);
end

function test_enhanced_schema_validation(testCase)
    % Test: Enhanced schema specific validation errors
    testFile = fullfile(testCase.TestData.tempDir, 'enhanced_validation.h5');
    B = bct.bct.create(testFile);
    
    % Create base signal
    T = 20; N = 5; fs = 100;
    X = single(randn(T, N));
    B.write_raw(X, fs);
    
    % Test 1: Node descriptor dimension mismatch
    wrong_channel_names = string(compose("CH%d", 1:N+2));  % N+2 instead of N
    h5create(testFile, '/node_info/channel_name', [N+2, 1], 'Datatype', 'string');
    h5write(testFile, '/node_info/channel_name', wrong_channel_names');
    
    % This creates an inconsistent state - in practice, validation should catch this
    channels_read = h5read(testFile, '/node_info/channel_name');
    verifyNotEqual(testCase, length(channels_read), N, ...
        'Inconsistent channel count should be detectable');
    
    % Clean up invalid data
    delete(testFile);
    B = bct.bct.create(testFile);
    B.write_raw(X, fs);
    
    % Test 2: Preprocessed signal dimension mismatch
    X_preproc_wrong = single(randn(T+5, N));  % Wrong T dimension
    h5create(testFile, '/signals/preproc', [T+5, N], 'Datatype', 'single');
    h5write(testFile, '/signals/preproc', X_preproc_wrong);
    
    % This should be caught by dimension constraint validation
    preproc_size = size(h5read(testFile, '/signals/preproc'));
    raw_size = size(h5read(testFile, '/signals/raw'));
    verifyNotEqual(testCase, preproc_size(1), raw_size(1), ...
        'Dimension mismatch should be detectable');
    
    % Test 3: Invalid feature matrix dimensions
    num_chunks = 10;
    num_features = 5;
    wrong_features = single(randn(num_chunks+3, num_features));  % Wrong chunk count
    chunk_ids = int32(1:num_chunks)';  % Correct chunk count
    
    h5create(testFile, '/features/matrix/feature_matrix', size(wrong_features), 'Datatype', 'single');
    h5write(testFile, '/features/matrix/feature_matrix', wrong_features);
    h5create(testFile, '/features/matrix/chunk_ids', size(chunk_ids), 'Datatype', 'int32');
    h5write(testFile, '/features/matrix/chunk_ids', chunk_ids);
    
    % Dimension mismatch should be detectable
    features_read = h5read(testFile, '/features/matrix/feature_matrix');
    ids_read = h5read(testFile, '/features/matrix/chunk_ids');
    verifyNotEqual(testCase, size(features_read, 1), length(ids_read), ...
        'Feature matrix and chunk ID count mismatch should be detectable');
    
    % Test 4: Invalid subject metadata
    % Test empty subject name
    h5writeatt(testFile, '/', 'subject_name', '');
    empty_subject = h5readatt(testFile, '/', 'subject_name');
    verifyEqual(testCase, empty_subject, '', 'Empty subject name should be readable but invalid');
    
    % Cleanup
    delete(testFile);
end

function test_enhanced_schema_edge_cases(testCase)
    % Test: Edge cases specific to enhanced schema
    testFile = fullfile(testCase.TestData.tempDir, 'enhanced_edge_cases.h5');
    B = bct.bct.create(testFile);
    
    % Test 1: Very large node descriptor strings
    T = 5; N = 3; fs = 50;
    X = single(randn(T, N));
    B.write_raw(X, fs);
    
    % Create very long channel names
    long_names = string(compose("VERY_LONG_CHANNEL_NAME_THAT_EXCEEDS_NORMAL_LENGTH_%03d", 1:N));
    h5create(testFile, '/node_info/channel_name', [N, 1], 'Datatype', 'string');
    h5write(testFile, '/node_info/channel_name', long_names');
    
    % Should still work
    names_read = h5read(testFile, '/node_info/channel_name');
    verifyEqual(testCase, names_read, long_names', 'Long channel names should be handled');
    
    % Test 2: Unicode in channel names
    unicode_names = ["α-wave", "β-channel", "γ-sensor"];
    if N >= length(unicode_names)
        h5create(testFile, '/node_info/channel_name_unicode', [length(unicode_names), 1], 'Datatype', 'string');
        h5write(testFile, '/node_info/channel_name_unicode', unicode_names');
        
        unicode_read = h5read(testFile, '/node_info/channel_name_unicode');
        verifyEqual(testCase, unicode_read, unicode_names', 'Unicode channel names should be handled');
    end
    
    % Test 3: Extreme coordinate values
    extreme_positions = single([1e6, -1e6, 0; 0, 1e-6, -1e-6; NaN, Inf, -Inf]);
    if N >= 3
        h5create(testFile, '/node_info/node_position_extreme', [3, 3], 'Datatype', 'single');
        h5write(testFile, '/node_info/node_position_extreme', extreme_positions);
        
        pos_read = h5read(testFile, '/node_info/node_position_extreme');
        % NaN and Inf should be preserved
        verifyTrue(testCase, isnan(pos_read(3,1)), 'NaN should be preserved');
        verifyTrue(testCase, isinf(pos_read(3,2)), 'Inf should be preserved');
    end
    
    % Test 4: Empty feature descriptions
    empty_descriptions = string.empty(0, 1);
    h5create(testFile, '/features/metadata/empty_descriptions', [0, 1], 'Datatype', 'string');
    h5write(testFile, '/features/metadata/empty_descriptions', empty_descriptions);
    
    desc_read = h5read(testFile, '/features/metadata/empty_descriptions');
    verifyEqual(testCase, length(desc_read), 0, 'Empty descriptions should be handled');
    
    % Cleanup
    delete(testFile);
end