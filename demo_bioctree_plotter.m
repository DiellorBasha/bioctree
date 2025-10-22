%% BioctreePlotter Demo Script
% This script demonstrates the BioctreePlotter class for visualizing
% Bioctree HDF5 data and graph structures.

clear; close all; clc;

fprintf('=== BioctreePlotter Demonstration ===\n\n');

%% Demo 1: Plot from HDF5 file
fprintf('1. Testing BioctreePlotter with HDF5 file...\n');

% Path to the icosphere demo file
config = bioctree_config();
hdf5_file = fullfile(config.DataPath, 'bioctree_files', 'icosphere_patch_demo.h5');

if exist(hdf5_file, 'file')
    fprintf('   Loading from HDF5 file: %s\n', hdf5_file);
    
    % Create plotter from HDF5 file
    plotter1 = BioctreePlotter(hdf5_file);
    
    % Display graph information
    plotter1.displayInfo();
    
    % Create wireframe plot
    figure('Position', [100, 100, 800, 600]);
    plotter1.plotWireframe('Title', 'Icosphere from HDF5 File', ...
                          'ShowVertices', false, ...
                          'LineWidth', 0.8, ...
                          'EdgeColor', [0.2, 0.2, 0.8]);
    
    fprintf('   ✓ HDF5 wireframe plot created\n\n');
    
else
    fprintf('   ⚠ HDF5 demo file not found: %s\n', hdf5_file);
    fprintf('   Run workflow_sphere.m first to create demo data\n\n');
end

%% Demo 2: Plot from direct graph structure
fprintf('2. Testing BioctreePlotter with graph structure...\n');

% Create an icosphere directly
fprintf('   Creating icosphere graph...\n');
G = build_icosphere(2, 1, 'laplacianType', 'cotangent');
fprintf('   ✓ Created icosphere: %d vertices, %d edges\n', G.N, G.Ne);

% Create plotter from graph structure
plotter2 = BioctreePlotter(G);

% Display graph information  
plotter2.displayInfo();

% Create wireframe plot with vertices
figure('Position', [150, 150, 800, 600]);
plotter2.plotWireframe('Title', 'Icosphere from Graph Structure', ...
                      'ShowVertices', true, ...
                      'VertexSize', 25, ...
                      'VertexColor', [0.8, 0.2, 0.2], ...
                      'LineWidth', 1.0, ...
                      'EdgeColor', [0.3, 0.3, 0.3], ...
                      'ViewAngle', [45, 30]);

fprintf('   ✓ Graph structure wireframe plot created\n\n');

%% Demo 3: Multiple view angles
fprintf('3. Creating multiple view perspectives...\n');

% Create subplot figure with different views
fig3 = figure('Position', [200, 200, 1200, 800]);
sgtitle('BioctreePlotter: Multiple Perspectives', 'FontSize', 16, 'FontWeight', 'bold');

% View 1: Front view
subplot(2, 3, 1);
plotter2.plotWireframe('Figure', fig3, ...
                      'Title', 'Front View', ...
                      'ShowVertices', false, ...
                      'ViewAngle', [0, 0], ...
                      'EdgeColor', 'blue');

% View 2: Side view  
subplot(2, 3, 2);
plotter2.plotWireframe('Figure', fig3, ...
                      'Title', 'Side View', ...
                      'ShowVertices', false, ...
                      'ViewAngle', [90, 0], ...
                      'EdgeColor', 'green');

% View 3: Top view
subplot(2, 3, 3);
plotter2.plotWireframe('Figure', fig3, ...
                      'Title', 'Top View', ...
                      'ShowVertices', false, ...
                      'ViewAngle', [0, 90], ...
                      'EdgeColor', 'red');

% View 4: Perspective 1
subplot(2, 3, 4);
plotter2.plotWireframe('Figure', fig3, ...
                      'Title', 'Perspective 1', ...
                      'ShowVertices', true, ...
                      'VertexSize', 15, ...
                      'ViewAngle', [45, 30], ...
                      'EdgeColor', 'magenta');

