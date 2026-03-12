%% omega_preilm_fsaverage.m
%  Exploratory script: sensor → spectral-domain source analysis on fsaverage5.
%
%  Pipeline:
%    1. Load fsaverage5 manifolds (with 1000 eigenmodes, pre-saved as zarr)
%    2. Load subject data (provenance, imaging kernel, CWT bands)
%    3. Build vertex projection W*K and spectral projection P
%    4. Project signed CWT band to eigenmode coefficients
%    5. Reconstruct selectable spatial-frequency bands on vertices
%    6. Visualize with SourceExplorer
%
%  Correct operator ordering:
%    CWT (signed) → W·K or P (linear) → hilbert → abs  ✓
%    CWT → hilbert → abs → W·K  ✗  (envelope is nonlinear, K sees only positive)

%% ========================================================================
%  SECTION 1 — PATHS & CONSTANTS
%  ========================================================================

analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
groupPath    = fullfile(analysisRoot, "group");
subjectId    = "sub-0004";
outPath      = fullfile(analysisRoot, subjectId);
fs5root      = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf";

%% ========================================================================
%  SECTION 2 — LOAD FSAVERAGE5 MANIFOLDS (with cached eigenmodes)
%  ========================================================================
%  These zarr files contain V, F, geometry, topology, operators, solvers,
%  and 1000 eigenmodes each — computed once and saved.

Mleft  = bct.file.read.manifold(fullfile(groupPath, "lhfsaverage.zarr"));
Mright = bct.file.read.manifold(fullfile(groupPath, "rhfsaverage.zarr"));

%% ========================================================================
%  SECTION 3 — LOAD SUBJECT DATA
%  ========================================================================

meta = load(fullfile(outPath, "provenance.mat")).provenance;
sfreq = meta.sfreq;  % 600 Hz

% Imaging kernel: maps 270 channels → 10244 subject vertices
K = load(fullfile(outPath, "ImagingKernel.mat")).K;  % [10244 × 270]

% CWT signed band data — fast reload from per-band datastore
%   (Written once by: writeCWTBands(fullfile(outPath,"cwt"), outPath) )
cwtBandsPath = fullfile(outPath, "cwt_bands");
cwtBandsMeta = load(fullfile(cwtBandsPath, "provenance.mat")).provenance;

sds_alpha = signalDatastore(fullfile(cwtBandsPath, "alpha"), SampleRate=sfreq);
[alphaCWT, chanNames, ~] = readBandMatrix(sds_alpha);
% alphaCWT: [270 × 180001]  (signed, sensor-space)

nSamples = size(alphaCWT, 2);
tFull = (0:nSamples-1) / sfreq;  % full time vector in seconds

%% ========================================================================
%  SECTION 4 — BUILD PROJECTION MATRICES (once per subject)
%  ========================================================================

% --- 4a. Vertex projection: W * K  [20484 × 270] ---
[destSphL, ~] = mne_read_surface(fullfile(fs5root, 'lh.sphere.reg'));
[destSphR, ~] = mne_read_surface(fullfile(fs5root, 'rh.sphere.reg'));

[W, projInfo] = buildProjectionMatrix(meta, destSphL, destSphR);
WK = W * K;  % [20484 × 270]

% --- 4b. Spectral projection: P = U' * M * W * K  [2000 × 270] ---
[P, specInfo] = buildSpectralProjection(WK, Mleft, Mright);
% P: [2000 × 270]   (1000 left modes + 1000 right modes)
% specInfo contains: UL, UR, Ublock, lambdaL, lambdaR, kL, kR, ...

%% ========================================================================
%  SECTION 5 — SELECT TIME WINDOW
%  ========================================================================

t1 = 10;  % seconds
t2 = 14;  % seconds
iWin = round(t1 * sfreq) + 1 : round(t2 * sfreq) + 1;
tWin = (iWin - 1) / sfreq;

