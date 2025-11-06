%% Complete Example: Signal Feature Extraction Pipeline
% This script demonstrates how to use bstSigFeatures for real biosignal analysis

clear; clc; close all;

%% Step 1: Setup and Data Preparation
fprintf('=== Signal Feature Extraction Example ===\n\n');

% For this example, we'll create realistic EEG-like data
% In practice, replace this with your actual H5 file path
h5_file = create_example_eeg_data();

fprintf('Example H5 file created: %s\n\n', h5_file);

%% Step 2: Run Feature Extraction
fprintf('Running feature extraction pipeline...\n');
tic;
bstSigFeatures(h5_file);
extraction_time = toc;
fprintf('Feature extraction completed in %.2f seconds\n\n', extraction_time);

%% Step 3: Load and Explore Results
[filepath, name, ~] = fileparts(h5_file);
features_file = fullfile(filepath, [name '_features.mat']);
load(features_file, 'Features', 'info');

fprintf('=== Results Summary ===\n');
fprintf('Total feature vectors: %d\n', height(Features));
fprintf('Total features per vector: %d\n', width(Features)-1); % -1 for ChannelName
fprintf('Time range: %.1f to %.1f seconds\n', ...
    seconds(Features.Time(1)), seconds(Features.Time(end)));
fprintf('Channels processed: %s\n', strjoin(unique(Features.ChannelName), ', '));

%% Step 4: Analyze Frequency Band Powers
fprintf('\n=== Frequency Band Analysis ===\n');

% Extract band power features
band_features = Features(:, contains(Features.Properties.VariableNames, 'BandPower'));
band_names = {'Delta (1-4 Hz)', 'Theta (4-8 Hz)', 'Alpha (8-12 Hz)', ...
              'Beta (12-30 Hz)', 'Gamma (30-60 Hz)'};

% Calculate mean band powers across all time and channels
mean_powers = mean(table2array(band_features), 1);

figure('Position', [100, 100, 1200, 800]);

% Plot 1: Band Power Distribution
subplot(2,3,1);
bar(mean_powers);
set(gca, 'XTickLabel', band_names, 'XTickLabelRotation', 45);
title('Mean Band Powers');
ylabel('Power (µV²)');
grid on;

%% Step 5: Time Course Analysis
% Plot time evolution of different features for first channel
ch1_data = Features(strcmp(Features.ChannelName, Features.ChannelName{1}), :);

subplot(2,3,2);
plot(ch1_data.Time, ch1_data.RMS, 'LineWidth', 2);
title('RMS Over Time');
xlabel('Time'); ylabel('RMS');
grid on;

subplot(2,3,3);
plot(ch1_data.Time, ch1_data.BandPower_Band3, 'LineWidth', 2); % Alpha band
title('Alpha Band Power Over Time');
xlabel('Time'); ylabel('Alpha Power');
grid on;

%% Step 6: Channel Comparison
channels = unique(Features.ChannelName);
colors = lines(length(channels));

subplot(2,3,4);
hold on;
for i = 1:length(channels)
    ch_data = Features(strcmp(Features.ChannelName, channels{i}), :);
    plot(ch_data.Time, ch_data.SpectralCentroid, 'Color', colors(i,:), ...
         'LineWidth', 2, 'DisplayName', channels{i});
end
title('Spectral Centroid by Channel');
xlabel('Time'); ylabel('Frequency (Hz)');
legend('show'); grid on;

%% Step 7: Feature Correlation Analysis
subplot(2,3,5);
numeric_features = Features(:, varfun(@isnumeric, Features, 'OutputFormat', 'uniform'));
corr_matrix = corr(table2array(numeric_features), 'Rows', 'complete');
imagesc(corr_matrix); colorbar;
title('Feature Correlation Matrix');
set(gca, 'XTick', 1:size(corr_matrix,1), 'YTick', 1:size(corr_matrix,1), ...
    'XTickLabel', numeric_features.Properties.VariableNames, ...
    'YTickLabel', numeric_features.Properties.VariableNames, ...
    'XTickLabelRotation', 90, 'YTickLabelRotation', 0);

%% Step 8: Statistical Summary
subplot(2,3,6);
% Show distribution of alpha/beta ratio (common in EEG analysis)
alpha_power = Features.BandPower_Band3;
beta_power = Features.BandPower_Band4;
alpha_beta_ratio = alpha_power ./ (beta_power + eps);

histogram(alpha_beta_ratio, 20);
title('Alpha/Beta Ratio Distribution');
xlabel('Alpha/Beta Ratio'); ylabel('Count');
grid on;

sgtitle('Signal Feature Extraction Results', 'FontSize', 16, 'FontWeight', 'bold');

%% Step 9: Export Results for Further Analysis
fprintf('\n=== Exporting Results ===\n');

% Create summary statistics
summary_stats = table();
feature_names = numeric_features.Properties.VariableNames;

for i = 1:length(feature_names)
    feat_data = numeric_features{:, i};
    summary_stats.Feature{i} = feature_names{i};
    summary_stats.Mean(i) = mean(feat_data, 'omitnan');
    summary_stats.Std(i) = std(feat_data, 'omitnan');
    summary_stats.Min(i) = min(feat_data);
    summary_stats.Max(i) = max(feat_data);
end

% Save summary
summary_file = fullfile(filepath, [name '_summary.csv']);
writetable(summary_stats, summary_file);
fprintf('Summary statistics saved: %s\n', summary_file);

% Save full features as CSV for external analysis (Python, R, etc.)
csv_file = fullfile(filepath, [name '_features.csv']);
writetable(Features, csv_file);
fprintf('Features saved as CSV: %s\n', csv_file);

