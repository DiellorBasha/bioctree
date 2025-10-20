function [Z, x2, y2, t, comp] = generateSurfaceNoiseToWave( ...
    Nx, Ny, T, f, lambda, varargin)
% generateSurfaceNoiseToWave
% Create a plane-time signal Z(y,x,t) that evolves from noise to a 2-D wave
% (and optionally back to noise), with localization masks and optional curvature.
%
% Z(:,:,t) = N(:,:,t) + s(t)*M(x,y) .* (W(:,:,t) - N(:,:,t))
%
% REQUIRED
%   Nx, Ny   : spatial samples (x,y)
%   T        : time samples
%   f        : wave temporal frequency (Hz)
%   lambda   : spatial wavelength (in x/y units)
%
% NAME-VALUE OPTIONS (selected)
%   'XSpan'        : [xmin xmax] (default [-64 64])
%   'YSpan'        : [ymin ymax] (default [-64 64])
%   'TSpan'        : [t0 t1] seconds (default [0 1])
%   'WaveType'     : 'plane' (default) | 'ripple'
%   'Theta'        : wave travel direction (radians; 0 = +x) [used for 'plane']
%   'Origin'       : [x0 y0] phase origin (default [0 0])
%   'Alpha'        : spatial decay (amplitude envelope exp(-alpha*radius)), default 0
%
%   RAMP (same semantics as your line generator)
%   'RampType'     : 'one-sided' (default) | 'two-sided'
%   'RampFrac'     : fraction of T used to ramp (0..1, default 0.5)
%   'HoldFrac'     : plateau fraction in two-sided mode (0..1, default 0)
%   'RampShape'    : 'cosine' (default) | 'smoothstep' | 'logistic'
%
%   NOISE
%   'NoiseSigma'   : base noise std (default 1.0)
%   'NoiseAR'      : temporal AR(1) rho in [0,1) (default 0.95)
%   'SpatialSigma' : Gaussian spatial smoothing std (in samples; default 1.5)
%   'NormalizeEnergy' : true/false (match noise & wave energy; default true)
%   'Seed'         : rng seed (default [])
%
%   LOCALIZATION MASK (2-D)
%   'MaskType'     : 'none' (default) | 'gaussian' | 'tophat' | 'tukey' | 'custom'
%   'MaskWidth'    : scalar or [sigx sigy] (gaussian sigma / tophat radius / tukey radius)
%   'MaskBeta'     : 0..1 tukey edge softness (default 0.5)
%   'WaveMask'     : custom Ny-by-Nx mask in [0,1], overrides MaskType
%
%   CURVATURE (optional base surface)
%   'Curved'          : true/false (default false)
%   'CurvatureType'   : 'paraboloid' | 'saddle' (default 'paraboloid')
%   'CurvatureStrength' : scalar (default 0.1)
%
% OUTPUTS
%   Z   : [Ny x Nx x T] array
%   x2,y2 : meshgrid coordinates (Ny x Nx)
%   t   : time vector (1 x T)
%   comp: struct with .wave, .noise, .ramp, .mask, .kernX, .kernY, .params

    % --------- parse options ----------
    p = inputParser;
    addParameter(p,'XSpan',[-64 64]);
    addParameter(p,'YSpan',[-64 64]);
    addParameter(p,'TSpan',[0 1]);
    addParameter(p,'WaveType','plane');     % 'plane' or 'ripple'
    addParameter(p,'Theta',0);              % radians; 0 = +x
    addParameter(p,'Origin',[0 0]);
    addParameter(p,'Alpha',0);

    addParameter(p,'RampType','one-sided'); % 'one-sided' | 'two-sided'
    addParameter(p,'RampFrac',0.5);
    addParameter(p,'HoldFrac',0);
    addParameter(p,'RampShape','cosine');

    addParameter(p,'NoiseSigma',1.0);
    addParameter(p,'NoiseAR',0.95);
    addParameter(p,'SpatialSigma',1.5);
    addParameter(p,'NormalizeEnergy',true);
    addParameter(p,'Seed',[]);

    addParameter(p,'MaskType','none');
    addParameter(p,'MaskWidth',10);
    addParameter(p,'MaskBeta',0.5);
    addParameter(p,'WaveMask',[]);

    addParameter(p,'Curved',false);
    addParameter(p,'CurvatureType','paraboloid');
    addParameter(p,'CurvatureStrength',0.1);

    parse(p,varargin{:});
    opt = p.Results;

    if ~isempty(opt.Seed), rng(opt.Seed); end

    % --------- grids ----------
    x = linspace(opt.XSpan(1), opt.XSpan(2), Nx);
    y = linspace(opt.YSpan(1), opt.YSpan(2), Ny);
    t = linspace(opt.TSpan(1), opt.TSpan(2), T);
    [x2, y2] = meshgrid(x, y);

    dx = median(diff(x));
    dy = median(diff(y));

    % --------- base curvature (optional) ----------
    baseZ = zeros(Ny, Nx);
    if opt.Curved
        switch lower(opt.CurvatureType)
            case 'paraboloid'
                baseZ = -opt.CurvatureStrength * (x2.^2 + y2.^2);
            case 'saddle'
                baseZ =  opt.CurvatureStrength * (x2.^2 - y2.^2);
            otherwise
                warning('Unknown CurvatureType. Proceeding with flat base.');
        end
    end

    % --------- traveling wave field W(y,x,t) ----------
    k  = 2*pi / lambda;         % spatial wavenumber magnitude
    w  = 2*pi * f;              % temporal angular frequency
    x0 = opt.Origin(1); y0 = opt.Origin(2);

    switch lower(opt.WaveType)
        case 'plane'
            % direction unit vector (ux,uy)
            ux = cos(opt.Theta); uy = sin(opt.Theta);
            % spatial phase term, referenced to origin
            phi0 = -k * ( ux*(x2 - x0) + uy*(y2 - y0) );   % Ny x Nx
            % optional radial amplitude decay from origin
            if opt.Alpha > 0
                r = sqrt( (x2 - x0).^2 + (y2 - y0).^2 );
                env = exp(-opt.Alpha * r);
            else
                env = 1;
            end
            W = zeros(Ny, Nx, T);
            for ti = 1:T
                W(:,:,ti) = baseZ + env .* sin( w*t(ti) + phi0 );
            end

        case 'ripple'
            % radial ripple like your draft
            r = sqrt( (x2 - x0).^2 + (y2 - y0).^2 );
            env = exp(-opt.Alpha * r);
            W = zeros(Ny, Nx, T);
            for ti = 1:T
                W(:,:,ti) = baseZ + env .* sin( w*t(ti) - k*r );
            end

        otherwise
            error('WaveType must be ''plane'' or ''ripple''.');
    end

    % --------- temporally correlated noise N(y,x,t) ----------
    sigma = opt.NoiseSigma; rho = opt.NoiseAR;
    N = zeros(Ny, Nx, T);
    N(:,:,1) = sigma * randn(Ny, Nx);
    ar_scale = sigma * sqrt(max(0, 1 - rho^2));
    for ti = 2:T
        N(:,:,ti) = rho * N(:,:,ti-1) + ar_scale * randn(Ny, Nx);
    end

    % optional spatial smoothing per frame (Gaussian, separable)
    kernX = []; kernY = [];
    if opt.SpatialSigma > 0
        radX = max(3, ceil(4*opt.SpatialSigma));
        xi   = (-radX:radX);
        kernX = exp(-0.5*(xi/opt.SpatialSigma).^2); kernX = kernX / sum(kernX);

        % allow anisotropy by interpreting scalar as both x & y sigmas
        sigY = opt.SpatialSigma;
        radY = max(3, ceil(4*sigY));
        yi   = (-radY:radY);
        kernY = exp(-0.5*(yi/sigY).^2); kernY = kernY / sum(kernY);

        for ti = 1:T
            % separable conv: along x then y
            N(:,:,ti) = conv2( conv2(N(:,:,ti), kernX, 'same'), kernY.', 'same' );
        end
        % renormalize overall scale
        sN = std(N(:)); if sN > 0, N = N * (sigma / sN); end
    end

    % --------- ramp s(t): noise -> wave (one-sided) or noise->wave->noise (two-sided) ----------
    s = make_ramp(opt.RampType, opt.RampFrac, opt.HoldFrac, opt.RampShape, T);
    s3 = reshape(s, 1, 1, T);   % broadcastable

    % --------- spatial mask M(x,y) for localization ----------
    M = build_mask(opt, x2, y2, x0, y0, dx, dy);

    % --------- energy normalization (optional) ----------
    if opt.NormalizeEnergy
        sw = std(W(:)); sn = std(N(:));
        if sn > 0 && sw > 0
            N = N * (sw / sn);
        end
    end

    % --------- crossfade (global or masked) ----------
    if isempty(M)
        Z = (1 - s3).*N + s3.*W;
    else
        Z = N + (M .* s3) .* (W - N);   % only inside mask moves toward wave
    end

    % --------- outputs ----------
    comp.wave  = W;
    comp.noise = N;
    comp.ramp  = s;
    comp.mask  = M;
    comp.kernX = kernX;
    comp.kernY = kernY;
    comp.params = opt;
end

% ===== helpers =====
function s = make_ramp(rampType, rampFrac, holdFrac, rampShape, T)
    rampType = lower(rampType);
    rampFrac = max(0,min(1,rampFrac));
    holdFrac = max(0,min(1,holdFrac));
    switch rampType
        case 'one-sided'
            R = max(1, round(rampFrac*T));
            s = ones(1,T);
            s(1:R) = ramp_up(rampShape, R);
        case 'two-sided'
            nonHold = max(2, round((1 - holdFrac) * T));
            rise = floor(nonHold/2); fall = nonHold - rise;
            hold = T - (rise + fall);
            s = zeros(1,T);
            s(1:rise) = ramp_up(rampShape, rise);
            s(rise+1:rise+hold) = 1;
            s(rise+hold+1:end) = fliplr(ramp_up(rampShape, fall));
        otherwise
            error('RampType must be ''one-sided'' or ''two-sided''.');
    end
end

function r = ramp_up(shape, n)
    if n<=1, r = 1; return; end
    switch lower(shape)
        case 'cosine'
            u = linspace(0,1,n); r = 0.5*(1 - cos(pi*u));
        case 'smoothstep'
            u = linspace(0,1,n); r = u.^2 .* (3 - 2*u);
        case 'logistic'
            u = linspace(-6,6,n); r = 1 ./ (1 + exp(-u));
            r = (r - r(1)) / (r(end)-r(1) + eps);
        otherwise
            error('Unknown RampShape "%s".', shape);
    end
end

function M = build_mask(opt, x2, y2, x0, y0, dx, dy)
    if ~isempty(opt.WaveMask)
        M = opt.WaveMask; M = min(1,max(0,M));
        return
    end
    switch lower(opt.MaskType)
        case 'none'
            M = [];
        case 'gaussian'
            w = opt.MaskWidth;
            if numel(w)==1, w = [w w]; end
            M = exp(-0.5 * ( ((x2-x0)/w(1)).^2 + ((y2-y0)/w(2)).^2 ));
        case 'tophat'
            w = opt.MaskWidth; if numel(w)==1, w = [w w]; end
            r = sqrt( ((x2-x0)/w(1)).^2 + ((y2-y0)/w(2)).^2 );
            M = double(r <= 1);
        case 'tukey'
            R = opt.MaskWidth;      % radius (scalar)
            beta = max(0,min(1,opt.MaskBeta));
            r = sqrt( (x2-x0).^2 + (y2-y0).^2 );
            M = zeros(size(x2));
            R0 = (1 - beta)*R;
            core = (r <= R0); trans = (r > R0) & (r <= R);
            M(core) = 1;
            M(trans) = 0.5*(1 + cos(pi*(r(trans)-R0)/(beta*R)));
        otherwise
            error('MaskType must be ''none'',''gaussian'',''tophat'',''tukey'', or use WaveMask.');
    end
end