sensorWin = alphaCWT(:, iWin);  % [270 × nSamp], signed CWT alpha

%% ========================================================================
%  SECTION 6 — PROJECT TO SPECTRAL COEFFICIENTS
%  ========================================================================

% Project sensor data directly to eigenmode coefficients
cSpectral = P * sensorWin;  % [2000 × nSamp]
% Rows 1:1000    = left-hemisphere eigenmode coefficients
% Rows 1001:2000 = right-hemisphere eigenmode coefficients

%% ========================================================================
%  SECTION 7 — RECONSTRUCT FROM EIGENMODES
%  ========================================================================

% --- 7a. Full reconstruction (all 1000 modes, left hemisphere) ---
xFullLeft = reconstructFromModes(specInfo, cSpectral, ...
    'Hemisphere', 'left');
% xFullLeft: [10242 × nSamp]

% --- 7b. Smooth spatial patterns (first 50 modes) ---
xSmooth = reconstructFromModes(specInfo, cSpectral, ...
    'Hemisphere', 'left', 'ModeRange', 50);

% --- 7c. Mid-frequency band (modes 50–200) ---
xMid = reconstructFromModes(specInfo, cSpectral, ...
    'Hemisphere', 'left', 'ModeRange', [50 200]);

% --- 7d. High-frequency band (modes 200–1000) ---
xHigh = reconstructFromModes(specInfo, cSpectral, ...
    'Hemisphere', 'left', 'ModeRange', [200 1000]);

%% ========================================================================
%  SECTION 8 — HILBERT ENVELOPE (optional, in source space)
%  ========================================================================
%  Since we projected the SIGNED CWT band through W·K (linear), we can
%  now safely take the amplitude envelope in source space.

% Envelope of smooth reconstruction
xSmoothEnv = reconstructFromModes(specInfo, cSpectral, ...
    'Hemisphere', 'left', 'ModeRange', 50, 'Envelope', true);

% Envelope of full reconstruction
xFullEnv = reconstructFromModes(specInfo, cSpectral, ...
    'Hemisphere', 'left', 'Envelope', true);

%% ========================================================================
%  SECTION 9 — VISUALIZE WITH SOURCE EXPLORER
%  ========================================================================

% --- 9a. Signed smooth alpha (modes 1:50) ---
ex1 = SourceExplorer(Mleft, xSmooth, tWin, ...
    SensorData=sensorWin, ...
    ChannelNames=chanNames, ...
    TimePoint=12.0, ...
    Title="Alpha signed — modes 1:50");

% --- 9b. Alpha envelope (modes 1:50) ---
ex2 = SourceExplorer(Mleft, xSmoothEnv, tWin, ...
    SensorData=sensorWin, ...
    ChannelNames=chanNames, ...
    TimePoint=12.0, ...
    Title="Alpha envelope — modes 1:50");

% --- 9c. Full reconstruction signed ---
ex3 = SourceExplorer(Mleft, xFullLeft, tWin, ...
    SensorData=sensorWin, ...
    ChannelNames=chanNames, ...
    TimePoint=12.0, ...
    Title="Alpha signed — all 1000 modes");

%% ========================================================================
%  SECTION 10 — COMPARE VERTEX vs SPECTRAL PIPELINE
%  ========================================================================
%  Sanity check: vertex-space WK projection should match full-mode
%  spectral reconstruction (up to numerical precision).

sourceVertexLeft = WK(1:projInfo.nDestL, :) * sensorWin;   % vertex pipeline
xReconAll = reconstructFromModes(specInfo, cSpectral, 'Hemisphere', 'left');  % spectral pipeline

reconError = norm(sourceVertexLeft - xReconAll, 'fro') / norm(sourceVertexLeft, 'fro');
fprintf('Relative reconstruction error (all 1000 modes vs vertex): %.2e\n', reconError);
% Should be ~1e-12 or smaller (machine precision)
