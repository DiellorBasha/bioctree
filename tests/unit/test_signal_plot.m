%% Test BioctreePlotter Signal Functionality
% Quick test script for signal plotting

clear; close all; clc;

fprintf('Testing BioctreePlotter signal plotting...\n');

try
    % Load configuration
    config = bioctree_config();
    hdf5_file = fullfile(config.DataPath, 'bioctree_files', 'icosphere_patch_demo.h5');
    
    if ~exist(hdf5_file, 'file')
        error('Demo HDF5 file not found: %s', hdf5_file);
    end
    
    % Create plotter
    fprintf('1. Creating BioctreePlotter...\n');
    plotter = BioctreePlotter(hdf5_file);
    
    % Get available signals
    fprintf('2. Getting available signals...\n');
    signals = plotter.getAvailableSignals();
    fprintf('   Found %d signals: %s\n', length(signals), strjoin(signals(1:min(3,length(signals))), ', '));
    
    % Test basic signal plot
    fprintf('3. Testing basic signal plot...\n');
    figure('Position', [100, 100, 800, 600]);
    
    % Try plotting the 5% patch signal
    if any(strcmp(signals, 'signal_patch_05_pct'))
        plotter.plotSignal('SignalName', 'signal_patch_05_pct', ...
                          'Title', 'Test: 5% Patch Signal', ...
                          'ViewAngle', [45, 30], ...
                          'EdgeAlpha', 0.2);
        fprintf('   ✓ 5%% patch signal plotted successfully\n');
    else
        % Fallback to first available signal
        plotter.plotSignal('SignalName', signals{1}, ...
                          'Title', sprintf('Test: %s', signals{1}));
        fprintf('   ✓ Signal "%s" plotted successfully\n', signals{1});
    end
    
    fprintf('\n=== Signal Plotting Test Successful ===\n');
    fprintf('Close the figure window to continue...\n');
    
catch ME
    fprintf('\n=== Error in Signal Plotting Test ===\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('Location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
end