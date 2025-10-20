function [X,t,meta] = generateSphereWave(V, T, Fs, waves, opts)
% GENERATESPHEREWAVE  Simulate windowed waves on a spherical mesh

% Extended: supports multiple spatial wave types:
%   - 'greatcircle' (default) : phase varies around a great-circle plane.
%   - 'radial'               : concentric/radial waves around a specified spot center.
%   - 'spiral'               : spiral waves combining radial distance + angular winding.
%
% Usage
%   [X,t,meta] = generateSphereWave(V, T, Fs, waves)
%   [X,t,meta] = generateSphereWave(..., opts)
%
% waves struct fields (per-element)
%   Common:
%     .type          - 'greatcircle' | 'radial' | 'spiral' (default 'greatcircle')
%     .A             - amplitude
%     .fHz           - temporal frequency (Hz)
%     .cycles        - spatial cycles (meaning depends on type)
%     .t0, .dur      - start time and duration (s)
%     .tukeyAlpha    - tukey window alpha
%     .phi0          - phase offset (rad, optional)
%   Great-circle specific:
%     .normal        - 3×1 normal vector for great-circle plane (required for greatcircle)
%   Radial / Spiral specific:
%     .spotCenter    - 3×1 Cartesian center vector (unit) around which radial/spiral are defined
%     .spotSigmaDeg  - angular sigma (deg) for amplitude mask (optional)
%     .speed         - propagation speed (radians per second along geodesic). Default = 1
%   Spiral extra:
%     .spiralTurns   - integer controlling angular winding (default 1)
%
% Notes
%   - For 'radial' and 'spiral' types the code uses geodesic angular distance
%     ang = acos(clamp(V * c, -1, 1)) (radians). Propagation delay = ang / speed.
%   - phase at vertex j and time ti is computed as:
%         phase(j,ti) = phaseSpace(j) + (-2*pi*f) * ( t(ti) - delay(j) ) + phi0
%     so the wave propagates outward with given speed.
%
% Outputs
%   X    - N×T simulated signals
%   t    - 1×T time vector
%   meta - per-wave metadata (phiPrime, mask, env, w, ang, center)
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

meta = struct('phiPrime',[],'mask',[],'env',[],'w',[],'ang',[],'center',[]);

deg2rad = @(d) d * pi/180;
clamp = @(x,m,M) max(m, min(M, x));