%% Step 10: Clinical/Research Insights
fprintf('\n=== Clinical Insights ===\n');

% Calculate some common EEG metrics
overall_alpha = mean(Features.BandPower_Band3);
overall_beta = mean(Features.BandPower_Band4);
overall_theta = mean(Features.BandPower_Band2);
overall_delta = mean(Features.BandPower_Band1);

fprintf('Average band powers:\n');
fprintf('  Delta: %.3f µV²\n', overall_delta);
fprintf('  Theta: %.3f µV²\n', overall_theta);
fprintf('  Alpha: %.3f µV²\n', overall_alpha);
fprintf('  Beta:  %.3f µV²\n', overall_beta);

% Alpha/Beta ratio (attention indicator)
ab_ratio = overall_alpha / overall_beta;
fprintf('  Alpha/Beta ratio: %.3f\n', ab_ratio);

% Spectral edge frequency (90% of power below this frequency)
avg_rolloff = mean(Features.SpectralRolloffPoint);
fprintf('  Spectral edge (90%%): %.1f Hz\n', avg_rolloff);

% Complexity measures
avg_entropy = mean(Features.SpectralEntropy);
fprintf('  Spectral entropy: %.3f\n', avg_entropy);

fprintf('\nInterpretation hints:\n');
if ab_ratio > 1.5
    fprintf('- High alpha/beta ratio suggests relaxed state\n');
elseif ab_ratio < 0.7
    fprintf('- Low alpha/beta ratio suggests active/alert state\n');
else
    fprintf('- Moderate alpha/beta ratio suggests balanced state\n');
end

if avg_entropy > 0.8
    fprintf('- High spectral entropy suggests complex/irregular activity\n');
else
    fprintf('- Low spectral entropy suggests more rhythmic activity\n');
end

%% Cleanup
fprintf('\nExample completed! Check the generated plots and files.\n');

%% Helper Function: Create Realistic EEG Data
function h5_file = create_example_eeg_data()
    h5_file = fullfile(tempdir, 'example_eeg_data.h5');
    
    if exist(h5_file, 'file')
        delete(h5_file);
    end
    
    % Realistic EEG parameters
    Fs = 256;           % Standard EEG sampling rate
    duration = 60;      % 1 minute of data
    num_channels = 4;   % 4 EEG channels
    
    t = (0:1/Fs:duration-1/Fs)';
    
    % Channel names and locations
    channel_names = {'Fp1', 'C3', 'O1', 'T7'};
    
    for ch = 1:num_channels
        % Create realistic EEG with different dominant frequencies per channel
        switch ch
            case 1 % Frontal - more beta activity
                alpha = 1.0 * sin(2*pi*10*t + randn*2*pi);
                beta = 2.0 * sin(2*pi*20*t + randn*2*pi);
                theta = 0.5 * sin(2*pi*6*t + randn*2*pi);
                
            case 2 % Central - mixed activity
                alpha = 2.0 * sin(2*pi*10*t + randn*2*pi);
                beta = 1.0 * sin(2*pi*18*t + randn*2*pi);
                theta = 0.8 * sin(2*pi*7*t + randn*2*pi);
                
            case 3 % Occipital - strong alpha
                alpha = 3.0 * sin(2*pi*10*t + randn*2*pi);
                beta = 0.5 * sin(2*pi*22*t + randn*2*pi);
                theta = 0.3 * sin(2*pi*6*t + randn*2*pi);
                
            case 4 % Temporal - more theta
                alpha = 1.5 * sin(2*pi*9*t + randn*2*pi);
                beta = 1.0 * sin(2*pi*15*t + randn*2*pi);
                theta = 2.0 * sin(2*pi*6*t + randn*2*pi);
        end
        
        % Add some gamma activity
        gamma = 0.3 * sin(2*pi*40*t + randn*2*pi);
        
        % Add physiological noise
        noise = 0.2 * randn(size(t));
        
        % Combine all components
        signal = alpha + beta + theta + gamma + noise;
        
        % Add some artifacts
        if ch == 1 % Eye blinks in frontal channel
            blink_times = 10:15:duration-5;
            for bt = blink_times
                blink_idx = round(bt * Fs);
                blink_duration = round(0.3 * Fs);
                if blink_idx + blink_duration <= length(signal)
                    blink_amplitude = 20;
                    blink_profile = blink_amplitude * exp(-((1:blink_duration) - blink_duration/2).^2 / (blink_duration/8)^2);
                    signal(blink_idx:blink_idx+blink_duration-1) = ...
                        signal(blink_idx:blink_idx+blink_duration-1) + blink_profile';
                end
            end
        end
        
        % Write to H5 file
        dataset_path = sprintf('/preproc/F/%s', channel_names{ch});
        h5create(h5_file, dataset_path, size(signal), 'Datatype', 'double');
        h5write(h5_file, dataset_path, signal);
        
        % Add channel attributes
        h5writeatt(h5_file, dataset_path, 'ChannelName', channel_names{ch});
        h5writeatt(h5_file, dataset_path, 'SampleRate', Fs);
        h5writeatt(h5_file, dataset_path, 'Units', 'µV');
    end
    
    % Add group attributes
    h5writeatt(h5_file, '/preproc/F', 'SampleRate', Fs);
    h5writeatt(h5_file, '/preproc/F', 'NumChannels', num_channels);
    h5writeatt(h5_file, '/preproc/F', 'Duration', duration);
    h5writeatt(h5_file, '/preproc/F', 'Description', 'Example EEG data with realistic characteristics');
end