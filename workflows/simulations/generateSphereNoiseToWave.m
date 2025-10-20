function [X, V, t, G, comp] = generateSphereNoiseToWave(Nv, T, f, lambda, alpha, origin, varargin)
% generateSphereNoiseToWave
% Create a sphere signal X(n,t) that evolves from random dynamics to a
% localized traveling wave on the unit sphere.
%
% X(:,ti) = (1 - s(ti)) * Noise(:,ti) + s(ti) * ( M .* Wave(:,ti) + (1-M) .* Noise(:,ti) )
% with s(t) a smooth ramp (one- or two-sided) and M a spatial mask (optional).
%
% Inputs
%   Nv, T       : # sphere vertices (Fibonacci) and # time samples
%   f           : temporal frequency (Hz)
%   lambda      : spatial wavelength along geodesic distance (in radians on unit sphere)
%   alpha       : spatial exponential decay vs. geodesic distance
%   origin      : wave center; either 3-vector (unit or not) OR [lat,lon] in degrees
%
% Name-Value options (mirrors your 1D version)
%   'TSpan'        : [t0 t1] time span (default [0 1])
%   'RampFrac'     : fraction of T used to ramp (0..1), default 0.5
%   'RampShape'    : 'cosine'|'smoothstep'|'logistic' (default 'cosine')
%   'RampType'     : 'one-sided' | 'two-sided' (default 'one-sided')
%   'HoldFrac'     : hold at peak for two-sided (0..1), default 0
%   'NoiseSigma'   : base noise std (default 1.0)
%   'NoiseAR'      : AR(1) temporal correlation rho in [0 1) (default 0.95)
%   'SpatialSigma' : sphere noise smoothing "strength" (default 1.5) → #steps ~ ceil(2*SpatialSigma)
%   'NormalizeEnergy' : true/false to match noise energy to wave (default true)
%   'Seed'         : RNG seed (default [])
%   'MaskType'     : 'none'|'gaussian'|'tophat'|'tukey'|'custom' (default 'none')
%   'MaskWidth'    : width in radians: sigma (gaussian), radius (tophat/tukey). default pi/6
%   'MaskBeta'     : Tukey softness (0..1), default 0.5
%   'WaveMask'     : custom Nv×1 mask (0..1); overrides MaskType if provided
%   'GraphK'       : k for kNN graph (default 8)
%
% Outputs
%   X    : [Nv x T] morphing signal on sphere vertices
%   V    : [Nv x 3] unit sphere coordinates
%   t    : [1 x T] time grid
%   G    : struct with graph (fields: W, coords, L, d, etc.) for GSPBox
%   comp : struct with fields:
%           .wave, .noise, .ramp (s), .mask (M), .theta (geodesic), .kappa,
%           .origin_vec (3x1), .params (options), .graph_deg, .rw_steps
%
% Example
%   [X,V,t,G,comp] = generateSphereNoiseToWave(15002, 1200, 12, 0.5, 0.8, [45 -30], ...
%       'TSpan',[0 2], 'RampType','two-sided','HoldFrac',0.25, ...
%       'MaskType','gaussian','MaskWidth',pi/8,'SpatialSigma',2.0,'Seed',7);
%
%   % Joint spectrum in GSPBox (if installed):
%   % G = gsp_graph(V); G = gsp_estimate_lmax(G);  % or use the G returned here
%   % Xhat = gsp_jft(G, X);   % size: (#graph modes) × (#time freqs)
%
% Author: ChatGPT (adapting your 1D API to S^2)

    % ---- parse options ----
    p = inputParser;
    addParameter(p,'TSpan',[0 1]);
    addParameter(p,'RampFrac',0.5);
    addParameter(p,'RampShape','cosine');
    addParameter(p,'RampType','one-sided');
    addParameter(p,'HoldFrac',0);
    addParameter(p,'NoiseSigma',1.0);
    addParameter(p,'NoiseAR',0.95);
    addParameter(p,'SpatialSigma',1.5);
    addParameter(p,'NormalizeEnergy',true);
    addParameter(p,'Seed',[]);
    addParameter(p,'MaskType','none');
    addParameter(p,'MaskWidth',pi/6);
    addParameter(p,'MaskBeta',0.5);
    addParameter(p,'WaveMask',[]);
    addParameter(p,'GraphK',8);
    parse(p,varargin{:});
    opt = p.Results;

    % ---- RNG ----
    if ~isempty(opt.Seed), rng(opt.Seed); end

    % ---- sphere vertices (quasi-uniform) ----
    V = fibonacci_sphere(Nv);       % [Nv x 3], unit vectors

    % ---- center/origin as unit vector ----
    n0 = parse_origin(origin);      % 3x1 unit vector

    % ---- time grid ----
    t = linspace(opt.TSpan(1), opt.TSpan(2), T);
    dt = (T>1) * (t(2)-t(1));

    % ---- geodesic distance (radians on S^2) ----
    theta = acos( clamp(V*n0, -1, 1) );   % [Nv x 1]

    % ---- traveling spherical ripple (radial w.r.t. origin) ----
    % phase: phi = 2*pi*f*t - kappa * theta, with kappa = 2*pi/lambda
    kappa = 2*pi / lambda;
    W = zeros(Nv, T);
    phase_space = -kappa * theta;                % [Nv x 1]
    for ti = 1:T
        W(:,ti) = sin(2*pi*f*t(ti) + phase_space) .* exp(-alpha * theta);
    end

    % ---- AR(1) temporally correlated noise on sphere ----
    Nn = zeros(Nv, T);
    sigma = opt.NoiseSigma;
    rho   = min(max(opt.NoiseAR,0), 0.9999);
    Nn(:,1) = sigma * randn(Nv,1);
    ar_scale = sigma * sqrt(1 - rho^2);
    for ti = 2:T
        Nn(:,ti) = rho * Nn(:,ti-1) + ar_scale * randn(Nv,1);
    end

    % ---- optional spatial smoothing via random-walk averaging ----
    % build a light kNN graph for smoothing and later GSP use
    K = max(3, round(opt.GraphK));
    [Wg, deg] = knn_graph(V, K);
    rw_steps = max(0, ceil(2*opt.SpatialSigma));   % heuristic mapping
    if rw_steps > 0
        % random-walk operator P = D^{-1} W
        P = bsxfun(@rdivide, Wg, deg + eps);
        for s = 1:rw_steps
            Nn = P * Nn;
        end
        % rescale to keep per-entry std near sigma
        if std(Nn(:)) > 0
            Nn = Nn * (sigma / std(Nn(:)));
        end
    end

    % ---- ramp s(t) : one-sided (0→1) or two-sided (0→1→hold→0) ----
    switch lower(opt.RampType)
        case 'one-sided'
            up_len = max(1, round(opt.RampFrac * T));
            s = ones(1,T);
            s(1:up_len) = ramp_up(opt.RampShape, up_len);
        case 'two-sided'
            holdFrac = max(0, min(1, opt.HoldFrac));
            nonHold  = max(2, round((1 - holdFrac)*T));
            riseLen  = floor(nonHold/2);
            fallLen  = nonHold - riseLen;
            holdLen  = T - (riseLen + fallLen);
            s = zeros(1,T);
            s(1:riseLen) = ramp_up(opt.RampShape, riseLen);
            s(riseLen+1:riseLen+holdLen) = 1;
            s(riseLen+holdLen+1:end) = fliplr(ramp_up(opt.RampShape, fallLen));
        otherwise
            error('RampType must be ''one-sided'' or ''two-sided''.');
    end

    % ---- optional spatial mask to localize the emergence ----
    if ~isempty(opt.WaveMask)
        M = opt.WaveMask(:);
        assert(numel(M)==Nv, 'WaveMask must be Nv-by-1.');
        M = max(0, min(1, M));
    else
        switch lower(opt.MaskType)
            case 'none'
                M = [];   % global crossfade
            case 'gaussian'
                sigma_geo = opt.MaskWidth;
                M = exp(-0.5*(theta/sigma_geo).^2);
            case 'tophat'
                R = opt.MaskWidth;
                M = double(theta <= R);
            case 'tukey'
                R = opt.MaskWidth;
                beta = max(0,min(1,opt.MaskBeta));
                r = theta;
                M = zeros(Nv,1);
                R0 = (1 - beta)*R;          % flat-top
                core = r <= R0;
                trans = (r > R0) & (r <= R);
                M(core) = 1;
                M(trans) = 0.5*(1 + cos(pi*(r(trans)-R0)/(beta*R)));
            otherwise
                error('MaskType must be ''none'',''gaussian'',''tophat'',''tukey'', or use WaveMask.');
        end
    end

    % ---- energy normalization (optional) ----
    if opt.NormalizeEnergy
        sw = std(W(:)); sn = std(Nn(:));
        if sn > 0 && sw > 0
            Nn = Nn * (sw / sn);
        end
    end

    % ---- crossfade: Noise → (localized) Wave ----
    if isempty(M)
        X = (1 - s) .* Nn + s .* W;  % global morph
    else
        % localized morph only where M>0, elsewhere remain noise
        X = Nn + (M * s) .* (W - Nn);   % implicit expansion: (Nv×1)*(1×T)
    end

    % ---- Package graph for GSPBox convenience ----
    % Minimal fields useful for GSP:
    G = struct();
    G.W = Wg;
    G.coords = V;
    G.N = Nv;
    G.type = 'knn sphere';
    G.directed = 0;
    G.lap_type = 'combinatorial';
    d = deg;
    L = diag(d) - Wg;
    G.d = d;
    G.L = L;
    G.plotting = struct();

    % ---- outputs ----
    comp.wave        = W;
    comp.noise       = Nn;
    comp.ramp        = s;
    comp.mask        = ~isempty(M) * M;
    comp.theta       = theta;
    comp.kappa       = kappa;
    comp.origin_vec  = n0;
    comp.params      = opt;
    comp.graph_deg   = d;
    comp.rw_steps    = rw_steps;
    comp.dt          = dt;
end

% ---------- helpers ----------

function V = fibonacci_sphere(N)
% quasi-uniform points on unit sphere (Nx3)
    i = (0:N-1)'; 
    phi = (1 + sqrt(5))/2;          % golden ratio
    z = 1 - 2*(i+0.5)/N;           % in (-1,1)
    r = sqrt(max(0,1 - z.^2));
    theta = 2*pi*i/phi;
    V = [r.*cos(theta), r.*sin(theta), z];
    % normalize (numerical safety)
    V = V ./ vecnorm(V,2,2);
end

function n0 = parse_origin(origin)
    if numel(origin)==3
        n0 = origin(:); 
        if norm(n0)==0, error('Origin vector must be nonzero.'); end
        n0 = n0./norm(n0);
    elseif numel(origin)==2
        lat = deg2rad(origin(1)); lon = deg2rad(origin(2));
        n0 = [cos(lat)*cos(lon); cos(lat)*sin(lon); sin(lat)];
    else
        error('Origin must be 3-vector or [lat lon] in degrees.');
    end
end

function y = clamp(x, a, b)
    y = min(max(x, a), b);
end

function r = ramp_up(shape, n)
% return 1xN vector from 0 -> 1
    if n<=1, r = 1; return; end
    u = linspace(0,1,n);
    switch lower(shape)
        case 'cosine'
            r = 0.5*(1 - cos(pi*u));
        case 'smoothstep'
            r = u.^2 .* (3 - 2*u);
        case 'logistic'
            z = 1 ./ (1 + exp(-linspace(-6,6,n)));
            r = (z - z(1)) / (z(end) - z(1) + eps);
        otherwise
            error('Unknown RampShape "%s".', shape);
    end
end

function [W, deg] = knn_graph(V, k)
% simple kNN graph with cosine distance (equivalently Euclidean on unit sphere)
    Nv = size(V,1);
    % use dot products to get angles; do blockwise if Nv is huge
    % here a simple (dense) version—replace with knnsearch for very large Nv
    D = squareform(pdist(V,'euclidean'));     %#ok<NASGU> 
    % faster: use knnsearch (Statistics Toolbox) if available:
    try
        IDX = knnsearch(V, V, 'K', k+1);  % self incl.
        IDX = IDX(:,2:end);
    catch
        % fallback: brute force
        X = V;
        IDX = zeros(Nv,k);
        for i=1:Nv
            di = sum((X - X(i,:)).^2,2);
            [~,ord] = sort(di,'ascend');
            IDX(i,:) = ord(2:k+1);
        end
    end
    % weights = exp(-||xi-xj||^2 / (2*sigma^2)) with sigma from median nn-dist
    dists = zeros(Nv,k);
    for i=1:Nv, dists(i,:) = sqrt(sum((V(i,:) - V(IDX(i,:),:)).^2,2)); end
    sig = median(dists(:)) + eps;
    W = sparse(Nv,Nv);
    for i=1:Nv
        j = IDX(i,:)';
        w = exp(-0.5*(dists(i,:)/sig).^2);
        W(i,j) = w;
        W(j,i) = max(W(j,i), w'); % symmetrize (keep max)
    end
    deg = full(sum(W,2));
end
