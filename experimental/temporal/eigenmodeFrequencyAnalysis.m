%% Eigenmode–Frequency analysis (broadband, multi-window)
%
%  Single-subject script that:
%    1) Loads subject data (provenance, eigen, broadband sensor data)
%    2) Builds windowed access to broadband sensors.mat via matfile
%       using 4 s windows with 50% overlap (Welch-like averaging)
%    3) Loops over all windows, projecting each into eigenmode space,
%       computing the FFT, and accumulating the windowed PSD
%    4) Visualizes the time-averaged eigenmode–frequency decomposition
%
%  The windowed FFT with 50% overlap is equivalent to Welch's method:
%  each 4 s window produces a PSD with df = 1/4 = 0.25 Hz resolution,
%  and averaging across overlapping windows reduces spectral variance.
%
%  Prerequisite: run buildEigenProjection() once per subject to create eigen.mat

%% 1) Load subject data
analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
subjectName  = "sub-0002";
subjectPath  = fullfile(analysisRoot, subjectName);

meta  = load(fullfile(subjectPath, "provenance.mat")).provenance;
eigen = load(fullfile(subjectPath, "eigen.mat")).eigen;

fprintf('Subject:  %s\n', subjectName);
fprintf('Eigen:    lh [%d × %d],  rh [%d × %d]\n', ...
    size(eigen.lh.imagingKernel), size(eigen.rh.imagingKernel));
fprintf('Signal:   %d samples at %.0f Hz (%.1f s)\n', ...
    meta.nSamples, meta.sfreq, meta.nSamples / meta.sfreq);

%% 2) Make windowed datastore over broadband sensors.mat
%      4 s windows, 50% overlap → Welch-like spectral averaging

[segDs, winTbl] = makeWindowedDatastore( ...
    fullfile(subjectPath, "sensors.mat"), meta.sfreq, meta.nSamples, ...
    WindowSec=4, OverlapSec=2);

nWindows = height(winTbl);
fprintf('Windows:  %d × %.0f s  (50%% overlap)\n', nWindows, winTbl.durationSec(1));

%% 3) Loop over windows: project → FFT → accumulate PSD
%
%   For each window:
%     1) Project sensor data to eigenmodes: c = QK * X  [nModes × winSamp]
%     2) Apply Hanning window to reduce spectral leakage
%     3) Compute one-sided PSD: |FFT{c}|² / (nSamp · fs)
%     4) Accumulate into running sum
%
%   Result: avgPsdL/R [nModes × nFreqs] — Welch-averaged eigenmode PSD

winSamp = winTbl.samplesPerWin(1);
nFFT    = 2^nextpow2(winSamp);
freqsAll = (0:nFFT/2) * (meta.sfreq / nFFT);  % full one-sided axis
maxFreq  = 60;                                 % Hz — nothing above this
keepIdx  = freqsAll <= maxFreq;
freqs    = freqsAll(keepIdx);                  % truncated frequency axis
nFreqs   = numel(freqs);

% Hanning window for spectral leakage reduction
hannWin = hanning(winSamp, 'periodic')';        % [1 × winSamp]
winNorm = sum(hannWin.^2);                      % window power normalization

% Precompute PSD normalization + single-sided scaling vector [1 × nFreqs]
%   DC and Nyquist bins get ×1, interior bins get ×2 (fold negative freqs)
psdScale = 2 / (winNorm * meta.sfreq) * ones(1, nFreqs);
psdScale([1 end]) = 1 / (winNorm * meta.sfreq);

sumPsdL = zeros(eigen.lh.nModes, nFreqs);
sumPsdR = zeros(eigen.rh.nModes, nFreqs);

reset(segDs);
winCount = 0;

while hasdata(segDs)
    w = read(segDs);
    winCount = winCount + 1;

    % Window sensor data once (270 × T) instead of both projections (2000 × T)
    Xw = w.X .* hannWin;                                   % [nCh × winSamp]

    % Project → FFT → one-sided PSD in one pass per hemisphere
    fL = fft(eigen.lh.imagingKernel * Xw, nFFT, 2);
    pL = abs(fL(:, keepIdx)).^2 .* psdScale;

    fR = fft(eigen.rh.imagingKernel * Xw, nFFT, 2);
    pR = abs(fR(:, keepIdx)).^2 .* psdScale;

    sumPsdL = sumPsdL + pL;
    sumPsdR = sumPsdR + pR;

    fprintf('  Window %3d / %d  (%.1f–%.1f s)\n', ...
        winCount, nWindows, w.tStartSec, w.tStopSec);
end

