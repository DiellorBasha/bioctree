function [X, x, t, comp] = generateLineNoiseToWave(Nx, T, f, lambda, alpha, x0, varargin)
% generateLineNoiseToWave
% Create a line signal X(x,t) that evolves from random dynamics to a traveling wave.
%
% X(:,ti) = (1 - s(ti)) * Noise(:,ti) + s(ti) * Wave(:,ti)
% where s(t) ramps smoothly from 0 -> 1.
%
% Inputs
%   Nx, T     : # spatial samples, # time samples
%   f         : wave frequency (Hz, defines temporal oscillation)
%   lambda    : spatial wavelength (same spatial units as x)
%   alpha     : spatial decay from x0 (optional aesthetic)
%   x0        : ripple center (scalar)
%
% Name-Value options
%   'XSpan'        : [xmin xmax] spatial range (default [-64 64])
%   'TSpan'        : [t0 t1] time span (default [0 1])
%   'RampFrac'     : fraction of T used to ramp (0..1), default 0.5
%   'RampShape'    : 'cosine'|'smoothstep'|'logistic' (default 'cosine')
%   'NoiseSigma'   : base noise std (default 1.0)
%   'NoiseAR'      : AR(1) temporal correlation rho in [0 1) (default 0.95)
%   'SpatialSigma' : Gaussian spatial std (in samples) for noise smoothing (default 1.5)
%   'NormalizeEnergy' : true/false (match noise energy to wave), default true
%   'Seed'         : RNG seed (default [])
%
% Outputs
%   X   : [Nx x T] morphing signal
%   x   : [Nx x 1] spatial grid
%   t   : [1 x T]  time grid
%   comp: struct with fields .wave, .noise, .ramp (s), .kernel (if used)
%
% Example
%   [X,x,t] = generateLineNoiseToWave(256, 400, 3, 16, 0.02, 0, ...
%                  'RampFrac',0.6,'NoiseAR',0.98,'SpatialSigma',2.5,'Seed',42);
%   exportLineWaveVideo(X, x, t, 'noise_to_wave.mp4', 24, 'Title','Noise → Wave');

    % ---- parse options ----
    p = inputParser;
    addParameter(p,'XSpan',[-64 64]);
    addParameter(p,'TSpan',[0 1]);
    addParameter(p,'RampFrac',0.5);
    addParameter(p,'RampShape','cosine');
    addParameter(p,'NoiseSigma',1.0);
    addParameter(p,'NoiseAR',0.95);
    addParameter(p,'SpatialSigma',1.5);
    addParameter(p,'NormalizeEnergy',true);
    addParameter(p,'Seed',[]);
    addParameter(p,'RampType','one-sided');   % 'one-sided' | 'two-sided'
addParameter(p,'HoldFrac',0);             % 0..1, only used when RampType='two-sided'
addParameter(p,'MaskType','none');   % 'none' | 'gaussian' | 'tophat' | 'tukey' | 'custom'
addParameter(p,'MaskWidth',10);      % width in *x units*: sigma (gaussian), radius (tophat/tukey)
addParameter(p,'MaskBeta',0.5);      % softness for 'tukey' (0..1)
addParameter(p,'WaveMask',[]);       % custom Nx-by-1 mask (0..1); overrides MaskType if provided

    parse(p,varargin{:});
    opt = p.Results;

    if ~isempty(opt.Seed), rng(opt.Seed); end

    % ---- grids ----
    x = linspace(opt.XSpan(1), opt.XSpan(2), Nx).';
    t = linspace(opt.TSpan(1), opt.TSpan(2), T);

    % ---- traveling wave (target) ----
    k = 2*pi/lambda;
    W = zeros(Nx, T);
    for ti = 1:T
        W(:,ti) = sin(2*pi*f*t(ti) - k*x) .* exp(-alpha*abs(x - x0));
    end

    % ---- temporally correlated noise (OU/AR(1)) ----
    sigma = opt.NoiseSigma;
    rho   = opt.NoiseAR;
    N = zeros(Nx,T);
    N(:,1) = sigma * randn(Nx,1);
    ar_scale = sigma * sqrt(1 - rho^2);
    for ti = 2:T
        N(:,ti) = rho * N(:,ti-1) + ar_scale * randn(Nx,1);
    end

    % ---- optional spatial smoothing of noise (Gaussian 1D) ----
    ker = [];
    if opt.SpatialSigma > 0
        rad = max(3, ceil(4*opt.SpatialSigma));             % kernel half-width
        xi  = (-rad:rad)';
        ker = exp(-0.5*(xi/opt.SpatialSigma).^2);
        ker = ker / sum(ker);
        for ti = 1:T
            N(:,ti) = conv(N(:,ti), ker, 'same');
        end
        % keep overall noise scale reasonable
        if std(N(:)) > 0
            N = N * (sigma / std(N(:)));
        end
    end

   % ---- smooth ramp s(t): 0->1 (one-sided) or 0->1->0 (two-sided) ----
