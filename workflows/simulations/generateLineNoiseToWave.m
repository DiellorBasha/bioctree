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

    % ---- smooth ramp s(t) : 0 -> 1 over RampFrac of T ----
    rampLen = max(1, round(opt.RampFrac * T));
    s = ones(1,T);
    switch lower(opt.RampShape)
        case 'cosine'
            % half-cosine: 0 -> 1
            r = 0:(rampLen-1);
            s(1:rampLen) = 0.5 * (1 - cos(pi * (r / max(1,rampLen-1))));
        case 'smoothstep'
            % 3x^2 - 2x^3 over [0,1]
            u = linspace(0,1,max(1,rampLen));
            s(1:rampLen) = u.^2 .* (3 - 2*u);
        case 'logistic'
            u = linspace(-6,6,max(1,rampLen));
            s(1:rampLen) = 1 ./ (1 + exp(-u));
            s(1:rampLen) = (s(1:rampLen) - s(1)) / (s(rampLen) - s(1) + eps); % normalize 0..1
        otherwise
            error('Unknown RampShape "%s".', opt.RampShape);
    end
    s(rampLen+1:end) = 1;

    % ---- energy normalization (optional) ----
    if opt.NormalizeEnergy
        sw = std(W(:)); sn = std(N(:));
        if sn > 0 && sw > 0
            N = N * (sw / sn);
        end
    end

    % ---- crossfade: Noise -> Wave ----
    X = (1 - s) .* N + s .* W;     % implicit expansion along rows

    % ---- outputs ----
    comp.wave   = W;
    comp.noise  = N;
    comp.ramp   = s;
    comp.kernel = ker;
end
