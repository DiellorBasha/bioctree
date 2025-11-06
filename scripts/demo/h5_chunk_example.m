%% H5-Based Feature Extraction and Chunk Indexing Example
% This example demonstrates the advanced H5-based approach for storing
% features as chunk descriptors for efficient indexing and retrieval

clear; clc; close all;

fprintf('=== H5-Based Feature Extraction Example ===\n\n');

%% Step 1: Create example data and extract features with H5 storage
% Create test H5 file
test_file = create_test_eeg_h5();
fprintf('Created test H5 file: %s\n', test_file);

% Extract features and store as chunk descriptors in H5
fprintf('\nExtracting features with H5 chunk storage...\n');
bstSigFeaturesH5(test_file, ...
    'frameSize', 4, ...      % 4-second chunks
    'hopSize', 2, ...        % 50% overlap (2-second hop)
    'overwrite', true);

fprintf('Features stored as chunk descriptors in H5 file!\n');

%% Step 2: Explore the H5 structure
fprintf('\n=== H5 File Structure ===\n');
h5_structure = h5info(test_file);
display_h5_structure(h5_structure, '');

%% Step 3: Query chunks by features
fprintf('\n=== Feature-Based Chunk Querying ===\n');

% Example 1: Find chunks with high alpha activity
fprintf('\n1. Finding high alpha activity chunks:\n');
query1 = struct();
query1.feature = 'BandPower_Band3';  % Alpha band
query1.operator = '>';
query1.threshold = 0.5;              % Adjust threshold as needed

[alpha_chunks, alpha_indices] = queryChunksByFeatures(test_file, query1);
fprintf('Found %d chunks with high alpha activity\n', length(alpha_chunks));

% Example 2: Find chunks from specific channels with multiple criteria
fprintf('\n2. Finding complex patterns:\n');
query2 = struct();
query2.channel = {'C3', 'O1'};      % Specific channels
query2.criteria = [
    struct('feature', 'BandPower_Band3', 'operator', '>', 'threshold', 0.3); ... % Alpha > 0.3
    struct('feature', 'BandPower_Band4', 'operator', '<', 'threshold', 0.8) ...  % Beta < 0.8
];

[complex_chunks, complex_indices] = queryChunksByFeatures(test_file, query2);
fprintf('Found %d chunks matching complex criteria\n', length(complex_chunks));

% Example 3: Custom function query
fprintf('\n3. Using custom query function:\n');
custom_query = @(chunk) chunk.BandPower_Band3 > chunk.BandPower_Band4 && ... % Alpha dominance
                       chunk.SpectralEntropy < 0.8;                          % Low complexity

[custom_chunks, custom_indices] = queryChunksByFeatures(test_file, custom_query);
fprintf('Found %d chunks with alpha dominance and low complexity\n', length(custom_chunks));

%% Step 4: Analyze retrieved chunks
fprintf('\n=== Chunk Analysis ===\n');

if ~isempty(alpha_chunks)
    % Analyze the first high-alpha chunk
    chunk1 = alpha_chunks{1};
    
    fprintf('First high-alpha chunk details:\n');
    fprintf('  Channel: %s\n', chunk1.descriptor.channel_name);
    fprintf('  Time: %.2f - %.2f seconds\n', ...
        chunk1.descriptor.start_time, chunk1.descriptor.end_time);
    fprintf('  Alpha power: %.3f\n', chunk1.descriptor.BandPower_Band3);
    fprintf('  Beta power: %.3f\n', chunk1.descriptor.BandPower_Band4);
    fprintf('  Alpha/Beta ratio: %.3f\n', ...
        chunk1.descriptor.BandPower_Band3 / chunk1.descriptor.BandPower_Band4);
    
    % Plot the chunk data
    figure('Position', [100, 100, 1200, 800]);
    
    subplot(2,2,1);
    plot(chunk1.data.time_vector, chunk1.data.signal);
    title(sprintf('High Alpha Chunk - %s', chunk1.descriptor.channel_name));
    xlabel('Time (s)'); ylabel('Amplitude');
    grid on;
    
    % Show power spectrum
    subplot(2,2,2);
    [pxx, f] = pwelch(chunk1.data.signal, [], [], [], chunk1.data.sample_rate);
    plot(f, 10*log10(pxx));
    title('Power Spectrum of Chunk');
    xlabel('Frequency (Hz)'); ylabel('Power (dB)');
    xlim([0 50]); grid on;
    
    % Band power comparison
    subplot(2,2,3);
    bands = {'Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'};
    powers = [chunk1.descriptor.BandPower_Band1, chunk1.descriptor.BandPower_Band2, ...
              chunk1.descriptor.BandPower_Band3, chunk1.descriptor.BandPower_Band4, ...
              chunk1.descriptor.BandPower_Band5];
    bar(powers);
    set(gca, 'XTickLabel', bands);
    title('Band Powers for This Chunk');
    ylabel('Power'); grid on;
