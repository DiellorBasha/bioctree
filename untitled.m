% Setup!
B=fs6;
viewer=viewer3d ("BackgroundColor",[0 0 0 ],"BackgroundGradient","off","RenderingQuality","high");
ManifoldTriangulation = B.Manifold.getTriangulation;
ManifoldSurf = images.ui.graphics.Surface(viewer,...
    'Data',  ManifoldTriangulation, ...
    'Alpha', 0.7, ...
    'Color',[0.6 0.6 0.6]);
BrushSurf = images.ui.graphics.Surface(viewer,...
    'Data',  ManifoldTriangulation, ...
    'Alpha', 1, ...
     'Color',[0.6 0.6 0.6]);
%%
% Create spectral brush
B.Manifold.dual = B.Lambda; B.Lambda.dual=B.Manifold;

params = struct();
params.source = 1000;
params.target = 500;
params.kernel = 'heat';
params.kernel_params = struct('tau', 1);
w = bct.brush.trajectory.spectral(B.Manifold, params);

w = full(w);          % dense kernel
wRGB=bct.show.x2rgb(w);
BrushSurf.Color=wRGB;

%%
B.Time = bct.Time(100,10);
params.source = 100;
params.target = 500;
params.tau_range = [0.02, 0.4];
params.tau_profile = 'exponential';

w = bct.brush.time.heat(B.Manifold, B.Time, params);
% w is [N×T]: N vertices, T time steps
w = full(w);          % dense kernel
%%
w = full(w);     %
%%
for k = 1:1:100
    wRGB = bct.show.x2rgb(w(:, k));   % assume w(:,k) changes over time
    BrushSurf.Color = wRGB;
    
    drawnow;          % force graphics update
    pause(0.1);       % control animation speed (seconds)
end
%%
% Example 2: Moving source along path
[path, ~] = B.Manifold.Graph.shortestPath(100, 500);
params.source = @(t, T) path(round(t/T * length(path)));
params.kernel = 'gaussian';
params.sigma = 15;
w = bct.brush.time.spectral(B.Manifold, B.Time, params);
%%
% Example: Moving source with increasing heat diffusion over time
[path, ~] = B.Manifold.Graph.shortestPath(100, 500);
params.source = @(t, T) path(min(max(1, round(t/T * length(path))), length(path)));
params.kernel = 'heat';
params.tau = @(t, T) 0.05 + 0.3*(t/T);  % Increase from 0.05 to 0.35
w = bct.brush.time.spectral(B.Manifold, B.Time, params);
%%
% Example 3: Explicit source array
params.source = [100, 120, 150];  % One per time step
params.kernel = 'heat';
params.tau = linspace(0.05, 0.3, T);
w = bct.brush.time.spectral(B.Manifold, B.Time, params);
%%
% Example: Moving source along path with heat kernel
[path, ~] = B.Manifold.Graph.shortestPath(100, 500);
params.source = @(t, T) path(min(max(1, round(t/T * length(path))), length(path)));
params.kernel = 'heat';
params.tau = 10;  % Heat diffusion parameter (instead of sigma)
w = bct.brush.time.spectral(B.Manifold, B.Time, params);

%%
% Setup: Create path between vertices
[path, ~] = B.Manifold.Graph.shortestPath(100, 500);

% Arrive at target after 40% of time duration, then stay
arrival_frac = 0.4;  % Reach target at 40% of time

params.source = @(t, T) path(min(round((t/T)/arrival_frac * length(path)), length(path)));
params.kernel = 'gaussian';
params.sigma = 15;  % Gaussian bandwidth parameter
params.bandwidth = 50;  % Limit to first 50 eigenmodes

w = bct.brush.time.spectral(B.Manifold, B.Time, params);
%%
fprintf('Generating spectral heat brush signal (tau=0.2)...\n');

sig = bct.Signal.fromBrush(B.Manifold, 'Category', 'patch', ...
    'Type', 'spectral', 'Source', 1000, 'Kernel', 'heat', 'Tau', 0.2);

%% Visualize spatial pattern
figure('Name', 'Spatial Pattern');
B.Manifold.plot('data', sig.Data, 'shading', 'interp');
colormap(jet); colorbar;
title('Heat Brush Signal (tau=0.2, source=1000)');
axis equal tight off; view([0 90]);

%% Plot eigenspectrum
fprintf('Computing and plotting eigenspectrum...\n');

% Basic power spectrum
bct.show.eigenspectrum(sig);

% Index spectrum with log scale (clearer view)
bct.show.eigenspectrum(sig, 'Type', 'index', 'Scale', 'log');

% Normalized energy with 90% threshold
bct.show.eigenspectrum(sig, 'Type', 'normalized', ...
    'ShowThreshold', true, 'ThresholdValue', 90);

% Show top 4 modes
bct.show.eigenspectrum(sig, 'TopModes', 4);

fprintf('\nDone! Generated spectral heat brush and visualized its eigenspectrum.\n');
%%
% Transform to joint spectral domain
sig_spectral = bct.operator.transform.joint(sig_st);

% Visualize (default: Hz frequency, power)
bct.show.jointspectrum(sig_spectral);

% Custom visualization
bct.show.jointspectrum(sig_spectral, ...
    'PlotType', 'logpower', ...
    'FrequencyUnits', 'Hz', ...
    'SpatialUnits', 'wavenumber', ...
    'FrequencyRange', [-20 20]);