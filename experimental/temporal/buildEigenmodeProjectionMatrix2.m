%% Eigenmode projection matrix
%
%  Single-subject script that:
%    1) Loads subject data (provenance, eigen, bands)
%    2) Builds windowed access to CWT band data via matfile
%    3) Applies eigen to a windowed band for eigenmode power spectrum
%
%  Prerequisite: run buildEigenProjection() once per subject to create eigen.mat

%% 1) Load subject data
analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
subjectName  = "sub-0002";
subjectPath  = fullfile(analysisRoot, subjectName);
load("Z:\brainstorm_protocols_analysis\TutorialOmega2\group\fsaverage5.mat");

meta  = load(fullfile(subjectPath, "provenance.mat")).provenance;
eigen = load(fullfile(subjectPath, "eigen.mat")).eigen;

fprintf('Subject:  %s\n', subjectName);
fprintf('Eigen:    lh [%d × %d],  rh [%d × %d]\n', ...
    size(eigen.lh.imagingKernel), size(eigen.rh.imagingKernel));
fprintf('Signal:   %d samples at %.0f Hz (%.1f s)\n', ...
    meta.nSamples, meta.sfreq, meta.nSamples / meta.sfreq);

%% 2) Make windowed datastore over bands.mat

[segDs, winTbl] = makeWindowedDatastore( ...
    fullfile(subjectPath, "bands.mat"), meta.sfreq, meta.nSamples, ...
    WindowSec=20);

%% Load first window
reset(segDs);
w1 = read(segDs);

size(w1.X)         % expected: 270 x 12000 x 5
w1.window          % expected: 1
w1.tStartSec       % expected: 0

%% 3) Apply eigen to a windowed band
%
%   w1.X is [nChannels × winSamp × nBands]
%   bandIdx 3 = alpha  →  squeeze(w1.X(:,:,3)) is [nChannels × winSamp]

bandIdx = 3;  % alpha
alphaSensor = squeeze(w1.X(:, :, bandIdx));

coeffsL = eigen.lh.imagingKernel * alphaSensor;    % [nModesL × winSamp]
coeffsR = eigen.rh.imagingKernel * alphaSensor;    % [nModesR × winSamp]

% Eigenmode power spectrum (time-averaged squared coefficients)
modePowerL = mean(coeffsL.^2, 2);
modePowerR = mean(coeffsR.^2, 2);

fprintf('Alpha-band eigenmode power (window %d, %.1f–%.1f s):\n', ...
    w1.window, w1.tStartSec, w1.tStopSec);
[maxPowerL, maxModeL] = max(modePowerL);
[maxPowerR, maxModeR] = max(modePowerR);
fprintf('  lh: max=%.4g at mode %d (eigenvalue=%.2f)\n', ...
    maxPowerL, maxModeL, eigen.lh.eigenvalues(maxModeL));
fprintf('  rh: max=%.4g at mode %d (eigenvalue=%.2f)\n', ...
    maxPowerR, maxModeR, eigen.rh.eigenvalues(maxModeR));

%% 4) Explore the eigenspectrum

% Power spectrum: mean |c_k|^2 vs mode index (linear + log scale)
plotEigenSpectrum(coeffsL, coeffsR, ...
    eigen.lh.eigenvalues, eigen.rh.eigenvalues);

plotEigenSpectrum(coeffsL, coeffsR, ...
    eigen.lh.eigenvalues, eigen.rh.eigenvalues, ...
    Scale="semilogy", XAxis="eigenvalue", ...
    Title="Alpha Power vs Eigenvalue (log scale)");

% Time courses of selected modes
plotEigenTimeCourse(coeffsL, coeffsR, ...
    eigen.lh.eigenvalues, eigen.rh.eigenvalues, meta.sfreq, ...
    Modes=[1 2 3 5 10 20 50], TStartSec=w1.tStartSec);

% Spectrogram: mode × time energy map (decimated for readability)
plotEigenSpectrogram(coeffsL, coeffsR, ...
    eigen.lh.eigenvalues, eigen.rh.eigenvalues, meta.sfreq, ...
    MaxModes=100, Decimate=60, TStartSec=w1.tStartSec, ...
    Title="Alpha Eigenmode Spectrogram");

%%
