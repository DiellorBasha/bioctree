# Signal Feature Extraction Pipeline

This pipeline extracts comprehensive signal features from preprocessed biosignal data (EEG, MEG, etc.) stored in H5 format using MATLAB's built-in signal processing feature extractors.

## Overview

The `bstSigFeatures` function processes multichannel biosignal data and extracts three types of features:

1. **Time-domain features**: Statistical properties of the signal
2. **Frequency-domain features**: Spectral characteristics  
3. **Time-frequency features**: Spectrogram-based features

## Usage

### Basic Usage
```matlab
% Run feature extraction on your H5 file
bstSigFeatures('path/to/your/preprocessed_data.h5');
```

### Expected H5 File Structure
Your H5 file should have the following structure:
```
/preproc/F/
├── channel_01    (dataset: time series data)
├── channel_02    (dataset: time series data)
├── ...
└── attributes:
    ├── SampleRate: sampling frequency (Hz)
    └── NumChannels: number of channels
```

## Features Extracted

### Time-Domain Features (7 features)
- **RMS**: Root mean square
- **ImpulseFactor**: Impulse factor
- **StandardDeviation**: Standard deviation
- **ZeroCrossingRate**: Zero-crossing rate
- **MeanAbsoluteDeviation**: Mean absolute deviation
- **Kurtosis**: Fourth moment statistic
- **Skewness**: Third moment statistic

### Frequency-Domain Features (12 features)
- **MedianFrequency**: Median frequency
- **BandPower**: Power in frequency bands (5 bands: δ, θ, α, β, γ)
- **PeakAmplitude**: Peak amplitude in spectrum
- **MeanFrequency**: Mean frequency
- **PowerBandwidth**: Power bandwidth
- **SpectralCentroid**: Spectral centroid
- **SpectralCrest**: Spectral crest factor
- **SpectralDecrease**: Spectral decrease
- **SpectralEntropy**: Spectral entropy
- **SpectralFlatness**: Spectral flatness
- **SpectralRolloffPoint**: Spectral rolloff point
- **SpectralSlope**: Spectral slope
- **SpectralSpread**: Spectral spread

### Time-Frequency Features (4 features)
- **SpectralKurtosis**: Spectral kurtosis
- **SpectralSkewness**: Spectral skewness
- **TFRidges**: Time-frequency ridges
- **SpectrogramPeaks**: Spectrogram peaks

## Parameters

### Frame Settings
- **Frame size**: 4 seconds (adjustable)
- **Hop size**: 1 second (adjustable)
- **Overlap**: 3 seconds (frame - hop)

### Frequency Bands
- **Delta**: 1-4 Hz
- **Theta**: 4-8 Hz
- **Alpha**: 8-12 Hz
- **Beta**: 12-30 Hz
- **Gamma**: 30-60 Hz (or Nyquist-1)

## Output

The function saves extracted features to a MAT file named `{input_filename}_features.mat` containing:

- **Features**: Timetable with all extracted features
- **info**: Metadata about the input data

### Feature Timetable Structure
```matlab
Features = 
    Time         | RMS  | ImpulseFactor | ... | ChannelName
    00:02:00     | 1.23 | 2.45         | ... | 'EEG01'
    00:03:00     | 1.45 | 2.67         | ... | 'EEG01'
    ...
```

## Example Workflow

```matlab
%% 1. Load and inspect your data
h5File = 'my_biosignal_data.h5';
h5disp(h5File);  % Check structure

%% 2. Run feature extraction
bstSigFeatures(h5File);

%% 3. Load and analyze results
load('my_biosignal_data_features.mat', 'Features');

% Basic statistics
fprintf('Extracted %d feature vectors\n', height(Features));
fprintf('Features: %s\n', strjoin(Features.Properties.VariableNames, ', '));

% Plot time course of a feature
figure;
plot(Features.Time, Features.RMS);
title('RMS Feature Over Time');
xlabel('Time'); ylabel('RMS');

% Analyze by channel
channels = unique(Features.ChannelName);
for i = 1:length(channels)
    ch_data = Features(strcmp(Features.ChannelName, channels{i}), :);
    % Analysis for each channel...
end
```

## Demo Scripts

### Quick Validation
```matlab
validate_feature_extraction();  % Quick test with synthetic data
```

### Complete Example
```matlab
example_usage();  % Full workflow demonstration
```

### Custom Test Data
```matlab
test_signal_features();  % Create and test with custom synthetic data
```

## Requirements

- MATLAB R2020b or later
- Signal Processing Toolbox
- Audio Toolbox (for some features)
- Your data in H5 format with the expected structure

## Troubleshooting

### Common Issues

1. **"File not found"**: Check the H5 file path
2. **"Invalid H5 structure"**: Ensure your H5 file has `/preproc/F/` group with channel datasets
3. **"Frame size too large"**: Reduce frame size for shorter signals
4. **Memory issues**: Process fewer channels at once or reduce frame size

### Error Handling
The pipeline includes error handling for:
- Missing files
- Corrupted data
- Insufficient signal length
- Individual channel processing errors

### Performance Tips
- Use shorter frames for faster processing
- Process channels in batches for large datasets
- Consider downsampling very high-frequency data

## Advanced Usage

### Custom Frame Parameters
```matlab
% Edit bstSigFeatures.m to modify:
frame = round(2*Fs);    % 2-second frames
hop = round(0.5*Fs);    % 0.5-second hop
```

### Custom Feature Selection
```matlab
% Edit the feature extractor setup in bstSigFeatures.m:
timeFE = signalTimeFeatureExtractor(...
    'RMS', true, ...
    'ZeroCrossingRate', false, ...  % Disable specific features
    ...);
```

### Custom Frequency Bands
```matlab
% Modify frequency bands for BandPower:
setExtractorParameters(freqFE, 'BandPower', 'FrequencyBands', ...
    [0.5 4; 4 8; 8 13; 13 30; 30 100]);  % Custom bands
```

## Citation

When using this pipeline, please cite:
- MATLAB Signal Processing Toolbox
- Your biosignal acquisition method/device
- Any relevant preprocessing steps