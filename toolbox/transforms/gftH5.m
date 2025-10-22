function [gft_data, analysis_info] = gftH5(hdf5_file_or_path, varargin)
% GFTH5 Compute Graph Fourier Transform for signals in HDF5 Bioctree files
%
% This function computes the Graph Fourier Transform (GFT) of signals stored
% in Bioctree HDF5 format using GSPBox tools. It handles graph loading,
% Fourier basis computation, and signal transformation with comprehensive
% output options.
%
% Syntax:
%   [gft_data, analysis_info] = gftH5(hdf5_file)
%   [gft_data, analysis_info] = gftH5(hdf5_file, 'param', value, ...)
%
% Inputs:
%   hdf5_file_or_path - Path to HDF5 file (string) or loaded Bioctree data structure
%
% Parameters (Name-Value pairs):
%   'SignalName'     - Signal dataset name (default: 'signal')
%   'TimeIndex'      - Time index for temporal signals (default: 1, [] for all)
%   'OutputFile'     - Output HDF5 file for saving results (default: '', no save)
%   'ComputeBasis'   - Force recomputation of Fourier basis (default: false)
%   'Verbose'        - Display detailed information (default: true)
%   'SaveIntermediates' - Save intermediate results to output file (default: true)
%
% Outputs:
%   gft_data - Structure containing:
%     .X_gft          - Graph Fourier coefficients [N x T] or [N x 1]
%     .eigenvalues    - Graph Laplacian eigenvalues [N x 1]
%     .eigenvectors   - Graph Fourier basis (eigenvectors) [N x N]
%     .signal_name    - Name of processed signal
%     .time_index     - Time index(es) processed
%     .spectral_energy - Energy in each frequency component [N x T] or [N x 1]
%
%   analysis_info - Structure containing:
%     .graph_info     - Graph properties (vertices, edges, etc.)
%     .signal_info    - Signal properties (dimensions, range, etc.)
%     .computation_time - Processing time breakdown
%     .gsp_params     - GSPBox parameters used
%
% Dependencies:
%   - GSPBox (Graph Signal Processing Toolbox)
%   - Bioctree toolbox (inbct, outbct functions)
%   - MATLAB HDF5 functions
%
% Examples:
%   % Basic GFT computation
%   [gft_data, info] = gftH5('icosphere_demo.h5');
%
%   % Process specific signal with all time points
%   [gft_data, info] = gftH5('demo.h5', 'SignalName', 'signal_patch_05_pct', ...
%                            'TimeIndex', []);
%
%   % Save results to new file
%   [gft_data, info] = gftH5('input.h5', 'SignalName', 'signal', ...
%                            'OutputFile', 'gft_results.h5');
%
% See also: GSP_GFT, GSP_COMPUTE_FOURIER_BASIS, INBCT, OUTBCT
%
% Author: Bioctree Toolbox
% Created: October 2025

%% Input validation and parameter parsing
if nargin == 0
    error('gftH5:InvalidInput', 'HDF5 file path or data structure required');
end

% Parse input parameters
p = inputParser;
addRequired(p, 'hdf5_file_or_path', @(x) ischar(x) || isstring(x) || isstruct(x));
addParameter(p, 'SignalName', 'signal', @(x) ischar(x) || isstring(x));
addParameter(p, 'TimeIndex', 1, @(x) isnumeric(x) || isempty(x));
addParameter(p, 'OutputFile', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'ComputeBasis', false, @islogical);
addParameter(p, 'Verbose', true, @islogical);
addParameter(p, 'SaveIntermediates', true, @islogical);

parse(p, hdf5_file_or_path, varargin{:});
params = p.Results;

% Initialize timing
tic_start = tic;
computation_time = struct();

%% Check GSPBox availability
if params.Verbose
    fprintf('=== Graph Fourier Transform Analysis ===\n');
    fprintf('1. Checking dependencies...\n');
end

if ~exist('gsp_start', 'file')
    error('gftH5:GSPBoxNotFound', ...
        'GSPBox not found. Please install GSPBox and add it to MATLAB path.');