end

%% Step 5: Bulk analysis of selected chunks
fprintf('\n=== Bulk Chunk Analysis ===\n');

if length(alpha_chunks) > 1
    % Extract features from all high-alpha chunks
    alpha_powers = zeros(length(alpha_chunks), 1);
    beta_powers = zeros(length(alpha_chunks), 1);
    channels = cell(length(alpha_chunks), 1);
    times = zeros(length(alpha_chunks), 1);
    
    for i = 1:length(alpha_chunks)
        alpha_powers(i) = alpha_chunks{i}.descriptor.BandPower_Band3;
        beta_powers(i) = alpha_chunks{i}.descriptor.BandPower_Band4;
        channels{i} = alpha_chunks{i}.descriptor.channel_name;
        times(i) = alpha_chunks{i}.descriptor.center_time;
    end
    
    % Plot distributions
    if exist('subplot', 'builtin')
        subplot(2,2,4);
        scatter(alpha_powers, beta_powers, 50, times, 'filled');
        xlabel('Alpha Power'); ylabel('Beta Power');
        title('Alpha vs Beta Power (High Alpha Chunks)');
        colorbar; colormap(jet);
        grid on;
    end
    
    % Summary statistics
    fprintf('High-alpha chunks summary:\n');
    fprintf('  Mean alpha power: %.3f ± %.3f\n', mean(alpha_powers), std(alpha_powers));
    fprintf('  Mean beta power: %.3f ± %.3f\n', mean(beta_powers), std(beta_powers));
    fprintf('  Channels involved: %s\n', strjoin(unique(channels), ', '));
    fprintf('  Time range: %.1f - %.1f seconds\n', min(times), max(times));
end

%% Step 6: Feature-based machine learning preparation
fprintf('\n=== ML Preparation ===\n');

% Load all chunk descriptors for ML
all_descriptors = queryChunksByFeatures(test_file, @(x) true, 'returnData', false);
fprintf('Loaded %d total chunk descriptors\n', length(all_descriptors));

% Convert to feature matrix
feature_names = {'RMS', 'PeakValue', 'MeanLevel', 'StandardDeviation', ...
                 'SpectralCentroid', 'SpectralRolloffPoint', 'SpectralEntropy', ...
                 'BandPower_Band1', 'BandPower_Band2', 'BandPower_Band3', ...
                 'BandPower_Band4', 'BandPower_Band5'};

X = zeros(length(all_descriptors), length(feature_names));
channel_labels = cell(length(all_descriptors), 1);
time_stamps = zeros(length(all_descriptors), 1);

for i = 1:length(all_descriptors)
    for j = 1:length(feature_names)
        if isfield(all_descriptors(i), feature_names{j})
            X(i, j) = all_descriptors(i).(feature_names{j});
        end
    end
    channel_labels{i} = all_descriptors(i).channel_name;
    time_stamps(i) = all_descriptors(i).center_time;
end

fprintf('Feature matrix: %d samples × %d features\n', size(X, 1), size(X, 2));
fprintf('Ready for ML algorithms!\n');

%% Step 7: Demonstrate efficiency gains
fprintf('\n=== Efficiency Demonstration ===\n');

% Time the chunk-based approach vs loading full data
tic;
selected_chunks = queryChunksByFeatures(test_file, query1);
chunk_time = toc;

tic;
% Simulate loading full dataset
ds = H5ChannelDatastore(test_file, '/preproc/F');
[full_data, ~] = read(ds);
full_time = toc;

fprintf('Chunk-based retrieval: %.4f seconds\n', chunk_time);
fprintf('Full data loading: %.4f seconds\n', full_time);
fprintf('Speedup factor: %.1fx\n', full_time / chunk_time);

%% Step 8: Export chunk index for external tools
fprintf('\n=== Export Options ===\n');

% Export chunk descriptors to CSV for external analysis
export_file = 'chunk_descriptors.csv';
export_chunk_descriptors_to_csv(all_descriptors, export_file);
fprintf('Chunk descriptors exported to: %s\n', export_file);

% Create summary report
create_chunk_summary_report(test_file, all_descriptors);

fprintf('\n=== Example Complete! ===\n');
fprintf('Key advantages of H5-based approach:\n');
fprintf('✓ Efficient chunk-based data access\n');
fprintf('✓ Feature-based indexing and querying\n');
fprintf('✓ Reduced memory usage for large datasets\n');
fprintf('✓ Fast retrieval of specific patterns\n');
fprintf('✓ Integration with original data structure\n');
fprintf('✓ Scalable to very large biosignal datasets\n');

%% Helper Functions