rampType  = lower(p.Results.RampType);
holdFrac  = max(0,min(1,p.Results.HoldFrac));
rampLenOS = max(1, round(opt.RampFrac * T));  % one-sided total up-length

switch rampType
    case 'one-sided'
        s = ones(1,T);
        s(1:rampLenOS) = ramp_up(opt.RampShape, rampLenOS);
        s(rampLenOS+1:end) = 1;

    case 'two-sided'
        % total non-hold portion (up + down)
        nonHoldLen = max(2, round((1 - holdFrac) * T));
        riseLen    = floor(nonHoldLen/2);
        fallLen    = nonHoldLen - riseLen;
        holdLen    = T - (riseLen + fallLen);
        % build s: [ 0->1 (rise) | 1 (hold) | 1->0 (fall) ]
        s = zeros(1,T);
        s(1:riseLen) = ramp_up(opt.RampShape, riseLen);
        s(riseLen+1:riseLen+holdLen) = 1;
        s(riseLen+holdLen+1:end) = fliplr(ramp_up(opt.RampShape, fallLen));
    otherwise
        error('RampType must be ''one-sided'' or ''two-sided''.');
end


    % ---- energy normalization (optional) ----
    if opt.NormalizeEnergy
        sw = std(W(:)); sn = std(N(:));
        if sn > 0 && sw > 0
            N = N * (sw / sn);
        end
    end
% ---- spatial mask M(x) in [0,1] for localization near x0 ----
M = [];  % default: no mask
if ~isempty(p.Results.WaveMask)
    M = p.Results.WaveMask(:);
    assert(numel(M)==Nx, 'WaveMask must be Nx-by-1.');
else
    switch lower(p.Results.MaskType)
        case 'none'
            % leave M empty to preserve original global crossfade
        case 'gaussian'
            sigma = p.Results.MaskWidth;
            M = exp(-0.5*((x - x0)/sigma).^2);
        case 'tophat'
            R = p.Results.MaskWidth;
            M = double(abs(x - x0) <= R);
        case 'tukey'
            R = p.Results.MaskWidth;    % outer radius where mask falls to 0
            beta = max(0,min(1,p.Results.MaskBeta));
            r = abs(x - x0);
            M = zeros(Nx,1);
            R0 = (1 - beta)*R;          % flat-top half-width
            core = (r <= R0);
            trans = (r > R0) & (r <= R);
            M(core) = 1;
            % raised-cosine taper to 0 over [R0, R]
            M(trans) = 0.5*(1 + cos(pi*(r(trans)-R0)/(beta*R)));
        otherwise
            error('MaskType must be ''none'',''gaussian'',''tophat'',''tukey'', or use WaveMask.');
    end
end
if ~isempty(M)
    % safety clamp (numerics)
    M = max(0,min(1,M));
end

    % ---- crossfade: Noise -> Wave ----
if isempty(M)
    % original global crossfade (no localization)
    X = (1 - s) .* N + s .* W;
else
    % localized crossfade: only positions with M>0 move toward the wave
    % Equivalent form: X = (1 - s.*M).*N + (s.*M).*W;
    X = N + (M * s) .* (W - N);   % implicit expansion: (Nx×1)*(1×T)
end

    % ---- outputs ----
    comp.wave   = W;
    comp.noise  = N;
    comp.ramp   = s;
    comp.kernel = ker;
end
function r = ramp_up(shape, n)
% 0 -> 1 smooth ramp of length n (n>=1)
    if n<=1, r = 1; return; end
    switch lower(shape)
        case 'cosine'     % half-cosine
            u = linspace(0,1,n);
            r = 0.5*(1 - cos(pi*u));
        case 'smoothstep' % 3u^2 - 2u^3
            u = linspace(0,1,n);
            r = u.^2 .* (3 - 2*u);
        case 'logistic'   % normalized logistic
            u = linspace(-6,6,n);
            r = 1 ./ (1 + exp(-u));
            r = (r - r(1)) / (r(end) - r(1) + eps);
        otherwise
            error('Unknown RampShape "%s".', shape);
    end
end