end

if params.Verbose
    fprintf('   ✓ GSPBox detected\n');
end

%% Load data from HDF5 file or structure
if params.Verbose
    fprintf('2. Loading data...\n');
end

tic_load = tic;

if ischar(params.hdf5_file_or_path) || isstring(params.hdf5_file_or_path)
    % Load from file
    input_file = char(params.hdf5_file_or_path);
    
    if ~exist(input_file, 'file')
        error('gftH5:FileNotFound', 'HDF5 file not found: %s', input_file);
    end
    
    if params.Verbose
        fprintf('   Loading from file: %s\n', input_file);
    end
    
    % Load using inbct function
    try
        data = inbct(input_file);
    catch ME
        error('gftH5:LoadError', 'Failed to load HDF5 file: %s', ME.message);
    end
    
else
    % Use provided data structure
    data = params.hdf5_file_or_path;
    input_file = 'data_structure';
    
    if params.Verbose
        fprintf('   Using provided data structure\n');
    end
end

computation_time.data_loading = toc(tic_load);

% Extract or construct graph
if isfield(data, 'graph')
    if isfield(data.graph, 'N')
        % Already a complete GSPBox graph
        G = data.graph;
        if params.Verbose
            fprintf('   ✓ GSPBox graph loaded: %d vertices, %d edges\n', G.N, G.Ne);
        end
        
    elseif isfield(data.graph, 'coords')
        % Reconstruct GSPBox graph from coordinates
        if params.Verbose
            fprintf('   Reconstructing GSPBox graph from coordinates...\n');
        end
        
        coords = data.graph.coords;
        N = size(coords, 1);
        
        % Create adjacency matrix from coordinates (similar to BioctreePlotter)
        D = pdist2(coords, coords);
        threshold = prctile(D(triu(true(size(D)), 1)), 5); % 5th percentile as threshold
        W = double(D < threshold & D > 0);
        
        % Create GSPBox graph structure
        G = struct();
        G.N = N;
        G.W = sparse(W);
        G.coords = coords;
        
        % Compute additional GSPBox properties
        G.d = sum(G.W, 2); % Degree
        G.Ne = nnz(G.W) / 2; % Number of edges (undirected)
        
        % Add Laplacian
        G.L = diag(G.d) - G.W;
        G.lap_type = 'combinatorial';
        
        if params.Verbose
            fprintf('   ✓ GSPBox graph reconstructed: %d vertices, %d edges\n', G.N, G.Ne);
            fprintf('   Edge threshold used: %.4f\n', threshold);
        end
    else
        error('gftH5:InvalidGraph', 'Graph field exists but has no coordinates or N field');
    end
    
else
    error('gftH5:NoGraph', 'No "graph" field found in data structure');
end

%% Load and validate signal data
if params.Verbose
    fprintf('3. Loading signal data...\n');
end

tic_signal = tic;

% Load signal using the same approach as BioctreePlotter
signal_data = [];
signal_info = struct();