function h5_file = create_test_eeg_h5()
    h5_file = fullfile(tempdir, 'test_eeg_with_chunks.h5');
    
    if exist(h5_file, 'file')
        delete(h5_file);
    end
    
    % Create realistic multi-channel EEG data
    Fs = 256;
    duration = 30;  % 30 seconds
    channels = {'Fp1', 'C3', 'O1', 'T7'};
    
    t = (0:1/Fs:duration-1/Fs)';
    
    for ch = 1:length(channels)
        % Create channel-specific patterns
        switch channels{ch}
            case 'Fp1'  % Frontal - artifacts and beta
                signal = 1.5*sin(2*pi*20*t) + 0.8*sin(2*pi*10*t) + 0.3*randn(size(t));
                % Add some artifacts
                signal(2*Fs:3*Fs) = signal(2*Fs:3*Fs) + 5*randn(Fs+1, 1);
                
            case 'C3'   % Central - mixed activity
                signal = 1.2*sin(2*pi*15*t) + 1.8*sin(2*pi*10*t) + 0.4*randn(size(t));
                
            case 'O1'   % Occipital - strong alpha
                signal = 3.0*sin(2*pi*10*t) + 0.5*sin(2*pi*20*t) + 0.3*randn(size(t));
                % Modulate alpha over time
                alpha_mod = 1 + 0.5*sin(2*pi*0.1*t);
                signal = signal .* alpha_mod;
                
            case 'T7'   % Temporal - theta and alpha
                signal = 1.5*sin(2*pi*6*t) + 2.0*sin(2*pi*10*t) + 0.4*randn(size(t));
        end
        
        % Write to H5
        dataset_path = sprintf('/preproc/F/%s', channels{ch});
        h5create(h5_file, dataset_path, size(signal), 'Datatype', 'double');
        h5write(h5_file, dataset_path, signal);
        h5writeatt(h5_file, dataset_path, 'SampleRate', Fs);
        h5writeatt(h5_file, dataset_path, 'ChannelName', channels{ch});
    end
    
    h5writeatt(h5_file, '/preproc/F', 'SampleRate', Fs);
    h5writeatt(h5_file, '/preproc/F', 'Duration', duration);
end

function display_h5_structure(info, indent)
    for i = 1:length(info.Groups)
        fprintf('%s+ %s/\n', indent, info.Groups(i).Name);
        display_h5_structure(info.Groups(i), [indent '  ']);
    end
    
    for i = 1:length(info.Datasets)
        fprintf('%s- %s [%s]\n', indent, info.Datasets(i).Name, ...
            mat2str(info.Datasets(i).Dataspace.Size));
    end
end

function export_chunk_descriptors_to_csv(descriptors, filename)
    % Convert struct array to table and export
    if isempty(descriptors)
        return;
    end
    
    % Get all field names
    fields = fieldnames(descriptors);
    
    % Create table
    T = table();
    for f = 1:length(fields)
        field_data = {descriptors.(fields{f})};
        if isnumeric(field_data{1})
            T.(fields{f}) = cell2mat(field_data);
        else
            T.(fields{f}) = field_data';
        end
    end
    
    writetable(T, filename);
end

function create_chunk_summary_report(h5_file, descriptors)
    % Create a summary report of chunk characteristics
    
    report_file = 'chunk_summary_report.txt';
    fid = fopen(report_file, 'w');
    
    fprintf(fid, 'CHUNK SUMMARY REPORT\n');
    fprintf(fid, '==================\n\n');
    fprintf(fid, 'H5 File: %s\n', h5_file);
    fprintf(fid, 'Generated: %s\n\n', datestr(now));
    
    fprintf(fid, 'CHUNK STATISTICS\n');
    fprintf(fid, '---------------\n');
    fprintf(fid, 'Total chunks: %d\n', length(descriptors));
    
    % Channel distribution
    channels = {descriptors.channel_name};
    unique_channels = unique(channels);
    fprintf(fid, 'Channels: %s\n', strjoin(unique_channels, ', '));
    
    for ch = 1:length(unique_channels)
        count = sum(strcmp(channels, unique_channels{ch}));
        fprintf(fid, '  %s: %d chunks\n', unique_channels{ch}, count);
    end
    
    % Feature statistics
    fprintf(fid, '\nFEATURE STATISTICS\n');
    fprintf(fid, '-----------------\n');
    
    alpha_powers = [descriptors.BandPower_Band3];
    fprintf(fid, 'Alpha power: %.3f ± %.3f (range: %.3f - %.3f)\n', ...
        mean(alpha_powers), std(alpha_powers), min(alpha_powers), max(alpha_powers));
    
    beta_powers = [descriptors.BandPower_Band4];
    fprintf(fid, 'Beta power: %.3f ± %.3f (range: %.3f - %.3f)\n', ...
        mean(beta_powers), std(beta_powers), min(beta_powers), max(beta_powers));
    
    fclose(fid);
    fprintf('Summary report saved to: %s\n', report_file);
end