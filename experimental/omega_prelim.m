%% Project raw MEG data to the REPAIRED LEFT HEMISPHERE mesh (script)
% Inputs assumed in workspace:
%   cortex15k  (Brainstorm surface struct: Vertices [15002x3], Faces, etc.)
%   dSPM       (struct with ImagingKernel [15002x270], GoodChannel [1x270], etc.)
%   raw100     (struct with F [300x60000])
%
% Outputs:
%   lMesh            repaired LH surfaceMesh
%   rep2fullL        mapping from repaired LH vertex -> full cortex vertex index (1..15002)
%   IKL_repaired     [nL x 270] kernel aligned with lMesh.Vertices
%   SL               [nL x nTime] source time series on repaired LH vertices
%   (optional) Sfull_L [15002 x nTime] full-cortex source, only repaired LH nonzero

%% ------------------- USER SETTINGS -------------------
tol = 1e-12;                 % coordinate match tolerance for knn (adjust if needed)
makeFullMaskedSource = true; % also compute 15002 x T masked source map
load("C:\Users\diell\OneDrive\Documents\preliminary_omega_sub0002.mat")
%% ------------------- INPUTS -------------------
IK = dSPM.ImagingKernel;          % [15002 x 270]
V  = cortex15k.Vertices;          % [15002 x 3]
F  = cortex15k.Faces;             % [nF x 3]

Fraw_full = raw100.F;             % [300 x nTime]
iChanKernel = dSPM.GoodChannel(:);% [270 x 1] indices into raw channels

nFull = size(V,1);
nK    = size(IK,2);
nTime = size(Fraw_full,2);

%% ------------------- CHANNEL ALIGNMENT -------------------
if numel(iChanKernel) ~= nK
    error('dSPM.GoodChannel has %d entries but kernel expects %d.', numel(iChanKernel), nK);
end
if size(Fraw_full,1) < max(iChanKernel)
    error('raw100.F has only %d channels but GoodChannel references channel %d.', size(Fraw_full,1), max(iChanKernel));
end

% Select the 270 channels used by the inverse solution
Fraw = Fraw_full(iChanKernel, :);    % [270 x nTime]

%% ------------------- HEMISPLIT (FULL INDEX SPACE) -------------------
[rH, lH] = tess_hemisplit(cortex15k);
rH = rH(:); lH = lH(:);

%% ------------------- BUILD LH SUBMESH (STORE MAPPINGS!) -------------------
hemiMask = false(nFull,1);
hemiMask(lH) = true;

keepFace = hemiMask(F(:,1)) & hemiMask(F(:,2)) & hemiMask(F(:,3));
Fkeep_full = F(keepFace,:);                 % faces in FULL vertex indexing

usedVertsL_full = unique(Fkeep_full(:));    % FULL vertex ids used by LH faces

% Map: LH-submesh index -> FULL vertex id
new2oldL_full = usedVertsL_full(:);

% Map: FULL vertex id -> LH-submesh index (0 if not used)
old2newL = zeros(nFull,1);
old2newL(usedVertsL_full) = 1:numel(usedVertsL_full);

% LH submesh arrays
Vl = V(usedVertsL_full,:);
Fl = old2newL(Fkeep_full);

%% ------------------- REPAIR LH MESH USING MATLAB TOOLS -------------------
lMesh = surfaceMesh(Vl, int32(Fl));

removeDefects(lMesh,"duplicate-faces");
removeDefects(lMesh,"degenerate-faces");
removeDefects(lMesh,"duplicate-vertices");
removeDefects(lMesh,"unreferenced-vertices");
removeDefects(lMesh,"nonmanifold-edges");
removeDefects(lMesh,"degenerate-faces");
removeDefects(lMesh,"unreferenced-vertices");

% Optional checks
allowBoundaryEdges = false;
fprintf('LH edge-manifold (no boundary allowed): %d\n', isEdgeManifold(lMesh, allowBoundaryEdges));
fprintf('LH vertex-manifold: %d\n', isVertexManifold(lMesh));
fprintf('LH watertight: %d\n', isWatertight(lMesh));

