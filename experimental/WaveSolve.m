%% ============================================================
%  Wave fields on a mesh with bct operators
%  Option 1: Helmholtz Green's function (time-harmonic)
%  Option 2: Time stepping wave equation (true propagation)
% ============================================================

bct.start

%% --- Load mesh + build manifold ---
fs4path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
[vertices, faces] = freesurfer_read_surf(fs4path);

M  = bct.Manifold(vertices, faces);
%M  = M.flip;                     % you do this routinely

topo = M.topology;
geom = M.geometry;
ops  = M.operators;

V = M.Vertices;
F = double(M.Faces);

nV = size(V,1);
nF = size(F,1);

Mass = ops.mass.value;           % nV x nV sparse SPD
L    = ops.stiffness.value;      % nV x nV sparse (cotan stiffness)

fprintf('--- sizes --- |V|=%d |F|=%d\n', nV, nF);

%% --- Source (point load) ---
seed = 6653;                     % e.g., anterior pole
f = sparse(seed, 1, 1, nV, 1);   % delta at seed (unit amplitude)

% If you want "mass-correct" source (often preferable):
% f = Mass(:,seed);              % equals Mass*e_seed

viewer = bct.ui.show(M);

%% ============================================================
%  OPTION 1: Helmholtz Green's function (time-harmonic field)
%
%  Solve:  (L - k^2 M) u = f        (indefinite in general)
%
%  Practical robust variant (recommended): damped Helmholtz
%      (L - (k^2 + i*eta) M) u = f
%  or a "shifted" SPD-like solve for visualization:
%      (L + alpha M) u = f    (screened Poisson / Yukawa)
%
%  If you want a wave-like oscillatory spatial pattern, use complex damping.
% ============================================================

% --- Choose frequency / wavenumber ---
% If you want to relate to temporal frequency: omega = 2*pi*f0
% On a mesh, physical scaling needs a wave speed c: k = omega/c
f0 = 10;                         % Hz (conceptual)
omega = 2*pi*f0;

c = 250;                         % (arbitrary units unless you calibrate)
k = omega / c;

eta = 0.05 * k^2;                % damping strength (tune; must be >0)

% --- Build Helmholtz operator ---
Ahelm = L - (k^2 + 1i*eta) * Mass;     % complex sparse

