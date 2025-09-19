%% compare_sphere_joint_spectra.m
% Spatiotemporal joint spectrum on a sphere:
%   (A) Classical spherical harmonics (ground truth)
%   (B) Graph-based (GSP) JFT using cotangent Laplacian eigenmodes
%
% Diellor Basha — Network oscillations project

clear; clc;

%% -------------------- Parameters --------------------
Lmax    = 40;                   % spherical-harmonic bandlimit (→ (Lmax+1)^2 modes)
Fs      = 200;                  % Hz
T       = 800;                  % time samples (NFFT = T)
waves   = [];                   % (set below)
lapType = "cotangent";          % for build_icosphere
rng(7);

%% -------------------- Build sphere + wave --------------------
G = build_icosphere(4, 1, 'laplacianType', lapType);   % ~5k vertices
assert(isfield(G,'V') && size(G.V,2)==3, 'G.V (Nx3) required');

% Wave 1 is propagating 16 cycles/m at 5 Hz with global spread
% Wave 2 is propagating at 64 cycles/m at 20 Hz with local spread
% === Your wave recipe ===
tmpl = struct('fHz',[],'cycles',[],'normal',[],'t0',[],'dur',[], ...
              'tukeyAlpha',[],'A',[],'phi0',0, ...
              'beltSigmaDeg',[],'spotCenter',[],'spotSigmaDeg',[]);
waves = repmat(tmpl,1,2);
waves(1) = struct('fHz',5,'cycles',16,'normal',[0;0;1], ...
    't0',0.5,'dur',2,'tukeyAlpha',0.5,'A',15, 'phi0',0, ...
    'beltSigmaDeg',30, ...            % was 18 → tighter ribbon (≈ 0.35·λ for λ≈22.5°)
    'spotCenter',[0.1;0.1;0.1], ...        % pick a point on the great circle (any unit xyz)
    'spotSigmaDeg',60);              % keep a modest cap (≈ 0.5·λ)

waves(2) = struct('fHz',20,'cycles',64,'normal',[0.3;0.7;0.64], ...
                  't0',2.5,'dur',1,'tukeyAlpha',0.5,'A',10, ...
                  'phi0',pi/4,'beltSigmaDeg',45,'spotCenter',[2;0;0], ...
                  'spotSigmaDeg',20);

[X,t,meta] = generateSphereWave(G.V, T, Fs, waves);    % X: (N x T)

N = size(G.V,1);
assert(size(X,1)==N && size(X,2)==T, 'X must be N x T');

% select parameters
framerate = 24;
spinAz =3; spinEl = 0;

% choose trace indices (e.g. evenly sample 512 vertices)
numTraces = size(X,1);
traceIdx = round(linspace(1, size(G.V,1), numTraces));

% optional display settings for imagesc
colorLimits = 1.05*[-max(abs(X(:))) max(abs(X(:)))]; % symmetric CL
cmap = 'bone';

% call exporter with imagesc on the right (sphere left, imagesc right)
exportIcosphereVideo(G.V, G.F, X, t, 'icosphere_waves.mp4', framerate, ...
    'Save', 0, ...
    'Title', '', ...
    'View', [30 -15], ...
    'SpinAzimuthDegPerSec', spinAz, ...
    'SpinElevationDegPerSec', spinEl, ...
    'Lighting', 'flat', ...
    'ShowColorbar', true, ...
    'Colormap', cmap, ...
    'ColorLimits', colorLimits, ...
    'EdgeColor', 'none', ...
    'EdgeAlpha', 0.25, ...
    'ShowTraces', true, ...
    'NumTraces', numTraces, ...
    'TraceIndices', traceIdx, ...
    'SpaceTimeMode', 'image', ...
    'FigurePosition', [1.6377e+03 627 911.3333 723.3333]);
%% -------------------- (A) Classical spherical joint spectrum --------------------
fprintf('[A] Classical spherical analysis (Lmax = %d)\n', Lmax);