% View 5: Perspective 2  
subplot(2, 3, 5);
plotter2.plotWireframe('Figure', fig3, ...
                      'Title', 'Perspective 2', ...
                      'ShowVertices', true, ...
                      'VertexSize', 15, ...
                      'ViewAngle', [-45, -30], ...
                      'EdgeColor', 'cyan');

% View 6: Isometric
subplot(2, 3, 6);
plotter2.plotWireframe('Figure', fig3, ...
                      'Title', 'Isometric', ...
                      'ShowVertices', false, ...
                      'ViewAngle', [45, 35.26], ...
                      'EdgeColor', 'black', ...
                      'LineWidth', 1.2);

fprintf('   ✓ Multiple perspective plots created\n\n');

%% Demo 4: Plot styling options
fprintf('4. Demonstrating styling options...\n');

% Create figure with different styling
fig4 = figure('Position', [250, 250, 1200, 600]);
sgtitle('BioctreePlotter: Styling Options', 'FontSize', 16, 'FontWeight', 'bold');

% Style 1: Minimal wireframe
subplot(1, 3, 1);
plotter2.plotWireframe('Figure', fig4, ...
                      'Title', 'Minimal Style', ...
                      'ShowVertices', false, ...
                      'LineWidth', 0.3, ...
                      'EdgeColor', [0.7, 0.7, 0.7]);

% Style 2: Bold with vertices
subplot(1, 3, 2);  
plotter2.plotWireframe('Figure', fig4, ...
                      'Title', 'Bold Style', ...
                      'ShowVertices', true, ...
                      'VertexSize', 40, ...
                      'VertexColor', [1, 0.5, 0], ...
                      'LineWidth', 2.0, ...
                      'EdgeColor', [0, 0, 0.8]);

% Style 3: Custom colorful
subplot(1, 3, 3);
plotter2.plotWireframe('Figure', fig4, ...
                      'Title', 'Colorful Style', ...
                      'ShowVertices', true, ...
                      'VertexSize', 20, ...
                      'VertexColor', [0.8, 0.2, 0.8], ...
                      'LineWidth', 1.5, ...
                      'EdgeColor', [0.2, 0.8, 0.2]);

fprintf('   ✓ Styling demonstration plots created\n\n');

%% Demo 5: Compare different icosphere resolutions
fprintf('5. Comparing different icosphere resolutions...\n');

subdivisions = [0, 1, 2];
fig5 = figure('Position', [300, 300, 1200, 400]);
sgtitle('BioctreePlotter: Resolution Comparison', 'FontSize', 16, 'FontWeight', 'bold');

for i = 1:length(subdivisions)
    subdiv = subdivisions(i);
    G_res = build_icosphere(subdiv, 1);
    plotter_res = BioctreePlotter(G_res);
    
    subplot(1, 3, i);
    plotter_res.plotWireframe('Figure', fig5, ...
                             'Title', sprintf('Subdivision %d (%d vertices)', subdiv, G_res.N), ...
                             'ShowVertices', true, ...
                             'VertexSize', 20, ...
                             'LineWidth', 1.0);
    
    fprintf('   ✓ Resolution %d: %d vertices\n', subdiv, G_res.N);
end

fprintf('\n');

%% Demo 6: Signal plotting from HDF5 file
fprintf('6. Testing signal plotting from HDF5 file...\n');

if exist(hdf5_file, 'file')
    % Get available signals
    signals = plotter1.getAvailableSignals();
    
    if ~isempty(signals)
        % Create figure for signal comparisons
        fig6 = figure('Position', [350, 350, 1400, 800]);
        sgtitle('BioctreePlotter: Graph Signal Visualization', 'FontSize', 16, 'FontWeight', 'bold');
        
        % Plot first few signals
        signal_indices = [1, 7, 8, 9]; % signal, patch_05_pct, patch_10_pct, patch_15_pct
        for i = 1:min(4, length(signal_indices))
            if signal_indices(i) <= length(signals)
                subplot(2, 2, i);
                signal_name = signals{signal_indices(i)};
                
                plotter1.plotSignal('SignalName', signal_name, ...
                                   'Figure', fig6, ...
                                   'Title', sprintf('Signal: %s', signal_name), ...
                                   'ViewAngle', [45, 30], ...
                                   'EdgeAlpha', 0.1, ...
                                   'MarkerSize', 40, ...
                                   'Colormap', 'parula');
                
                fprintf('   ✓ Plotted signal: %s\n', signal_name);
            end
        end
        
        fprintf('   ✓ Signal visualization demo completed\n\n');
    else
        fprintf('   ⚠ No signal data found in HDF5 file\n\n');
    end