try
    if isfield(data, 'X_layers') && isfield(data.X_layers, params.SignalName)
        % Multi-layer signal format
        signal_full = data.X_layers.(params.SignalName);
        signal_info.source = 'X_layers';
        
    elseif isfield(data, 'X') && strcmp(params.SignalName, 'signal')
        % Default signal format
        signal_full = data.X;
        signal_info.source = 'X';
        
    elseif isfield(data, params.SignalName)
        % Direct field access
        signal_full = data.(params.SignalName);
        signal_info.source = 'direct';
        
    else
        % Try to load from raw data in original HDF5 structure
        if ischar(params.hdf5_file_or_path) || isstring(params.hdf5_file_or_path)
            try
                signal_path = sprintf('/data/raw/%s', params.SignalName);
                signal_full = h5read(input_file, signal_path);
                signal_info.source = 'hdf5_raw';
            catch
                try
                    signal_path = sprintf('/data/%s', params.SignalName);
                    signal_full = h5read(input_file, signal_path);
                    signal_info.source = 'hdf5_data';
                catch
                    error('Signal "%s" not found in data', params.SignalName);
                end
            end
        else
            error('Signal "%s" not found in data structure', params.SignalName);
        end
    end
    
    % Handle temporal dimension
    signal_info.original_size = size(signal_full);
    
    if isempty(params.TimeIndex)
        % Process all time points
        signal_data = signal_full;
        time_indices = 1:size(signal_full, 2);
    else
        % Process specific time point(s)
        if max(params.TimeIndex) > size(signal_full, 2)
            error('Time index %d exceeds signal length %d', ...
                max(params.TimeIndex), size(signal_full, 2));
        end
        signal_data = signal_full(:, params.TimeIndex);
        time_indices = params.TimeIndex;
    end
    
    % Validate signal dimensions
    if size(signal_data, 1) ~= G.N
        error('Signal length (%d) does not match graph vertices (%d)', ...
            size(signal_data, 1), G.N);
    end
    
    signal_info.processed_size = size(signal_data);
    signal_info.time_indices = time_indices;
    signal_info.signal_range = [min(signal_data(:)), max(signal_data(:))];
    signal_info.nonzero_vertices = sum(any(signal_data ~= 0, 2));
    
    computation_time.signal_loading = toc(tic_signal);
    
    if params.Verbose
        fprintf('   ✓ Signal "%s" loaded: %d vertices × %d samples\n', ...
            params.SignalName, signal_info.processed_size);
        fprintf('   Signal range: [%.6f, %.6f]\n', signal_info.signal_range);
        fprintf('   Nonzero vertices: %d/%d (%.1f%%)\n', ...
            signal_info.nonzero_vertices, G.N, ...
            100 * signal_info.nonzero_vertices / G.N);
    end
    
catch ME
    error('gftH5:SignalLoadError', ...
        'Failed to load signal "%s": %s', params.SignalName, ME.message);
end

%% Prepare graph for GFT computation
if params.Verbose
    fprintf('4. Preparing graph for Fourier analysis...\n');
end

tic_graph = tic;

% Ensure graph has required properties for GSPBox
if ~isfield(G, 'lmax') || isempty(G.lmax)
    if params.Verbose
        fprintf('   Computing graph Laplacian spectrum bound...\n');
    end
    G = gsp_estimate_lmax(G);
end

% Compute or verify Fourier basis
basis_computed = false;
if ~isfield(G, 'U') || isempty(G.U) || params.ComputeBasis
    if params.Verbose
        fprintf('   Computing full graph Fourier basis (eigenvectors)...\n');
        fprintf('   This may take a moment for large graphs (N=%d)...\n', G.N);
    end
    
    % Compute full eigendecomposition using GSPBox
    G = gsp_compute_fourier_basis(G);
    basis_computed = true;
    
    if params.Verbose
        fprintf('   ✓ Fourier basis computed: %d eigenvectors\n', size(G.U, 2));
        fprintf('   Eigenvalue range: [%.6f, %.6f]\n', min(G.e), max(G.e));
        
        % Display spectral gap information
        if length(G.e) > 1
            spectral_gaps = diff(G.e);
            max_gap_idx = find(spectral_gaps == max(spectral_gaps), 1);
            fprintf('   Largest spectral gap: %.6f (between λ_%d and λ_%d)\n', ...
                max(spectral_gaps), max_gap_idx, max_gap_idx + 1);
        end
    end
else
    if params.Verbose
        fprintf('   ✓ Using existing Fourier basis (%d eigenvectors)\n', size(G.U, 2));
    end
end

computation_time.graph_preparation = toc(tic_graph);

%% Compute Graph Fourier Transform
if params.Verbose
    fprintf('5. Computing Graph Fourier Transform...\n');
end

tic_gft = tic;

% Compute GFT using GSPBox
X_gft = gsp_gft(G, signal_data);
gft_coeffs = X_gft;  % Store for selective HDF5 update

% Compute spectral energy
spectral_energy = abs(X_gft).^2;

computation_time.gft_computation = toc(tic_gft);

