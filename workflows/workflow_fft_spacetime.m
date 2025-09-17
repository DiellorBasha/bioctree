%% ------------------------------------------------------------------------
%  0) Your data (already provided)
%     X: [Nx x T], x: spatial coords (meters), t: time (seconds)
% -------------------------------------------------------------------------
[X,x,t] = generateLineNoiseToWave(256, 400, 10, 16, 0.02, 0, ...
    'RampFrac',0.6, 'RampShape','cosine', 'NoiseAR',0.98, ...
    'SpatialSigma',2.5, 'Seed', 7, ...
    'XSpan', [-128 128], 'TSpan', [0 1], ...
    'RampType','two-sided', 'HoldFrac',0.250, ...
    'MaskType','Gaussian', 'MaskWidth', 100);

[X1,x1,t1] = generateLineNoiseToWave(256, 400, 20, 4, 0.02, 64, ...
    'RampFrac',0.6, 'RampShape','cosine', 'NoiseAR',0.98, ...
    'SpatialSigma',2.5, 'Seed', 7, ...
    'XSpan', [-128 128], 'TSpan', [1 2], ...
    'RampType','two-sided', 'HoldFrac',0.05, ...
    'MaskType','Gaussian', 'MaskWidth', 8);

overlapSec = 0.01;
[Y, ty] = crossfadeXT(X, t, X1, t1, overlapSec);

X = Y;    % line × time data
t = ty;

%% ------------------------------------------------------------------------
%  1) Spacings (meters & seconds)
% -------------------------------------------------------------------------
dx = mean(diff(x));   % meters per spatial sample
dt = mean(diff(t));   % seconds per time sample

%% ------------------------------------------------------------------------
%  2) FFT (time is columns → timeDim = 2). Keep time on x-axis.
%     Windowing helps leakage. Zero-pad for nicer grids (optional).
% -------------------------------------------------------------------------
nfft = [2^nextpow2(size(X,1)), 2^nextpow2(size(X,2))];

[Fk, ax, info] = fftn_spacetime( ...
    X, ...                % data (space × time)
    [dx, dt], ...         % spacings
    nfft, ...             % FFT lengths
    2, ...                % timeDim (columns)
    true, ...             % doWindow
    'hann', ...           % windowType
    true, ...             % doShift (center DC)
    true);                % alignTimeSecond (time stays as columns → x-axis)

%% ------------------------------------------------------------------------
%  3) Plot in different unit systems (time on x-axis)
%     - Frequency:     cycles/m vs Hz
%     - Angular:       rad/m (k) vs rad/s (ω)
%     - Physical:      wavelength (m) vs period (s)
%     (Set TimePosOnly=true to keep f≥0; SpacePosOnly to keep k≥0)
% -------------------------------------------------------------------------
% Assuming you've already computed:
% [Fk, ax, info] = fftn_spacetime(X, [dx, dt], nfft, 2, true, 'hann', true, true);

% Classic frequency view: cycles/m vs Hz, with top temporal line
plot_spacetime_spectrum(Fk, ax, info, ...
    Units="frequency", TimePosOnly=true, SpacePosOnly=false, ...
    TemporalAgg="power-mean", Title="Frequency view: cycles/m vs Hz", ...
    TopHeightFrac = 0.2);

% Angular view: k (rad/m) vs ω (rad/s), top temporal line in rad/s
plot_spacetime_spectrum(Fk, ax, info, ...
    Units="angular", TimePosOnly=true, SpacePosOnly=false, ...
    TemporalAgg="mag-mean", Title="Angular view: k vs \omega");

% Physical view: λ (m) vs T (s), great for reading phase velocity (λ/T)
plot_spacetime_spectrum(Fk, ax, info, ...
    Units="physical", TimePosOnly=true, SpacePosOnly=true, ...
    TemporalAgg="power-sum", Title="Physical view: \lambda vs T");


%% ------------------------------------------------------------------------
%  4) (Optional) Pull a line cut at a particular temporal frequency
% -------------------------------------------------------------------------
f_Hz = ax{2};
[~, i10] = min(abs(f_Hz - 10));   % ~10 Hz slice
kx_cyc = ax{1}/(2*pi);            % cycles/m
figure; plot(kx_cyc, abs(Fk(:, i10)));
grid on; xlabel('Spatial frequency (cycles/m)'); ylabel('|F(k_x, f=10 Hz)|');
title('Spatial spectrum at ~10 Hz');

%% ------------------------------------------------------------------------
%  5) (Optional) Peak velocity overlay in physical view
%     λ = v · T → straight lines in (T, λ). Example:
% -------------------------------------------------------------------------
% Reproduce the physical plot with velocity overlays
% Build the converted axes like the plotting helper does
k_rad_m = ax{1}; f_Hz = ax{2};
cyc_m   = k_rad_m/(2*pi);
pos_s   = cyc_m > 0; pos_t = f_Hz > 0;
lambda  = 1./cyc_m(pos_s);
T       = 1./f_Hz(pos_t);
M       = abs(Fk(pos_s, pos_t));

figure; imagesc(T, lambda, M);
set(gca,'YDir','normal'); colormap parula; colorbar;
xlabel('Period T (s)'); ylabel('Wavelength \lambda (m)');
title('|F(\lambda, T)| with iso-velocity overlays');

hold on;
v_list = [0.5, 1, 2, 5];  % m/s (pick values that make sense for your signals)
for v = v_list
    plot(T, v*T, 'k--', 'LineWidth', 0.75);
end
legend(arrayfun(@(v)sprintf('v=%.2f m/s',v), v_list, 'uni',0), 'Location','northwest');
