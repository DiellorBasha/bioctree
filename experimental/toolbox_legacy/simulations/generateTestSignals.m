function S = generateTestSignals(N, varargin)
%GENERATE_TEST_SIGNALS  Make common test signals by specifying only N.
%
%   S = GENERATE_TEST_SIGNALS(N) returns a struct S with fields:
%     .N, .T, .fs, .t                         % metadata
%     .sin, .multitone, .chirp_lin            % sinusoids & chirp
%     .square, .saw                           % square & sawtooth (toolbox-free)
%     .impulse, .step                         % unit impulse/step
%     .wgn, .colored                          % white & AR(1) colored noise
%     .gauss_win, .gauss_pulse                % Gaussian window & Gaussian-modulated pulse
%     .ricker, .morlet                        % Ricker/Mexican-hat & Morlet wavelets
%     .band_noise                             % band-limited noise (FFT-domain)
%     .params                                 % all derived parameters
%
%   Optional name-value pairs:
%     'Seed'        : RNG seed (default: 0). Set [] to skip seeding.
%     'NormalizeRMS': true|false normalize each signal to unit RMS (default: false)
%
%   Example:
%     S = generate_test_signals(2000,'NormalizeRMS',true);
%     plot(S.t, S.sin); title('Auto-scaled 1-second 1kHz-sampled sine (N=2000)');
%
%   Notes:
%   - Duration is fixed T=1 s so fs=N Hz. Frequencies are chosen as fractions
%     of Nyquist and clamped to [1/T, 0.45*Nyquist] to avoid aliasing.
%   - No toolboxes required (chirp/square/saw implemented manually).

% ---------- options ----------
p = inputParser;
addParameter(p,'Seed',0);
addParameter(p,'NormalizeRMS',false);
parse(p,varargin{:});
opt = p.Results;

% ---------- timeline & basics ----------
N = max(4, round(N)); % guard
T  = 1;               % seconds
fs = N/T;             % Hz
t  = (0:N-1)'/fs;     % column
Ny = fs/2;

if ~isempty(opt.Seed)
    rng(opt.Seed);
end

% helper to clamp frequency into safe band
clampf = @(f) min(max(f, 1/T), 0.45*Ny);

% ---------- derived frequencies (scaled to Nyquist) ----------
f0      = clampf(0.10*Ny);                 % base sine ~0.1*Ny
f_multi = clampf([0.05 0.12 0.30]*Ny);     % multitone trio
A_multi = [1 0.6 0.3];
phi     = pi/6;

f_chirp0 = clampf(0.02*Ny);                % chirp start
f_chirp1 = clampf(0.40*Ny);                % chirp end

f_wave1  = clampf(0.05*Ny);                % for square/saw & Ricker
f_wave2  = clampf(0.10*Ny);                % Morlet carrier
f_gaussC = clampf(0.15*Ny);                % Gaussian-modulated pulse carrier

% Gaussian widths (time)
mu   = 0.5*T;
sigma_t = 0.05*T;                           % 50 ms window
sigma_m = 6/(2*pi*max(f_wave2,eps));        % ~6 cycles under Morlet

% Band-limited noise band (theta-like fraction)
f_lo = clampf(0.08*Ny);
f_hi = clampf(0.16*Ny);
if f_hi <= f_lo, f_hi = clampf(f_lo*1.5); end

% ---------- signals ----------
% 1) Sinusoid & multitone
sin_sig = sin(2*pi*f0*t + phi);
multi   = A_multi(1)*sin(2*pi*f_multi(1)*t) + ...
          A_multi(2)*sin(2*pi*f_multi(2)*t) + ...
          A_multi(3)*sin(2*pi*f_multi(3)*t);

% 2) Linear chirp (manual phase: phi(t)=2π(f0 t + 0.5 k t^2))
k       = (f_chirp1 - f_chirp0) / T;
chirp_l = sin(2*pi*(f_chirp0*t + 0.5*k*t.^2));

