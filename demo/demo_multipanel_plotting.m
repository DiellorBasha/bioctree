%% Demo: Multipanel Plotting with BioctreePlotter
% This script demonstrates the new multipanel plotting capability of
% BioctreePlotter, showing how plotting functions can act as components
% that are packaged into a single figure with custom layouts.

% Clear workspace
clear; close all; clc;

fprintf('=== BioctreePlotter Multipanel Demo ===\n\n');

%% Load sample data
% You can replace this with your actual HDF5 file path
sample_file = 'sample_data.bct';

% For this demo, we'll use a data structure approach
% (replace with actual file loading when available)
fprintf('Setting up sample data...\n');

% Create sample graph data structure
N = 100; % Number of vertices
G.coords = randn(N, 3); % Random 3D coordinates
G.coords = G.coords ./ vecnorm(G.coords, 2, 2); % Normalize to unit sphere

% Create adjacency based on distance
D = pdist2(G.coords, G.coords);
threshold = 0.5;
[i, j] = find(triu(D < threshold & D > 0));
G.edge_list = [i, j];

% Create sample signals
X = randn(N, 1); % Random signal
X_patch = zeros(N, 1);
X_patch(1:round(N*0.15)) = sin(linspace(0, 4*pi, round(N*0.15)))'; % Localized signal

% Package into data structure
data_struct = struct();
data_struct.graph = G;
data_struct.X = X;
data_struct.X_layers.signal_random = X;
data_struct.X_layers.signal_patch_15_pct = X_patch;

fprintf('✓ Sample data created: %d vertices, %d edges\n', N, size(G.edge_list, 1));

%% Initialize BioctreePlotter
fprintf('\nInitializing BioctreePlotter...\n');
plotter = BioctreePlotter(data_struct);

%% Demo 1: Simple 2-Panel Layout
fprintf('\n--- Demo 1: Simple 2-Panel Layout ---\n');

% Define plot specifications for 2-panel layout
specs_2panel = {
    struct('type', 'surfaceSignal', 'subplot', [1,2,1], ...
           'title', 'Surface Signal Distribution', ...
           'params', {{'SignalName', 'signal_patch_15_pct', 'Colormap', 'turbo'}}), ...
    struct('type', 'signal', 'subplot', [1,2,2], ...
           'title', 'Vertex Signal Scatter', ...
           'params', {{'SignalName', 'signal_patch_15_pct', 'MarkerSize', 40}})
};

% Create 2-panel figure
fig1 = plotter.plotMultipanel(specs_2panel, ...
    'MainTitle', 'Two-Panel Analysis: Signal Views', ...
    'FigureSize', [1200, 500]);

fprintf('✓ 2-panel figure created\n');

%% Demo 2: Comprehensive 4-Panel Layout
fprintf('\n--- Demo 2: Comprehensive 4-Panel Layout ---\n');

% Define plot specifications for 4-panel layout
specs_4panel = {
    struct('type', 'wireframe', 'subplot', [2,2,1], ...
           'title', 'Graph Structure', ...
           'params', {{'ShowVertices', true, 'VertexSize', 15, 'EdgeColor', [0.3, 0.3, 0.8]}}), ...
    struct('type', 'surface', 'subplot', [2,2,2], ...
           'title', 'Surface Mesh', ...
           'params', {{'FaceColor', [0.8, 0.9, 1.0], 'EdgeAlpha', 0.2}}), ...
    struct('type', 'surfaceSignal', 'subplot', [2,2,3], ...
           'title', 'Signal on Surface', ...
           'params', {{'SignalName', 'signal_patch_15_pct', 'Colormap', 'viridis'}}), ...
    struct('type', 'gft', 'subplot', [2,2,4], ...
           'title', 'Frequency Analysis', ...
           'params', {{'SignalName', 'signal_patch_15_pct', 'PlotType', 'stem'}})
};

% Create 4-panel figure
fig2 = plotter.plotMultipanel(specs_4panel, ...
    'MainTitle', 'Comprehensive Analysis: Structure, Signal & Spectrum', ...
    'FigureSize', [1400, 1000], ...
    'ShowInfo', false);

fprintf('✓ 4-panel figure created\n');

%% Demo 3: Custom Layout with Different Signals
fprintf('\n--- Demo 3: Custom Signal Comparison ---\n');

