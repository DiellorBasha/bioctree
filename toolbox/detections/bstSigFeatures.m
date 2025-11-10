
function bstSigFeatures(outFile)
% BSTSIGFEATURES Signal feature extraction pipeline for biosignal data
%
% This function extracts time-domain, frequency-domain, and time-frequency
% features from preprocessed H5 channel data using MATLAB's built-in
% signal feature extractors.
%
% Usage:
%   bstSigFeatures(outFile)
%
% Input:
%   outFile - Path to H5 file containing preprocessed data at '/preproc/F'

if nargin < 1
    error('Please provide the path to the H5 file containing preprocessed data');
end

% Check if file exists
if ~exist(outFile, 'file')
    error('File not found: %s', outFile);
end

fprintf('Starting signal feature extraction pipeline...\n');
fprintf('Input file: %s\n', outFile);

%% ---- Load preprocessed data ---------------------------------------------
fprintf('Loading preprocessed data...\n');
ds_proc = H5ChannelDatastore(outFile, '/preproc/F');
fprintf('Datastore created with %d channels\n', ds_proc.NumChannels);

% Read first channel to get data info
[TT, info] = read(ds_proc);      % TT: timetable with variable 'x', Time in seconds
disp('Data info:');
disp(info);
fprintf('Data preview (first 5 rows):\n');
disp(head(TT, 5));
fprintf('Data size: %d samples x %d channels\n', length(TT.x), ds_proc.NumChannels);

% Reset to beginning for processing
reset(ds_proc);

%% ---- Framing (4 s frames, 1 s hop) -------------------------------------
fprintf('Setting up framing parameters...\n');
Fs      = ds_proc.Fs;
frame   = round(4*Fs);              % e.g., 1024 if Fs=256, 1200 if Fs=300
hop     = round(1*Fs);              % 1 s hop
overlap = frame - hop;

fprintf('Framing parameters:\n');
fprintf('  Sampling rate: %d Hz\n', Fs);
fprintf('  Frame size: %d samples (%.1f s)\n', frame, frame/Fs);
fprintf('  Hop size: %d samples (%.1f s)\n', hop, hop/Fs);
fprintf('  Overlap: %d samples (%.1f s)\n', overlap, overlap/Fs);

%% ---- 1) Time-domain extractor ------------------------------------------
fprintf('Setting up time-domain feature extractor...\n');
timeFE = signalTimeFeatureExtractor( ...
    'SampleRate', Fs, ...
    'FrameSize', frame, ...
    'FrameOverlapLength', overlap, ...
    'RMS', true, ...
    'ImpulseFactor', true, ...
    'StandardDeviation', true, ...
    'ZeroCrossingRate', true, ...
    'MeanAbsoluteDeviation', true, ...
    'Kurtosis', true, ...
    'Skewness', true);

fprintf('Time-domain features: %s\n', strjoin(timeFE.FeatureNames, ', '));

%% ---- 2) Frequency-domain extractor -------------------------------------
fprintf('Setting up frequency-domain feature extractor...\n');
freqFE = signalFrequencyFeatureExtractor( ...
    'SampleRate', Fs, ...
    'FrameSize', frame, ...
    'FrameOverlapLength', overlap, ...
    'MedianFrequency', true, ...
    'BandPower', true, ...
    'PeakAmplitude', true, ...
    'MeanFrequency', true, ...
    'PowerBandwidth', true, ...
    'SpectralCentroid', true, ...
    'SpectralCrest', true, ...
    'SpectralDecrease', true, ...
    'SpectralEntropy', true, ...
    'SpectralFlatness', true, ...
    'SpectralRolloffPoint', true, ...
    'SpectralSlope', true, ...
    'SpectralSpread', true);

% Set canonical MEG/EEG frequency bands for BandPower
% Delta (1-4 Hz), Theta (4-8 Hz), Alpha (8-12 Hz), Beta (12-30 Hz), Gamma (30-60 Hz)
setExtractorParameters(freqFE, 'BandPower', 'FrequencyBands', ...
    [1 4; 4 8; 8 12; 12 30; 30 min(60, Fs/2-1)]);  % Ensure max freq < Nyquist

fprintf('Frequency-domain features: %s\n', strjoin(freqFE.FeatureNames, ', '));

%% ---- 3) Time–frequency extractor (spectrogram-based) --------------------
fprintf('Setting up time-frequency feature extractor...\n');
timeFreqFE = signalTimeFrequencyFeatureExtractor( ...
    'SampleRate', Fs, ...
    'FrameSize', frame, ...
    'FrameOverlapLength', overlap, ...
    'SpectralKurtosis', true, ...
    'SpectralSkewness', true, ...
    'TFRidges', true, ...
    'SpectrogramPeaks', true);