%% ------------------- MAP REPAIRED LH VERTICES -> FULL CORTEX VERTICES -------------------
% rep2oldL_sub: repaired LH vertex index -> LH-submesh vertex index
rep2oldL_sub = knnsearch(Vl, lMesh.Vertices);

d = vecnorm(Vl(rep2oldL_sub,:) - lMesh.Vertices, 2, 2);
if any(d > tol)
    warning('Vertex mapping exceeds tol. max(d)=%g (increase tol if needed).', max(d));
end

% rep2fullL: repaired LH vertex index -> FULL cortex vertex index (1..15002)
rep2fullL = new2oldL_full(rep2oldL_sub);

% For your bookkeeping (which LH-submesh vertices were removed)
keptL_sub = unique(rep2oldL_sub);
removedVertIdxL_sub  = setdiff((1:size(Vl,1))', keptL_sub);
removedVertIdxL_full = new2oldL_full(removedVertIdxL_sub);

fprintf('LH vertices before repair (submesh): %d\n', size(Vl,1));
fprintf('LH vertices after repair  (repaired): %d\n', size(lMesh.Vertices,1));
fprintf('LH removed vertices (submesh): %d\n', numel(removedVertIdxL_sub));
fprintf('LH removed vertices (full): %d\n', numel(removedVertIdxL_full));

%% ------------------- BUILD REPAIRED LH IMAGING KERNEL (COMPACT) -------------------
IKL_repaired = IK(rep2fullL, :);       % [nL x 270], aligned with lMesh.Vertices

%% ------------------- PROJECT TO REPAIRED LH SOURCES -------------------
% SL: [nL x nTime]
SL = IKL_repaired * Fraw;

fprintf('Projected SL size: %d x %d\n', size(SL,1), size(SL,2));

%% ------------------- OPTIONAL: FULL-CORTEX MASKED SOURCE MAP -------------------
if makeFullMaskedSource
    keepFullL = false(nFull,1);
    keepFullL(rep2fullL) = true;       % keep ONLY repaired LH vertices in full indexing

    IK_masked = IK;
    IK_masked(~keepFullL,:) = 0;

    Sfull_L = IK_masked * Fraw;        % [15002 x nTime], only repaired LH nonzero
    fprintf('Full-cortex masked source size: %d x %d\n', size(Sfull_L,1), size(Sfull_L,2));
end

%% ------------------- OPTIONAL: Verify time alignment -------------------
if isfield(dSPM,'Time') && isfield(raw100,'Time')
    if numel(dSPM.Time) == numel(raw100.Time)
        dt = max(abs(dSPM.Time - raw100.Time));
        fprintf('Max |dSPM.Time - raw100.Time| = %g s\n', dt);
    else
        fprintf('Time vectors differ in length: dSPM=%d, raw100=%d\n', numel(dSPM.Time), numel(raw100.Time));
    end
end

%%
Mbst=bct.Manifold(lMesh.Vertices, lMesh.Faces);
%Mf=M.flip;clear(M);M=Mf;
topo = Mbst.topology;
geom = Mbst.geometry;
ops=Mbst.operators;
eigen=Mbst.eigenmodes(2500);
eigen2500=eigen;
eigen=Mbst.eigenmodes(5000);
%% Eigenspectrum of SL in Laplace–Beltrami basis (mass-weighted)
% Assumes in workspace:
%   SL                          [7497 x nT]
%   eigen.eigenvectors.value    Phi [7497 x 1000]
%   eigen.eigenvalues.value     lam [1000 x 1]
%   ops.mass.value              M   [7497 x 7497] sparse diagonal
% 
% Phi = eigen.eigenvectors.value;     % [nV x K]
% lam = eigen.eigenvalues.value;      % [K x 1]
% M   = ops.mass.value;               % [nV x nV] sparse diagonal (nnz = nV)
% 
% [nV,K] = size(Phi);
% nT = size(SL,2);
% 
% %% --- Fast diagonal mass apply: w = diag(M), M*SL = w .* SL ---
% w = full(diag(M));                  % [nV x 1]
%     if numel(w) ~= nV
%         error('Mass diagonal length mismatch.');
%     end
% 
% MSL  = SL .* w;                     % [nV x nT]
% Shat = Phi' * MSL;                  % [K x nT] spectral coefficients


%% Build mode-space imaging kernel and project directly to eigenmodes

Phi = eigen.eigenvectors.value;    % [nV x K]
lam = eigen.eigenvalues.value;    
M   = ops.mass.value;              % [nV x nV] sparse diagonal
Kvx = IKL_repaired;                % [nV x nC]  (nC = 270)
Y   = Fraw;                        % [nC x nT]

% Efficient diagonal mass apply
w = full(diag(M));                 % [nV x 1]

% Compute Kmode = Phi' * M * Kvx, but use w .* Kvx instead of M*Kvx
MK = Kvx .* w;                     % [nV x nC]
Kmode = Phi' * MK;                 % [K x nC]

% Direct eigenmode time series (no need to compute SL)
Shat = Kmode * Y;                  % [K x nT]

%% --- Time-averaged spectrum ---
Pavg = mean(abs(Shat).^2, 2);       % [K x 1]
[nV,K] = size(Phi);
nT = size(Shat,2);

%% --- Plot power vs mode index ---
figure(1);
subplot(221)
plot(1:K, Pavg, 'LineWidth', 1);
xlabel('Eigenmode index'); ylabel('Mean |coef|^2');
title('Time-averaged Laplace–Beltrami eigenspectrum');
subplot (222)
plot(lam, Pavg, '.-');
xlabel('\lambda (1/area)'); ylabel('Mean |coef|^2');
title('Time-averaged power vs Laplace–Beltrami eigenvalue');
% --- Optional: cumulative energy (how many modes explain signal energy?) ---
cumE = cumsum(Pavg) / sum(Pavg);
subplot(223)
plot(1:K, cumE, 'LineWidth', 1);
xlabel('Eigenmode index'); ylabel('Cumulative energy');
title('Cumulative energy of SL in LB basis');
grid on;
% --- Optional: normalize spectrum (compare across subjects/conditions) ---
Pavg_norm = Pavg / sum(Pavg);
subplot(224)
plot(lam, Pavg_norm, '.-');
xlabel('\lambda (1/area)'); ylabel('Normalized mean power');
title('Normalized time-averaged spectral power vs eigenvalue');

%% Joint eigenmode-frequency spectrum (JFT on manifold x time)
% sampling rate
if exist('raw100','var') && isfield(raw100,'Time')
    dt = raw100.Time(2) - raw100.Time(1);
elseif exist('dSPM','var') && isfield(dSPM,'Time')
    dt = dSPM.Time(2) - dSPM.Time(1);
else
    error('Need Time vector (raw100.Time or dSPM.Time) to infer sampling rate.');
end
Fs = 1/dt;

%% Windowed joint eigenmode-frequency spectrum (4-second windows)
% Assumes:
%   SL   [nV x nT]
%   eigen.eigenvectors.value  Phi [nV x K]
%   eigen.eigenvalues.value   lam [K x 1]
%   ops.mass.value            M   [nV x nV] sparse diagonal (nnz=nV)
%   raw100.Time or dSPM.Time present

%% 1) Spatial projection: Shat(k,t) = Phi' * M * SL
% w = full(diag(M));                   % [nV x 1]
% Shat = Phi' * (SL .* w);             % [K x nT]

