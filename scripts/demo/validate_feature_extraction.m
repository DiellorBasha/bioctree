function validate_feature_extraction()
% VALIDATE_FEATURE_EXTRACTION Quick validation of the signal feature pipeline
%
% This script creates simple test data and runs the feature extraction
% to verify everything is working correctly.

fprintf('=== Feature Extraction Validation ===\n\n');

try
    % Create temporary test data
    fprintf('Creating test data...\n');
    testFile = create_test_data();
    
    % Run feature extraction
    fprintf('Running feature extraction...\n');
    bstSigFeatures(testFile);
    
    % Load and examine results
    [filepath, name, ~] = fileparts(testFile);
    featuresFile = fullfile(filepath, [name '_features.mat']);
    
    if exist(featuresFile, 'file')
        load(featuresFile, 'Features');
        
        fprintf('\n=== Validation Results ===\n');
        fprintf('✓ Feature extraction completed successfully!\n');
        fprintf('✓ Features file created: %s\n', featuresFile);
        fprintf('✓ Total feature vectors: %d\n', height(Features));
        fprintf('✓ Feature variables: %d\n', width(Features));
        fprintf('✓ Variable names: %s\n', strjoin(Features.Properties.VariableNames, ', '));
        
        % Check for any NaN or Inf values
        numericVars = varfun(@isnumeric, Features, 'OutputFormat', 'uniform');
        if any(numericVars)
            numericData = Features{:, numericVars};
            nanCount = sum(isnan(numericData(:)));
            infCount = sum(isinf(numericData(:)));
            
            if nanCount == 0 && infCount == 0
                fprintf('✓ No NaN or Inf values detected\n');
            else
                fprintf('⚠ Warning: Found %d NaN and %d Inf values\n', nanCount, infCount);
            end
        end
        
        fprintf('\n=== Sample Features ===\n');
        disp(Features(1:min(3, height(Features)), 1:min(8, width(Features))));
        
    else
        error('Features file was not created');
    end
    
    % Clean up
    if exist(testFile, 'file')
        delete(testFile);
    end
    if exist(featuresFile, 'file')
        delete(featuresFile);
    end
    
    fprintf('\n✓ Validation completed successfully!\n');
    
catch ME
    fprintf('\n❌ Validation failed: %s\n', ME.message);
    rethrow(ME);
end

end

function testFile = create_test_data()
% Create minimal test H5 file with valid structure

    testFile = fullfile(tempdir, 'test_features.h5');
    
    % Delete if exists
    if exist(testFile, 'file')
        delete(testFile);
    end
    
    % Simple test parameters
    Fs = 128;
    duration = 10;  % Short duration for quick test
    t = (0:1/Fs:duration-1/Fs)';
    
    % Create simple test signal (mix of frequencies)
    signal = sin(2*pi*10*t) + 0.5*sin(2*pi*20*t) + 0.1*randn(size(t));
    
    % Write to H5 file
    h5create(testFile, '/preproc/F/test_channel', size(signal));
    h5write(testFile, '/preproc/F/test_channel', signal);
    
    % Add required attributes
    h5writeatt(testFile, '/preproc/F', 'SampleRate', Fs);
    h5writeatt(testFile, '/preproc/F/test_channel', 'ChannelName', 'TEST_CH');
    
    fprintf('Created test file: %s\n', testFile);
end