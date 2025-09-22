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
%% 

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

% One-sided temporal frequencies
K1 = floor(S.params.NFFT/2)+1;
Fk = S.Pell_f(:, 1:K1);                 % (ell x freq) power

% y-axis in cycles/m (R = 1 m)
nu_ell = sqrt((0:S.params.Lmax)'.*(1+(0:S.params.Lmax)')) / (2*pi*1);  % cycles/m

ax_cell = { nu_ell, S.f(1:K1) };
info = struct('spacings', [NaN, 1/Fs]);


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
%gsp_plot_jtv_signal_spin(Gg, X, param);
clear param
daz=15; del=0
param.cp=[1 -25 1]
figure(3)
gsp_plot_jtv_signal(Gg,X(:,200:300))
ax=gca
view(45,-20)
camorbit(ax, daz, del, 'data');

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
%
%%
% Graph/GSP (this function)
Sg = fft_vertextime(G, X, Fs, 'NFFT', T, 'Detrend', true, ...
                       'MapToDegree', false, 'LmaxTarget', 40);
infog = struct('spacings', [NaN, 1/Fs]);

K1g = floor(Sg.params.NFFT/2)+1;
Fkg = Sg.Plam_f(:, 1:K1g);              % (modes x freq) power

% Ensure we have a mapper; fit if missing
ab = struct('alpha', NaN, 'b', NaN);
if isfield(Sg,'params') && isfield(Sg.params,'mapper')
    ab = Sg.params.mapper;
end
if isnan(ab.alpha)
    LmaxLab = 40;
    LLB  = (0:LmaxLab)'.*((0:LmaxLab)'+1);
    Mfit = min(numel(Sg.lam), numel(LLB));
    Afit = [LLB(1:Mfit), ones(Mfit,1)];
    yfit = Sg.lam(1:Mfit);
    coeff   = Afit \ yfit;              % [alpha; b]
    ab.alpha = max(coeff(1), eps);
    ab.b     = coeff(2);
end

% cycles/m from eigenvalues (R = 1 m)
nu_est = sqrt(max((Sg.lam - ab.b)/max(ab.alpha,eps), 0)) / (2*pi*1);   % cycles/m

ax_cellg = { nu_est, Sg.f(1:K1g) };
infog = struct('spacings', [NaN, 1/Fs]);
figure(3)
plot_spacetime_spectrum(Fkg, ax_cellg, infog, ...
  'Units','frequency','SpatialDims',1,'InputKind','magnitude', ...
  'TimePosOnly',true,'LogMag',true,'Colormap','bone', ...
  'Title','Graph joint spectrum (cycles/m × Hz, native λ)');
%% 
% Convert sphere & graph spatial axes to cycles/m and compare
% Requires: G, S, Sg in workspace

% 1) get mesh radius R
if isfield(S.params,'R') && ~isempty(S.params.R)
    R = S.params.R;
elseif exist('G','var') && isfield(G,'R') && ~isempty(G.R)
    R = G.R;
elseif exist('G','var') && isfield(G,'V')
    R = mean(sqrt(sum(G.V.^2,2)));
else
    error('Provide mesh G with G.V or S.params.R');
end

% 2) sphere axis (use Pell_f rows -> ell = 0:Lmax)
Lmax = size(S.Pell_f,1)-1;
ell = (0:Lmax).';
cycles_sphere = (1./(2*pi*R)) .* sqrt( ell .* (ell + 1) );   % cycles/m
% sphere power collapsed across freq (or choose freq index)
psphere = mean(S.Pell_f, 2);    % size Lmax+1 x 1

% 3) graph eigenvalues
lam_graph = Sg.lam(:);
lam_graph = sort(lam_graph);    % ascending

% 4) fit lam_graph(1:K) ≈ alpha * mu(1:K) + b  using K = Lmax+1 (or smaller)
K = min(numel(lam_graph), numel(ell));
mu = (ell .* (ell + 1)) / (R^2);   % continuum eigenvalues for ℓ
X = [mu(1:K), ones(K,1)];
y = lam_graph(1:K);
beta = X \ y;
alpha = beta(1); b = beta(2);
fprintf('fit: lam_graph ≈ alpha*mu + b  (alpha=%.6g, b=%.6g)\n', alpha, b);

% 5) convert all lam_graph -> mu_est -> cycles_graph
mu_est = max((lam_graph - b) ./ max(alpha, eps), 0);
k_est = sqrt(mu_est);                  % rad/m
cycles_graph = k_est / (2*pi);        % cycles/m

% 6) graph power collapsed across freq
pgraph = mean(Sg.Plam_f, 2);   % size num_eigs x 1

% 7) plot comparison (normalize for display)
figure;
subplot(2,1,1);
plot(cycles_sphere, psphere./max(psphere), 'k.-','DisplayName','sphere (P_{ell})'); hold on;
% map graph modes that correspond to ell indices (first K) using fitted mapping
% scatter the first K mapped points
plot(cycles_graph(1:K), pgraph(1:K)./max(pgraph), 'bo','DisplayName','graph modes (first K)');
xlabel('spatial cycles / m'); ylabel('normalized power'); legend; title('Collapsed spatial power');

subplot(2,1,2);
% show raw spectra as images at specific freq index (choose fi or avg)
fi = round(size(S.Pell_f,2)/4);   % example freq slice
imagesc(S.f, cycles_sphere, S.Pell_f); axis xy; colormap parula;
xlabel('freq (Hz)'); ylabel('spatial cycles / m'); title('Spherical harmonic Pell\_f');
colorbar;

figure;
imagesc(Sg.f, cycles_graph, Sg.Plam_f); axis xy; colormap parula;
xlabel('freq (Hz)'); ylabel('spatial cycles / m'); title('Graph Plam\_f (mapped)');
colorbar;

% Quick diagnostics
fprintf('cycles_sphere range: [%.4g .. %.4g] cycles/m\n', min(cycles_sphere), max(cycles_sphere));
fprintf('cycles_graph range: [%.4g .. %.4g] cycles/m\n', min(cycles_graph), max(cycles_graph));