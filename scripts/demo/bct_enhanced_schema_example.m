%% BCT Enhanced Schema Usage Example
% This example demonstrates the enhanced BCT schema with:
% 1. Node descriptors (channel names, positions, etc.)
% 2. Preprocessed signals
% 3. Feature extraction with chunk descriptors
% 4. Subject-level metadata

clear; clc; close all;

fprintf('=== BCT Enhanced Schema Example ===\n\n');

%% Step 1: Create a BCT file with enhanced metadata
example_file = 'example_enhanced_bct.h5';

if exist(example_file, 'file')
    delete(example_file);
end

% Basic parameters
Fs = 256;           % Sampling rate
T_duration = 60;    % 60 seconds of data
num_nodes = 64;     % 64 EEG channels
T_samples = Fs * T_duration;

% Time axis
time_s = (0:T_samples-1) / Fs;

% Node IDs
node_ids = int32(1:num_nodes);

fprintf('Creating BCT file with enhanced schema...\n');

%% Step 2: Create basic structure and metadata
% Root attributes (enhanced with subject info)
h5create(example_file, '/temp', 1);  % Temporary dataset to create file
h5write(example_file, '/temp', 0);

% Required root attributes
h5writeatt(example_file, '/', 'datatype', 'bct');
h5writeatt(example_file, '/', 'schema_name', 'bct-core');
h5writeatt(example_file, '/', 'schema_version', '1.0.0');
h5writeatt(example_file, '/', 'indexing', 'C');
h5writeatt(example_file, '/', 'uuid', char(matlab.lang.internal.uuid()));
h5writeatt(example_file, '/', 'created_utc', datestr(now, 'yyyy-mm-ddTHH:MM:SS'));

% Optional root attributes (NEW)
h5writeatt(example_file, '/', 'subject_name', 'SUBJ001');
h5writeatt(example_file, '/', 'session_id', 'SES01');
h5writeatt(example_file, '/', 'recording_date', '2025-11-05');

% Remove temporary dataset
h5delete_if_exists(example_file, '/temp');

%% Step 3: Create axes
fprintf('Creating axes...\n');

% Time axis
h5create(example_file, '/axes/time_s', length(time_s), 'Datatype', 'double');
h5write(example_file, '/axes/time_s', time_s);

% Node ID axis
h5create(example_file, '/axes/node_id', length(node_ids), 'Datatype', 'int32');
h5write(example_file, '/axes/node_id', node_ids);

%% Step 4: Create node descriptors (NEW FEATURE)
fprintf('Creating node descriptors...\n');

% Generate realistic EEG channel names
channel_names = generate_eeg_channel_names(num_nodes);

% Channel types
channel_types = repmat("EEG", num_nodes, 1);
channel_types(1:4) = "EOG";  % First 4 are EOG channels

% 3D positions (simulated electrode positions)
positions = generate_electrode_positions(num_nodes);

% Units
units = repmat("µV", num_nodes, 1);

