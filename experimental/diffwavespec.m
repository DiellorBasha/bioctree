%% ============================================================
%  SETUP: mesh, operators, eigenmodes
% ============================================================
bct.start

fs4path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
[vertices, faces] = freesurfer_read_surf(fs4path);

M  = bct.Manifold(vertices,faces);
M  = M.flip;

topo    = M.topology;
geom    = M.geometry('includeDual', true);
ops     = M.operators;
solvers = M.solvers;

% Eigenmodes (truncate)
K = 1000;
eigen = M.eigenmodes(K);

Phi = eigen.eigenvectors.value;     % nV x K  (assumed)
lam = eigen.eigenvalues.value;      % K x 1

Mass = ops.mass.value;              % nV x nV sparse
nV   = size(M.Vertices,1);

fprintf('Loaded: nV=%d, K=%d, lambda range=[%.3g, %.3g]\n', nV, K, lam(1), lam(end));

%% ============================================================
%  TIME GRID (common to all examples)
% ============================================================
Fs = 200;                 % Hz (choose manageable rate)
T  = 4.0;                 % seconds
t  = (0:1/Fs:T).';
nt = numel(t);

% For joint spectrum: temporal FFT frequency axis
f = (0:nt-1)'*(Fs/nt);     % 0..Fs*(1-1/nt)
% (Optional: use fftshift later)

%% ============================================================
%  SOURCE / SEED
% ============================================================
seed = 43;  % anterior pole (example)
delta = zeros(nV,1);
delta(seed) = 1;
    deltaHeat=solvers.heatDistance.value(seed);
    deltaHeat(deltaHeat<2)=0;
delta=deltaHeat; % add some smear
%viewer = bct.ui.show(M)
% Mass-weighted impulse (P1-FEM consistent)
rhs0 = Mass * delta;       % "M delta" input

