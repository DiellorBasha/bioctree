G = gsp_2dgrid(16);
param.show_edges = 1;
gsp_plot_graph(G,param);
%% 

[TR, V, F, Nx, Ny, vert2grid_lin, grid2vert, xvals, yvals] = surfaceMeshFromGridGraph(G)
%% 

[X, x, t] = generateRippleLine(256, 300, 3, 16, 0.02, 0);

rng("default")
randNoise= randn(size(X,1), size(X,2),1);
X = [randNoise X];
t = linspace(0, 1, size(X,2));
exportLineWaveVideo(X, x, t, 'figures/line_wave.mp4', 24, 'Title','1D traveling wave', 'Save', 0);


%% 
% Generate a morphing signal and animate it
[X,x,t] = generateLineNoiseToWave(256, 400, 30, 16, 0.02, 0, ...
    'RampFrac',0.6, 'RampShape','cosine', 'NoiseAR',0.98, ...
    'SpatialSigma',2.5, 'Seed', 7);


%% 

exportLineWaveVideo(X, x, t, 'noise_to_wave.mp4', 24, ...
    'Title','Noise → Traveling wave', 'Colormap','bone', ...
    'AmplitudeLimits',[-1.2 1.2], 'ColorLimits',[-1.2 1.2], 'Save', 0);
%% 
% Wiggle traces (lines)
exportLineWaveVideo(X, x, t, 'line_wave_wiggles.mp4', 24, 'Save',0, ...
    'SpaceTimeMode','lines', 'NumLines',size(X,1), 'TraceLineWidth',0.5, ...
    'TraceColor',[0.1 0.1 0.1], 'WiggleScale', 1.5);
%% 

% Left = colormap rectangle, Right = wiggle lines
exportLineWaveVideo(X, x, t, 'demo_rect_wiggles.mp4', 24, 'Save',0, ...
    'LeftMode','colormap', 'LeftRectWidth' , 5, 'Colormap','bone',  'SpaceTimeMode','lines', ...
    'NumLines',size(X,1),'TraceLineWidth',0.5, ...
    'TraceColor',[0.1 0.1 0.1], 'WiggleScale', 1.5);