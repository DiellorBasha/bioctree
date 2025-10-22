function success = outbct(filePath, analysisData, varargin)
% OUTBCT Export Bioctree analysis results to structured HDF5 format
%
% This function creates a comprehensive HDF5 file optimized for querying Bioctree
% analysis results by time periods, graph patches, frequency bands, and any 
% combination thereof.
%
% Usage:
%   success = outbct(filePath, analysisData)
%   success = outbct(filePath, analysisData, 'param', value, ...)
%
% Inputs:
%   filePath     - Output HDF5 file path (e.g., 'bioctree_results.h5')
%   analysisData - Structure containing Bioctree analysis results with fields:
%     .G           - Graph structure with adjacency, coordinates, eigendecomposition
%     .X           - Time-vertex signal matrix [N x T]
%     .Xhat_gft    - Graph Fourier Transform coefficients [N x T] (optional)
%     .Xhat_jft    - Joint Fourier Transform coefficients [N_modes x NFFT] (optional)
%     .spectral    - Spectral analysis results (optional)
%     .gradients   - Spatial gradient analysis (optional)
%     .tv_analysis - Total variation analysis (optional)
%     .metadata    - Analysis metadata and parameters
%
% Parameters:
%   'Compression'    - Compression level 0-9 (default: 6)
%   'ChunkSize'      - HDF5 chunk size for optimal access patterns
%   'FreqBands'      - Frequency band definitions for indexing
%   'SpatialPatches' - Spatial patch definitions for regional queries
%   'Precision'      - 'single' or 'double' (default: 'single' for large data)
%   'IncludeRaw'     - Include raw time-vertex data (default: true)
%   'IncludeSpectral'- Include spectral decompositions (default: true)
%   'Verbose'        - Display progress information (default: true)
%
% Output HDF5 Structure:
% ├── /metadata/
% │   ├── analysis_info          (analysis parameters, timestamps)
% │   ├── graph_properties       (N, connectivity, eigenvalues)
% │   ├── temporal_info          (T, fs, time_vector)
% │   └── spatial_info           (coordinates, patches, regions)
% │
% ├── /graph/
% │   ├── adjacency_matrix       [N x N sparse] - Graph connectivity
% │   ├── coordinates            [N x 3] - Vertex positions
% │   ├── eigenvalues            [N x 1] - Graph Laplacian eigenvalues
% │   ├── eigenvectors           [N x N] - Graph Fourier basis
% │   └── edge_list              [E x 2] - Edge connectivity list
% │
% ├── /temporal/
% │   ├── time_vector            [T x 1] - Time points
% │   ├── sampling_frequency     scalar - Sampling rate (Hz)
% │   └── frequency_vector       [NFFT x 1] - Frequency bins for spectral data
% │
% ├── /data/
% │   ├── raw/
% │   │   ├── signal             [N x T] - Original time-vertex signal
% │   │   ├── signal_patches     [P x T] - Regional average signals
% │   │   └── signal_bands       [N x T x B] - Frequency band filtered signals
% │   │
% │   ├── spectral/
% │   │   ├── gft_coeffs         [N x T] - Graph Fourier Transform coefficients
% │   │   ├── jft_coeffs         [N_modes x NFFT] - Joint Fourier Transform
% │   │   ├── power_spectral     [N x F] - Power spectral density per vertex
% │   │   ├── cross_spectral     [N x N x F] - Cross-spectral density matrix
% │   │   └── joint_spectrum     [N_modes x F] - Joint space-time spectrum
% │   │
% │   └── derived/
% │       ├── gradients          [E x T] - Edge-wise spatial gradients
% │       ├── divergence         [N x T] - Vertex-wise divergence
% │       ├── total_variation    [N x T] - Spatial total variation per vertex
% │       ├── phase_gradients    [E x T] - Phase gradient magnitudes
% │       └── connectivity_maps  [N x F] - Frequency-specific connectivity
% │
% ├── /indices/
% │   ├── time_indices/
% │   │   ├── epochs             [E_epochs x 2] - Start/end indices for epochs
% │   │   ├── events             [E_events x 1] - Event time indices  
% │   │   └── bands_time         [B x 2] - Time ranges for analysis bands
% │   │
% │   ├── spatial_indices/
% │   │   ├── patches            [P x Np] - Vertex indices per spatial patch
% │   │   ├── hemispheres        [2 x Nh] - Left/right hemisphere vertices
% │   │   ├── regions            [R x Nr] - Anatomical region definitions
% │   │   └── communities        [C x Nc] - Graph community assignments
% │   │
% │   └── frequency_indices/
% │       ├── bands              [B x 2] - Frequency band ranges (Hz)
% │       ├── peaks              [Pk x 1] - Spectral peak frequencies  
% │       └── modes              [M x 1] - Selected graph mode indices
% │
% └── /analysis/
%     ├── statistics/
%     │   ├── signal_stats       [N x S] - Per-vertex signal statistics
%     │   ├── spectral_stats     [N x S] - Per-vertex spectral statistics
%     │   ├── connectivity_stats [N x S] - Per-vertex connectivity statistics
%     │   └── temporal_stats     [T x S] - Per-timepoint statistics
%     │
%     ├── decompositions/
%     │   ├── pca_coeffs         [K x T] - Principal component coefficients
%     │   ├── ica_sources        [K x T] - Independent component sources
%     │   └── nmf_factors        [N x K], [K x T] - Non-negative matrix factorization
%     │
%     └── detection/
%         ├── events             [Ev x 4] - Detected events [vertex, time, strength, type]
%         ├── patterns           [Pt x 6] - Pattern detections [vertex, time, freq, size, type, confidence]
%         └── anomalies          [An x 3] - Anomaly detections [vertex, time, score]
%
% Query Examples:
%   % Read alpha band activity in posterior cortex during 2-4 second window
%   time_mask = h5read(file, '/indices/time_indices/epochs');
%   alpha_mask = h5read(file, '/indices/frequency_indices/bands');
%   posterior_vertices = h5read(file, '/indices/spatial_indices/regions');
%   alpha_data = h5read(file, '/data/raw/signal_bands', [posterior_vertices(3,:), time_mask(1,1):time_mask(1,2), 2]);
%
%   % Read joint spectrum for specific graph modes and frequencies
%   modes = 1:50; freqs = 1:100;
%   joint_spec = h5read(file, '/data/spectral/joint_spectrum', [modes, freqs]);
%
% Returns:
%   success - true if export completed successfully
%
% See also: inbct, exportDerivedMaps, h5create, h5write

