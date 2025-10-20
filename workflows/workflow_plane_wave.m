[Nx,Ny,T] = deal(256,256,400);
f = 12; lambda = 24;                    % Hz and spatial units
[Z,x2,y2,t,comp] = generateSurfaceNoiseToWave(Nx,Ny,T,f,lambda, ...
    'XSpan',[-128 128], 'YSpan',[-128 128], 'TSpan',[0 2], ...
    'WaveType','ripple', 'Theta', pi/4, 'Origin',[0 0], 'Alpha',0.0, ...
    'MaskType','gaussian', 'MaskWidth',[64 ], ...   % elongated lobe
    'RampType','two-sided', 'HoldFrac',0.25, 'RampFrac',0.5, ...
    'NoiseAR',0.98, 'SpatialSigma',2.5, 'Seed',7);
%% Show a few frames (imagesc with time cursor)

exportRippleVideo(Z, x2, y2, t, 'plane_wave.mp4', 24, 0);

%%

[Nx,Ny,T] = deal(256,256,400);
f = 12; lambda = 24;                    % Hz and spatial units
[Z,x2,y2,t,comp] = generateSurfaceNoiseToWave(Nx,Ny,T,f,lambda, ...
    'XSpan',[-128 128], 'YSpan',[-128 128], 'TSpan',[0 2], ...
    'WaveType','ripple', 'Theta', pi/4, 'Origin',[0 0], 'Alpha',0.0, ...
    'MaskType','gaussian', 'MaskWidth',[64 ], ...   % elongated lobe
    'RampType','two-sided', 'HoldFrac',0.25, 'RampFrac',0.5, ...
    'NoiseAR',0.98, 'SpatialSigma',2.5, 'Seed',7);

exportRippleVideo(Z, x2, y2, t, 'ripple_wave_on_paraboloid.mp4', 24, 0);
%%
cmap = parula(256);
s = sliceViewer(Z,"Colormap",cmap,"Parent",figure);

%% -------------------- Setup (you already have Z, x2, y2, t) --------------------
% Z : [Ny x Nx x T], x2,y2 : meshgrid coordinates, t : [1 x T]
Ny = size(Z,1); Nx = size(Z,2); T = size(Z,3);

% spacings (match dims: [y, x, t])
dy = mean(diff(y2(:,1)));                 % y spacing (units of your grid)
dx = mean(diff(x2(1,:)));                 % x spacing
dt = mean(diff(t));                       % seconds per sample

% Optional: remove static (time-mean) component to avoid huge DC from curvature
Z0 = Z - mean(Z, 3);                      % per-pixel demean over time

% FFT sizes (optional zero-padding to next power-of-two per dimension)
nfft = [2^nextpow2(Ny), 2^nextpow2(Nx), 2^nextpow2(T)];

%% -------------------- 3-D FFT (y × x × t) --------------------
% timeDim = 3 (Z's 3rd dimension is time)
% doWindow=true with 'hann' to reduce leakage
% doShift=true to center DC in every dimension
% alignTimeSecond=true => output is permuted so that the TIME-FREQ axis is dim #2
[Fk, ax, info] = fftn_spacetime( ...
    Z0, ...                % data: y × x × t
    [dy, dx, dt], ...      % spacings: [y, x, t]
    nfft, ...              % FFT lengths
    3, ...                 % timeDim = 3 (t is 3rd dim)
    true, ...              % doWindow
    'hann', ...            % windowType
    true, ...              % doShift (center DC)
    true);                 % alignTimeSecond (time-frequency becomes 2nd dim)

% After alignTimeSecond, the output dimensions are:
%   Fk : [Ny_fft  ×  T_fft  ×  Nx_fft]
%   ax{1} -> ky (rad/unit), ax{2} -> f (Hz), ax{3} -> kx (rad/unit)

P = abs(Fk).^2;           % power spectrum
P = abs(Fk);           % power spectrum

%% 

cmap = bone(256);
s = sliceViewer(P,"Colormap",cmap,"Parent",figure, ...
    'DisplayRange', [min(P(:)) max(P(:))], ...
    'DisplayRangeInteraction','on', ...
    'SliceDirection','Z');

%% -------------------- Useful slices --------------------
% 1) kx–f plane at ky ≈ 0
[~, iy0] = min(abs(ax{1}));               % ky index nearest 0
Pkx_f = squeeze(P(iy0, :, :));            % [T_fft × Nx_fft]
figure('Color','w'); imagesc(ax{2}, ax{3}, Pkx_f.'); axis xy tight
xlabel('f (Hz)'); ylabel('k_x (rad/unit)');
title('Power slice: k_x vs f @ k_y=0'); colorbar

% 2) ky–f plane at kx ≈ 0
[~, ix0] = min(abs(ax{3}));               % kx index nearest 0
Pky_f = squeeze(P(:, :, ix0));            % [Ny_fft × T_fft]
figure('Color','w'); imagesc(ax{2}, ax{1}, Pky_f.'); axis xy tight
xlabel('f (Hz)'); ylabel('k_y (rad/unit)');
title('Power slice: k_y vs f @ k_x=0'); colorbar

% 3) kx–ky plane at f ≈ 0 (spatial spectrum near DC in time)
[~, if0] = min(abs(ax{2}));               % temporal freq ~ 0 Hz
Pkxky = squeeze(P(:, if0, :));            % [Ny_fft × Nx_fft]
figure('Color','w'); imagesc(ax{3}, ax{1}, Pkxky); axis xy equal tight
xlabel('k_x (rad/unit)'); ylabel('k_y (rad/unit)');
title('Spatial power: k_x vs k_y @ f≈0'); colorbar

%% -------------------- Radial spatial average: P(|k|, f) --------------------
% Collapse (k_x,k_y) -> |k| to get a 2-D map of power vs spatial frequency magnitude & f
[KY, KX] = ndgrid(ax{1}, ax{3});          % grids for ky and kx
Kmag = sqrt(KX.^2 + KY.^2);               % |k| grid

% Choose radial bins
nbins = 80;
k_edges = linspace(0, max(Kmag(:)), nbins+1);
k_centers = 0.5*(k_edges(1:end-1) + k_edges(end:-1:2));  % (we'll recompute simply below)

% Compute radial mean for each temporal frequency bin
nf = numel(ax{2});
Pkf = zeros(nbins, nf);
for jf = 1:nf
    S = squeeze(P(:, jf, :));             % [Ny_fft × Nx_fft]
    [Pkf(:,jf), k_centers] = radial_mean(S, Kmag, nbins);
end

figure('Color','w');
imagesc(ax{2}, k_centers, Pkf); axis xy tight
xlabel('f (Hz)'); ylabel('|k| (rad/unit)');
title('Radially averaged power  P(|k|, f)'); colorbar

%% -------------------- Helper: radial mean --------------------
function [m, kcent] = radial_mean(S, Kmag, nb)
    % S, Kmag: [Ny × Nx]
    kmax = max(Kmag(:));
    edges = linspace(0, kmax, nb+1);
    kcent = 0.5*(edges(1:end-1) + edges(2:end));
    % bin indices for each pixel
    b = discretize(Kmag(:), edges);
    % accumulate sums & counts per bin
    valid = ~isnan(b);
    sums   = accumarray(b(valid), S(valid), [nb 1], @sum, 0);
    counts = accumarray(b(valid), 1,       [nb 1], @sum, 0);
    m = sums ./ max(1, counts);
end