avgPsdL = sumPsdL / winCount;   % [nModesL × nFreqs]
avgPsdR = sumPsdR / winCount;   % [nModesR × nFreqs]

fprintf('Processed %d windows.  PSD: [%d × %d] per hemi  (df = %.2f Hz)\n', ...
    winCount, size(avgPsdL), meta.sfreq / nFFT);

%% 4) Sort eigenmodes by eigenvalue and build joint spectrum
%
%   Merge left and right hemisphere eigenmodes into a single list sorted
%   by eigenvalue (ascending).  Each row in jointPsd corresponds to one
%   eigenmode from either hemisphere, ordered by its Laplace–Beltrami
%   eigenvalue (spatial frequency).

lambdaL = eigen.lh.eigenvalues(:);   % [nModesL × 1]
lambdaR = eigen.rh.eigenvalues(:);   % [nModesR × 1]

% Concatenate eigenvalues and PSD rows
jointLambda = [lambdaL; lambdaR];            % [nTotal × 1]
jointPsd    = [avgPsdL; avgPsdR];            % [nTotal × nFreqs]
hemiLabel   = [repmat("L", numel(lambdaL), 1); ...
               repmat("R", numel(lambdaR), 1)];

% Sort by eigenvalue (ascending = lowest spatial frequency first)
[jointLambda, sortIdx] = sort(jointLambda, 'ascend');
jointPsd   = jointPsd(sortIdx, :);
hemiLabel  = hemiLabel(sortIdx);

% Also sort per-hemisphere PSD by eigenvalue (for per-hemi plots)
[sortedLambdaL, sortIdxL] = sort(lambdaL, 'ascend');
[sortedLambdaR, sortIdxR] = sort(lambdaR, 'ascend');
sortedPsdL = avgPsdL(sortIdxL, :);
sortedPsdR = avgPsdR(sortIdxR, :);

nTotal = numel(jointLambda);
fprintf('Joint spectrum: %d eigenmodes (L:%d + R:%d) sorted by eigenvalue.\n', ...
    nTotal, numel(lambdaL), numel(lambdaR));

%% 5) Bin joint PSD by rank
%
%   Group every N consecutive modes (sorted by eigenvalue) and aggregate
%   their PSD.  This reduces the 2000-row matrix to ~200 rows while
%   preserving the eigenvalue ordering.

modesPerBin = 10;   % group 10 consecutive modes → 200 bins for 2000 modes
[binnedPsd, binRankCenters, binLambdaMean] = binPsdByRank( ...
    jointPsd, jointLambda, ModesPerBin=modesPerBin);

fprintf('Binned PSD: %d bins (%d modes/bin), rank range [%.0f, %.0f]\n', ...
    numel(binRankCenters), modesPerBin, binRankCenters(1), binRankCenters(end));

%% 6) Plot joint eigenmode–frequency spectrum with wavelength markers
%
%   y-axis = joint eigenmode rank (sorted by eigenvalue)
%   x-axis = temporal frequency (Hz)
%   Horizontal lines at modes 10, 100, 200 annotated with wavelength

useLogScale = false;   % ← set false for linear PSD color scale

markerModes = [10, 100, 200];
markerModes = markerModes(markerModes <= nTotal);   % guard against too few modes

fig = figure('Name', 'Joint Eigenmode–Frequency Spectrum', 'NumberTitle', 'off');

fMask = freqs >= 1 & freqs <= 60;
if useLogScale
    P = log10(jointPsd + eps);
    cbLabel = 'log_{10} PSD';
else
    P = jointPsd;
    cbLabel = 'PSD';
end
imagesc(freqs(fMask), 1:nTotal, P(:, fMask));
axis xy;
xlabel('Frequency (Hz)');
ylabel('Eigenmode rank (sorted by \lambda)');
title(sprintf('Joint Eigenmode–Frequency Spectrum — %s  (%d windows)', ...
    subjectName, winCount));
colormap parula;
cb = colorbar;
cb.Label.String = cbLabel;

% Band boundary lines (vertical)
hold on;
bands = [4 8 12 30];
for b = bands
    xline(b, '-', 'Color', 'w', 'LineWidth', 0.8, 'Alpha', 0.6);
end

% Horizontal marker lines with wavelength annotation
for mi = 1:numel(markerModes)
    mIdx = markerModes(mi);
    lam  = jointLambda(mIdx);
    wl   = 2*pi / sqrt(max(lam, eps));          % mm (mesh units)
    yline(mIdx, '-', 'Color', 'k', 'LineWidth', 1.2, 'Alpha', 0.9);
    text(freqs(find(fMask,1,'last')), mIdx, ...
        sprintf('  #%d  \\lambda=%.1f  \\ell=%.0f mm', mIdx, lam, wl), ...
        'Color', 'k', 'FontSize', 8, 'FontWeight', 'bold', ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
end
hold off;

%% 7) Plot binned eigenvalue–frequency spectrum

