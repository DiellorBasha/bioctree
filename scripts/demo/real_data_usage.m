%% Real Data Usage Example
% This shows how to use bstSigFeatures with your actual H5 files

%% Step 1: Basic Usage
% Simply point to your H5 file with preprocessed data at '/preproc/F'
h5_file = 'path/to/your/preprocessed_data.h5';  % Update this path
bstSigFeatures(h5_file);

% This creates: your_preprocessed_data_features.mat

%% Step 2: Load and Analyze Results
load('path/to/your/preprocessed_data_features.mat', 'Features', 'info');

% Basic info
fprintf('Extracted features from %d channels\n', length(unique(Features.ChannelName)));
fprintf('Time range: %.1f to %.1f seconds\n', ...
    seconds(Features.Time(1)), seconds(Features.Time(end)));
fprintf('Total feature vectors: %d\n', height(Features));

%% Step 3: Access Specific Features

% Time domain features
rms_values = Features.RMS;                    % Root mean square
peak_values = Features.PeakValue;             % Peak amplitude
mean_values = Features.MeanLevel;             % Mean level

% Frequency domain features  
centroid = Features.SpectralCentroid;         % Spectral centroid
rolloff = Features.SpectralRolloffPoint;      % 90% rolloff point
entropy = Features.SpectralEntropy;           % Spectral entropy

% Canonical frequency bands (most important for EEG/MEG)
delta_power = Features.BandPower_Band1;       % 1-4 Hz
theta_power = Features.BandPower_Band2;       % 4-8 Hz  
alpha_power = Features.BandPower_Band3;       % 8-12 Hz
beta_power = Features.BandPower_Band4;        % 12-30 Hz
gamma_power = Features.BandPower_Band5;       % 30-60 Hz

%% Step 4: Analysis by Channel
channels = unique(Features.ChannelName);

for ch = 1:length(channels)
    ch_name = channels{ch};
    ch_data = Features(strcmp(Features.ChannelName, ch_name), :);
    
    fprintf('\nChannel %s:\n', ch_name);
    fprintf('  Mean Alpha Power: %.3f\n', mean(ch_data.BandPower_Band3));
    fprintf('  Mean Beta Power: %.3f\n', mean(ch_data.BandPower_Band4));
    fprintf('  Alpha/Beta Ratio: %.3f\n', ...
        mean(ch_data.BandPower_Band3) / mean(ch_data.BandPower_Band4));
end

%% Step 5: Export for Machine Learning
% Features are already in a nice table format for ML
% Remove non-numeric columns if needed
numeric_features = Features(:, varfun(@isnumeric, Features, 'OutputFormat', 'uniform'));

% Save as CSV for Python/R
writetable(Features, 'features_for_ml.csv');

% Or prepare for MATLAB machine learning
X = table2array(numeric_features);  % Feature matrix
% y = your_labels; % Your labels/targets (replace with actual labels)

%% Step 6: Time-Frequency Analysis
% The pipeline extracts comprehensive time-frequency features
% including spectrograms features if your data supports it

% Plot time evolution of key features
figure;
subplot(2,2,1);
plot(Features.Time, Features.BandPower_Band3);
title('Alpha Band Power Over Time');

subplot(2,2,2);
plot(Features.Time, Features.SpectralCentroid);
title('Spectral Centroid Over Time');

subplot(2,2,3);
plot(Features.Time, Features.SpectralEntropy);
title('Spectral Entropy Over Time');

subplot(2,2,4);
scatter(Features.BandPower_Band3, Features.BandPower_Band4);
xlabel('Alpha Power'); ylabel('Beta Power');
title('Alpha vs Beta Power');

%% Step 7: Advanced Analysis
% Calculate derived metrics common in neuroscience

% Relative band powers (normalized)
total_power = Features.BandPower_Band1 + Features.BandPower_Band2 + ...
              Features.BandPower_Band3 + Features.BandPower_Band4 + ...
              Features.BandPower_Band5;

rel_alpha = Features.BandPower_Band3 ./ total_power;
rel_beta = Features.BandPower_Band4 ./ total_power;

% Frequency ratios (common biomarkers)
alpha_beta_ratio = Features.BandPower_Band3 ./ Features.BandPower_Band4;
theta_beta_ratio = Features.BandPower_Band2 ./ Features.BandPower_Band4;

% Add these to your feature set
Features.RelativeAlpha = rel_alpha;
Features.RelativeBeta = rel_beta;
Features.AlphaBetaRatio = alpha_beta_ratio;
Features.ThetaBetaRatio = theta_beta_ratio;

fprintf('\nDerived biomarkers calculated and added to feature table.\n');

%% Step 8: Statistical Analysis
% Basic statistics across all time points and channels
feature_stats = table();
numeric_vars = Features(:, varfun(@isnumeric, Features, 'OutputFormat', 'uniform'));

for i = 1:width(numeric_vars)
    var_name = numeric_vars.Properties.VariableNames{i};
    data = numeric_vars{:, i};
    
    feature_stats.FeatureName{i} = var_name;
    feature_stats.Mean(i) = mean(data, 'omitnan');
    feature_stats.Std(i) = std(data, 'omitnan');
    feature_stats.Median(i) = median(data, 'omitnan');
    feature_stats.IQR(i) = iqr(data);
end

disp('Feature Statistics:');
disp(feature_stats);

%% That's it! 
% Your features are now ready for:
% - Machine learning classification/regression
% - Statistical analysis
% - Biomarker discovery
% - Clinical research
% - Real-time monitoring applications