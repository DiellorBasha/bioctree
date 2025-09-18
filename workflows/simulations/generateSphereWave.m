function [X,t,meta] = generateSphereWave(V, T, Fs, waves, opts)
% GENERATESPHEREWAVE  Simulate windowed great-circle waves on a spherical mesh
% Syntax
%   [X, t, meta] = generateSphereWave(V, T, Fs, waves)
%   [X, t, meta] = generateSphereWave(V, T, Fs, waves, opts)
%
% Description
%   Simulates time-varying signals on vertices V (N×3) composed of AR(1)
%   background noise plus one or more localized great‑circle traveling waves.
%   Waves are created by projecting a phase around a specified great‑circle
%   plane and applying optional spatial envelopes (belts or Gaussian spots)
%   and time-windowing (Tukey window).
%
% Inputs
%   V       - (N×3) vertex coordinates (Cartesian, not necessarily unit)
%   T       - scalar integer, number of time samples
%   Fs      - sampling rate (Hz)
%   waves   - 1×W struct array, each element defines one wave with fields:
%       .normal        - (3×1) normal vector of great‑circle plane (required)
%       .A             - amplitude scalar (required)
%       .fHz           - temporal frequency in Hz (required)
%       .cycles        - spatial cycles around the great circle (required)
%       .t0            - start time (s) of the window (required)
%       .dur           - duration (s) of the window (required)
%       .tukeyAlpha    - tukey window alpha ∈ [0,1] (required)
%     Optional spatial/phase fields:
%       .phi0          - phase offset (radians) (optional)
%       .spotCenter    - (3×1) Cartesian center vector for a Gaussian spot
%       .spotSigmaDeg  - angular sigma in degrees for spot mask (required if spotCenter used)
%       .beltSigmaDeg  - angular sigma in degrees for a latitudinal belt mask
%
%   opts    - name-value style options (struct accepted positionally):
%       .NoiseAR   - AR(1) coefficient for background noise (default 0.97)
%       .NoiseStd  - standard deviation of additive Gaussian noise (default 0.4)
%       .Seed      - RNG seed (default 7)
%
% Outputs
%   X       - (N×T) simulated signals on vertices V
%   t       - (1×T) time vector in seconds (0:(T-1))/Fs
%   meta    - struct array with per-wave metadata fields:
%            .phiPrime  - per-vertex angular phase around the great circle
%            .mask      - spatial envelope (N×1)
%            .env       - time envelope (1×T)
%            .w         - copy of the input wave struct
%
% Notes
%   - V is treated as points on a unit sphere orientation; dot products and
%     angles are used to compute great-circle phases and angular masks.
%   - Spatial masks use angular distances in radians; spot/belt sigma
%     parameters are specified in degrees (converted internally).
%   - The generated wave term is: A * mask .* cos(cycles*phiPrime + phaseTime)
%     multiplied by the Tukey time envelope and added to the AR(1) noise.
%
% Examples
%   % Create single wave on an icosphere vertex set V:
%   w.normal = [0 0 1]; w.A = 1; w.fHz = 2; w.cycles = 3;
%   w.t0 = 0; w.dur = 1; w.tukeyAlpha = 0.2;
%   [X,t,meta] = generateSphereWave(V, 500, 200, w);
%
%   % Two waves with a spot mask and different starts:
%   w1 = w; w1.spotCenter = [1 0 0]; w1.spotSigmaDeg = 15;
%   w2 = w; w2.normal = [0 1 0]; w2.t0 = 0.5;
%   [X,~,m] = generateSphereWave(V, 800, 250, [w1,w2], struct('Seed',42));
%
% Implementation details
%   - Background noise: X(:,1) initialized from Gaussian noise, subsequent
%     samples follow an AR(1) recursion X(:,k) = NoiseAR*X(:,k-1)+eps.
%   - Local great‑circle phase: computed via a local orthonormal basis
%     (p,q) spanning the great‑circle plane; phiPrime = atan2(V*q, V*p).
%
% See also: tukeywin, atan2, acos

arguments
    V double {mustBeFinite}
    T (1,1) {mustBeInteger, mustBePositive}
    Fs (1,1) double {mustBePositive}
    waves (1,:) struct
    opts.NoiseAR (1,1) double = 0.97
    opts.NoiseStd (1,1) double = 0.4
    opts.Seed (1,1) double = 7
end
[N,~] = size(V); t = (0:T-1)/Fs; X = zeros(N,T);
if ~isempty(opts.Seed), rng(opts.Seed); end
epsi = opts.NoiseStd*randn(N,T); X(:,1)=epsi(:,1);
for k=2:T, X(:,k)=opts.NoiseAR*X(:,k-1)+epsi(:,k); end

meta = struct('phiPrime',[],'mask',[],'env',[],'w',[]);
for wi = 1:numel(waves)
    w = waves(wi);
    n = w.normal(:)/norm(w.normal);
    [p,q] = local_basis(n);
    phiPrime = atan2( V*q, V*p );     % angle around great circle plane
    % optional belt/spot masks
    M = ones(N,1);
    if isfield(w,'beltSigmaDeg') && ~isempty(w.beltSigmaDeg)
        lat = asin( V*n );                    % signed "latitude" wrt plane
        M = M .* exp(-0.5*(lat/deg2rad(w.beltSigmaDeg)).^2);
    end
    if isfield(w,'spotCenter') && ~isempty(w.spotCenter)
        c = w.spotCenter(:)/norm(w.spotCenter);
        ang = real(acos(max(-1,min(1,V*c))));
        M = M .* exp(-0.5*(ang/deg2rad(w.spotSigmaDeg)).^2);
    end
    env = zeros(1,T);
    idx = find(t>=w.t0 & t<(w.t0+w.dur));
    env(idx) = tukeywin(numel(idx), w.tukeyAlpha).';
    phaseSpace = w.cycles * phiPrime;
    phaseTime  = -2*pi*w.fHz * t + (isfield(w,'phi0')*w.phi0);
    X = X + w.A * (M .* cos(phaseSpace + phaseTime)) .* env;

    meta(wi).phiPrime=phiPrime; meta(wi).mask=M; meta(wi).env=env; meta(wi).w=w;
end
end

function [p,q]=local_basis(n)
n=n(:)/norm(n);
a = (abs(n(3))<0.9)*[0;0;1] + (abs(n(3))>=0.9)*[1;0;0];
p = a - (a.'*n)*n; p=p/norm(p); q = cross(n,p); q=q/norm(q);
end
