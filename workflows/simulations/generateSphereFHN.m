function [X,t,meta] = generateSphereFHN(G, T, Fs, pars, opts)
% GENERATESPHEREFHN  Reaction–diffusion FitzHugh–Nagumo on an icosphere.
%
% Usage
%   [X,t,meta] = generateSphereFHN(G, T, Fs, pars)
%   [X,t,meta] = generateSphereFHN(G, T, Fs, pars, opts)
%
% Inputs
%   G     : struct from build_icosphere(...). Fields used:
%           .V [N x 3], .F [M x 3], .L (cotangent Laplacian), .vertexArea [N x 1], .R
%           If .L or .vertexArea missing, they are computed here.
%   T     : number of time samples (integer)
%   Fs    : sampling rate (Hz)
%   pars  : parameters for FHN and seeding (struct)
%           Required (FHN):
%             .Du, .Dv           (diffusivities; Dv can be 0)
%             .eps, .a, .b, .I   (FHN kinetics parameters)
%           Optional (initialization & seeds):
%             .u0, .v0           (Nx1 initial states; override any seeds)
%             .seedType          ('spot'|'belt'|'random'|'none'), default 'spot'
%             .spotCenter        (3x1) direction for spot seed (default [0;0;1])
%             .spotSigmaDeg      (deg) angular radius for spot (default 10)
%             .beltNormal        (3x1) great-circle normal (for belt), default [0;0;1]
%             .beltSigmaDeg      (deg) half-width of belt (default 20)
%             .seedU, .seedV     offsets added to u,v where mask is high (defaults  -0.3,+0.3)
%
%   opts  : optional settings (struct)
%           .ReturnField   'u'|'v'|'both' (default 'u')
%           .UseMass       true/false (default true)  % lumped mass matrix
%           .Implicit      'semi'|'full' (default 'semi') % semi-implicit diffusion
%           .ARNoise       scalar in [0,1) for additive AR(1) sensor noise on X (default 0)
%           .NoiseStd      std of sensor noise (default 0.0)
%           .DetrendOutput true/false (default false)
%           .Seed          RNG seed (default [])
%
% Outputs
%   X     : [N x T] time series of the chosen field ('u','v', or concatenated in meta)
%   t     : [1 x T] time vector (s)
%   meta  : struct with fields:
%           .U, .V           (N x T) full state histories
%           .params, .opts   copies of inputs
%           .mask            seeding mask used
%           .A_u, .A_v       struct with LU factors of implicit systems (for reference)
%
% Notes
%   - Time-stepping uses backward Euler for diffusion (semi-implicit) and
%     explicit reaction. For stiff cases set opts.Implicit='full'.
%   - This function is shaped to plug into exportIcosphereVideo: pass X and G.V/G.F.

arguments
    G struct
    T (1,1) {mustBeInteger,mustBePositive}
    Fs (1,1) double {mustBePositive}
    pars struct
    opts.ReturnField char = 'u'
    opts.UseMass (1,1) logical = true
    opts.Implicit char = 'semi'
    opts.ARNoise (1,1) double = 0
    opts.NoiseStd (1,1) double = 0.0
    opts.DetrendOutput (1,1) logical = false
    opts.Seed = []
end

% ---- Basics ----
N  = size(G.V,1);
dt = 1/Fs; t = (0:T-1)*dt;

if ~isempty(opts.Seed), rng(opts.Seed); end

% ---- Ensure Laplacian & areas ----
if ~isfield(G,'L') || isempty(G.L)
    % build cotangent Laplacian and vertex areas
    [L, Avert] = local_cotan_laplacian(G.V, G.F);
else
    L = G.L;
    if issparse(L); else; L = sparse(L); end
    if isfield(G,'vertexArea') && ~isempty(G.vertexArea)
        Avert = G.vertexArea(:);
    else
        [~, Avert] = local_cotan_laplacian(G.V, G.F);
    end
end

% Lumped mass matrix (optional)
if opts.UseMass
    M = spdiags(Avert,0,N,N);
else
    M = speye(N);
end

% ---- Parameters (FHN) ----
Du  = getfield_default(pars,'Du',  1e-3);
Dv  = getfield_default(pars,'Dv',  0);
eps = getfield_default(pars,'eps', 0.08);
a   = getfield_default(pars,'a',   0.7);
b   = getfield_default(pars,'b',   0.8);
Iin = getfield_default(pars,'I',   0.0);

% ---- Initialization (u0,v0 or seeds) ----
[u0, v0, maskSeed] = init_states(G.V, pars, N);

% ---- Pre-factor implicit system matrices ----
% We advance:  M (u^{n+1} - u^n)/dt = Du * L u^{n+1} + M * f(u^n,v^n)
% => (M - dt*Du*L) u^{n+1} = M*u^n + dt*M*f(u^n,v^n)
Au = (M - dt*Du*L);
if strcmpi(opts.Implicit,'full')
    Av = (M - dt*Dv*L);
end

[L_u,U_u,P_u] = lu(Au);   % robust; Chol also fine if SPD
if strcmpi(opts.Implicit,'full') && Dv~=0
    [L_v,U_v,P_v] = lu(Av);
else
    L_v = []; U_v = []; P_v = [];
end