% 3) Square & sawtooth (toolbox-free)
square_sig = sign(sin(2*pi*f_wave1*t));
% saw: map phase to [-1,1): 2*(frac(phase)-0.5)
phase  = f_wave1*t; saw = 2*(phase - floor(phase + 0.5));

% 4) Impulse & step
impulse = zeros(N,1); impulse(max(1,round(0.25*T*fs))) = 1;
step    = double(t >= 0.5*T);

% 5) Noise: white & colored (AR(1))
sigma = 0.2;
wgn   = sigma*randn(N,1);
a     = 0.95; % AR(1) pole (closer to 1 = redder)
colored = filter(1, [1 -a], randn(N,1));

% 6) Gaussian window & Gaussian-modulated pulse
tau        = t - mu;
gauss_win  = exp(-0.5*(tau./sigma_t).^2);
gauss_pulse= gauss_win .* cos(2*pi*f_gaussC*tau);

% 7) Ricker (Mexican hat) wavelet
pi2f2t2 = (pi*f_wave1*tau).^2;
ricker  = (1 - 2*pi2f2t2).*exp(-pi2f2t2);

% 8) Morlet (Gabor) wavelet (real part)
morlet  = real( exp(1i*2*pi*f_wave2*tau) .* exp(-(tau.^2)/(2*sigma_m^2)) );

% 9) Band-limited noise via FFT masking
xw   = randn(N,1);
X    = fft(xw);
% build symmetric passband mask
freqs = (0:N-1)'*(fs/N);                    % 0..fs-step..fs-step
freqs(freqs>Ny) = fs - freqs(freqs>Ny);     % fold (mirror) to [0,Ny]
mask  = double(freqs>=f_lo & freqs<=f_hi);
X_bp  = X .* mask;
band_noise = real(ifft(X_bp));
% optional spectral whitening inside band (normalize RMS)
if any(mask)
    rms_in = sqrt(mean(abs(band_noise).^2));
    if rms_in > 0, band_noise = band_noise / rms_in; end
end

% ---------- normalization (optional) ----------
if opt.NormalizeRMS
    normrms = @(x) x./max(eps, sqrt(mean(x.^2)));
    sin_sig     = normrms(sin_sig);
    multi       = normrms(multi);
    chirp_l     = normrms(chirp_l);
    square_sig  = normrms(square_sig);
    saw         = normrms(saw);
    impulse     = normrms(impulse);
    step        = normrms(step);
    wgn         = normrms(wgn);
    colored     = normrms(colored);
    gauss_win   = normrms(gauss_win);
    gauss_pulse = normrms(gauss_pulse);
    ricker      = normrms(ricker);
    morlet      = normrms(morlet);
    band_noise  = normrms(band_noise);
end

% ---------- pack struct ----------
S = struct();
S.N   = N; S.T = T; S.fs = fs; S.t = t;

S.sin        = sin_sig;
S.multitone  = multi;
S.chirp_lin  = chirp_l;

S.square     = square_sig;
S.saw        = saw;

S.impulse    = impulse;
S.step       = step;

S.wgn        = wgn;
S.colored    = colored;

S.gauss_win  = gauss_win;
S.gauss_pulse= gauss_pulse;

S.ricker     = ricker;
S.morlet     = morlet;

S.band_noise = band_noise;

S.params = struct( ...
    'Nyquist', Ny, ...
    'f0', f0, ...
    'f_multi', f_multi, ...
    'phi', phi, ...
    'f_chirp0', f_chirp0, 'f_chirp1', f_chirp1, ...
    'f_wave1', f_wave1, 'f_wave2', f_wave2, ...
    'f_gaussC', f_gaussC, 'mu', mu, 'sigma_t', sigma_t, ...
    'sigma_m', sigma_m, ...
    'band_lo', f_lo, 'band_hi', f_hi, ...
    'AR1_a', a ...
);

end