%% 2) Window parameters (4 seconds)
winSec = 4.0;
hopSec = 1.0;                        % change hop if you want (e.g., 0.5 or 2.0)

win = max(1, round(winSec * Fs));    % samples
hop = max(1, round(hopSec * Fs));    % samples

idx0 = 1:hop:(nT - win + 1);
nWin = numel(idx0);

% Window function (recommended to reduce leakage)
wtime = hann(win, 'periodic');       % [win x 1]
wtime = wtime(:)';

%% 3) FFT settings
Nfft = 2^nextpow2(win);              % FFT length per window
freq = (0:Nfft-1) * (Fs/Nfft);
nKeep = floor(Nfft/2) + 1;
freq = freq(1:nKeep);

% Accumulators for average power over windows
Jpow_avg = zeros(K, nKeep);          % [K x nFreq]

% Optional: store per-window power (large: K x nFreq x nWin)
storeCube = false;
if storeCube
    Jpow_cube = zeros(K, nKeep, nWin);
end

tWin = zeros(1,nWin);                % window start time (s)

%% 4) Loop windows: FFT along time for each mode
for i = 1:nWin
    ii = idx0(i):(idx0(i)+win-1);
    tWin(i) = (ii(1)-1) * dt;

    X = Shat(:, ii);                 % [K x win]
    X = X .* wtime;                  % apply Hann window

    Fcoef = fft(X, Nfft, 2);         % [K x Nfft]
    Fcoef = Fcoef(:,1:nKeep);        % one-sided

    Jpow = abs(Fcoef).^2;            % [K x nFreq]

    % accumulate average
    Jpow_avg = Jpow_avg + Jpow;

    if storeCube
        Jpow_cube(:,:,i) = Jpow;
    end