else
    fprintf('   ⚠ HDF5 demo file not available for signal plotting\n\n');
end

%% Demo 7: Signal comparison with different colormaps
fprintf('7. Comparing signal visualizations with different styles...\n');

if exist(hdf5_file, 'file') && ~isempty(signals)
    % Use a patch signal for demonstration
    patch_signals = signals(contains(signals, 'patch'));
    
    if ~isempty(patch_signals)
        demo_signal = patch_signals{1}; % Use first patch signal
        
        fig7 = figure('Position', [400, 400, 1400, 600]);
        sgtitle('BioctreePlotter: Signal Visualization Styles', 'FontSize', 16, 'FontWeight', 'bold');
        
        % Style 1: Jet colormap with edges
        subplot(1, 3, 1);
        plotter1.plotSignal('SignalName', demo_signal, ...
                           'Figure', fig7, ...
                           'Title', 'Jet + Edges', ...
                           'Colormap', 'jet', ...
                           'EdgeAlpha', 0.3, ...
                           'MarkerSize', 60);
        
        % Style 2: Hot colormap without edges  
        subplot(1, 3, 2);
        plotter1.plotSignal('SignalName', demo_signal, ...
                           'Figure', fig7, ...
                           'Title', 'Hot + No Edges', ...
                           'Colormap', 'hot', ...
                           'EdgeAlpha', 0.0, ...
                           'MarkerSize', 80);
        
        % Style 3: Cool colormap with different view
        subplot(1, 3, 3);
        plotter1.plotSignal('SignalName', demo_signal, ...
                           'Figure', fig7, ...
                           'Title', 'Cool + Side View', ...
                           'Colormap', 'cool', ...
                           'EdgeAlpha', 0.2, ...
                           'ViewAngle', [90, 0], ...
                           'MarkerSize', 70);
        
        fprintf('   ✓ Signal style comparison completed\n\n');
    else
        fprintf('   ⚠ No patch signals found for style demo\n\n');
    end
end

%% Summary
fprintf('=== Demo Summary ===\n');
fprintf('✓ BioctreePlotter class successfully demonstrated\n');
fprintf('✓ Supports both HDF5 files and direct graph structures\n');
fprintf('✓ Flexible wireframe plotting with customization options\n');
fprintf('✓ Graph signal visualization with multiple colormaps\n');
fprintf('✓ Multiple view angles and styling capabilities\n');
fprintf('✓ Works with different graph resolutions\n');
fprintf('✓ Signal data loading from HDF5 multi-layer files\n');

fprintf('\nBioctreePlotter Features:\n');
fprintf('• Input: HDF5 file path or graph structure\n');
fprintf('• Automatic edge detection from coordinates\n');
fprintf('• Customizable wireframe visualization\n');
fprintf('• Graph signal plotting with color mapping\n');
fprintf('• Multi-layer signal support\n');
fprintf('• Graph information display\n');
fprintf('• Multiple view perspectives\n');
fprintf('• Flexible styling options\n');

fprintf('\nUsage Examples:\n');
fprintf('  plotter = BioctreePlotter(''data.h5'');        %% From HDF5 file\n');
fprintf('  plotter = BioctreePlotter(graph_struct);       %% From graph structure\n');
fprintf('  plotter.plotWireframe();                       %% Basic wireframe\n');
fprintf('  plotter.plotSignal(''SignalName'', ''signal'');  %% Plot graph signal\n');
fprintf('  plotter.getAvailableSignals();                 %% List available signals\n');
fprintf('  plotter.displayInfo();                         %% Show graph info\n');

fprintf('\n=== BioctreePlotter Demo Complete ===\n');