% Spectrogram settings for better time-frequency resolution
setExtractorParameters(timeFreqFE, "spectrogram", 'Leakage', 0.85);

fprintf('Time-frequency features: %s\n', strjoin(timeFreqFE.FeatureNames, ', '));


%% ---- Per-channel pipeline using transform() -----------------------------
fprintf('Setting up feature extraction pipeline...\n');

% For each channel timetable TT, compute all three domains and return
% a single timetable whose row times are the frame centers.
proc = @(TT) perChannelFeatures(TT, timeFE, freqFE, timeFreqFE, Fs, frame, hop);

% Apply transformation to all channels
fprintf('Applying feature extraction to all channels...\n');
tds = transform(ds_proc, proc, 'IncludeInfo', true);

% Collect all channels' features (each is a timetable with a ChannelName col)
reset(tds);
all_feat = cell(1, ds_proc.NumChannels);
fprintf('Processing %d channels...\n', ds_proc.NumChannels);

for k = 1:ds_proc.NumChannels
    fprintf('  Processing channel %d/%d...\n', k, ds_proc.NumChannels);
    FTT = read(tds);                 % timetable for channel k
    all_feat{k} = FTT;
end

% Combine all channel features
fprintf('Combining features from all channels...\n');
Features = vertcat(all_feat{:});     % one big timetable

fprintf('Feature extraction completed!\n');
fprintf('Total feature rows: %d\n', height(Features));
fprintf('Feature variables: %s\n', strjoin(Features.Properties.VariableNames, ', '));
fprintf('Preview of extracted features:\n');
disp(Features(1:min(5, height(Features)),:));

% Save features to output file
[filepath, name, ~] = fileparts(outFile);
featuresFile = fullfile(filepath, [name '_features.mat']);
save(featuresFile, 'Features', 'info', '-v7.3');
fprintf('Features saved to: %s\n', featuresFile);

end

%% ---- Helper function for per-channel feature extraction ----------------
function FTT = perChannelFeatures(TT, timeFE, freqFE, timeFreqFE, Fs, frame, hop)
% PERCHANNELFEATURES Extract features from a single channel timetable
%
% Inputs:
%   TT - Input timetable with signal data in first variable
%   timeFE - Time-domain feature extractor
%   freqFE - Frequency-domain feature extractor  
%   timeFreqFE - Time-frequency feature extractor
%   Fs - Sampling frequency
%   frame - Frame size in samples
%   hop - Hop size in samples
%
% Output:
%   FTT - Feature timetable with extracted features

    try
        % Extract signal data from first variable
        var_names = TT.Properties.VariableNames;
        x = TT{:, 1};  % Get data from first variable
        
        % Get channel name from variable name
        channelName = var_names{1};
        
        % Ensure signal is column vector
        if isrow(x)
            x = x(:);
        end
        
        % Check if signal is long enough for framing
        if length(x) < frame
            warning('Signal too short for frame size. Padding with zeros.');
            x = [x; zeros(frame - length(x), 1)];
        end
        
        % Extract time-domain features
        timeFeat = extract(timeFE, x);
        
        % Extract frequency-domain features  
        freqFeat = extract(freqFE, x);
        
        % Extract time-frequency features
        timeFreqFeat = extract(timeFreqFE, x);
        
        % Create frame time stamps (center of each frame)
        numFrames = size(timeFeat, 1);
        frameStarts = (0:numFrames-1) * hop + 1;
        frameCenters = frameStarts + frame/2 - 1;
        frameTimeStamps = seconds(frameCenters / Fs);
        
        % Convert to timetables
        timeTT = array2timetable(timeFeat, 'RowTimes', frameTimeStamps, ...
            'VariableNames', timeFE.FeatureNames);
        freqTT = array2timetable(freqFeat, 'RowTimes', frameTimeStamps, ...
            'VariableNames', freqFE.FeatureNames);
        timeFreqTT = array2timetable(timeFreqFeat, 'RowTimes', frameTimeStamps, ...
            'VariableNames', timeFreqFE.FeatureNames);
        
        % Combine all features
        FTT = [timeTT, freqTT, timeFreqTT];
        
        % Add channel identifier
        FTT.ChannelName = repmat({channelName}, height(FTT), 1);
        
    catch ME
        warning('Error processing channel %s: %s', channelName, ME.message);
        % Return empty timetable on error
        FTT = timetable();
    end
end