% Ground-truth joint spectrum on the sphere (no GSP)
S = fft_icospheretime(G, X, Fs, 'Lmax', 40, 'NFFT', T, 'Detrend', true);

% Build a 2D spectrum from S (degree × frequency)
K1 = floor(S.params.NFFT/2)+1;               % one-sided
Fk = S.Pell_f(:,1:K1);                       % magnitude-like already
ax_cell = { sqrt((0:S.params.Lmax)'.*(1+(0:S.params.Lmax)')) / G.R * (2*pi), ... % rad/m (k = 2π*cycles/m)
            S.f(1:K1) };                     % Hz
info = struct('spacings', [NaN, 1/Fs]);      % only time spacing needed here
figure(2)
clf
plot_spacetime_spectrum(Fk, ax_cell, info, ...
    'Units','frequency', 'SpatialDims',1, 'InputKind','magnitude', ...
    'TimePosOnly',true, 'LogMag',true, 'Colormap','bone', ...
    'Title','Sphere joint spectrum (degree-collapsed)');
%% 
% Build your sphere & wave
 Gg = gsp_from_icosphere(G);
 param.NFFT=S.params.NFFT;
Gg=gsp_jtv_graph(Gg, T, Fs, param);
%% 

param.spin_azimuth_deg_per_sec = 15;   % Spin 15 deg/sec around Z
param.spin_elevation_deg_per_sec = 5;  % Spin 5 deg/sec in elevation
param.framerate = 24;                  % 24 frames per second
% Run the animated plot
gsp_plot_jtv_signal_spin(Gg, X, param);
gsp_plot_jtv_signal(Gg,X, param)
gsp_plot_jtv_signal_spin(Gg,X,)
%%
% Graph/GSP (this function)
Sg = fft_vertextime(G, X, Fs, 'NFFT', T, 'Detrend', true, ...
                       'MapToDegree', true, 'LmaxTarget', 40);
infog = struct('spacings', [NaN, 1/Fs]);
%% 

% If your Laplacian is the cotangent FEM LB (good!), you can put the
%spatial wavenumber on the y-axis by mapping λ to k

K1g = floor(Sg.params.NFFT/2)+1;
Fkg = Sg.Plam_f(:, 1:K1);

% Guard: mapper may be missing/NaN when MapToDegree=false
ab = struct('alpha', NaN, 'b', NaN);
if isfield(Sg,'params') && isfield(Sg.params,'mapper')
    ab = Sg.params.mapper;
end

if isnan(ab.alpha)
    % Quick on-the-fly fit λ ≈ α ℓ(ℓ+1) + b for labeling (no binning)
    LmaxLab = 40;                           % or Sg.params.LmaxTarget if present
    LLB     = (0:LmaxLab)'.*((0:LmaxLab)'+1);
    Mfit    = min(numel(Sg.lam), numel(LLB));
    Afit    = [LLB(1:Mfit), ones(Mfit,1)];
    yfit    = Sg.lam(1:Mfit);

    coeff   = Afit \ yfit;                  % [alpha; b]
    ab.alpha = max(coeff(1), eps);
    ab.b     = coeff(2);
end

% Now you can compute k(λ)
k_est = (2*pi/Sg.params.R) * sqrt(max((Sg.lam - ab.b)/ab.alpha, 0));


k_est = (2*pi/Sg.params.R) * sqrt(max((Sg.lam - ab.b)/max(ab.alpha,eps), 0));
ax_cellg = { k_est, Sg.f(1:K1) };   % y-axis in rad/m
figure(3)

plot_spacetime_spectrum(Fkg, ax_cellg, infog, ...
  'Units','frequency','SpatialDims',1,'InputKind','magnitude', ...
  'TimePosOnly',true,'LogMag',true,'Colormap','bone', ...
  'Title','Graph joint spectrum (k(λ) × f)');
