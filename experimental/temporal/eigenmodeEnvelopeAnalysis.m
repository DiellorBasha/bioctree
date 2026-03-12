%% Eigenmode envelope analysis (Hilbert amplitude, multi-window)
%
%  Single-subject script that:
%    1) Loads subject data (provenance, eigen, bands)
%    2) Builds windowed access to CWT band data via matfile
%    3) Loops over all windows, extracting the Hilbert envelope of each
%       band and projecting it into eigenmode space
%    4) Accumulates a time-averaged eigenmode power spectrum per band
%    5) Visualizes the per-band eigenspectra
%
%  By projecting the *amplitude envelope* (non-negative) rather than the
%  signed oscillation, we obtain eigenmode coefficients that capture the
%  spatial distribution of instantaneous power, free of carrier-frequency
%  oscillation artifacts.
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

%% 3) Loop over windows: Hilbert envelope → eigenmode projection → accumulate
%
%   For each window and each band:
%     1) Extract band signal:   S = squeeze(w.X(:,:,b))  [nCh × winSamp]
%     2) Hilbert envelope:      E = abs(hilbert(S'))'    [nCh × winSamp]
%     3) Project to eigenmodes: c = QK * E               [nModes × winSamp]
%     4) Accumulate mean(c.^2, 2) into running average
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
        bandSignal = squeeze(w.X(:, :, bi));            % [nCh × winSamp]
        envelope   = abs(hilbert(bandSignal'))';         % [nCh × winSamp]

        cL = eigen.lh.imagingKernel * envelope;          % [nModesL × winSamp]
        cR = eigen.rh.imagingKernel * envelope;          % [nModesR × winSamp]

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
    Title=sprintf("Envelope Eigenspectrum — %s (%d windows)", subjectName, winCount));

plotEnvelopeEigenSpectrumAllBands(avgPowerL, avgPowerR, ...
    eigen.lh.eigenvalues, eigen.rh.eigenvalues, bandNames, ...
    Scale="semilogy", MaxModes=200, ...
    Title=sprintf("Envelope Eigenspectrum (log) — %s", subjectName));

% ---- Individual band panels ----
plotEnvelopeEigenSpectrumGrid(avgPowerL, avgPowerR, ...
    eigen.lh.eigenvalues, eigen.rh.eigenvalues, bandNames, ...
    MaxModes=200, ...
    Title=sprintf("Per-Band Envelope Eigenspectrum — %s", subjectName));
%%

envelopeAnalysis.lh = avgPowerL;
envelopeAnalysis.rh = avgPowerR;
save(fullfile(subjectPath, "envelopeAnalysis.mat"), "envelopeAnalysis", "-v7.3");