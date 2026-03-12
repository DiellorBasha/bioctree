%% Eigenmode signed-band analysis (multi-window)
%
%  Single-subject script that:
%    1) Loads subject data (provenance, eigen, bands)
%    2) Builds windowed access to CWT band data via matfile
%    3) Loops over all windows, projecting each band's signed signal
%       into eigenmode space and accumulating a time-averaged power spectrum
%    4) Visualizes the per-band eigenmode decomposition
%
%  This script projects the raw signed oscillation (preserving phase) into
%  eigenmodes.  Compare with eigenmodeEnvelopeAnalysis.m which projects the
%  Hilbert amplitude envelope, and eigenmodeFrequencyAnalysis.m which works
%  on broadband data and adds an FFT step.
%
%  Prerequisite: run buildEigenProjection() once per subject to create eigen.mat

%% 1) Load subject data
analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
subjectName  = "sub-0002";
subjectPath  = fullfile(analysisRoot, subjectName);

meta  = load(fullfile(subjectPath, "provenance.mat")).provenance;
eigen = load(fullfile(subjectPath, "eigen.mat")).eigen;

bandNames = ["delta", "theta", "alpha", "beta", "gamma1"];
nBands    = numel(bandNames);

fprintf('Subject:  %s\n', subjectName);
fprintf('Eigen:    lh [%d × %d],  rh [%d × %d]\n', ...
    size(eigen.lh.imagingKernel), size(eigen.rh.imagingKernel));
fprintf('Signal:   %d samples at %.0f Hz (%.1f s)\n', ...
    meta.nSamples, meta.sfreq, meta.nSamples / meta.sfreq);
fprintf('Bands:    %s\n', strjoin(bandNames, ", "));

%% 2) Make windowed datastore over bands.mat

[segDs, winTbl] = makeWindowedDatastore( ...
    fullfile(subjectPath, "bands.mat"), meta.sfreq, meta.nSamples, ...
    WindowSec=20);

nWindows = height(winTbl);
fprintf('Windows:  %d × %.0f s\n', nWindows, winTbl.durationSec(1));

%% 3) Loop over windows: signed projection → accumulate per-band eigenmode power
%
%   For each window and each band:
%     1) Extract band signal:   S = squeeze(w.X(:,:,b))  [nCh × winSamp]
%     2) Project to eigenmodes: c = QK * S               [nModes × winSamp]
%     3) Accumulate mean(c.^2, 2) into running average
%
%   Result: avgPowerL/R [nModes × nBands] — time-averaged eigenmode power per band

nModesL = eigen.lh.nModes;
nModesR = eigen.rh.nModes;
sumPowerL = zeros(nModesL, nBands);
sumPowerR = zeros(nModesR, nBands);

reset(segDs);
winCount = 0;

while hasdata(segDs)
    w = read(segDs);
    winCount = winCount + 1;

    for bi = 1:nBands
        bandSignal = squeeze(w.X(:, :, bi));             % [nCh × winSamp]

        cL = eigen.lh.imagingKernel * bandSignal;         % [nModesL × winSamp]
        cR = eigen.rh.imagingKernel * bandSignal;         % [nModesR × winSamp]

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
    eigen.lh.eigenvalues, eigen.rh.eigenvalues, bandNames, ...
    Title=sprintf("Signed Eigenspectrum — %s (%d windows)", subjectName, winCount));

plotEnvelopeEigenSpectrumAllBands(avgPowerL, avgPowerR, ...
    eigen.lh.eigenvalues, eigen.rh.eigenvalues, bandNames, ...
    Scale="semilogy", MaxModes=200, ...
    Title=sprintf("Signed Eigenspectrum (log) — %s", subjectName));

% ---- Individual band panels ----
plotEnvelopeEigenSpectrumGrid(avgPowerL, avgPowerR, ...
    eigen.lh.eigenvalues, eigen.rh.eigenvalues, bandNames, ...
    MaxModes=200, ...
    Title=sprintf("Per-Band Signed Eigenspectrum — %s", subjectName));
%%

signedBandAnalysis.lh = avgPowerL;
signedBandAnalysis.rh = avgPowerR;
save(fullfile(subjectPath, "signedBandAnalysis.mat"), "signedBandAnalysis", "-v7.3");