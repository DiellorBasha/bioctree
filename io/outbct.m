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
%     .graph       - Graph structure with adjacency, coordinates, eigendecomposition
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
requiredFields = {'graph'};
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
    G = analysisData.graph;
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
    if opts.IncludeRaw
        writeRawData(filePath, analysisData, opts, dataType);
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

% ============================================================================
% HELPER FUNCTIONS - HDF5 Implementation using MATLAB's h5* functions
% ============================================================================

function createHDF5Groups(filePath, verbose)
% Create the standard Bioctree HDF5 group structure using JSON configuration
    
    if verbose
        fprintf('Creating HDF5 group structure...\n');
    end
    
    try
        % Load structure configuration from JSON file
        structure_config = loadHDF5StructureConfig();
        
        % Create structure using configuration
        success = createHDF5StructureFromConfig(filePath, structure_config, verbose);
        
        if ~success
            error('Failed to create HDF5 structure from configuration');
        end
        
        if verbose
            fprintf('   ✓ HDF5 structure created from configuration (version %s)\n', ...
                structure_config.version);
        end
        
        return; % Exit early since new method handles everything
        
    catch ME
        if verbose
            fprintf('   ⚠ Configuration-based creation failed: %s\n', ME.message);
            fprintf('   Falling back to hardcoded structure...\n');
        end
        
        % Fallback to original hardcoded approach
        % Main groups
        groups = {'/metadata', '/graph', '/temporal', '/data', '/indices', '/analysis'};
        
        % Data subgroups
        data_groups = {'/data/raw', '/data/spectral', '/data/derived'};
        
        % Indices subgroups  
        indices_groups = {'/indices/time_indices', '/indices/spatial_indices', '/indices/frequency_indices'};
        
        % Analysis subgroups
        analysis_groups = {'/analysis/statistics', '/analysis/decompositions', '/analysis/detection'};
        
        all_groups = [groups, data_groups, indices_groups, analysis_groups];
    end % End of try-catch for configuration-based vs fallback creation
    
    % Create file and groups (fallback method)
    if exist(filePath, 'file')
        delete(filePath);
    end
    
    % Create empty file first
    h5create(filePath, '/temp_dataset', 1);
    h5write(filePath, '/temp_dataset', 0);
    
    % Create all groups
    for i = 1:length(all_groups)
        try
            % Check if group exists, if not create it
            groupPath = all_groups{i};
            parts = strsplit(groupPath(2:end), '/');
            currentPath = '';
            
            for j = 1:length(parts)
                currentPath = [currentPath '/' parts{j}];
                try
                    h5info(filePath, currentPath);
                catch
                    % Group doesn't exist, create it
                    if j == 1
                        % Create top-level group
                        fid = H5F.open(filePath, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
                        gid = H5G.create(fid, currentPath, 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
                        H5G.close(gid);
                        H5F.close(fid);
                    else
                        % Create subgroup
                        fid = H5F.open(filePath, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
                        parent_path = currentPath(1:find(currentPath == '/', 1, 'last')-1);
                        if isempty(parent_path), parent_path = '/'; end
                        
                        gid_parent = H5G.open(fid, parent_path);
                        gid = H5G.create(gid_parent, parts{j}, 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
                        H5G.close(gid);
                        H5G.close(gid_parent);
                        H5F.close(fid);
                    end
                end
            end
        catch ME
            if verbose
                fprintf('  Warning: Could not create group %s: %s\n', all_groups{i}, ME.message);
            end
        end
    end
    
    % Remove temporary dataset
    try
        fid = H5F.open(filePath, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
        H5L.delete(fid, 'temp_dataset', 'H5P_DEFAULT');
        H5F.close(fid);
    catch
        % Ignore if can't delete temp dataset
    end
    
    if verbose
        fprintf('  ✓ HDF5 groups created\n');
    end
end

function writeMetadata(filePath, analysisData, opts, N, T, fs, dataType)
% Write metadata information to HDF5 file
    
    if opts.Verbose
        fprintf('Writing metadata...\n');
    end
    
    % Analysis info
    analysis_info = struct();
    analysis_info.creation_date = datestr(now);
    analysis_info.bioctree_version = '1.0';
    analysis_info.precision = dataType;
    analysis_info.compression_level = opts.Compression;
    
    if isfield(analysisData, 'metadata')
        fields = fieldnames(analysisData.metadata);
        for i = 1:length(fields)
            analysis_info.(fields{i}) = analysisData.metadata.(fields{i});
        end
    end
    
    writeStructToHDF5(filePath, '/metadata/analysis_info', analysis_info);
    
    % Graph properties
    G = analysisData.graph;
    graph_props = struct();
    graph_props.N = N;
    graph_props.num_edges = nnz(G.W) / 2;
    graph_props.is_directed = 0;
    graph_props.is_weighted = double(any(G.W(:) ~= 0 & G.W(:) ~= 1));
    
    if isfield(G, 'e')
        graph_props.spectral_gap = G.e(2) - G.e(1);
        graph_props.max_eigenvalue = max(G.e);
    end
    
    writeStructToHDF5(filePath, '/metadata/graph_properties', graph_props);
    
    % Temporal info
    temporal_info = struct();
    temporal_info.T = T;
    temporal_info.fs = fs;
    temporal_info.duration = (T-1)/fs;
    
    writeStructToHDF5(filePath, '/metadata/temporal_info', temporal_info);
    
    % Spatial info
    spatial_info = struct();
    if isfield(G, 'coords')
        spatial_info.coordinate_system = 'cartesian';
        spatial_info.dimensions = size(G.coords, 2);
    end
    
    writeStructToHDF5(filePath, '/metadata/spatial_info', spatial_info);
    
    if opts.Verbose
        fprintf('  ✓ Metadata written\n');
    end
end

function writeGraphData(filePath, G, opts, dataType)
% Write graph structure data to HDF5 file
    
    if opts.Verbose
        fprintf('Writing graph data...\n');
    end
    
    % Adjacency matrix (sparse)
    if isfield(G, 'W') && ~isempty(G.W)
        writeSparseMatrix(filePath, '/graph/adjacency_matrix', G.W, opts.Compression);
    end
    
    % Coordinates
    if isfield(G, 'coords') && ~isempty(G.coords)
        writeArrayToHDF5(filePath, '/graph/coordinates', G.coords, dataType, opts.Compression);
    end
    
    % Eigenvalues
    if isfield(G, 'e') && ~isempty(G.e)
        writeArrayToHDF5(filePath, '/graph/eigenvalues', G.e, dataType, opts.Compression);
    end
    
    % Eigenvectors
    if isfield(G, 'U') && ~isempty(G.U)
        writeArrayToHDF5(filePath, '/graph/eigenvectors', G.U, dataType, opts.Compression);
    end
    
    % Edge list - prioritize direct edge list (G.E) over adjacency matrix (G.W)
    if isfield(G, 'E') && ~isempty(G.E)
        % Use direct edge list from graph structure (preferred for icospheres)
        writeArrayToHDF5(filePath, '/graph/edge_list', G.E, 'int32', opts.Compression);
        if opts.Verbose
            fprintf('  ✓ Edge connectivity saved: %d edges from G.E\n', size(G.E, 1));
        end
    elseif isfield(G, 'W') && ~isempty(G.W)
        % Extract edge list from adjacency matrix
        [i, j] = find(triu(G.W));
        edges = [i, j];
        writeArrayToHDF5(filePath, '/graph/edge_list', edges, 'int32', opts.Compression);
        if opts.Verbose
            fprintf('  ✓ Edge connectivity saved: %d edges from G.W\n', size(edges, 1));
        end
    end
    
    % Face connectivity (triangular mesh)
    if isfield(G, 'F') && ~isempty(G.F)
        writeArrayToHDF5(filePath, '/graph/faces', G.F, 'int32', opts.Compression);
        if opts.Verbose
            fprintf('  ✓ Face connectivity saved: %d triangular faces from G.F\n', size(G.F, 1));
        end
    end
    
    if opts.Verbose
        fprintf('  ✓ Graph data written\n');
    end
end

function writeTemporalData(filePath, ~, T, fs, opts, dataType)
% Write temporal information to HDF5 file
    
    if opts.Verbose
        fprintf('Writing temporal data...\n');
    end
    
    % Time vector
    time_vector = (0:T-1) / fs;
    writeArrayToHDF5(filePath, '/temporal/time_vector', time_vector, dataType, opts.Compression);
    
    % Sampling frequency
    writeScalarToHDF5(filePath, '/temporal/sampling_frequency', fs, dataType);
    
    % Frequency vector for spectral analysis
    NFFT = 2^nextpow2(T);
    freq_vector = (0:NFFT-1) * fs / NFFT;
    writeArrayToHDF5(filePath, '/temporal/frequency_vector', freq_vector, dataType, opts.Compression);
    
    if opts.Verbose
        fprintf('  ✓ Temporal data written\n');
    end
end

function writeRawData(filePath, analysisData, opts, dataType)
% Write raw signal data to HDF5 file (supports multiple signal layers)
    
    if opts.Verbose
        fprintf('Writing raw signal data...\n');
    end
    
    % Handle multiple signal formats
    signal_count = 0;
    
    % Main signal (X field - primary signal)
    if isfield(analysisData, 'X') && ~isempty(analysisData.X)
        writeArrayToHDF5(filePath, '/data/raw/signal', analysisData.X, dataType, opts.Compression, opts.ChunkSize);
        signal_count = signal_count + 1;
        if opts.Verbose
            fprintf('  ✓ Primary signal written: %s\n', mat2str(size(analysisData.X)));
        end
    end
    
    % Additional signal layers (X_layers field)
    if isfield(analysisData, 'X_layers') && isstruct(analysisData.X_layers)
        layer_names = fieldnames(analysisData.X_layers);
        for i = 1:length(layer_names)
            layer_name = layer_names{i};
            layer_data = analysisData.X_layers.(layer_name);
            
            if ~isempty(layer_data) && isnumeric(layer_data)
                dataset_path = sprintf('/data/raw/signal_%s', layer_name);
                writeArrayToHDF5(filePath, dataset_path, layer_data, dataType, opts.Compression, opts.ChunkSize);
                signal_count = signal_count + 1;
                
                if opts.Verbose
                    fprintf('  ✓ Signal layer "%s" written: %s\n', layer_name, mat2str(size(layer_data)));
                end
            end
        end
    end
    
    % Numbered signal layers (X1, X2, X3, etc.)
    field_names = fieldnames(analysisData);
    signal_fields = field_names(startsWith(field_names, 'X') & ~strcmp(field_names, 'X') & ~strcmp(field_names, 'X_layers'));
    
    for i = 1:length(signal_fields)
        field_name = signal_fields{i};
        signal_data = analysisData.(field_name);
        
        if ~isempty(signal_data) && isnumeric(signal_data)
            % Extract layer identifier (e.g., X1 -> 001, X_patch -> patch)
            layer_id = field_name(2:end);
            if isempty(layer_id)
                continue;
            end
            
            % Format as numbered layer if purely numeric
            if ~isempty(str2double(layer_id))
                dataset_path = sprintf('/data/raw/signal_%03d', str2double(layer_id));
            else
                dataset_path = sprintf('/data/raw/signal_%s', layer_id);
            end
            
            writeArrayToHDF5(filePath, dataset_path, signal_data, dataType, opts.Compression, opts.ChunkSize);
            signal_count = signal_count + 1;
            
            if opts.Verbose
                fprintf('  ✓ Signal layer "%s" written: %s\n', layer_id, mat2str(size(signal_data)));
            end
        end
    end
    
    if opts.Verbose && signal_count > 0
        fprintf('  ✓ Total signal layers written: %d\n', signal_count);
    elseif opts.Verbose
        fprintf('  ℹ No signal data found to write\n');
    end
end

function writeSpectralData(filePath, analysisData, opts, dataType)
% Write spectral analysis results to HDF5 file
    
    if opts.Verbose
        fprintf('Writing spectral data...\n');
    end
    
    % GFT coefficients
    if isfield(analysisData, 'Xhat_gft') && ~isempty(analysisData.Xhat_gft)
        writeArrayToHDF5(filePath, '/data/spectral/gft_coeffs', analysisData.Xhat_gft, dataType, opts.Compression, opts.ChunkSize);
    end
    
    % Joint Fourier Transform
    if isfield(analysisData, 'Xhat_jft') && ~isempty(analysisData.Xhat_jft)
        writeArrayToHDF5(filePath, '/data/spectral/jft_coeffs', analysisData.Xhat_jft, dataType, opts.Compression, opts.ChunkSize);
    end
    
    % Power spectral density
    if isfield(analysisData, 'spectral') && isfield(analysisData.spectral, 'psd')
        writeArrayToHDF5(filePath, '/data/spectral/power_spectral', analysisData.spectral.psd, dataType, opts.Compression);
    end
    
    if opts.Verbose
        fprintf('  ✓ Spectral data written\n');
    end
end

function writeDerivedData(filePath, analysisData, opts, dataType)
% Write derived analysis results to HDF5 file
    
    if opts.Verbose
        fprintf('Writing derived data...\n');
    end
    
    % Gradients
    if isfield(analysisData, 'gradients') && ~isempty(analysisData.gradients)
        writeArrayToHDF5(filePath, '/data/derived/gradients', analysisData.gradients, dataType, opts.Compression);
    end
    
    % Total variation
    if isfield(analysisData, 'tv_analysis') && isfield(analysisData.tv_analysis, 'tv_signal')
        writeArrayToHDF5(filePath, '/data/derived/total_variation', analysisData.tv_analysis.tv_signal, dataType, opts.Compression);
    end
    
    if opts.Verbose
        fprintf('  ✓ Derived data written\n');
    end
end

function writeIndices(filePath, ~, opts)
% Write index arrays for efficient querying
    
    if opts.Verbose
        fprintf('Writing index arrays...\n');
    end
    
    % Frequency bands
    if ~isempty(opts.FreqBands)
        freq_bands = struct2cell(opts.FreqBands);
        freq_bands = cell2mat(freq_bands');
        writeArrayToHDF5(filePath, '/indices/frequency_indices/bands', freq_bands, 'double', opts.Compression);
    end
    
    % Spatial patches
    if ~isempty(opts.SpatialPatches)
        % Write patch definitions if provided
        patches = opts.SpatialPatches;
        if isstruct(patches)
            fields = fieldnames(patches);
            for i = 1:length(fields)
                patch_data = patches.(fields{i});
                if isnumeric(patch_data)
                    writeArrayToHDF5(filePath, ['/indices/spatial_indices/' fields{i}], patch_data, 'int32', opts.Compression);
                end
            end
        end
    end
    
    if opts.Verbose
        fprintf('  ✓ Index arrays written\n');
    end
end

function writeAnalysisResults(filePath, analysisData, opts, dataType)
% Write analysis statistics and results
    
    if opts.Verbose
        fprintf('Writing analysis results...\n');
    end
    
    % Signal statistics
    if isfield(analysisData, 'X')
        X = analysisData.X;
        stats = struct();
        stats.mean = mean(X, 2);
        stats.std = std(X, 0, 2);
        stats.var = var(X, 0, 2);
        stats.energy = sum(X.^2, 2);
        
        signal_stats = [stats.mean, stats.std, stats.var, stats.energy];
        writeArrayToHDF5(filePath, '/analysis/statistics/signal_stats', signal_stats, dataType, opts.Compression);
    end
    
    if opts.Verbose
        fprintf('  ✓ Analysis results written\n');
    end
end

function verifyHDF5File(filePath)
% Verify HDF5 file integrity
    
    try
        info = h5info(filePath);
        fprintf('  ✓ HDF5 file integrity verified (%d groups)\n', length(info.Groups));
    catch ME
        warning('BioctreeHDF5:VerificationFailed', 'HDF5 file verification failed: %s', ME.message);
    end
end

% ============================================================================
% UTILITY FUNCTIONS for HDF5 operations
% ============================================================================

function writeArrayToHDF5(filePath, datasetPath, data, dataType, compression, chunkSize)
% Write array data to HDF5 with proper chunking and compression
    
    if nargin < 6 || isempty(chunkSize)
        chunkSize = min(size(data), [50, 50]);  % Default chunk size
    end
    
    if nargin < 5
        compression = 6;
    end
    
    % Convert data type
    if strcmp(dataType, 'single')
        data = single(data);
    elseif strcmp(dataType, 'double')
        data = double(data);
    elseif strcmp(dataType, 'int32')
        data = int32(data);
    end
    
    try
        % Create dataset with compression
        h5create(filePath, datasetPath, size(data), 'Datatype', dataType, ...
                'ChunkSize', chunkSize, 'Deflate', compression);
        
        % Write data
        h5write(filePath, datasetPath, data);
        
        % Add attributes
        h5writeatt(filePath, datasetPath, 'data_type', dataType);
        h5writeatt(filePath, datasetPath, 'compression_level', compression);
        
    catch ME
        warning('Failed to write array to %s: %s', datasetPath, ME.message);
    end
end

function writeScalarToHDF5(filePath, datasetPath, value, dataType)
% Write scalar value to HDF5
    
    if strcmp(dataType, 'single')
        value = single(value);
    elseif strcmp(dataType, 'double')  
        value = double(value);
    end
    
    try
        h5create(filePath, datasetPath, 1, 'Datatype', dataType);
        h5write(filePath, datasetPath, value);
        h5writeatt(filePath, datasetPath, 'data_type', dataType);
    catch ME
        warning('Failed to write scalar to %s: %s', datasetPath, ME.message);
    end
end

function writeSparseMatrix(filePath, datasetPath, spMatrix, compression)
% Write sparse matrix in HDF5-compatible format
    
    [i, j, s] = find(spMatrix);
    
    try
        % Store indices and values separately
        writeArrayToHDF5(filePath, [datasetPath '_i'], i, 'int32', compression);
        writeArrayToHDF5(filePath, [datasetPath '_j'], j, 'int32', compression);  
        writeArrayToHDF5(filePath, [datasetPath '_s'], s, 'double', compression);
        
        % Store matrix dimensions
        h5create(filePath, [datasetPath '_size'], 2, 'Datatype', 'int32');
        h5write(filePath, [datasetPath '_size'], int32(size(spMatrix)));
        
        % Add attributes
        h5writeatt(filePath, [datasetPath '_size'], 'matrix_type', 'sparse');
        h5writeatt(filePath, [datasetPath '_size'], 'nnz', nnz(spMatrix));
        
    catch ME
        warning('Failed to write sparse matrix to %s: %s', datasetPath, ME.message);
    end
end

function writeStructToHDF5(filePath, groupPath, structData)
% Write structure fields as HDF5 attributes or datasets
    
    fields = fieldnames(structData);
    
    for i = 1:length(fields)
        field = fields{i};
        value = structData.(field);
        
        try
            if ischar(value) || isstring(value)
                h5writeatt(filePath, groupPath, field, char(value));
            elseif isnumeric(value) && numel(value) == 1
                h5writeatt(filePath, groupPath, field, double(value));
            elseif isnumeric(value)
                % For arrays, create dataset
                writeArrayToHDF5(filePath, [groupPath '/' field], value, 'double', 6);
            end
        catch ME
            % Skip fields that can't be written
            continue;
        end
    end
end

function bands = getDefaultFreqBands()
% Default frequency bands for neural analysis
    bands = struct();
    bands.delta = [1, 4];
    bands.theta = [4, 8]; 
    bands.alpha = [8, 13];
    bands.beta = [13, 30];
    bands.gamma = [30, 100];
end