end

Jpow_avg = Jpow_avg / nWin;

%% 5) Visualize average joint power using eigenvalues as y-axis
figure;
imagesc(freq, lam, log10(Jpow_avg + eps));
axis xy;
xlabel('Frequency (Hz)');
ylabel('\lambda (1/area)');
title(sprintf('Windowed joint spectrum (avg over %d windows): win=%.1fs hop=%.1fs', nWin, winSec, hopSec));
colorbar;
xlim([0 60])
%%

epsPlot = 1e-30;                     % avoid eps saturation effects
Z = log10(Jpow_avg + epsPlot);
Z = log10(Jpow + epsPlot);

figure;
imagesc(freq, lam, Z);
axis xy;
xlabel('Frequency (Hz)');
ylabel('\lambda');
title(sprintf('Windowed joint spectrum (avg over %d windows)', nWin));
colorbar;
xlim([0 60]);

% optional: tighten dynamic range so low-power regions don't dominate
caxis([prctile(Z(:),5) prctile(Z(:),99)]);
%%
fprintf('Jpow_avg min/max = %.3e / %.3e\n', min(Jpow_avg(:)), max(Jpow_avg(:)));
fprintf('Any negative in Jpow_avg? %d\n', any(Jpow_avg(:) < 0));
fprintf('Most negative value = %.3e\n', min(Jpow_avg(:)));

fprintf('Any NaN? %d  Any Inf? %d\n', any(isnan(Jpow_avg(:))), any(isinf(Jpow_avg(:))));
%%
ell_mm = 1e3*(2*pi) ./ sqrt(lam);              % [K x 1] mm (will inf/huge for small lam)

% Exclude near-DC modes (pick one)
lambdaMin = 1e-6;                               % 1/m^2 (tune; this is conservative)
keep = lam > lambdaMin;

ell_use = ell_mm(keep);
J_use   = Jpow_avg(keep, :);
J_use   = Jpow(keep, :);

% Sort by wavelength increasing
[ell_sorted, idx] = sort(ell_use, 'ascend');
J_sorted = J_use(idx, :);

figure;
imagesc(freq, ell_sorted, log10(J_sorted + eps));
axis xy;
xlabel('Frequency (Hz)');
ylabel('Effective wavelength (mm)');
title('Joint spectrum (DC removed): log10 power vs frequency and wavelength');
colorbar;
xlim([0 60])

%% Clipped to domain size

lam = eigen.eigenvalues.value;
ell_mm = 1e3*(2*pi) ./ sqrt(lam);

