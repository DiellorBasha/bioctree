%% Eigenmode surface-band analysis (step-by-step projection, multi-window)
%
%  Single-subject script that:
%    1) Loads subject data (provenance, kernel, fsaverage5, bands)
%    2) Builds the projection chain step-by-step:
%         K:  sensor → subject sources
%         W:  subject sources → fsaverage vertices
%         U'M: fsaverage vertices → eigenmode coefficients
%    3) Loops over all windows, applying the chain at each step and
%       accumulating a time-averaged eigenmode power spectrum per band
%    4) Visualizes the per-band eigenmode decomposition
%
%  This script performs the SAME mathematical computation as
%  eigenmodeSignedBandAnalysis.m, but executes each matrix multiply
%  separately instead of using the precomposed eigen.imagingKernel.
%  Use this to verify that the precomposed QK = U'*M*W*K gives identical
%  results to the step-by-step chain.
%
%  Chain (per hemisphere):
%      sensorData    [nCh × T]
%      → K * sensor  [nSrc × T]          source reconstruction
%      → W * sources [nDest × T]         project to fsaverage
%      → U'*M * fsav [nModes × T]        eigenmode decomposition

%% 1) Load subject data & build projection matrices
analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
subjectName  = "sub-0002";
subjectPath  = fullfile(analysisRoot, subjectName);

% ---- Subject provenance & imaging kernel ----
meta = load(fullfile(subjectPath, "provenance.mat")).provenance;
K    = load(fullfile(subjectPath, "ImagingKernel.mat")).K;   % [nSrc × nCh]

% ---- fsaverage5 (eigenmodes + mass + sphere) ----
load(fullfile(analysisRoot, "group", "fsaverage5.mat"));

% ---- Build sphere interpolation W using Reg/Atlas from provenance ----
[W, projInfo] = buildProjectionMatrix(meta, ...
    fsaverage5.lh.sphere, fsaverage5.rh.sphere);   % [nDestTotal × nSrc]

% ---- Split W into hemispheres ----
W_lh = W(1:projInfo.nDestL, :);           % [nDestL × nSrc]
W_rh = W(projInfo.nDestL+1:end, :);       % [nDestR × nSrc]

% ---- Pre-compose U'*M per hemisphere (does NOT include W or K) ----
UM_lh = fsaverage5.lh.eigen.eigenvectors.value' * fsaverage5.lh.ops.mass.value;  % [kL × nDestL]
UM_rh = fsaverage5.rh.eigen.eigenvectors.value' * fsaverage5.rh.ops.mass.value;  % [kR × nDestR]

eigenvaluesL = fsaverage5.lh.eigen.eigenvalues.value(:);
eigenvaluesR = fsaverage5.rh.eigen.eigenvalues.value(:);
nModesL = numel(eigenvaluesL);
nModesR = numel(eigenvaluesR);

bandNames = ["delta", "theta", "alpha", "beta", "gamma1"];
nBands    = numel(bandNames);

fprintf('Subject:      %s\n', subjectName);
fprintf('K:            [%d × %d]\n', size(K));
fprintf('W:            lh [%d × %d],  rh [%d × %d]\n', size(W_lh), size(W_rh));
fprintf('U''M:          lh [%d × %d],  rh [%d × %d]\n', size(UM_lh), size(UM_rh));
fprintf('Signal:       %d samples at %.0f Hz (%.1f s)\n', ...
    meta.nSamples, meta.sfreq, meta.nSamples / meta.sfreq);
fprintf('Bands:        %s\n', strjoin(bandNames, ", "));

%% 2) Make windowed datastore over bands.mat

[segDs, winTbl] = makeWindowedDatastore( ...
    fullfile(subjectPath, "bands.mat"), meta.sfreq, meta.nSamples, ...
    WindowSec=20);

nWindows = height(winTbl);
fprintf('Windows:      %d × %.0f s\n', nWindows, winTbl.durationSec(1));

%% 3) Loop over windows: step-by-step projection → accumulate
%
%   For each window and each band:
%     1) Extract band signal:           S = squeeze(w.X(:,:,b))   [nCh × T]
%     2) Source reconstruction:         src = K * S               [nSrc × T]
%     3) Project to fsaverage:          fsL = W_lh * src          [nDestL × T]
%                                       fsR = W_rh * src          [nDestR × T]
%     4) Eigenmode decomposition:       cL = UM_lh * fsL          [kL × T]
%                                       cR = UM_rh * fsR          [kR × T]
%     5) Accumulate mean(c.^2, 2)

sumPowerL = zeros(nModesL, nBands);
sumPowerR = zeros(nModesR, nBands);

reset(segDs);
winCount = 0;

while hasdata(segDs)
    w = read(segDs);
    winCount = winCount + 1;

    for bi = 1:nBands
        bandSignal = squeeze(w.X(:, :, bi));     % [nCh × T]

        % Step 1: sensor → subject sources
        sources = K * bandSignal;                 % [nSrc × T]

        % Step 1b: amplitude envelope in source space (Hilbert)
        sources = abs(hilbert(sources'))';         % [nSrc × T]

        % Step 2: subject sources → fsaverage vertices
        fsavgL = W_lh * sources;                  % [nDestL × T]
        fsavgR = W_rh * sources;                  % [nDestR × T]

        % Step 3: fsaverage vertices → eigenmode coefficients
        cL = UM_lh * fsavgL;                      % [kL × T]
        cR = UM_rh * fsavgR;                      % [kR × T]

        sumPowerL(:, bi) = sumPowerL(:, bi) + mean(cL.^2, 2);
        sumPowerR(:, bi) = sumPowerR(:, bi) + mean(cR.^2, 2);
    end

    fprintf('  Window %2d / %d  (%.1f–%.1f s)\n', ...
        winCount, nWindows, w.tStartSec, w.tStopSec);
end

avgPowerL = sumPowerL / winCount;   % [nModesL × nBands]
avgPowerR = sumPowerR / winCount;   % [nModesR × nBands]

fprintf('Processed %d windows across %d bands.\n', winCount, nBands);

%% 4) Visualize per-band time-averaged eigenspectra

% ---- All bands overlaid (per hemisphere) ----
plotEnvelopeEigenSpectrumAllBands(avgPowerL, avgPowerR, ...
    eigenvaluesL, eigenvaluesR, bandNames, ...
    Title=sprintf("Surface Eigenspectrum — %s (%d windows)", subjectName, winCount));

plotEnvelopeEigenSpectrumAllBands(avgPowerL, avgPowerR, ...
    eigenvaluesL, eigenvaluesR, bandNames, ...
    Scale="semilogy", MaxModes=200, ...
    Title=sprintf("Surface Eigenspectrum (log) — %s", subjectName));

% ---- Individual band panels ----
plotEnvelopeEigenSpectrumGrid(avgPowerL, avgPowerR, ...
    eigenvaluesL, eigenvaluesR, bandNames, ...
    MaxModes=200, ...
    Title=sprintf("Per-Band Surface Eigenspectrum — %s", subjectName));

%%
surfaceBandAnalysis.lh = avgPowerL;
surfaceBandAnalysis.rh = avgPowerR;
save(fullfile(subjectPath, "surfaceBandAnalysis.mat"), "surfaceBandAnalysis", "-v7.3");