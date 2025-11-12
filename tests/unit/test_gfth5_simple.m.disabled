%% Simple gftH5 Test
% Test the Graph Fourier Transform function

clear; close all; clc;

fprintf('=== Testing gftH5 Function ===\n');

% Get demo file
config = bioctree_config();
hdf5_file = fullfile(config.DataPath, 'bioctree_files', 'icosphere_patch_demo.h5');

if exist(hdf5_file, 'file')
    fprintf('Testing with file: %s\n', hdf5_file);
    
    % First check if GSPBox is available
    if ~exist('gsp_start', 'file')
        fprintf('GSPBox not found - please install GSPBox\n');
        return;
    end
    
    fprintf('GSPBox detected, starting computation...\n');
    
    % Run gftH5 function
    tic;
    [gft_data, analysis_info] = gftH5(hdf5_file, 'SignalName', 'signal_patch_05_pct');
    elapsed_time = toc;
    
    fprintf('\n=== Results ===\n');
    fprintf('Computation completed in %.2f seconds\n', elapsed_time);
    fprintf('GFT coefficients: %d × %d\n', size(gft_data.X_gft, 1), size(gft_data.X_gft, 2));
    fprintf('Eigenvalues: %d values\n', length(gft_data.eigenvalues));
    fprintf('Eigenvectors: %d × %d\n', size(gft_data.eigenvectors, 1), size(gft_data.eigenvectors, 2));
    
    fprintf('\nSpectral analysis:\n');
    fprintf('  Min eigenvalue: %.6f\n', min(gft_data.eigenvalues));
    fprintf('  Max eigenvalue: %.6f\n', max(gft_data.eigenvalues));
    fprintf('  Spectral energy range: [%.2e, %.2e]\n', ...
        min(gft_data.spectral_energy), max(gft_data.spectral_energy));
    
    fprintf('\nGraph info:\n');
    fprintf('  Vertices: %d\n', analysis_info.graph_info.N);
    fprintf('  Edges: %d\n', analysis_info.graph_info.Ne);
    
    fprintf('\n✓ gftH5 test successful!\n');
    
else
    fprintf('Demo file not found: %s\n', hdf5_file);
end