if params.Verbose
    fprintf('   ✓ GFT computed: %d frequency components × %d time samples\n', ...
        size(X_gft));
    
    % Display spectral energy statistics
    total_energy = sum(spectral_energy(:));
    low_freq_energy = sum(spectral_energy(1:round(G.N/10), :), 'all');
    high_freq_energy = sum(spectral_energy(round(9*G.N/10):end, :), 'all');
    
    fprintf('   Total spectral energy: %.6e\n', total_energy);
    fprintf('   Low frequency energy (1st decile): %.2f%%\n', ...
        100 * low_freq_energy / total_energy);
    fprintf('   High frequency energy (10th decile): %.2f%%\n', ...
        100 * high_freq_energy / total_energy);
end

%% Save updated graph with Fourier basis back to original file
if basis_computed && (ischar(params.hdf5_file_or_path) || isstring(params.hdf5_file_or_path))
    if params.Verbose
        fprintf('6. Saving updated graph with Fourier basis to original file...\n');
    end
    
    tic_update = tic;
    
    try
        % Selective update: only modify Fourier-related data in HDF5 file
        % This preserves all existing signal data and other content
        
        if params.Verbose
            fprintf('   Updating only Fourier basis data (preserving signals)...\n');
        end
        
        % Update eigenvalues in /graph/eigenvalues
        if isfield(G, 'e') && ~isempty(G.e)
            try
                h5write(input_file, '/graph/eigenvalues', G.e);
                if params.Verbose
                    fprintf('   ✓ Updated eigenvalues: %d values\n', length(G.e));
                end
            catch ME
                if contains(ME.message, 'dataset does not exist')
                    % Create the dataset if it doesn't exist
                    h5create(input_file, '/graph/eigenvalues', length(G.e), 'Datatype', 'single', 'ChunkSize', min(50, length(G.e)), 'Deflate', 6);
                    h5write(input_file, '/graph/eigenvalues', G.e);
                    if params.Verbose
                        fprintf('   ✓ Created and wrote eigenvalues: %d values\n', length(G.e));
                    end
                else
                    rethrow(ME);
                end
            end
        end
        
        % Update eigenvectors in /graph/eigenvectors  
        if isfield(G, 'U') && ~isempty(G.U)
            % Check if dataset exists, if not create it
            try
                h5write(input_file, '/graph/eigenvectors', G.U);
                if params.Verbose
                    fprintf('   ✓ Updated eigenvectors: %s\n', mat2str(size(G.U)));
                end
            catch ME
                if contains(ME.message, 'dataset does not exist')
                    % Create the dataset if it doesn't exist
                    h5create(input_file, '/graph/eigenvectors', size(G.U), 'Datatype', 'single', 'ChunkSize', min([50 50], size(G.U)), 'Deflate', 6);
                    h5write(input_file, '/graph/eigenvectors', G.U);
                    if params.Verbose
                        fprintf('   ✓ Created and wrote eigenvectors: %s\n', mat2str(size(G.U)));
                    end
                else
                    rethrow(ME);
                end
            end
        end
        
        % Update spectral data if we computed GFT
        if exist('gft_coeffs', 'var') && ~isempty(gft_coeffs)
            % Update GFT coefficients in /data/spectral/signal_gft (or appropriate signal name)
            spectral_path = sprintf('/data/spectral/%s_gft', params.SignalName);
            try
                h5write(input_file, spectral_path, gft_coeffs);
                if params.Verbose
                    fprintf('   ✓ Updated GFT coefficients: %s\n', spectral_path);
                end
            catch ME
                if contains(ME.message, 'dataset does not exist')
                    % Create the dataset if it doesn't exist
                    h5create(input_file, spectral_path, size(gft_coeffs), 'Datatype', 'single', 'ChunkSize', min([50 50], size(gft_coeffs)), 'Deflate', 6);
                    h5write(input_file, spectral_path, gft_coeffs);
                    if params.Verbose
                        fprintf('   ✓ Created and wrote GFT coefficients: %s\n', spectral_path);
                    end
                else
                    warning('gftH5:SpectralUpdate', 'Could not update spectral data: %s', ME.message);
                end
            end
        end
        
        computation_time.graph_update = toc(tic_update);
        
        if params.Verbose
            fprintf('   ✓ Fourier basis selectively updated in: %s\n', input_file);
            fprintf('   File preserves all existing signals and data\n');
            fprintf('   File now contains eigenvalues (G.e) and eigenvectors (G.U)\n');
        end
        
    catch ME
        warning('gftH5:UpdateError', 'Failed to update Fourier data in file: %s', ME.message);
        computation_time.graph_update = toc(tic_update);
    end