figBin = figure('Name', 'Binned Eigenvalue–Frequency Spectrum', 'NumberTitle', 'off');

if useLogScale
    Pbin = log10(binnedPsd + eps);
else
    Pbin = binnedPsd;
end
imagesc(freqs(fMask), binRankCenters, Pbin(:, fMask));
axis xy;
xlabel('Frequency (Hz)');
ylabel('Eigenmode rank (sorted by \lambda)');
title(sprintf('Binned Eigenvalue–Frequency Spectrum — %s  (%d modes/bin)', ...
    subjectName, modesPerBin));
colormap parula;
cb2 = colorbar;
cb2.Label.String = cbLabel;

hold on;
for b = bands
    xline(b, '-', 'Color', 'w', 'LineWidth', 0.8, 'Alpha', 0.6);
end
hold off;

%% 8) Per-hemisphere visualizations (sorted by eigenvalue)

% 2-D map: mode × frequency power (both hemispheres, sorted by eigenvalue)
plotEigenFrequencyMap(sortedPsdL, sortedPsdR, freqs, ...
    sortedLambdaL, sortedLambdaR, ...
    FreqRange=[1 60], MaxModes=100, ...
    Title=sprintf("Eigenmode–Frequency Map (sorted by \\lambda) — %s (%d windows)", subjectName, winCount));

% Frequency spectra for selected modes (overlay)
plotEigenFrequencySpectrum(sortedPsdL, sortedPsdR, freqs, ...
    sortedLambdaL, sortedLambdaR, ...
    Modes=[1 2 3 5 10 20 50], FreqRange=[1 60], ...
    Title=sprintf("Eigenmode PSD (sorted by \\lambda) — %s (%d windows)", subjectName, winCount));

%% ===== Local Functions =====

function [binnedPsd, binRankCenters, binLambdaMean] = binPsdByRank(psd, eigenvalues, opts)
%BINPSDBYRANK  Aggregate PSD by grouping consecutive rank-sorted modes.
%
%   [binnedPsd, binRankCenters, binLambdaMean] = binPsdByRank(psd, eigenvalues)
%   [binnedPsd, binRankCenters, binLambdaMean] = binPsdByRank(__, Name=Value)
%
%   Groups every ModesPerBin consecutive rows of the PSD matrix (which must
%   already be sorted by eigenvalue) and aggregates them.  The y-axis
%   output is in rank units (1 to nModes).
%
%   Inputs:
%       psd          - [nModes × nFreqs] PSD matrix (rows sorted by eigenvalue)
%       eigenvalues  - [nModes × 1]      corresponding sorted eigenvalues
%
%   Name-Value Options:
%       ModesPerBin  - modes per bin             (default: 10)
%       Aggregation  - 'mean' | 'sum' | 'median' (default: 'mean')
%
%   Outputs:
%       binnedPsd      - [nBins × nFreqs] aggregated PSD per bin
%       binRankCenters - [nBins × 1]      center rank of each bin
%       binLambdaMean  - [nBins × 1]      mean eigenvalue in each bin

arguments
    psd          (:,:) double
    eigenvalues  (:,1) double
    opts.ModesPerBin (1,1) double {mustBePositive, mustBeInteger} = 10
    opts.Aggregation (1,1) string {mustBeMember(opts.Aggregation, ["mean","sum","median"])} = "mean"
end

nModes = size(psd, 1);
nFreqs = size(psd, 2);
nBins  = ceil(nModes / opts.ModesPerBin);

binnedPsd      = zeros(nBins, nFreqs);
binRankCenters = zeros(nBins, 1);
binLambdaMean  = zeros(nBins, 1);

for bi = 1:nBins
    r1 = (bi-1) * opts.ModesPerBin + 1;
    r2 = min(bi * opts.ModesPerBin, nModes);
    rows = r1:r2;

    binRankCenters(bi) = (r1 + r2) / 2;
    binLambdaMean(bi)  = mean(eigenvalues(rows));

    switch opts.Aggregation
        case "sum"
            binnedPsd(bi, :) = sum(psd(rows, :), 1);
        case "mean"
            binnedPsd(bi, :) = mean(psd(rows, :), 1);
        case "median"
            binnedPsd(bi, :) = median(psd(rows, :), 1);
    end
end

end