% Domain-based cap
A = full(sum(diag(ops.mass.value)));   % m^2
R = sqrt(A/(4*pi));                    % m
ellMax = 1e3*(pi*R);                   % mm (global scale cap)

ellMin = 5;                            % mm (or 10)
keep = isfinite(ell_mm) & (ell_mm >= ellMin) & (ell_mm <= ellMax);

ell_use = ell_mm(keep);
J_use   = Jpow_avg(keep,:);

% Choose orientation:
% bottom=coarse, top=fine (common expectation)
[ell_sorted, idx] = sort(ell_use, 'ascend');
J_sorted = J_use(idx,:);

figure;
imagesc(freq, ell_sorted, log10(J_sorted + eps));
axis xy;
xlabel('Frequency (Hz)');
ylabel('Effective wavelength (mm)');
title(sprintf('Joint spectrum (wavelength %.0f–%.0f mm)', ellMin, ellMax));
colorbar;
xlim([0 60]);

%% Characteristic length scale

lam = eigen.eigenvalues.value;          % [K x 1] 1/m^2
L_mm = 1e3 ./ sqrt(max(lam, eps));      % [K x 1] mm

% Remove DC/near-DC (otherwise L_mm explodes)
lambdaMin = 1e-6;                        % 1/m^2 (tune if needed)
keep = isfinite(L_mm) & (lam > lambdaMin);

L_use = L_mm(keep);
J_use = Jpow_avg(keep,:);

% Optional: cap to domain-relevant scales
Lmin = min(L_use);     % mm
Lmax = max(L_use);   % mm (set based on what you want to visualize)
keep2 = (L_use >= Lmin) & (L_use <= Lmax);
    L_use = L_use(keep2);
    J_use = J_use(keep2,:);

% Sort for display convention:
% Option A: bottom=coarse (large L), top=fine (small L)
[L_sorted, idx] = sort(L_use, 'descend');
J_sorted = J_use(idx,:);

figure;
imagesc(freq, L_sorted, log10(J_sorted + eps));
axis xy;
xlabel('Frequency (Hz)');
ylabel('Characteristic length scale L = 1/sqrt(\lambda) (mm)');
title(sprintf('Joint spectrum: log10 power vs frequency and spatial scale (%.0f–%.0f mm)', Lmin, Lmax));
colorbar;
xlim([0 60]);


%%
lam = eigen.eigenvalues.value;
ell_mm = 1e3*(2*pi) ./ sqrt(max(lam, eps));

% Sort by wavelength
[ell_sorted, idx] = sort(ell_mm, 'ascend');
J_sorted = Jpow_avg(idx,:);

figure;
imagesc(freq, log10(ell_sorted), log10(J_sorted + eps));
axis xy;
xlabel('Frequency (Hz)');
ylabel('log10 wavelength (mm)');
title('Joint spectrum: log10 power vs frequency and log10 wavelength');
colorbar;
%% Binned joined spectrum
lam = eigen.eigenvalues.value;
ell_mm = 1e3 * (2*pi) ./ sqrt(max(lam, eps));

% Choose bins (example)
edges = [5 7.5 10 15 20 30 40 60 80 120];   % mm
nB = numel(edges)-1;

Jbin = zeros(nB, size(Jpow_avg,2));
ell_cent = 0.5*(edges(1:end-1) + edges(2:end));

for b = 1:nB
    m = (ell_mm >= edges(b)) & (ell_mm < edges(b+1));
    if any(m)
        Jbin(b,:) = mean(Jpow_avg(m,:), 1);   % or sum(...)
    else
        Jbin(b,:) = NaN;
    end
end

figure;
imagesc(freq, ell_cent, log10(Jbin + eps));
axis xy;
xlabel('Frequency (Hz)');
ylabel('Wavelength bin center (mm)');
title('Binned joint spectrum: log10 mean power');
colorbar;
xlim([0 60]);
clim([-4 2])

