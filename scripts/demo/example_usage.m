% EXAMPLE_USAGE Script showing how to use the signal feature extraction pipeline
%
% This script demonstrates the complete workflow for extracting signal
% features from preprocessed H5 channel data.

%% Setup
clear; clc; close all;

fprintf('=== Signal Feature Extraction Example ===\n\n');

%% 1. Define your H5 file path
% Replace this with the actual path to your preprocessed H5 file
h5FilePath = 'path/to/your/data.h5';  % ← UPDATE THIS PATH

% For testing, you can create synthetic data:
if ~exist(h5FilePath, 'file')
    fprintf('Creating synthetic test data...\n');
    h5FilePath = create_synthetic_data();
end

%% 2. Run the feature extraction pipeline
try
    fprintf('Running feature extraction on: %s\n', h5FilePath);
    bstSigFeatures(h5FilePath);
    fprintf('✓ Feature extraction completed!\n');
    
catch ME
    fprintf('❌ Error during feature extraction: %s\n', ME.message);
    return;
end

%% 3. Load and examine the results
[filepath, name, ~] = fileparts(h5FilePath);
featuresFile = fullfile(filepath, [name '_features.mat']);

if exist(featuresFile, 'file')
    fprintf('\nLoading extracted features...\n');
    load(featuresFile, 'Features', 'info');
    
    fprintf('=== Feature Summary ===\n');
    fprintf('Number of feature vectors: %d\n', height(Features));
    fprintf('Number of feature types: %d\n', width(Features)-1); % -1 for ChannelName
    fprintf('Time range: %.2f to %.2f seconds\n', ...
        seconds(Features.Time(1)), seconds(Features.Time(end)));
    
    % Display feature names
    featureNames = Features.Properties.VariableNames;
    featureNames = featureNames(~strcmp(featureNames, 'ChannelName'));
    fprintf('\nExtracted features:\n');
    for i = 1:length(featureNames)
        fprintf('  %2d. %s\n', i, featureNames{i});
    end
    
    % Show sample data
    fprintf('\nSample feature data (first 3 time points):\n');
    disp(Features(1:min(3, height(Features)), 1:min(6, width(Features))));
    
else
    fprintf('❌ Features file not found: %s\n', featuresFile);
end

%% Helper function to create test data
function h5File = create_synthetic_data()
    h5File = fullfile(tempdir, 'synthetic_biosignal.h5');
    
    % Parameters
    Fs = 250;           % Typical EEG sampling rate
    duration = 30;      % 30 seconds of data
    numChannels = 3;    % 3 channels for demo
    
    fprintf('Creating synthetic biosignal data:\n');
    fprintf('  Sample rate: %d Hz\n', Fs);
    fprintf('  Duration: %d seconds\n', duration);
    fprintf('  Channels: %d\n', numChannels);
    
    t = (0:1/Fs:duration-1/Fs)';
    
    % Create H5 file structure
    if exist(h5File, 'file')
        delete(h5File);
    end
    
    for ch = 1:numChannels
        % Create realistic biosignal with multiple frequency components
        % Alpha rhythm around 10 Hz
        alpha = 2 * sin(2*pi*(9 + ch)*t + rand*2*pi);
        
        % Beta activity around 20 Hz  
        beta = 1 * sin(2*pi*(18 + ch*2)*t + rand*2*pi);
        
        % Gamma burst (short duration)
        gamma = zeros(size(t));
        burst_start = round(0.3 * length(t));
        burst_end = round(0.4 * length(t));
        gamma(burst_start:burst_end) = 0.5 * sin(2*pi*40*t(burst_start:burst_end));
        
        % Noise
        noise = 0.2 * randn(size(t));
        
        % Combine components
        signal = alpha + beta + gamma + noise;
        
        % Add some artifacts for realism
        if ch == 1
            % Eye blink artifact
            blink_times = [5, 15, 25];
            for bt = blink_times
                blink_idx = round(bt * Fs);
                blink_duration = round(0.2 * Fs);
                if blink_idx + blink_duration <= length(signal)
                    artifact = 5 * exp(-((1:blink_duration) - blink_duration/2).^2 / (blink_duration/6)^2);
                    signal(blink_idx:blink_idx+blink_duration-1) = ...
                        signal(blink_idx:blink_idx+blink_duration-1) + artifact';
                end
            end
        end
        
        % Write to H5 file
        dataset_path = sprintf('/preproc/F/channel_%02d', ch);
        h5create(h5File, dataset_path, size(signal), 'Datatype', 'double');
        h5write(h5File, dataset_path, signal);
        
        % Add channel attributes
        h5writeatt(h5File, dataset_path, 'ChannelName', sprintf('EEG%02d', ch));
        h5writeatt(h5File, dataset_path, 'SampleRate', Fs);
        h5writeatt(h5File, dataset_path, 'Units', 'µV');
    end
    
    % Add group attributes
    h5writeatt(h5File, '/preproc/F', 'SampleRate', Fs);
    h5writeatt(h5File, '/preproc/F', 'NumChannels', numChannels);
    h5writeatt(h5File, '/preproc/F', 'TotalSamples', length(t));
    h5writeatt(h5File, '/preproc/F', 'Duration', duration);
    
    fprintf('Synthetic data saved to: %s\n', h5File);
end