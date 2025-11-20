% Quick Start Guide: Bct Visualization System
%
% This guide shows how to use the new visualization features in the Bct class.
%
% SETUP
% -----
% First, initialize the bioctree environment:
%   bioctree_start
%
% LOADING A MESH
% --------------
% Load a FreeSurfer mesh:
%   path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
%   B = bct.io.import.mesh(path);
%   B.Time = bct.manifold.Time(100, 100);  % Optional: 1 sec @ 100 Hz
%
% BASIC MESH VISUALIZATION
% -------------------------
% 1. Default gray mesh:
%   B.showMesh()
%
% 2. With custom colormap:
%   B.showMesh('ColorMap', 'turbo')
%
% 3. Wireframe mode:
%   B.showMesh('WireFrame', true)
%
% SIGNAL VISUALIZATION
% --------------------
% First, create a signal:
%   sig = bct.signal.Signal();
%   sig.Data = randn(B.Manifold.N, 1);  % Static signal
%   sig.Label = 'Random noise';
%   B.Signals = sig;
%
% Then visualize it:
%   B.showSignal(1, 'ColorMap', 'jet')
%
% TIME-VARYING SIGNALS
% --------------------
% Create a dynamic signal:
%   sig2 = bct.signal.Signal();
%   sig2.Data = randn(B.Manifold.N, B.Time.T);  % [N×T] matrix
%   sig2.Label = 'Dynamic signal';
%   B.Signals(2) = sig2;
%
% Visualize at specific time point:
%   B.showSignal(2, 'TimePoint', 50, 'ColorMap', 'parula')
%
% ADVANCED USAGE
% --------------
% 1. Package functions (alternative API):
%   viewer = bct.show.mesh(B, 'ColorMap', 'cool');
%   viewer = bct.show.signal(B, 1, 'ColorMap', 'hot');
%
% 2. Direct visualizer with custom data:
%   customSignal = B.Manifold.V(:, 1);  % x-coordinate
%   viewer = bct.show.visualizer(B, 'SignalData', customSignal, 'ColorMap', 'viridis');
%
% AVAILABLE COLORMAPS
% -------------------
% Standard MATLAB colormaps: parula, jet, turbo, hot, cool, gray, bone, copper,
% pink, spring, summer, autumn, winter, viridis, plasma, inferno, magma, cividis
%
% VISUALIZATION ARCHITECTURE
% ---------------------------
% Three API levels:
%   Level 1 (Simplest):  B.showMesh(), B.showSignal()
%   Level 2 (Mid-level): bct.show.mesh(B, ...), bct.show.signal(B, ...)
%   Level 3 (Core):      bct.show.visualizer(B, ...)
%
% All three levels delegate to bct.show.visualizer, which uses MATLAB's
% high-performance images.ui.graphics3d.Surface API for rendering.
%
% EXAMPLES
% --------
% See these files for working examples:
%   demo_bct_visualization.m  - Comprehensive demo with all features
%   test_bct_viz_final.m      - Automated test suite
%
% For more information, see the Bct class documentation.
