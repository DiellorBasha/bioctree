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
[X,x,t] = generateLineNoiseToWave(256, 400, 10, 16, 0.02, 0, ...
    'RampFrac',0.6, 'RampShape','cosine', 'NoiseAR',0.98, ...
    'SpatialSigma',2.5, 'Seed', 7, ...
    'XSpan', [-128 128], 'TSpan', [0 1], ...
    'RampType','two-sided', 'HoldFrac',0.250, ...
     'MaskType','Gaussian', 'MaskWidth', 100);
% Generate a morphing signal and animate it
[X1,x1,t1] = generateLineNoiseToWave(256, 400, 20, 4, 0.02, 64, ...
    'RampFrac',0.6, 'RampShape','cosine', 'NoiseAR',0.98, ...
    'SpatialSigma',2.5, 'Seed', 7, ...
    'XSpan', [-128 128], 'TSpan', [1 2], ...
    'RampType','two-sided', 'HoldFrac',0.05, ...
     'MaskType','Gaussian', 'MaskWidth', 8);
% choose an overlap (e.g., 0.15 s)
overlapSec = 0.01;
[Y, ty] = crossfadeXT(X, t, X1, t1, overlapSec);

X=Y; t=ty;
exportLineWaveVideo(X, x, t, 'noise_to_wave.mp4', 24, ...
    'Title','Noise → Traveling wave', 'Colormap','bone', ...
    'AmplitudeLimits',[-1.2 1.2], 'ColorLimits',[-1.2 1.2], 'Save', 0);
%% 

% Left = colormap rectangle, Right = wiggle lines
exportLineWaveVideo(X, x, t, 'demo_rect_wiggles.mp4', 24, 'Save',0, ...
    'LeftMode','colormap', 'LeftRectWidth' , 5, 'Colormap','bone',  'SpaceTimeMode','lines', ...
    'NumLines',size(X,1),'TraceLineWidth',0.5, ...
    'TraceColor',[0.1 0.1 0.1], 'WiggleScale', 1.5);

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

%% 

%% 0) You already built Y, x, ty
% Y: [Nx x T] = crossfaded line-time array
% x: [Nx x 1]
% ty: [1 x T]

%% 1) Run multiscale (undecimated) wavelet analysis
% You already built Y, x, ty
OUT = waveletDetectLineTime(Y, x, ty, ...
    'Wavelet','db2', ...
    'Levels', 5, ...        % 256x800 -> cap is 5; safe
    'Boundary','per', ...
    'MakePlots', true, ...
    'EnergyFn','L2', ...
    'ThreshK', 3.0);
          % robust mask threshold (↑ for stricter, ↓ for more detections)

%% 2) Print a per-level summary (wavelength/period/speed + energy share)
j = 1:OUT.params.J;
EHH = OUT.E_D(:);                          % joint (HH) energy per level
share = 100 * EHH / max(eps, sum(EHH));    % % of total HH energy
Tsec = OUT.period_est(:);
Llam = OUT.lambda_est(:);
Vest = OUT.speed_est(:);

fprintf('\nLevel   Period(s)   Wavelength(x-units)   ~Speed(units/s)   HH Energy(%%)\n');
for k = 1:numel(j)
    fprintf('  %2d    %8.4f        %9.3f               %9.3f          %6.2f\n', ...
        j(k), Tsec(k), Llam(k), Vest(k), share(k));
end

% Dominant traveling-wave scale (by HH energy)
[~, jstar] = max(EHH);
fprintf('\nDominant joint scale: j=%d  (Period≈%.4fs, Wavelength≈%.3f, Speed≈%.3f)\n', ...
    jstar, Tsec(jstar), Llam(jstar), Vest(jstar));

%% 3) Visualize detection mask on top of the data (quick look)
figure('Color','w','Name','Wave detection overlay');
ax = axes; imagesc(ax, ty, x, Y); axis(ax,'xy'); colormap(ax,'turbo'); colorbar;
hold(ax,'on');
M = OUT.mask_joint;                      % Nx x T logical
% simple overlay: draw mask contours
contour(ax, ty, x, M, [0.5 0.5], 'k', 'LineWidth', 1.0);
xlabel('Time'); ylabel('x'); title('Data with joint (HH) detection mask');

%% 4) (Optional) Extract “wave-only” component using the mask
% Zero-out everything outside the detected joint-activity pixels:
Y_wave_only = Y .* double(M);
figure('Color','w'); 
subplot(1,2,1); imagesc(ty, x, Y);      axis xy; title('Original');  xlabel('Time'); ylabel('x'); colorbar;
subplot(1,2,2); imagesc(ty, x, Y_wave_only); axis xy; title('Wave-only (masked)'); xlabel('Time'); colorbar;

%% 5) (Optional) Try a different wavelet / threshold to see stability
% You already built Y, x, ty
OUT2= waveletDetectLineTime(Y, x, ty, ...
    'Wavelet','mexh', ...
    'Levels', 5, ...        % 256x800 -> cap is 5; safe
    'Boundary','per', ...
    'MakePlots', true, ...
    'EnergyFn','L2', ...
    'ThreshK', 3.0);
          % robust mask threshold (↑ for stricter, ↓ for more detections)
