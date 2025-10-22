%% OUTBCT Function Usage Guide
% This script demonstrates how to use the outbct function to export 
% Bioctree analysis results to structured BCT format.

%% Basic Usage
% The outbct function exports graph signal analysis data to BCT format
% with a standardized structure for efficient querying and analysis.

% Basic syntax:
% success = outbct(filePath, analysisData)
% success = outbct(filePath, analysisData, 'param', value, ...)

%% Required Inputs

% 1. filePath: Output BCT file path (string or char)
output_file = 'example1_graph_only.bct';  % .bct extension recommended

% 2. analysisData: Structure containing analysis results with required field 'G'
% The analysisData structure must contain at least:
%   .G - Graph structure (from GSPBox or build_icosphere, etc.)

%% Example 1: Minimal Usage with Graph Only
fprintf('=== Example 1: Basic Graph Export ===\n');

% Create a simple graph (using icosphere)
G = build_icosphere(2, 1);  % 162 vertices, radius 1

% Create minimal analysis data structure
data = struct();
data.G = G;

% Export to HDF5
success = outbct(output_file, data);

if success
    fprintf('✓ Graph exported successfully to example1_graph_only.bct\n');
else
    fprintf('✗ Export failed\n');
end

%% Example 2: Export with Signal Data
fprintf('\n=== Example 2: Graph + Signal Export ===\n');

% Create a graph signal
G = build_icosphere(3, 1);  % 642 vertices
[signal, ~] = generatePatchSignal(G, 'patchSize', 0.1, 'growthMode', 'none');

% Create analysis data with signal
data = struct();
data.G = G;
data.X = signal;  % Raw signal data [N x T]

% Add metadata
data.metadata = struct();
data.metadata.signal_type = 'patch_signal';
data.metadata.analysis_date = datestr(now);
data.metadata.description = 'Example icosphere patch signal';

% Export with options
success = outbct('example2_with_signal.bct', data, ...
    'Compression', 6, ...      % Compression level 0-9
    'Precision', 'single', ... % 'single' or 'double'
    'Verbose', true);          % Display progress

fprintf('Signal data exported: %s\n', mat2str(success));

%% Example 3: Advanced Export with All Optional Data
fprintf('\n=== Example 3: Complete Analysis Export ===\n');

% Create comprehensive analysis data
G = build_icosphere(3, 1);
N = G.N;
T = 100;  % 100 time points

% Generate multi-component signal
time_vec = (0:T-1) / 50;  % 50 Hz sampling
signal1 = generatePatchSignal(G, 'patchSize', 0.08);
signal2 = generatePatchSignal(G, 'patchSize', 0.12, 'patchCenter', round(N/2));
combined_signal = [signal1, signal2(:, ones(1, T-1))];  % Expand to T time points

data = struct();
data.G = G;
data.X = combined_signal;  % Raw signal [N x T]

% Add spectral analysis (simulated)
if isfield(G, 'U') && ~isempty(G.U)
    data.Xhat_gft = G.U' * combined_signal;  % Graph Fourier Transform
end

% Add gradient analysis (simulated)  
if size(combined_signal, 2) > 1
    data.gradients = diff(combined_signal, 1, 2);  % Temporal gradients
end

% Add comprehensive metadata
data.metadata = struct();
data.metadata.description = 'Complete icosphere analysis with multiple signals';
data.metadata.sampling_frequency = 50;
data.metadata.analysis_type = 'multi_patch';
data.metadata.created_by = 'MATLAB_demo';
data.metadata.version = '1.0';

% Define custom frequency bands
freq_bands = struct();
freq_bands.low = [0.5, 5];
freq_bands.medium = [5, 15]; 
freq_bands.high = [15, 25];

% Define spatial patches
spatial_patches = struct();
spatial_patches.anterior = 1:round(N/3);
spatial_patches.middle = round(N/3)+1:round(2*N/3);
spatial_patches.posterior = round(2*N/3)+1:N;

% Export with all options
success = outbct('example3_complete.bct', data, ...
    'Compression', 7, ...
    'ChunkSize', [50, 25], ...
    'FreqBands', freq_bands, ...
    'SpatialPatches', spatial_patches, ...
    'Precision', 'single', ...
    'IncludeRaw', true, ...
    'IncludeSpectral', true, ...
    'Verbose', true);

