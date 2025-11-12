%% Example: Understanding bstSigFeatures Output Location
% This script shows exactly where results are stored

clear; clc;

fprintf('=== bstSigFeatures Output Location Demo ===\n\n');

%% Example file paths
input_files = {
    'C:\Data\patient01_eeg.h5'
    'C:\Projects\study_data.h5'  
    'D:\MEG\session_001.h5'
    '/home/user/signals.h5'
};

output_files = {
    'C:\Data\patient01_eeg_features.mat'
    'C:\Projects\study_data_features.mat'
    'D:\MEG\session_001_features.mat'
    '/home/user/signals_features.mat'
};

fprintf('Input → Output file mapping:\n');
for i = 1:length(input_files)
    fprintf('  %s\n  → %s\n\n', input_files{i}, output_files{i});
end

%% What's inside the .mat file
fprintf('Contents of the _features.mat file:\n');
fprintf('  1. Features (table):\n');
fprintf('     - Rows: One per time frame per channel\n');
fprintf('     - Columns: All extracted features + metadata\n');
fprintf('     - Example columns:\n');

feature_columns = {
    'Time', 'datetime', 'Time stamp for each frame'
    'ChannelName', 'string', 'Channel identifier (e.g., "C3", "Fp1")'
    'RMS', 'double', 'Root mean square amplitude'
    'PeakValue', 'double', 'Peak amplitude in frame'
    'SpectralCentroid', 'double', 'Center frequency of spectrum'
    'BandPower_Band1', 'double', 'Delta power (1-4 Hz)'
    'BandPower_Band2', 'double', 'Theta power (4-8 Hz)'
    'BandPower_Band3', 'double', 'Alpha power (8-12 Hz)'
    'BandPower_Band4', 'double', 'Beta power (12-30 Hz)'
    'BandPower_Band5', 'double', 'Gamma power (30-60 Hz)'
    'SpectralEntropy', 'double', 'Spectral complexity measure'
};

fprintf('     %-20s %-10s %s\n', 'Column', 'Type', 'Description');
fprintf('     %s\n', repmat('-', 1, 70));
for i = 1:size(feature_columns, 1)
    fprintf('     %-20s %-10s %s\n', feature_columns{i,:});
end

fprintf('\n  2. info (struct):\n');
fprintf('     - Extraction parameters used\n');
fprintf('     - Timing information\n');
fprintf('     - Channel information\n');

%% File access examples
fprintf('\n=== How to Access Results ===\n');

fprintf('\nMethod 1 - Load everything:\n');
fprintf('  load(''your_file_features.mat'');\n');
fprintf('  %% Now you have: Features (table) and info (struct)\n');

fprintf('\nMethod 2 - Load specific variables:\n');
fprintf('  load(''your_file_features.mat'', ''Features'');\n');
fprintf('  %% Load only the Features table\n');

fprintf('\nMethod 3 - Programmatic access:\n');
fprintf('  data = load(''your_file_features.mat'');\n');
fprintf('  features = data.Features;\n');
fprintf('  metadata = data.info;\n');

%% Size expectations
fprintf('\n=== Expected File Sizes ===\n');
fprintf('For typical EEG data:\n');
fprintf('  • 64 channels × 60 seconds → ~960 feature vectors\n');
fprintf('  • ~25 features per vector\n');
fprintf('  • Result file: ~2-5 MB\n');
fprintf('\nFor MEG data:\n');
fprintf('  • 306 channels × 300 seconds → ~22,950 feature vectors\n');
fprintf('  • ~25 features per vector  \n');
fprintf('  • Result file: ~20-50 MB\n');

%% Important notes
fprintf('\n=== Important Notes ===\n');
fprintf('✓ Original H5 file is NEVER modified\n');
fprintf('✓ Results are stored in separate .mat file\n');
fprintf('✓ Safe to re-run without data loss\n');
fprintf('✓ Results are in standard MATLAB table format\n');
fprintf('✓ Easy to export to CSV, Excel, or other formats\n');
fprintf('✓ Ready for machine learning workflows\n');

fprintf('\n=== Quick Access Example ===\n');
fprintf('%% After running: bstSigFeatures(''mydata.h5'')\n');
fprintf('load(''mydata_features.mat'', ''Features'');\n');
fprintf('alpha_power = Features.BandPower_Band3;  %% Get alpha band\n');
fprintf('channels = unique(Features.ChannelName);  %% Get channel list\n');
fprintf('writetable(Features, ''results.csv'');   %% Export to CSV\n');

fprintf('\nDemo complete!\n');