else
    if params.Verbose && basis_computed
        fprintf('6. Fourier basis computed but not saving to original file (input was data structure)\n');
    end
end

%% Prepare output structures
computation_time.total = toc(tic_start);

% GFT data structure
gft_data = struct();
gft_data.X_gft = X_gft;
gft_data.eigenvalues = G.e;
gft_data.eigenvectors = G.U;
gft_data.signal_name = params.SignalName;
gft_data.time_index = time_indices;
gft_data.spectral_energy = spectral_energy;

% Analysis info structure
analysis_info = struct();
analysis_info.graph_info = struct('N', G.N, 'Ne', G.Ne, 'lmax', G.lmax, ...
    'eigenvalue_range', [min(G.e), max(G.e)]);
analysis_info.signal_info = signal_info;
analysis_info.computation_time = computation_time;
analysis_info.gsp_params = struct('fourier_basis_size', size(G.U), ...
    'laplacian_type', G.lap_type);

%% Save results if requested
if ~isempty(params.OutputFile)
    if params.Verbose
        fprintf('7. Saving results to HDF5 file...\n');
    end
    
    tic_save = tic;
    
    try
        % Prepare analysis data for export
        analysisData = struct();
        analysisData.G = G;
        analysisData.X = signal_data;
        analysisData.X_gft = X_gft;
        analysisData.spectral_energy = spectral_energy;
        
        % Add metadata
        analysisData.metadata = struct();
        analysisData.metadata.signal_name = params.SignalName;
        analysisData.metadata.time_indices = time_indices;
        analysisData.metadata.computation_time = computation_time;
        analysisData.metadata.created = datestr(now);
        analysisData.metadata.source_file = input_file;
        
        % Export using outbct
        outbct(params.OutputFile, analysisData);
        
        computation_time.saving = toc(tic_save);
        
        if params.Verbose
            fprintf('   ✓ Results saved to: %s\n', params.OutputFile);
        end
        
    catch ME
        warning('gftH5:SaveError', 'Failed to save results: %s', ME.message);
        computation_time.saving = toc(tic_save);
    end
end

%% Final summary
if params.Verbose
    fprintf('\n=== GFT Analysis Complete ===\n');
    fprintf('Processing time breakdown:\n');
    fprintf('  Data loading:     %.3f s\n', computation_time.data_loading);
    fprintf('  Signal loading:   %.3f s\n', computation_time.signal_loading);
    fprintf('  Graph preparation: %.3f s\n', computation_time.graph_preparation);
    fprintf('  GFT computation:  %.3f s\n', computation_time.gft_computation);
    if isfield(computation_time, 'graph_update')
        fprintf('  Graph update:     %.3f s\n', computation_time.graph_update);
    end
    if isfield(computation_time, 'saving')
        fprintf('  Result saving:    %.3f s\n', computation_time.saving);
    end
    fprintf('  Total time:       %.3f s\n', computation_time.total);
    
    fprintf('\nResults summary:\n');
    fprintf('  Signal: "%s" (%d vertices × %d samples)\n', ...
        params.SignalName, size(X_gft));
    fprintf('  Spectral energy range: [%.2e, %.2e]\n', ...
        min(spectral_energy(:)), max(spectral_energy(:)));
    fprintf('  Graph eigenvalue range: [%.6f, %.6f]\n', min(G.e), max(G.e));
    
    if ~isempty(params.OutputFile)
        fprintf('  Output file: %s\n', params.OutputFile);
    end
    
    fprintf('================================\n');
end

end