% ---- Time loop ----
u = u0(:); v = v0(:);
Uhist = zeros(N,T); Vhist = zeros(N,T);
for k = 1:T
    % Reaction (FHN kinetics) at time n
    fu = u - (u.^3)/3 - v + Iin;
    gv = eps*(u + a - b.*v);

    rhs_u = M*u + dt*(M*fu);

    % Solve implicit diffusion for u
    u = U_u \ (L_u \ (P_u*rhs_u));

    % v: either full implicit or explicit/semi
    if strcmpi(opts.Implicit,'full') && Dv~=0
        rhs_v = M*v + dt*(M*gv);
        v = U_v \ (L_v \ (P_v*rhs_v));
    else
        % Semi-implicit with no diffusion (or explicit on reaction if Dv=0)
        v = v + dt*gv;
        if Dv~=0
            % one cheap diffusion relaxation step (optional)
            v = (speye(N) - dt*Dv*(M\M)*L) \ v; % lightweight stabilization
        end
    end

    Uhist(:,k) = u; Vhist(:,k) = v;
end

% ---- Output selection + optional sensor noise ----
switch lower(opts.ReturnField)
    case 'u', X = Uhist;
    case 'v', X = Vhist;
    case 'both'
        % Stack as [U; V] in meta; keep X=U for video convenience
        X = Uhist;
    otherwise, error('ReturnField must be ''u'',''v'', or ''both''.');
end

if opts.DetrendOutput
    X = X - mean(X,2);
end

if opts.ARNoise > 0 && opts.NoiseStd > 0
    ar = opts.ARNoise; s = opts.NoiseStd;
    e = s*randn(N,T); n = zeros(N,T); n(:,1) = e(:,1);
    for k=2:T, n(:,k)=ar*n(:,k-1)+e(:,k); end
    X = X + n;
end

% ---- Pack meta ----
meta = struct();
meta.U = Uhist; meta.V = Vhist;
meta.params = pars; meta.opts = opts;
meta.mask = maskSeed;
meta.A_u = struct('L',L_u,'U',U_u,'P',P_u);
if ~isempty(L_v), meta.A_v = struct('L',L_v,'U',U_v,'P',P_v); else, meta.A_v = []; end
meta.L = L; meta.M = M;

end % main

% ===================== helpers =====================

function [u0,v0,mask] = init_states(V, pars, N)
% seeds: 'spot' | 'belt' | 'random' | 'none'
deg2rad = @(d) d*pi/180;
clamp = @(x,a,b) max(a, min(b, x));

seedType = getfield_default(pars,'seedType','spot');

% baseline around a rest state
u0 = getfield_default(pars,'u0',  (1 - 0.02*randn(N,1)));
v0 = getfield_default(pars,'v0',  (0 + 0.02*randn(N,1)));

mask = ones(N,1);

switch lower(string(seedType))
case "spot"
    c = getfield_default(pars,'spotCenter',[0;0;1]); c = c(:)/norm(c);
    sig = getfield_default(pars,'spotSigmaDeg',10);
    ang = real(acos(clamp(V*c, -1, 1)));   % radians
    mask = exp(-0.5*(ang/deg2rad(sig)).^2);
case "belt"
    n = getfield_default(pars,'beltNormal',[0;0;1]); n = n(:)/norm(n);
    sig = getfield_default(pars,'beltSigmaDeg',20);
    lat = asin( V*n ); % signed distance to great-circle plane
    mask = exp(-0.5*(lat/deg2rad(sig)).^2);
case "random"
    mask = rand(N,1);
case "none"
    mask = ones(N,1);
otherwise
    error('Unknown seedType: %s', seedType);
end

seedU = getfield_default(pars,'seedU', -0.3);
seedV = getfield_default(pars,'seedV', +0.3);
u0 = u0 + seedU * mask;
v0 = v0 + seedV * mask;
end

function val = getfield_default(s, field, default)
if isfield(s,field) && ~isempty(s.(field)), val = s.(field); else, val = default; end
end

function [L, Avert] = local_cotan_laplacian(V,F)
% minimal cotangent Laplacian + vertex areas
N = size(V,1);
if nargin<2 || isempty(F)
    error('G.F (faces) required to build Laplacian when G.L is missing.');
end
i1 = F(:,1); i2 = F(:,2); i3 = F(:,3);
% edge vectors
v1 = V(i2,:) - V(i3,:);
v2 = V(i3,:) - V(i1,:);
v3 = V(i1,:) - V(i2,:);
% triangle areas
Af = 0.5*vecnorm(cross(V(i2,:)-V(i1,:), V(i3,:)-V(i1,:), 2, 2), 2, 2);
% cotangents at each corner
cot12 = dot(v1, -v3, 2) ./ vecnorm(cross(v1, -v3,2), 2, 2);
cot23 = dot(v2, -v1, 2) ./ vecnorm(cross(v2, -v1,2), 2, 2);
cot31 = dot(v3, -v2, 2) ./ vecnorm(cross(v3, -v2,2), 2, 2);
I = [i1;i2;i2;i3;i3;i1];
J = [i2;i1;i3;i2;i1;i3];
S = 0.5*[cot31;cot31;cot12;cot12;cot23;cot23];
W = sparse(I,J,S,N,N);
W = (W + W.')*0.5;                 % symmetrize
d = -sum(W,2);
L = spdiags(d,0,N,N) + W;
Avert = accumarray(F(:), repmat(Af/3,3,1), [N,1]);
end
