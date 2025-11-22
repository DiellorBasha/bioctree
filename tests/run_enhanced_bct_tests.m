function run_enhanced_bct_tests()
% RUN_ENHANCED_BCT_TESTS - Execute all BCT tests including enhanced schema features
%
% This script runs the complete test suite for the enhanced BCT schema,
% including backward compatibility tests and new feature validation.

fprintf('=== Running Enhanced BCT Schema Test Suite ===\n\n');

% Add bioctree to path
bioctree_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(bioctree_root));

% List of test files to run
test_files = {
    'test_bct_enhanced_schema'; ...    % New enhanced schema tests
    'test_bct_raw_signals'; ...        % Updated raw signal tests
    'test_bct_validation_errors'; ...  % Updated validation tests  
    'test_bct_layers'; ...             % Layer functionality tests
    'test_bct_paths_attributes'; ...   % Path and attribute tests
    'test_bct_graph_roundtrip' ...     % Graph functionality tests
};

% Results tracking
total_tests = 0;
passed_tests = 0;
failed_tests = 0;
test_results = struct();

fprintf('Running %d test suites...\n\n', length(test_files));

for i = 1:length(test_files)
    test_name = test_files{i};
    fprintf('--- Running %s ---\n', test_name);
    
    try
        % Run the test suite
        test_suite = eval(test_name);
        results = run(test_suite);
        
        % Count results
        num_passed = sum([results.Passed]);
        num_failed = sum([results.Failed]);
        num_incomplete = sum([results.Incomplete]);
        num_total = length(results);
        
        total_tests = total_tests + num_total;
        passed_tests = passed_tests + num_passed;
        failed_tests = failed_tests + num_failed;
        
        % Store detailed results
        test_results.(test_name) = struct(...
            'Total', num_total, ...
            'Passed', num_passed, ...
            'Failed', num_failed, ...
            'Incomplete', num_incomplete, ...
            'Results', results);
        
        % Print summary for this test suite
        fprintf('  Tests: %d total, %d passed, %d failed, %d incomplete\n', ...
            num_total, num_passed, num_failed, num_incomplete);
        
        if num_failed > 0
            fprintf('  FAILED tests:\n');
            failed_indices = find([results.Failed]);
            for j = failed_indices
                fprintf('    - %s: %s\n', results(j).Name, results(j).Details.DiagnosticRecord.Report);
            end
        end
        
        if num_incomplete > 0
            fprintf('  INCOMPLETE tests:\n');
            incomplete_indices = find([results.Incomplete]);
            for j = incomplete_indices
                fprintf('    - %s\n', results(j).Name);
            end
        end
        
        fprintf('\n');
        
    catch ME
        fprintf('  ERROR running test suite: %s\n', ME.message);
        fprintf('  Stack trace:\n');
        for j = 1:length(ME.stack)
            fprintf('    %s at line %d in %s\n', ME.stack(j).name, ME.stack(j).line, ME.stack(j).file);
        end
        fprintf('\n');
        
        % Count as failed
        failed_tests = failed_tests + 1;
        total_tests = total_tests + 1;
        
        test_results.(test_name) = struct(...
            'Total', 1, 'Passed', 0, 'Failed', 1, 'Incomplete', 0, ...
            'Error', ME.message);
    end
end

% Overall summary
fprintf('=== OVERALL TEST RESULTS ===\n');
fprintf('Total tests: %d\n', total_tests);
fprintf('Passed: %d (%.1f%%)\n', passed_tests, 100*passed_tests/total_tests);
fprintf('Failed: %d (%.1f%%)\n', failed_tests, 100*failed_tests/total_tests);

if failed_tests == 0
    fprintf('\n🎉 ALL TESTS PASSED! Enhanced BCT schema is working correctly.\n');
else
    fprintf('\n❌ %d tests failed. See details above.\n', failed_tests);
end

% Test specific enhanced schema features
fprintf('\n=== Enhanced Schema Feature Verification ===\n');
test_enhanced_schema_features();

% Save detailed results
results_file = fullfile(tempdir, 'bct_test_results.mat');
save(results_file, 'test_results', 'total_tests', 'passed_tests', 'failed_tests');
fprintf('\nDetailed results saved to: %s\n', results_file);

end

function test_enhanced_schema_features()
% Test specific enhanced schema functionality
    
    fprintf('Testing enhanced schema features...\n');
    
    % Create a temporary enhanced BCT file
    test_file = fullfile(tempdir, 'enhanced_schema_verification.h5');
    cleanup_file = onCleanup(@() delete_if_exists(test_file));
    
    try
        % Create BCT with enhanced features
        B = bct.bct.create(test_file);
        
        % Basic signals
        T = 30; N = 4; fs = 100;
        X_raw = single(randn(T, N));
        B.write_raw(X_raw, fs);
        
        % Enhanced features
        % 1. Subject metadata
        h5writeatt(test_file, '/', 'subject_name', 'TEST_ENHANCED');
        h5writeatt(test_file, '/', 'session_id', 'SES_ENHANCED');
        
        % 2. Node descriptors
        channels = ["CH1", "CH2", "CH3", "CH4"];
        h5create(test_file, '/node_info/channel_name', [N, 1], 'Datatype', 'string');
        h5write(test_file, '/node_info/channel_name', channels');
        
        % 3. Preprocessed signals
        X_preproc = single(0.9 * X_raw);
        h5create(test_file, '/signals/preproc', [T, N], 'Datatype', 'single');
        h5write(test_file, '/signals/preproc', X_preproc);
        h5writeatt(test_file, '/signals/preproc', 'sampling_rate_hz', fs);
        
        % 4. Feature extraction metadata
        h5writeatt(test_file, '/features/metadata', 'extraction_time', datestr(now));
        h5writeatt(test_file, '/features/metadata', 'num_nodes', N);
        
        % Verify all features
        subject = h5readatt(test_file, '/', 'subject_name');
        channels_read = h5read(test_file, '/node_info/channel_name');
        preproc_fs = h5readatt(test_file, '/signals/preproc', 'sampling_rate_hz');
        extraction_time = h5readatt(test_file, '/features/metadata', 'extraction_time');
        
        % Check BCT compatibility
        bct_works = (B.T == T) && (B.N == N) && (B.fs == fs);
        
        fprintf('  ✓ Subject metadata: %s\n', subject);
        fprintf('  ✓ Channel descriptors: %d channels\n', length(channels_read));
        fprintf('  ✓ Preprocessed signals: %d Hz\n', preproc_fs);
        fprintf('  ✓ Feature metadata: %s\n', extraction_time);
        fprintf('  ✓ BCT compatibility: %s\n', logical_to_check(bct_works));
        
        if ~bct_works
            error('BCT compatibility check failed');
        end
        
        fprintf('Enhanced schema verification: PASSED\n');
        
    catch ME
        fprintf('Enhanced schema verification: FAILED\n');
        fprintf('Error: %s\n', ME.message);
        rethrow(ME);
    end
end

function delete_if_exists(filename)
    if exist(filename, 'file')
        delete(filename);
    end
end

function str = logical_to_check(tf)
    if tf
        str = '✓ PASS';
    else
        str = '❌ FAIL';
    end
end