% Input validation
p = inputParser;
addRequired(p, 'filePath', @(x) ischar(x) || isstring(x));
addRequired(p, 'analysisData', @isstruct);
addParameter(p, 'Compression', 6, @(x) isnumeric(x) && x >= 0 && x <= 9);
addParameter(p, 'ChunkSize', [], @isnumeric);
addParameter(p, 'FreqBands', getDefaultFreqBands(), @isstruct);
addParameter(p, 'SpatialPatches', [], @(x) isstruct(x) || isempty(x));
addParameter(p, 'Precision', 'single', @(x) ismember(x, {'single', 'double'}));
addParameter(p, 'IncludeRaw', true, @islogical);
addParameter(p, 'IncludeSpectral', true, @islogical);
addParameter(p, 'Verbose', true, @islogical);
parse(p, filePath, analysisData, varargin{:});

opts = p.Results;

% Convert to string for consistency
filePath = char(filePath);

% Validate required fields
requiredFields = {'G'};
for field = requiredFields
    if ~isfield(analysisData, field{1})
        error('BioctreeHDF5:MissingField', 'analysisData must contain field: %s', field{1});
    end
end

try
    if opts.Verbose
        fprintf('Creating Bioctree HDF5 file: %s\n', filePath);
    end
    
    % Delete existing file if it exists
    if exist(filePath, 'file')
        delete(filePath);
        if opts.Verbose
            fprintf('  Overwriting existing file\n');
        end
    end
    
    % Extract dimensions
    G = analysisData.G;
    N = G.N;  % Number of vertices
    
    % Determine temporal dimensions
    if isfield(analysisData, 'X') && ~isempty(analysisData.X)
        [N_check, T] = size(analysisData.X);
        if N_check ~= N
            error('BioctreeHDF5:DimensionMismatch', 'Signal matrix X must have %d rows (vertices)', N);
        end
    elseif isfield(G, 'jtv') && isfield(G.jtv, 'T')
        T = G.jtv.T;
    else
        T = 1; % Default for static analysis
    end
    
    % Get sampling frequency
    if isfield(G, 'jtv') && isfield(G.jtv, 'fs')
        fs = G.jtv.fs;
    else
        fs = 1; % Default
    end
    
    % Set data type based on precision
    if strcmp(opts.Precision, 'single')
        dataType = 'single';
        h5Type = 'H5T_IEEE_F32LE';
    else
        dataType = 'double';
        h5Type = 'H5T_IEEE_F64LE';
    end
    
    % Create HDF5 groups
    createHDF5Groups(filePath, opts.Verbose);
    
    % Write metadata
    writeMetadata(filePath, analysisData, opts, N, T, fs, dataType);
    
    % Write graph structure
    writeGraphData(filePath, G, opts, dataType);
    
    % Write temporal information
    writeTemporalData(filePath, G, T, fs, opts, dataType);
    
    % Write signal data
    if opts.IncludeRaw && isfield(analysisData, 'X')
        writeRawData(filePath, analysisData.X, opts, dataType);
    end
    
    % Write spectral data
    if opts.IncludeSpectral
        writeSpectralData(filePath, analysisData, opts, dataType);
    end
    
    % Write derived data
    writeDerivedData(filePath, analysisData, opts, dataType);
    
    % Write indices for efficient querying
    writeIndices(filePath, analysisData, opts);
    
    % Write analysis results
    writeAnalysisResults(filePath, analysisData, opts, dataType);
    
    % Verify file integrity
    if opts.Verbose
        verifyHDF5File(filePath);
    end
    
    success = true;
    
    if opts.Verbose
        fprintf('✅ Bioctree HDF5 export completed successfully\n');
        fprintf('   File: %s\n', filePath);
        fileInfo = dir(filePath);
        fprintf('   Size: %.1f MB\n', fileInfo.bytes / 1024^2);
    end
    
catch ME
    success = false;
    if exist(filePath, 'file')
        delete(filePath);
    end
    warning('BioctreeHDF5:ExportFailed', 'HDF5 export failed: %s', ME.message);
    rethrow(ME);
end

end