% Define plot specifications comparing different signals
specs_comparison = {
    struct('type', 'surfaceSignal', 'subplot', [2,3,1], ...
           'title', 'Random Signal', ...
           'params', {{'SignalName', 'signal_random', 'Colormap', 'jet'}}), ...
    struct('type', 'surfaceSignal', 'subplot', [2,3,2], ...
           'title', 'Patch Signal (15%)', ...
           'params', {{'SignalName', 'signal_patch_15_pct', 'Colormap', 'jet'}}), ...
    struct('type', 'signal', 'subplot', [2,3,3], ...
           'title', 'Patch Signal Vertices', ...
           'params', {{'SignalName', 'signal_patch_15_pct', 'MarkerSize', 30}}), ...
    struct('type', 'gft', 'subplot', [2,3,4], ...
           'title', 'Random Signal Spectrum', ...
           'params', {{'SignalName', 'signal_random', 'PlotType', 'bar'}}), ...
    struct('type', 'gft', 'subplot', [2,3,5], ...
           'title', 'Patch Signal Spectrum', ...
           'params', {{'SignalName', 'signal_patch_15_pct', 'PlotType', 'bar'}}), ...
    struct('type', 'wireframe', 'subplot', [2,3,6], ...
           'title', 'Graph Connectivity', ...
           'params', {{'ShowVertices', false, 'LineWidth', 0.8}})
};

% Create comparison figure
fig3 = plotter.plotMultipanel(specs_comparison, ...
    'MainTitle', 'Signal Comparison: Random vs Localized', ...
    'FigureSize', [1600, 900]);

fprintf('✓ Comparison figure created\n');

%% Demo 4: Publication-Ready Layout
fprintf('\n--- Demo 4: Publication-Ready Layout ---\n');

% Define publication-style layout
specs_publication = {
    struct('type', 'surfaceSignal', 'subplot', [2,2,1], ...
           'title', '(A) Signal Distribution', ...
           'params', {{'SignalName', 'signal_patch_15_pct', 'Colormap', 'plasma', ...
                      'EdgeAlpha', 0.05, 'ViewAngle', [45, 15]}}), ...
    struct('type', 'gft', 'subplot', [2,2,2], ...
           'title', '(B) Spectral Analysis', ...
           'params', {{'SignalName', 'signal_patch_15_pct', 'PlotType', 'stem', ...
                      'HighlightLowFreq', true, 'NumFreqBands', 5}}), ...
    struct('type', 'signal', 'subplot', [2,2,[3,4]], ...  % Span bottom row
           'title', '(C) Signal Amplitude Distribution', ...
           'params', {{'SignalName', 'signal_patch_15_pct', 'MarkerSize', 35, ...
                      'ViewAngle', [0, 90], 'EdgeAlpha', 0.1}})
};

% Create publication figure with custom settings
fig4 = plotter.plotMultipanel(specs_publication, ...
    'MainTitle', 'Graph Signal Processing on Spherical Mesh', ...
    'FigureSize', [1200, 800], ...
    'TightLayout', true, ...
    'ShowInfo', false);

fprintf('✓ Publication-ready figure created\n');

%% Display summary
fprintf('\n=== Demo Complete ===\n');
fprintf('Created 4 different multipanel layouts:\n');
fprintf('  1. Simple 2-panel layout (surface + scatter views)\n');
fprintf('  2. Comprehensive 4-panel layout (structure + signal + spectrum)\n');
fprintf('  3. Signal comparison layout (6 panels)\n');
fprintf('  4. Publication-ready layout (custom subplot spans)\n\n');

fprintf('Key Features Demonstrated:\n');
fprintf('  ✓ Component-based plotting architecture\n');
fprintf('  ✓ Flexible subplot layouts and positioning\n');
fprintf('  ✓ Parameter customization for each panel\n');
fprintf('  ✓ Custom titles and main figure titles\n');
fprintf('  ✓ Different signal comparisons\n');
fprintf('  ✓ Publication-quality formatting options\n\n');

fprintf('Usage Pattern:\n');
fprintf('  1. Define plot specifications as cell array of structs\n');
fprintf('  2. Each struct specifies: type, subplot position, parameters\n');
fprintf('  3. Call plotMultipanel() with specifications\n');
fprintf('  4. BioctreePlotter handles figure creation and layout\n\n');

% Display available plot types
fprintf('Available Plot Types:\n');
fprintf('  - wireframe     : Graph structure with edges and vertices\n');
fprintf('  - surface       : 3D surface mesh representation\n');
fprintf('  - signal        : Signal values as colored vertex scatter\n');
fprintf('  - surfaceSignal : Signal mapped onto surface mesh\n');
fprintf('  - gft           : Graph Fourier Transform spectrum\n\n');

fprintf('Next steps: Replace sample data with your HDF5 files!\n');