%% ============================================================
%  HELPER: project signal U(t) into eigenbasis with mass inner product
%  Given U: [nV x nt], returns A: [K x nt] with a_k(t) = phi_k^T M u(t)
% ============================================================
% This is the right projection if Phi is M-orthonormal:
%   Phi' * Mass * Phi ≈ I
Aproj = @(U) (Phi' * (Mass * U));

%% ============================================================
%  HELPER: joint spectrum magnitude |X(lambda, f)|
% ============================================================
jointSpec = @(A) abs(fft(A, [], 2));    % FFT along time (dim 2)

%% ============================================================
%  EXAMPLE 1: DIFFUSION (heat kernel evolving in time)
%  u(t) = exp(-kappa * t * L) * delta  (modal form)
%  In eigenbasis: a_k(t) = exp(-kappa * lam_k * t) * a_k(0)
% ============================================================
kappa = 1.0;

% Initial modal coefficients from rhs0:
% For eigenpairs of generalized problem L phi = lam M phi, and M-orthonormal Phi:
a0 = Phi' * rhs0;     % K x 1  (since rhs0 = M*delta)

Adiff = zeros(K, nt);
for it = 1:nt
    Adiff(:,it) = exp(-kappa * lam * t(it)) .* a0;
end

% Back to vertex domain (optional): Udiff = Phi * Adiff;
Udiff = Phi * Adiff;      % nV x nt

% Joint spectrum (diffusion: energy near low f, low lambda)
Jdiff = jointSpec(Adiff);

%% ============================================================
%  EXAMPLE 2: WAVE (time-harmonic, dispersion omega=c*sqrt(lambda))
%  Pick a narrow band of modes near lambda0 and oscillate with omega0.
%  For a single mode k: u(t)=phi_k * cos(omega_k t)
% ============================================================
c = 15.0;                     % wave speed-like parameter (tunes ridge)
k0 = 150;                     % pick a mode index (avoid DC)
omega0 = c*sqrt(lam(k0));      % rad/s
f0 = omega0/(2*pi);

Awave = zeros(K, nt);
Awave(k0,:) = cos(omega0 * t).';    % single-mode oscillation

Uwave = Phi * Awave;
Jwave = jointSpec(Awave);

fprintf('Wave example: mode k0=%d, lambda=%.4g, f0=%.3f Hz\n', k0, lam(k0), f0);

%% ============================================================
%  EXAMPLE 3: WAVE PACKET (bursty, band-limited around (lambda0, f0))
%  Build a packet by exciting a Gaussian band of eigenmodes around k0,
%  and apply a temporal Gaussian envelope (burst) with carrier oscillation.
%
%  This yields a compact "patch" in (lambda, f).
% ============================================================
sigmaK = 25;               % spectral width in mode index (controls spatial localization)
tau    = 0.35;             % burst width (s) -> controls temporal bandwidth
t0     = 1.8;              % burst center time (s)

% Gaussian weights in eigen-index (proxy for lambda-band)
kk = (1:K).';
wK = exp(-0.5*((kk-k0)/sigmaK).^2);
wK = wK / norm(wK);        % normalize energy

% Carrier frequency: choose consistent with dispersion at lambda(k0)
omegaC = omega0;

% Temporal envelope * carrier
env = exp(-0.5*((t - t0)/tau).^2);     % nt x 1
car = cos(omegaC * t);                % nt x 1
burst = (env .* car).';               % 1 x nt

Apack = (wK) * burst;                 % K x nt  (rank-1 packet in joint domain)

% Optional: add phase offsets across modes to mimic traveling packet behavior
% (simple toy: linear phase vs mode index)
phaseSlope = 0.15;                    % tweak
Apack = Apack .* exp(1i * phaseSlope * (kk-k0));   % complex amplitudes

% Bring back to vertex domain (complex)
Upack = Phi * Apack;                   % nV x nt (complex)

Jpack = jointSpec(Apack);

%% ============================================================
%  VISUAL CHECKS (optional): show example fields at a few times
% ============================================================
viewer = bct.ui.show(M);
viewer.setMesh(M)
% pick snapshot time indices
it1 = round(0.5*Fs);     % 0.5s
it2 = round(1.8*Fs);     % burst center ~t0
it3 = round(3.0*Fs);     % later

% Diffusion snapshot (should be smooth blob)
viewer.setScalar(Udiff(:,it1));  title(sprintf('Diffusion u(t=%.2f)', t(it1)));

% Wave snapshot (single mode oscillation)
viewer.setScalar(Uwave(:,it1)); title(sprintf('Wave u(t=%.2f)', t(it1)));

% Packet snapshot (take real part)
viewer.setScalar(real(Upack(:,it2))); title(sprintf('Packet Re(u)(t=%.2f)', t(it2)));

%% ============================================================
%  JOINT SPECTRUM VISUALIZATION (lambda x f)
%  Use imagesc with log scaling; restrict to f<=Fs/2 for readability.
% ============================================================
fMax = Fs/2;
fMask = (f <= fMax);
Fplot = f(fMask);

% Convert lambda axis to something monotone (already is)
Lplot = lam;

figure('Name','Joint spectra'); clf;

subplot(1,3,1);
imagesc(Fplot, Lplot, log10(Jdiff(:,fMask)+1e-12));
axis xy; xlabel('f (Hz)'); ylabel('\lambda'); title('Diffusion: log|X(\lambda,f)|');
colorbar;

subplot(1,3,2);
imagesc(Fplot, Lplot, log10(Jwave(:,fMask)+1e-12));
axis xy; xlabel('f (Hz)'); ylabel('\lambda'); title('Wave: log|X(\lambda,f)|');
colorbar;

subplot(1,3,3);
imagesc(Fplot, Lplot, log10(Jpack(:,fMask)+1e-12));
axis xy; xlabel('f (Hz)'); ylabel('\lambda'); title('Wave packet: log|X(\lambda,f)|');
colorbar;

%% ============================================================
%  EXPECTED SIGNATURES (what you should see)
%  - Diffusion: energy concentrated at low f, low lambda; no ridge.
%  - Wave: energy concentrated near one temporal frequency f0 and one lambda(k0)
%          (a bright spot, or a thin horizontal line if you excite multiple modes).
%  - Packet: localized patch around (lambda0, f0) with broader f spread (burst).
% ============================================================