%%
P = Jpow_avg;                          % [K x nFreq]
Pnorm_f = P ./ (sum(P,1) + eps);       % each column sums to 1
figure;
imagesc(freq, lam, log10(Pnorm_f + eps));
axis xy;
xlabel('Frequency (Hz)');
ylabel('\lambda (1/m^2)');
title('Per-frequency normalized joint spectrum: log10(P / sum_k P)');
colorbar;
xlim([0 60]);
clim([-4 2])
%%
P = Jpow_avg;          
Pnorm_k = P ./ (sum(P,2) + eps);       % each row sums to 1
logP = log10(P + eps);
logP_detr = logP - median(logP, 2);    % subtract median across freq for each mode
                % [K x nFreq]
figure;
imagesc(freq, lam, log10(Pnorm_k + eps));
axis xy;
xlabel('Frequency (Hz)');
ylabel('\lambda (1/m^2)');
title('Per-frequency normalized joint spectrum: log10(P / sum_k P)');
colorbar;
xlim([0 60]);

%%
find(pmean>60)
pmean=mean(Pnorm_k, 1);
figure
plot(freq,pmean)
xlim([0 60])
P = Jpow_avg;   
pfmean=mean(Pnorm_k(50:90,:), 2);
figure
plot(pfmean)

%%
viewer=bct.ui.show(Mbst);
viewer.setScalar(SL(:,2));

Manat=bct.Manifold (cortex15k.Vertices, cortex15k.Faces);
topo = Manat.topology;
geom = Manat.geometry;
ops=Mbst.operators;
eigen=Mbst.eigenmodes(2500);

Mesh = surfaceMesh(Manat.Vertices, Manat.Faces);

removeDefects(Mesh,"duplicate-faces");
removeDefects(Mesh,"degenerate-faces");
removeDefects(Mesh,"duplicate-vertices");
removeDefects(Mesh,"unreferenced-vertices");
removeDefects(Mesh,"nonmanifold-edges");
removeDefects(Mesh,"degenerate-faces");
removeDefects(Mesh,"unreferenced-vertices");

% Optional checks
allowBoundaryEdges = false;
fprintf('LH edge-manifold (no boundary allowed): %d\n', isEdgeManifold(Mesh, allowBoundaryEdges));
fprintf('LH vertex-manifold: %d\n', isVertexManifold(Mesh));
fprintf('LH watertight: %d\n', isWatertight(Mesh));

%% ------------------- MAP REPAIRED LH VERTICES -> FULL CORTEX VERTICES -------------------
% rep2oldL_sub: repaired LH vertex index -> LH-submesh vertex index
rep2oldL_sub = knnsearch(Manat.Vertices, Mesh.Vertices);

d = vecnorm(Manat.Vertices(rep2oldL_sub,:) - Mesh.Vertices, 2, 2);
if any(d > tol)
    warning('Vertex mapping exceeds tol. max(d)=%g (increase tol if needed).', max(d));
end

% rep2fullL: repaired LH vertex index -> FULL cortex vertex index (1..15002)
rep2fullL = new2oldL_full(rep2oldL_sub);

% For your bookkeeping (which LH-submesh vertices were removed)
keptL_sub = unique(rep2oldL_sub);
removedVertIdxL_sub  = setdiff((1:size(Vl,1))', keptL_sub);
removedVertIdxL_full = new2oldL_full(removedVertIdxL_sub);

fprintf('LH vertices before repair (submesh): %d\n', size(Vl,1));
fprintf('LH vertices after repair  (repaired): %d\n', size(lMesh.Vertices,1));
fprintf('LH removed vertices (submesh): %d\n', numel(removedVertIdxL_sub));
fprintf('LH removed vertices (full): %d\n', numel(removedVertIdxL_full));

%% Wave packet filter

% Apply a wave packet filter to the joint spectrum
wavePacketFilter = designWavePacketFilter(); % Assuming a function to design the filter
filteredSpectrum = wavePacketFilter * Jpow_avg; % Apply the filter to the joint spectrum

%%