fprintf('Complete analysis exported: %s\n', mat2str(success));

%% Parameter Reference

fprintf('\n=== Parameter Reference ===\n');
fprintf('Required Parameters:\n');
fprintf('  filePath     - Output HDF5 file path (string/char)\n');
fprintf('  analysisData - Structure with required field .G (graph)\n');
fprintf('\n');

fprintf('Optional Parameters:\n');
fprintf('  ''Compression''    - Compression level 0-9 (default: 6)\n');
fprintf('  ''ChunkSize''      - HDF5 chunk size [rows, cols] (default: auto)\n');
fprintf('  ''FreqBands''      - Frequency band definitions (struct)\n');
fprintf('  ''SpatialPatches'' - Spatial patch definitions (struct)\n');
fprintf('  ''Precision''      - ''single'' or ''double'' (default: ''single'')\n');
fprintf('  ''IncludeRaw''     - Include raw signal data (default: true)\n');
fprintf('  ''IncludeSpectral''- Include spectral analysis (default: true)\n');
fprintf('  ''Verbose''        - Show progress messages (default: true)\n');
fprintf('\n');

%% Data Structure Requirements

fprintf('Analysis Data Structure Requirements:\n');
fprintf('Required fields:\n');
fprintf('  .G              - Graph structure (GSPBox compatible)\n');
fprintf('\n');
fprintf('Optional fields:\n');
fprintf('  .X              - Raw signal data [N x T]\n');
fprintf('  .Xhat_gft       - Graph Fourier Transform coeffs [N x T]\n');
fprintf('  .Xhat_jft       - Joint Fourier Transform [N_modes x NFFT]\n');
fprintf('  .spectral       - Spectral analysis results (struct)\n');
fprintf('  .gradients      - Spatial gradient data [E x T]\n');
fprintf('  .tv_analysis    - Total variation analysis (struct)\n');
fprintf('  .metadata       - Analysis metadata (struct)\n');
fprintf('\n');

%% HDF5 File Structure Created

fprintf('Output HDF5 File Structure:\n');
fprintf('/metadata/           - Analysis parameters and info\n');
fprintf('/graph/              - Graph connectivity and coordinates\n');
fprintf('/temporal/           - Time vectors and sampling info\n');
fprintf('/data/raw/           - Original signal data\n');
fprintf('/data/spectral/      - Spectral analysis results\n');
fprintf('/data/derived/       - Derived quantities (gradients, etc.)\n');
fprintf('/indices/            - Index arrays for efficient querying\n');
fprintf('/analysis/           - Statistics and decompositions\n');
fprintf('\n');

%% Reading Data Back

fprintf('To read data back, use inbct():\n');
fprintf('  loaded_data = inbct(''example1_graph_only.bct'');\n');
fprintf('  signal = inbct(''example2_with_signal.bct'', ''DataType'', ''signal'');\n');
fprintf('\n');

%% Error Handling Example

fprintf('=== Error Handling Example ===\n');

% Example with missing required field
try
    bad_data = struct();  % Missing .G field
    bad_data.X = randn(100, 50);
    
    success = outbct('bad_example.bct', bad_data, 'Verbose', false);
    
catch ME
    fprintf('Expected error caught: %s\n', ME.message);
end

%% File Size and Performance Tips

fprintf('=== Performance Tips ===\n');
fprintf('• Use ''single'' precision for large datasets\n');
fprintf('• Set appropriate ChunkSize for your access patterns\n');
fprintf('• Higher compression (7-9) for archival, lower (3-6) for frequent access\n');
fprintf('• Include only necessary spectral data for large datasets\n');
fprintf('• Use SpatialPatches and FreqBands for efficient querying\n');
fprintf('\n');

%% Clean up example files
fprintf('Cleaning up example files...\n');
files_to_clean = {'example1_graph_only.bct', 'example2_with_signal.bct', 'example3_complete.bct', 'bad_example.bct'};
for i = 1:length(files_to_clean)
    if exist(files_to_clean{i}, 'file')
        delete(files_to_clean{i});
        fprintf('  Deleted: %s\n', files_to_clean{i});
    end
end

fprintf('\n=== OUTBCT Usage Guide Complete ===\n');