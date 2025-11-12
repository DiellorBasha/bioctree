%% Quick Start Example: Using bstSigFeatures
% This is a minimal example showing the basic usage

clear; clc;

%% Method 1: Using your actual H5 file
% Replace 'your_file.h5' with your actual file path
% h5_file = 'C:\path\to\your\preprocessed_data.h5';
% bstSigFeatures(h5_file);

%% Method 2: Test with simulated data
fprintf('Creating test data...\n');

% Create a simple test file
test_file = 'test_biosignals.h5';
create_test_data(test_file);

% Extract features
fprintf('Extracting features...\n');
bstSigFeatures(test_file);

% Load results
features = load('test_biosignals_features.mat');
fprintf('Success! Extracted %d feature vectors with %d features each.\n', ...
    height(features.Features), width(features.Features)-1);

% Show available features
fprintf('\nAvailable features:\n');
feature_names = features.Features.Properties.VariableNames;
for i = 1:length(feature_names)
    fprintf('  %d. %s\n', i, feature_names{i});
end

% Show frequency bands
fprintf('\nFrequency bands extracted:\n');
band_features = feature_names(contains(feature_names, 'BandPower'));
band_names = {'Delta (1-4 Hz)', 'Theta (4-8 Hz)', 'Alpha (8-12 Hz)', ...
              'Beta (12-30 Hz)', 'Gamma (30-60 Hz)'};
for i = 1:length(band_features)
    fprintf('  %s: %s\n', band_features{i}, band_names{i});
end

% Quick visualization
figure;
subplot(2,1,1);
plot(features.Features.Time, features.Features.RMS);
title('RMS over time');
xlabel('Time'); ylabel('RMS');

subplot(2,1,2);
plot(features.Features.Time, features.Features.BandPower_Band3);
title('Alpha band power over time');
xlabel('Time'); ylabel('Alpha Power');

fprintf('\nQuick start complete! Check test_biosignals_features.mat for full results.\n');

%% Helper function
function create_test_data(filename)
    if exist(filename, 'file'), delete(filename); end
    
    Fs = 250; t = (0:1/Fs:30)'; % 30 seconds at 250 Hz
    
    % Create 2 channels with different characteristics
    channels = {'C3', 'O1'};
    
    for i = 1:2
        % Simple signal with alpha and beta components
        alpha = 2 * sin(2*pi*10*t + randn*2*pi);
        beta = 1 * sin(2*pi*20*t + randn*2*pi);
        noise = 0.5 * randn(size(t));
        signal = alpha + beta + noise;
        
        % Write to H5
        path = sprintf('/preproc/F/%s', channels{i});
        h5create(filename, path, size(signal));
        h5write(filename, path, signal);
        h5writeatt(filename, path, 'SampleRate', Fs);
    end
end