% Store node descriptors
h5create(example_file, '/node_info/node_name', [num_nodes, 1], 'Datatype', 'string');
h5write(example_file, '/node_info/node_name', string(1:num_nodes)');

h5create(example_file, '/node_info/channel_name', [num_nodes, 1], 'Datatype', 'string');
h5write(example_file, '/node_info/channel_name', channel_names);

h5create(example_file, '/node_info/node_type', [num_nodes, 1], 'Datatype', 'string');
h5write(example_file, '/node_info/node_type', channel_types);

h5create(example_file, '/node_info/node_position', [num_nodes, 3], 'Datatype', 'single');
h5write(example_file, '/node_info/node_position', positions);

h5create(example_file, '/node_info/node_units', [num_nodes, 1], 'Datatype', 'string');
h5write(example_file, '/node_info/node_units', units);

%% Step 5: Create signal data
fprintf('Creating signal data...\n');

% Generate realistic multichannel EEG data
[raw_signals, preproc_signals] = generate_multichannel_eeg(T_samples, num_nodes, Fs, channel_names);

% Raw signals
h5create(example_file, '/signals/raw', [T_samples, num_nodes], 'Datatype', 'single');
h5write(example_file, '/signals/raw', raw_signals);
h5writeatt(example_file, '/signals/raw', 'sampling_rate_hz', Fs);

% Preprocessed signals (NEW FEATURE)
h5create(example_file, '/signals/preproc', [T_samples, num_nodes], 'Datatype', 'single');
h5write(example_file, '/signals/preproc', preproc_signals);
h5writeatt(example_file, '/signals/preproc', 'sampling_rate_hz', Fs);
h5writeatt(example_file, '/signals/preproc', 'preprocessing_steps', 'bandpass_filter:1-50Hz,notch_filter:60Hz,artifact_removal');

%% Step 6: Create feature extraction metadata (NEW FEATURE)
fprintf('Creating feature extraction metadata...\n');

% Chunk parameters
chunk_duration_s = 4.0;
hop_size_s = 2.0;  % 50% overlap
frame_size_samples = round(chunk_duration_s * Fs);
hop_size_samples = round(hop_size_s * Fs);
overlap_samples = frame_size_samples - hop_size_samples;

% Calculate number of chunks
num_chunks_per_channel = floor((T_samples - frame_size_samples) / hop_size_samples) + 1;
total_chunks = num_chunks_per_channel * num_nodes;

fprintf('  Chunk parameters: %.1fs chunks, %.1fs hop, %d total chunks\n', ...
    chunk_duration_s, hop_size_s, total_chunks);

% Create chunk descriptors
chunk_descriptors = create_chunk_descriptors(num_nodes, num_chunks_per_channel, ...
    chunk_duration_s, hop_size_s, Fs, T_duration);

% Store chunk descriptors
store_chunk_descriptors(example_file, chunk_descriptors);

% Store feature matrix (placeholder)
num_features = 12;  % Example: RMS, peak, spectral centroid, 5 band powers, etc.
feature_matrix = randn(total_chunks, num_features, 'single');
feature_names = ["RMS", "PeakValue", "SpectralCentroid", "SpectralRolloff", "SpectralEntropy", ...
                 "DeltaPower", "ThetaPower", "AlphaPower", "BetaPower", "GammaPower", ...
                 "AlphaBetaRatio", "ThetaBetaRatio"];

store_feature_matrix(example_file, feature_matrix, feature_names, chunk_descriptors.chunk_id);

% Store extraction metadata
store_extraction_metadata(example_file, frame_size_samples, hop_size_samples, num_nodes);

%% Step 7: Demonstrate data access
fprintf('\n=== Demonstrating Enhanced Data Access ===\n');

% Read subject information
subject_name = h5readatt(example_file, '/', 'subject_name');
session_id = h5readatt(example_file, '/', 'session_id');
fprintf('Subject: %s, Session: %s\n', subject_name, session_id);

% Read channel information
channel_names_read = h5read(example_file, '/node_info/channel_name');
channel_types_read = h5read(example_file, '/node_info/node_type');
fprintf('Channels: %s\n', strjoin(channel_names_read(1:5)', ', ') + "...");

% Read signal data with sampling rate
raw_data = h5read(example_file, '/signals/raw');
preproc_data = h5read(example_file, '/signals/preproc');
fs_raw = h5readatt(example_file, '/signals/raw', 'sampling_rate_hz');
fs_preproc = h5readatt(example_file, '/signals/preproc', 'sampling_rate_hz');

fprintf('Raw data: %dx%d at %d Hz\n', size(raw_data), fs_raw);
fprintf('Preprocessed data: %dx%d at %d Hz\n', size(preproc_data), fs_preproc);

% Read chunk descriptors
chunk_ids = h5read(example_file, '/features/chunks/chunk_id');
chunk_times = h5read(example_file, '/features/chunks/center_time_s');
chunk_nodes = h5read(example_file, '/features/chunks/node_id');

fprintf('Feature chunks: %d total chunks\n', length(chunk_ids));
fprintf('Time range: %.1f - %.1f seconds\n', min(chunk_times), max(chunk_times));

% Read feature matrix
features_read = h5read(example_file, '/features/matrix/feature_matrix');
feature_names_read = h5read(example_file, '/features/matrix/feature_names');

fprintf('Feature matrix: %dx%d (%s)\n', size(features_read), strjoin(feature_names_read(1:3)', ', ') + "...");

%% Step 8: Query examples
fprintf('\n=== Query Examples ===\n');

% Find chunks from specific channels
target_channels = ["Fp1", "O1", "C3"];
target_node_ids = find_node_ids_by_channel_names(example_file, target_channels);

chunks_mask = ismember(chunk_nodes, target_node_ids);
selected_chunks = sum(chunks_mask);
fprintf('Chunks from %s: %d chunks\n', strjoin(target_channels, ', '), selected_chunks);

% Find chunks in specific time range
time_start = 10; time_end = 20;
time_mask = chunk_times >= time_start & chunk_times <= time_end;
time_chunks = sum(time_mask);
fprintf('Chunks in %.0f-%.0fs: %d chunks\n', time_start, time_end, time_chunks);

% Combined query
combined_mask = chunks_mask & time_mask;
combined_chunks = sum(combined_mask);
fprintf('Combined query: %d chunks\n', combined_chunks);

%% Step 9: Visualization
fprintf('\n=== Creating Visualization ===\n');

figure('Position', [100, 100, 1400, 900]);

% Plot 1: Raw vs preprocessed signals for one channel
subplot(2,3,1);
ch_idx = find(strcmp(channel_names_read, "C3"));
plot(time_s(1:1000), raw_data(1:1000, ch_idx), 'b-', 'LineWidth', 1);
hold on;
plot(time_s(1:1000), preproc_data(1:1000, ch_idx), 'r-', 'LineWidth', 1);
title('Raw vs Preprocessed (C3)');
xlabel('Time (s)'); ylabel('Amplitude (µV)');
legend('Raw', 'Preprocessed');
grid on;

% Plot 2: Channel positions
subplot(2,3,2);
positions_read = h5read(example_file, '/node_info/node_position');
scatter3(positions_read(:,1), positions_read(:,2), positions_read(:,3), 50, 'filled');
title('Electrode Positions');
xlabel('X'); ylabel('Y'); zlabel('Z');
grid on;

% Plot 3: Chunk timeline
subplot(2,3,3);
scatter(chunk_times, chunk_nodes, 20, chunk_ids, 'filled');
title('Chunk Timeline');
xlabel('Time (s)'); ylabel('Node ID');
colorbar; colormap(jet);
grid on;

% Plot 4: Feature correlation
subplot(2,3,4);
feature_corr = corr(features_read, 'Rows', 'complete');
imagesc(feature_corr);
title('Feature Correlation Matrix');
set(gca, 'XTick', 1:length(feature_names_read), 'YTick', 1:length(feature_names_read), ...
    'XTickLabel', feature_names_read, 'YTickLabel', feature_names_read, ...
    'XTickLabelRotation', 45);
colorbar;

% Plot 5: Feature distribution for alpha power
subplot(2,3,5);
alpha_idx = find(strcmp(feature_names_read, "AlphaPower"));
histogram(features_read(:, alpha_idx), 20);
title('Alpha Power Distribution');
xlabel('Alpha Power'); ylabel('Count');
grid on;

% Plot 6: Channel type distribution
subplot(2,3,6);
[unique_types, ~, type_indices] = unique(channel_types_read);
type_counts = accumarray(type_indices, 1);
pie(type_counts, cellstr(unique_types));
title('Channel Type Distribution');

sgtitle('Enhanced BCT Schema Demonstration', 'FontSize', 16, 'FontWeight', 'bold');

fprintf('\nExample completed! Enhanced BCT file created: %s\n', example_file);
fprintf('Key new features demonstrated:\n');
fprintf('✓ Subject metadata (subject_name, session_id)\n');
fprintf('✓ Node descriptors (channel_name, positions, types)\n');
fprintf('✓ Preprocessed signals with metadata\n');
fprintf('✓ Feature extraction with chunk descriptors\n');
fprintf('✓ Sampling rate attributes for each signal type\n');

%% Helper Functions

function names = generate_eeg_channel_names(n)
    % Generate realistic EEG channel names
    standard_names = ["Fp1", "Fp2", "F3", "F4", "C3", "C4", "P3", "P4", "O1", "O2", ...
                      "F7", "F8", "T3", "T4", "T5", "T6", "Fz", "Cz", "Pz", "Oz"];
    
    if n <= length(standard_names)
        names = standard_names(1:n);
    else
        names = [standard_names, string(compose("CH%d", 1:(n-length(standard_names))))];
    end
    names = names(:);
end

function positions = generate_electrode_positions(n)
    % Generate simulated 3D electrode positions on a sphere
    theta = linspace(0, 2*pi, n+1); theta(end) = [];
    phi = linspace(-pi/2, pi/2, ceil(sqrt(n)));
    
    positions = zeros(n, 3);
    idx = 1;
    for i = 1:length(phi)
        for j = 1:length(theta)
            if idx > n, break; end
            positions(idx, :) = [cos(phi(i))*cos(theta(j)), ...
                               cos(phi(i))*sin(theta(j)), ...
                               sin(phi(i))];
            idx = idx + 1;
        end
        if idx > n, break; end
    end
end

function [raw_signals, preproc_signals] = generate_multichannel_eeg(T, N, Fs, channel_names)
    % Generate realistic multichannel EEG data
    t = (0:T-1) / Fs;
    raw_signals = zeros(T, N, 'single');
    
    for ch = 1:N
        % Different frequency content per channel type
        if contains(channel_names(ch), ["O1", "O2", "Oz"])  % Occipital - strong alpha
            alpha = 3.0 * sin(2*pi*10*t + randn*2*pi);
            beta = 1.0 * sin(2*pi*20*t + randn*2*pi);
            theta = 0.5 * sin(2*pi*6*t + randn*2*pi);
        elseif contains(channel_names(ch), ["F", "Fp"])     % Frontal - more beta
            alpha = 1.0 * sin(2*pi*10*t + randn*2*pi);
            beta = 2.5 * sin(2*pi*20*t + randn*2*pi);
            theta = 0.8 * sin(2*pi*6*t + randn*2*pi);
        else                                                % Central/other
            alpha = 2.0 * sin(2*pi*10*t + randn*2*pi);
            beta = 1.5 * sin(2*pi*18*t + randn*2*pi);
            theta = 1.0 * sin(2*pi*7*t + randn*2*pi);
        end
        
        % Add noise and artifacts
        noise = 0.3 * randn(size(t));
        if ch <= 4  % EOG channels have more artifacts
            artifacts = 0.5 * randn(size(t));
            raw_signals(:, ch) = alpha + beta + theta + noise + artifacts;
        else
            raw_signals(:, ch) = alpha + beta + theta + noise;
        end
    end
    
    % Preprocessed signals (filtered and cleaned)
    preproc_signals = raw_signals * 0.8 + 0.1 * randn(size(raw_signals), 'single');
end

function chunk_descriptors = create_chunk_descriptors(num_nodes, num_chunks_per_channel, ...
    chunk_duration_s, hop_size_s, Fs, ~)
    
    total_chunks = num_chunks_per_channel * num_nodes;
    
    chunk_descriptors = struct();
    chunk_descriptors.chunk_id = int32(1:total_chunks)';
    chunk_descriptors.node_id = int32(repmat(1:num_nodes, num_chunks_per_channel, 1)');
    
    % Time calculations
    chunk_descriptors.start_time_s = zeros(total_chunks, 1);
    chunk_descriptors.end_time_s = zeros(total_chunks, 1);
    chunk_descriptors.center_time_s = zeros(total_chunks, 1);
    chunk_descriptors.sample_start = int32(zeros(total_chunks, 1));
    chunk_descriptors.sample_end = int32(zeros(total_chunks, 1));
    chunk_descriptors.chunk_duration_s = single(repmat(chunk_duration_s, total_chunks, 1));
    
    idx = 1;
    for node = 1:num_nodes
        for chunk = 1:num_chunks_per_channel
            start_time = (chunk - 1) * hop_size_s;
            end_time = start_time + chunk_duration_s;
            center_time = start_time + chunk_duration_s / 2;
            
            chunk_descriptors.start_time_s(idx) = start_time;
            chunk_descriptors.end_time_s(idx) = end_time;
            chunk_descriptors.center_time_s(idx) = center_time;
            chunk_descriptors.sample_start(idx) = round(start_time * Fs) + 1;
            chunk_descriptors.sample_end(idx) = round(end_time * Fs);
            
            idx = idx + 1;
        end
    end
end

function store_chunk_descriptors(filename, chunk_descriptors)
    % Store chunk descriptors in H5 file
    
    fields = fieldnames(chunk_descriptors);
    for f = 1:length(fields)
        field_name = fields{f};
        data = chunk_descriptors.(field_name);
        dataset_path = ['/features/chunks/' field_name];
        
        if isa(data, 'int32')
            h5create(filename, dataset_path, size(data), 'Datatype', 'int32');
        elseif isa(data, 'single')
            h5create(filename, dataset_path, size(data), 'Datatype', 'single');
        else
            h5create(filename, dataset_path, size(data), 'Datatype', 'double');
        end
        h5write(filename, dataset_path, data);
    end
    
    % Add attributes
    h5writeatt(filename, '/features/chunks', 'chunk_duration_s', 4.0);
    h5writeatt(filename, '/features/chunks', 'hop_size_s', 2.0);
    h5writeatt(filename, '/features/chunks', 'sampling_rate_hz', 256);
    h5writeatt(filename, '/features/chunks', 'frame_size_samples', 1024);
    h5writeatt(filename, '/features/chunks', 'overlap_samples', 512);
end

function store_feature_matrix(filename, feature_matrix, feature_names, chunk_ids)
    % Store feature matrix and metadata
    
    h5create(filename, '/features/matrix/feature_matrix', size(feature_matrix), 'Datatype', 'single');
    h5write(filename, '/features/matrix/feature_matrix', feature_matrix);
    
    h5create(filename, '/features/matrix/feature_names', [length(feature_names), 1], 'Datatype', 'string');
    h5write(filename, '/features/matrix/feature_names', feature_names(:));
    
    h5create(filename, '/features/matrix/chunk_ids', size(chunk_ids), 'Datatype', 'int32');
    h5write(filename, '/features/matrix/chunk_ids', chunk_ids);
    
    % Add attributes
    h5writeatt(filename, '/features/matrix', 'num_features', length(feature_names));
    h5writeatt(filename, '/features/matrix', 'extraction_method', 'MATLAB_signalFeatureExtractor');
end

function store_extraction_metadata(filename, frame_size_samples, hop_size_samples, num_nodes)
    % Store extraction metadata
    
    h5writeatt(filename, '/features/metadata', 'extraction_time', datestr(now));
    h5writeatt(filename, '/features/metadata', 'extraction_software', 'MATLAB_R2025b');
    h5writeatt(filename, '/features/metadata', 'frame_size_samples', frame_size_samples);
    h5writeatt(filename, '/features/metadata', 'hop_size_samples', hop_size_samples);
    h5writeatt(filename, '/features/metadata', 'num_nodes', num_nodes);
    h5writeatt(filename, '/features/metadata', 'feature_extractor_version', '1.0.0');
    
    % Store frequency band definitions
    freq_bands = single([1, 4; 4, 8; 8, 12; 12, 30; 30, 60]);  % Delta, Theta, Alpha, Beta, Gamma
    h5create(filename, '/features/metadata/frequency_bands', size(freq_bands), 'Datatype', 'single');
    h5write(filename, '/features/metadata/frequency_bands', freq_bands);
    
    % Store feature descriptions
    descriptions = ["Root mean square amplitude", "Peak amplitude value", ...
                   "Spectral centroid frequency", "90% spectral rolloff point", ...
                   "Spectral entropy measure", "Delta band power (1-4 Hz)", ...
                   "Theta band power (4-8 Hz)", "Alpha band power (8-12 Hz)", ...
                   "Beta band power (12-30 Hz)", "Gamma band power (30-60 Hz)", ...
                   "Alpha to beta power ratio", "Theta to beta power ratio"];
    
    h5create(filename, '/features/metadata/feature_descriptions', [length(descriptions), 1], 'Datatype', 'string');
    h5write(filename, '/features/metadata/feature_descriptions', descriptions(:));
end

function node_ids = find_node_ids_by_channel_names(filename, target_channels)
    % Find node IDs corresponding to channel names
    channel_names = h5read(filename, '/node_info/channel_name');
    node_ids_all = h5read(filename, '/axes/node_id');
    
    node_ids = [];
    for i = 1:length(target_channels)
        idx = find(strcmp(channel_names, target_channels(i)));
        if ~isempty(idx)
            node_ids = [node_ids; node_ids_all(idx)];
        end
    end
end

function h5delete_if_exists(filename, dataset_path)
    % Helper to delete dataset if it exists
    try
        h5info(filename, dataset_path);
        % If we get here, dataset exists - but h5delete doesn't exist in MATLAB
        % We'll just skip this for now
    catch
        % Dataset doesn't exist, which is fine
    end
end