% --- Solve (use a direct solver; Cholesky won't apply to indefinite/complex) ---
% MATLAB: decomposition(A,'lu') works for sparse complex
HelmDecomp = decomposition(Ahelm, 'lu');
uHelm = HelmDecomp \ f;                 % complex nV x 1

% --- What to visualize ---
% Real part looks like standing wave pattern; magnitude shows decay
uHelm_real = real(uHelm);
uHelm_mag  = abs(uHelm);
    uHelmFull=full(uHelm_real);
viewer.setScalar( uHelmFull);
% viewer.setScalar(uHelm_mag);

% --- Optional: normalize for display ---
viewer.setScalar(full(uHelm_real ./ max(abs(uHelm_real))));

%% --- SPD fallback if LU is too heavy (screened Poisson) ---
% This is NOT oscillatory, but gives a "wave-like" attenuating field:
% alpha = k^2; 
% Ascreen = L + alpha*Mass;        % SPD
% ScreenDecomp = decomposition(Ascreen, 'chol');
% uScreen = ScreenDecomp \ f;
% viewer.setScalar(uScreen);

%% ============================================================
%  OPTION 2: Discrete wave equation time stepping (true propagation)
%
%  Continuous:  u_tt + 2*zeta*omega0 u_t + c^2 Δu = s(t)
%  On mesh (FEM):
%      M u_tt + C u_t + c^2 L u = f(t)
%
%  Use semi-implicit Newmark (unconditionally stable for linear problems):
%      (M + gamma*dt*C + beta*dt^2*c^2 L) u_{n+1} = RHS
%
%  This produces real propagation. You can animate u(t) in your viewer.
% ============================================================

% --- Simulation parameters ---
dt = 0.001;                      % seconds
T  = 1.0;                        % seconds total
nT = round(T/dt);

c  = 1.0;                        % wave speed (units relative to mesh)
zeta = 0.02;                     % damping ratio-like parameter

% Rayleigh damping is common on meshes:
%   C = a*M + b*L
a = 2*zeta*omega;                % crude mapping; you can tune
b = 0.0;
C = a*Mass + b*L;

% Newmark parameters (average acceleration)
betaN  = 1/4;
gammaN = 1/2;

% --- Prefactor the effective matrix once ---
Aeff = Mass + gammaN*dt*C + betaN*(dt^2)*(c^2)*L;

% Aeff should be SPD if Mass SPD and damping>=0 and L>=0
AeffDecomp = decomposition(Aeff, 'chol');

% --- Initial conditions ---
u  = zeros(nV,1);                % displacement
v  = zeros(nV,1);                % velocity
acc = zeros(nV,1);               % acceleration

% Initial impulse (choose one):
% (A) displacement bump:
% u(seed) = 1;
% (B) velocity kick:
v(seed) = 1;
% (C) force pulse over first few steps:
forcePulse = true;

% Precompute constant parts
K = c^2 * L;

% --- Time stepping ---
frameStride = 10;                % visualize every N steps
%%
for it = 1:nT
    tnow = (it-1)*dt;

    % External force f(t)
    ft = sparse(nV,1);
    if forcePulse
        % Short Gaussian pulse
        t0 = 0.05;
        sig = 0.01;
        amp = 1.0;
        ft(seed) = amp * exp(-0.5*((tnow - t0)/sig)^2);
    end

    % Newmark predictor
    u_pred = u + dt*v + (0.5 - betaN)*dt^2*acc;
    v_pred = v + (1 - gammaN)*dt*acc;

    % Effective RHS:
    % Aeff*u_{n+1} = ft - K*u_pred - C*v_pred   + (Mass term already in Aeff*u_{n+1})
    % More standard form:
    rhs = ft ...
        - K*u_pred ...
        - C*v_pred ...
        + Mass*u_pred*(0);  % (placeholder; see note below)

    % NOTE:
    % A common consistent Newmark derivation writes RHS as:
    % rhs = ft + Mass*( (1/(beta*dt^2))*u_pred ) + C*( (gamma/(beta*dt))*u_pred );
    % and Aeff = K + (gamma/(beta*dt))*C + (1/(beta*dt^2))*M
    %
    % To keep things simple and correct, use the "standard" Newmark form below:

    invBetaDt2 = 1/(betaN*dt^2);
    gammaOverBetaDt = gammaN/(betaN*dt);

    Aeff_std = K + gammaOverBetaDt*C + invBetaDt2*Mass;
    % Prefactor once outside loop in production; here we keep draft clarity:
    % (for speed, move this build+decomposition above loop)
    % But since you asked for prefactor reuse, do it properly:

    if it == 1
        AeffStdDecomp = decomposition(Aeff_std, 'chol');
    end

    rhs_std = ft ...
        + Mass*(invBetaDt2*u_pred) ...
        + C*(gammaOverBetaDt*u_pred);

    u_next = AeffStdDecomp \ rhs_std;

    % Recover acceleration and velocity
    acc_next = invBetaDt2*(u_next - u_pred);
    v_next   = v_pred + gammaN*dt*acc_next;

    % Commit
    u = u_next;
    v = v_next;
    acc = acc_next;

    us{it} = u;  % Store the current displacement for visualization
     
end
%%
clim=[min(us{1}), max(us{end})];


    % Visualize
    if mod(it, frameStride) == 0
        viewer.setScalar(us{500}, 'Clim', clim);
        drawnow limitrate
    end
%% ============================================================
%  Notes / recommendations
% ============================================================
% - Option 1 is a "steady-state" frequency-domain wavefield. Great for:
%   * standing-wave patterns, resonance probing, spectral intuition
%   * building wave bases / filters
%
% - Option 2 is actual time propagation, good for:
%   * wavefronts, arrival times, reflections, dispersion experiments
%   * generating synthetic movies to validate detection pipelines
%
% - Calibrating c (wave speed) to mm/s requires consistent mesh units
%   and interpretation of L, M (you have "area_units" in metadata).
us