for wi = 1:numel(waves)
    w = waves(wi);
    if ~isfield(w,'type') || isempty(w.type), w.type = 'greatcircle'; end
    typ = lower(string(w.type));
    phi0 = 0; if isfield(w,'phi0'), phi0 = w.phi0; end
    env = zeros(1,T);
    idx = find(t>=w.t0 & t<(w.t0+w.dur));
    if ~isempty(idx)
        env(idx) = tukeywin(numel(idx), w.tukeyAlpha).';
    end

    % default mask
    M = ones(N,1);

    switch typ
        case "greatcircle"
            % require normal
            if ~isfield(w,'normal') || isempty(w.normal)
                error('generateSphereWave:missingField','greatcircle wave requires .normal');
            end
            n = w.normal(:)/norm(w.normal);
            [p,q] = local_basis(n);
            phiPrime = atan2( V*q, V*p );     % angle around great circle plane
            % Optional belts/spots (same as before)
            if isfield(w,'beltSigmaDeg') && ~isempty(w.beltSigmaDeg)
                lat = asin( V*n );                    % signed "latitude" wrt plane
                M = M .* exp(-0.5*(lat/deg2rad(w.beltSigmaDeg)).^2);
            end
            if isfield(w,'spotCenter') && ~isempty(w.spotCenter)
                c = w.spotCenter(:)/norm(w.spotCenter);
                ang = real(acos(clamp(V*c, -1, 1))); % radians
                if ~isfield(w,'spotSigmaDeg'), error('spotSigmaDeg required with spotCenter'); end
                M = M .* exp(-0.5*(ang/deg2rad(w.spotSigmaDeg)).^2);
            else
                ang = []; c = [];
            end

            % --- time-varying helpers (chirp + precession) ---
            % chirpAlpha: Hz/s (linear); precessRateDeg: deg/s around precessAxis
            if isfield(w,'chirpAlpha') && ~isempty(w.chirpAlpha)
                % phaseTime = -2*pi*(f0*t + 0.5*alpha*t^2) + phi0
                phaseTime = -2*pi*(w.fHz * t + 0.5 * w.chirpAlpha * (t.^2)) + phi0;
            else
                phaseTime = -2*pi*w.fHz * t + phi0;       % 1xT
            end

            if isfield(w,'precessRateDeg') && ~isempty(w.precessRateDeg)
                % per-time rotated normal -> per-time phaseSpace; compute per-frame
                axisRot = [0;0;1]; % default rotation axis (z) if not provided
                if isfield(w,'precessAxis') && ~isempty(w.precessAxis)
                    axisRot = w.precessAxis(:)/norm(w.precessAxis);
                end
                precessRateRad = deg2rad(w.precessRateDeg);
                % build phase matrix NxT by rotating normal for each time
                phaseSpace = zeros(N, T);
                for ti = 1:T
                    angrot = precessRateRad * t(ti);
                    R = axang2rotm([axisRot(:).' angrot]);   % requires robotics toolbox or custom; fallback implemented below
                    nr = R * n;
                    [pr, qr] = local_basis(nr);
                    phaseSpace(:,ti) = w.cycles * atan2(V*qr, V*pr);
                end
            else
                phaseSpace = w.cycles * phiPrime;
            end

            % assemble phase (NxT)
            if ismatrix(phaseSpace) && size(phaseSpace,2)==1
                phase = phaseSpace(:) + phaseTime;        % NxT via broadcasting
            else
                % phaseSpace already NxT (precession case)
                % ensure phaseTime is 1xT and broadcast
                phase = phaseSpace + (zeros(N,1) * phaseTime);
            end

            meta(wi).phiPrime = phiPrime;
            meta(wi).ang = ang;
            meta(wi).center = c;

        case "standing"
            % Standing (normal-mode style) from superposition of opposite travelers
            % optional: use spherical harmonic mode if w.useSphericalHarmonic and w.l/w.m provided
            if isfield(w,'useSphericalHarmonic') && w.useSphericalHarmonic
                if ~isfield(w,'l') || ~isfield(w,'m')
                    error('generateSphereWave:missingField','spherical harmonic requires .l and .m');
                end
                % compute real spherical harmonic Y_lm(θ,φ) on unit directions
                uu = V ./ vecnorm(V,2,2);
                theta = acos( clamp(uu(:,3), -1, 1) );  % colatitude
                phi_ang = atan2(uu(:,2), uu(:,1));
                P = legendre(w.l, cos(theta)); % (m+1) x N
                Plm = squeeze(P(abs(w.m)+1,:)).';    % N x 1
                % normalization (real-valued)
                Nm = sqrt( (2*w.l+1)/(4*pi) * factorial(w.l-abs(w.m))/factorial(w.l+abs(w.m)) );
                if w.m >= 0
                    Y = Nm * Plm .* cos(w.m * phi_ang);
                else
                    Y = Nm * Plm .* sin(abs(w.m) * phi_ang);
                end
                % standing temporal cosine
                waveMat = (Y(:) * cos(2*pi*w.fHz * t)); % NxT
                X = X + w.A * (M .* waveMat) .* env;
                meta(wi).mask = M; meta(wi).env = env; meta(wi).w = w; meta(wi).phiPrime = []; continue;
            end

            % default standing from superposition of +/− traveling great-circle waves
            if ~isfield(w,'normal') || isempty(w.normal)
                error('generateSphereWave:missingField','standing wave requires .normal for great-circle standing mode');
            end
            n = w.normal(:)/norm(w.normal);
            [p,q] = local_basis(n);
            phiPrime = atan2( V*q, V*p );     % N x 1
            % standing pattern: 2*cos(c*phiPrime) * cos(2*pi*f*t + phi0)
            cosSpatial = 2 * cos(w.cycles * phiPrime);
            cosTime = cos(2*pi*w.fHz * t + phi0);
            waveMat = cosSpatial(:) * cosTime;   % NxT
            X = X + w.A * (M .* waveMat) .* env;
            meta(wi).mask = M; meta(wi).env = env; meta(wi).w = w; meta(wi).phiPrime = phiPrime;

        case "beam"
            % Gaussian beam / wave-packet localized transverse to a great-circle path
            if ~isfield(w,'normal') || isempty(w.normal)
                error('generateSphereWave:missingField','beam requires .normal for center great-circle');
            end
            n = w.normal(:)/norm(w.normal);
            [p,q] = local_basis(n);
            phiPrime = atan2( V*q, V*p );     % along-path coordinate (radians)
            % transverse distance: angular distance to great-circle = |asin(V*n)|
            d_gamma = abs( asin( clamp(V*n, -1, 1) ) );   % radians
            sigmaPerp = deg2rad(1); % default 1 deg
            if isfield(w,'sigmaPerpDeg') && ~isempty(w.sigmaPerpDeg), sigmaPerp = deg2rad(w.sigmaPerpDeg); end
            M = M .* exp(-0.5 * (d_gamma / sigmaPerp).^2);  % transverse Gaussian

            % propagation along centerline: delay proportional to along-path coordinate
            % map phiPrime (-pi..pi) -> s along path in radians; use speed if provided
            s = phiPrime;  % radians along great circle
            speed = 1; if isfield(w,'speed') && ~isempty(w.speed), speed = w.speed; end
            delay = s ./ speed;
            % chirp support
            if isfield(w,'chirpAlpha') && ~isempty(w.chirpAlpha)
                phaseTime = -2*pi*(w.fHz * t + 0.5 * w.chirpAlpha .* (t.^2)) + phi0;
            else
                phaseTime = -2*pi*w.fHz * t + phi0;
            end
            % phase includes propagation delay
            % build NxT phase: phaseSpace + (-2*pi*f) * (t - delay)
            phaseSpace = w.cycles * phiPrime;
            phase = phaseSpace(:) + (-2*pi*w.fHz) .* (t - delay);
            if isvector(phase)
                if numel(phase)==N, phase = phase(:) + zeros(1,T); else phase = ones(N,1)*phase(:).'; end
            end
            waveMat = cos(phase);
            X = X + w.A * (M .* waveMat) .* env;
            meta(wi).mask = M; meta(wi).env = env; meta(wi).w = w; meta(wi).phiPrime = phiPrime;

        case "spiral"
            % spiral wave: combine radial dependence and angular winding about spotCenter
            if ~isfield(w,'spotCenter') || isempty(w.spotCenter)
                % fallback center: mean of vertices projected to unit sphere
                c = mean(V,1)'; c = c / norm(c);
            else
                c = w.spotCenter(:)/norm(w.spotCenter);
            end
            ang = real(acos(clamp(V*c, -1, 1)));    % geodesic distance
            if isfield(w,'spotSigmaDeg') && ~isempty(w.spotSigmaDeg)
                M = M .* exp(-0.5*(ang/deg2rad(w.spotSigmaDeg)).^2);
            end
            % local tangent basis at center
            [p0,q0] = local_basis(c);
            xp = V * p0; yp = V * q0;               % projections onto local tangent
            theta = atan2(yp, xp);                  % -pi..pi angular coordinate around center
            k = max(0, w.cycles);                   % radial cycles factor
            m = 1; if isfield(w,'spiralTurns') && ~isempty(w.spiralTurns), m = w.spiralTurns; end
            phaseSpace = 2*pi*( k*(ang / pi) + m*(theta/(2*pi)) );
            % propagation
            speed = 1; if isfield(w,'speed') && ~isempty(w.speed), speed = w.speed; end
            delay = ang ./ speed;
            phase = phaseSpace(:) + (-2*pi*w.fHz) .* (t - delay);

            meta(wi).phiPrime = theta; meta(wi).ang = ang; meta(wi).center = c;

        case "radial"
            % radial wave: concentric waves about spotCenter (required)
            if ~isfield(w,'spotCenter') || isempty(w.spotCenter)
                error('generateSphereWave:missingField','radial wave requires .spotCenter (unit vector).');
            end
            c = w.spotCenter(:)/norm(w.spotCenter);
            ang = real(acos(clamp(V*c, -1, 1)));   % N x 1 radians (geodesic)
            if isfield(w,'spotSigmaDeg') && ~isempty(w.spotSigmaDeg)
                M = M .* exp(-0.5*(ang/deg2rad(w.spotSigmaDeg)).^2);
            end
            % spatial phase proportional to radial distance
            k = max(0, w.cycles);  % radial cycles
            phaseSpace = 2*pi * k * (ang / pi);    % maps ang in [0,pi] -> [0, k*2*pi]
            % propagation speed (radians per second). default 1
            speed = 1; if isfield(w,'speed') && ~isempty(w.speed), speed = w.speed; end
            delay = ang ./ speed;                    % N x 1 (s)
            % create NxT phase matrix: phaseSpace + (-2*pi*f) * (t - delay)
            phase = phaseSpace(:) + (-2*pi*w.fHz) .* (t - delay);  % N x T via broadcasting

            meta(wi).phiPrime = []; meta(wi).ang = ang; meta(wi).center = c;

        case "timevarying"
            % Generic time-varying wrapper: supports chirp and precession by rotating a base great-circle
            if ~isfield(w,'base') || ~isfield(w.base,'type')
                error('generateSphereWave:missingField','timevarying requires .base struct describing base wave');
            end
            % build a temporary wave struct and compute per-time frames
            base = w.base;
            % ensure base has normal for rotations
            if isfield(base,'normal') && ~isempty(base.normal)
                n0 = base.normal(:)/norm(base.normal);
            else
                n0 = [0;0;1];
            end
            axisRot = [0;0;1];
            if isfield(w,'precessAxis') && ~isempty(w.precessAxis)
                axisRot = w.precessAxis(:)/norm(w.precessAxis);
            end
            precessRateRad = 0;
            if isfield(w,'precessRateDeg') && ~isempty(w.precessRateDeg)
                precessRateRad = deg2rad(w.precessRateDeg);
            end
            % build per-time contributions into a temporary matrix
            Xtemp = zeros(N,T);
            for ti = 1:T
                % rotate normal
                if precessRateRad~=0
                    angrot = precessRateRad * t(ti);
                    R = axang2rotm([axisRot(:).' angrot]); % fallback implemented above if not available
                    base.normal = R * n0;
                end
                % chirp: adjust f for base
                if isfield(w,'chirpAlpha') && ~isempty(w.chirpAlpha)
                    base.fHz = base.fHz + w.chirpAlpha * t(ti);
                end
                % compute one time-slice by calling generateSphereWave recursively with T=1 and env=1 at that instant
                [Xslice, ~, ~] = generateSphereWave(V, 1, Fs, base, struct('NoiseAR',0,'NoiseStd',0,'Seed',[]));
                % Xslice is Nx1; place into Xtemp
                Xtemp(:,ti) = Xslice(:,1);
            end
            X = X + Xtemp .* (w.A .* (zeros(N,1)*env)); % env applied here; A scaling included
            meta(wi).mask = M; meta(wi).env = env; meta(wi).w = w;

        otherwise
            error('generateSphereWave:unknownType','Unknown wave type: %s', char(typ));
    end  % switch typ
    % ----------------- NEW: skip generic phase handling when 'phase' was not created -----------------
    if ~exist('phase','var') || isempty(phase)
        % some cases (e.g. standing, spherical-harmonic, timevarying, beam handled X already)
        % ensure meta fields are present and move to next wave
        meta(wi).mask = M;
        meta(wi).env  = env;
        meta(wi).w    = w;
        if exist('phase','var'), clear phase; end
        continue;
    end
    % Ensure phase is NxT (if the expression produced Nx1 + 1xT MATLAB will broadcast; be explicit if older MATLAB)
    if isvector(phase)
        % if phase is Nx1 and phaseTime later, broadcast:
        if numel(phase)==N
            phase = phase(:) + zeros(1,T);  % NxT
        else
            phase = ones(N,1) * phase(:).';
        end
    end

    % build wave contribution and add to X
    % phase includes phi0 already where applied above; now compute cos and scale
    waveMat = cos(phase);                % NxT
    X = X + w.A * (M .* waveMat) .* env; % broadcasting env (1xT) across rows

    % store meta
    meta(wi).mask = M;
    meta(wi).env = env;
    meta(wi).w = w;
end

end

function [p,q]=local_basis(n)
n=n(:)/norm(n);
a = (abs(n(3))<0.9)*[0;0;1] + (abs(n(3))>=0.9)*[1;0;0];
p = a - (a.'*n)*n; p=p/norm(p); q = cross(n,p); q=q/norm(q);
end
