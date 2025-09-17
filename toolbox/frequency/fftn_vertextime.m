% --- Inputs you already have:
% X : [256 x 796] line-time signal (rows = space, cols = time)
% x : [256 x 1] spatial coordinates (optional for plotting)
% t : [1 x 796]  time vector
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

N = size(X,1);
T = size(X,2);
%% 

% ===== 1) Build the spatial graph in GSPBox =====
% Choose boundary condition:
use_cycle = false;     % false = path/line graph; true = cycle/ring (periodic)

if use_cycle
    G = gsp_ring(N);                   % periodic ends (matches spatial FFT)
else
    G = gsp_path(N);                   % open ends (DCT-like spatial harmonics)
end
G = gsp_compute_fourier_basis(G);      % adds G.U (NxN), G.e (eigs)

% ===== 2) Define the Joint (time-vertex) transform operators =====
nfft = [2^nextpow2(size(X,1)), 2^nextpow2(size(X,2))];

G = gsp_jtv_graph(G,T,diff(t(1:2)));
G.jtv.NFFT=nfft(2);
param.show_edges=1
%gsp_plot_jtv_signal(G,X, param);
Xhat = gsp_jft(G,X);

    % Two-sided axes and centered spectrum
    k_idx = (-floor(nfft(1)/2):ceil(nfft(1)/2)-1);
    f_idx = (-floor(nfft(2)/2):ceil(nfft(2)/2)-1);

    k_rad = (2*pi) * (k_idx / (nfft(1)*dx));   % spatial angular frequency (rad/unit)
    f_hz  = f_idx / (nfft(2)*dt);              % temporal frequency (Hz)

    Xhat_shift = fftshift(Xhat,1);
    axes  = struct('k_rad', k_rad, 'f_hz', f_hz);
ax = struct2cell(axes)
%% 

% Classic frequency view: cycles/m vs Hz, with top temporal line
plot_spacetime_spectrum(Xhat, ax, info, ...
    Units="frequency", TimePosOnly=true, SpacePosOnly=false, ...
    TemporalAgg="power-mean", Title="Frequency view: cycles/m vs Hz", ...
    TopHeightFrac = 0.2);
