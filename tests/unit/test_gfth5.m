%% Test gftH5 Function
% Quick test script for the Graph Fourier Transform function

clear; close all; clc;

fprintf('Testing gftH5 function...\n');

try
    % Get demo file path
    config = bioctree_config();
    hdf5_file = fullfile(config.DataPath, 'bioctree_files', 'icosphere_patch_demo.h5');
    
    if ~exist(hdf5_file, 'file')
        error('Demo HDF5 file not found: %s', hdf5_file);
    end
    
    fprintf('1. Testing basic GFT computation...\n');
    
    % Test with minimal output for speed
    [gft_data, analysis_info] = gftH5(hdf5_file, ...
        'SignalName', 'signal_patch_05_pct', ...
        'Verbose', true);
    
    fprintf('\n=== Test Results ===\n');
    fprintf('GFT coefficients: %s\n', mat2str(size(gft_data.X_gft)));
    fprintf('Eigenvalues: %d values, range [%.6f, %.6f]\n', ...
        length(gft_data.eigenvalues), min(gft_data.eigenvalues), max(gft_data.eigenvalues));
    fprintf('Spectral energy range: [%.2e, %.2e]\n', ...
        min(gft_data.spectral_energy(:)), max(gft_data.spectral_energy(:)));
    
    fprintf('Graph info: %d vertices, %d edges\n', ...
        analysis_info.graph_info.N, analysis_info.graph_info.Ne);
    fprintf('Signal info: %s, nonzero vertices: %d\n', ...
        mat2str(analysis_info.signal_info.processed_size), ...
        analysis_info.signal_info.nonzero_vertices);
    
    fprintf('\n✓ gftH5 function test successful!\n');
    
catch ME
    fprintf('\n✗ Error in gftH5 test:\n');
    fprintf('Error: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
end