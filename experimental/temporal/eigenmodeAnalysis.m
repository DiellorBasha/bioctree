function results = eigenmodeAnalysis(analysisRoot, subjectName, opts)
%EIGENMODEANALYSIS  Consolidated eigenmode analysis for one subject.
%
%   results = eigenmodeAnalysis(analysisRoot, subjectName)
%   results = eigenmodeAnalysis(__, Name=Value)
%
%   Runs three eigenmode analyses in a single pass over the subject data:
%
%     1) Frequency analysis  — Welch-averaged PSD per eigenmode (broadband)
%     2) Signed-band analysis — per-band eigenmode power from signed CWT signal
%     3) Envelope analysis    — per-band eigenmode power from Hilbert envelope
%
%   Data is loaded once and reused across all analyses.  The band-based
%   analyses (signed + envelope) share a single windowed pass over the CWT
%   bands.mat file.  The frequency analysis uses a separate pass over the
%   broadband sensors.mat file.
%
%   Inputs:
%       analysisRoot - path to study analysis directory
%       subjectName  - subject folder name (e.g., "sub-0002")
%
%   Name-Value Options:
%       WindowSec    - window duration in seconds        (default: 4)
%       OverlapSec   - overlap in seconds                (default: 2)
%       MaxFreq      - max frequency for PSD (Hz)        (default: 60)
%       BandNames    - string array of CWT band names    (default: 5 bands)
%       ModesPerBin  - modes per rank bin for joint PSD   (default: 10)
%       Save         - save results to subject directory  (default: false)
%       Verbose      - print progress                     (default: true)
%
%   Output:
%       results — struct with fields:
%         .subject      — subject name
%         .meta         — provenance metadata
%         .eigenvalues  — struct with .lh, .rh eigenvalue vectors
%         .frequency    — Welch PSD results (per-hemi + joint + binned)
%         .signedBand   — signed-band eigenmode power per band
%         .envelope     — envelope eigenmode power per band
%         .params       — analysis parameters

arguments
    analysisRoot (1,1) string
    subjectName  (1,1) string
    opts.WindowSec   (1,1) double {mustBePositive} = 4
    opts.OverlapSec  (1,1) double {mustBeNonnegative} = 2
    opts.MaxFreq     (1,1) double {mustBePositive} = 60
    opts.BandNames   (1,:) string = ["delta","theta","alpha","beta","gamma1"]
    opts.ModesPerBin (1,1) double {mustBePositive, mustBeInteger} = 10
    opts.Save        (1,1) logical = false
    opts.Verbose     (1,1) logical = true
end

subjectPath = fullfile(analysisRoot, subjectName);

%% ---- 1. Load shared data (once) ----

meta  = load(fullfile(subjectPath, "provenance.mat")).provenance;
eigen = load(fullfile(subjectPath, "eigen.mat")).eigen;

if opts.Verbose
    fprintf('\n============================================================\n');
    fprintf('eigenmodeAnalysis — %s\n', subjectName);
    fprintf('   Eigen:  lh [%d × %d],  rh [%d × %d]\n', ...
        size(eigen.lh.imagingKernel), size(eigen.rh.imagingKernel));
    fprintf('   Signal: %d samples at %.0f Hz (%.1f s)\n', ...
        meta.nSamples, meta.sfreq, meta.nSamples / meta.sfreq);
    fprintf('   Window: %.1f s, overlap %.1f s\n', opts.WindowSec, opts.OverlapSec);
    fprintf('============================================================\n');
end

nBands    = numel(opts.BandNames);
nModesL   = eigen.lh.nModes;
nModesR   = eigen.rh.nModes;
lambdaL   = eigen.lh.eigenvalues(:);
lambdaR   = eigen.rh.eigenvalues(:);

%% ---- 2. Frequency analysis (broadband sensors.mat) ----

if opts.Verbose, fprintf('\n--- Frequency analysis (broadband) ---\n'); end

[freqDs, freqWinTbl] = makeWindowedDatastore( ...
    fullfile(subjectPath, "sensors.mat"), meta.sfreq, meta.nSamples, ...
    WindowSec=opts.WindowSec, OverlapSec=opts.OverlapSec);

nFreqWins = height(freqWinTbl);
winSamp   = freqWinTbl.samplesPerWin(1);
nFFT      = 2^nextpow2(winSamp);

% Frequency axis (truncated to MaxFreq)
freqsAll = (0:nFFT/2) * (meta.sfreq / nFFT);
keepIdx  = freqsAll <= opts.MaxFreq;
freqs    = freqsAll(keepIdx);
nFreqs   = numel(freqs);

% Hanning window + PSD scale vector
hannWin  = hanning(winSamp, 'periodic')';
winNorm  = sum(hannWin.^2);
psdScale = 2 / (winNorm * meta.sfreq) * ones(1, nFreqs);
psdScale([1 end]) = 1 / (winNorm * meta.sfreq);

sumPsdL = zeros(nModesL, nFreqs);
sumPsdR = zeros(nModesR, nFreqs);

reset(freqDs);
freqWinCount = 0;

while hasdata(freqDs)
    w = read(freqDs);
    freqWinCount = freqWinCount + 1;

    Xw = w.X .* hannWin;                                    % [nCh × winSamp]

    fL = fft(eigen.lh.imagingKernel * Xw, nFFT, 2);
    sumPsdL = sumPsdL + abs(fL(:, keepIdx)).^2 .* psdScale;

    fR = fft(eigen.rh.imagingKernel * Xw, nFFT, 2);
    sumPsdR = sumPsdR + abs(fR(:, keepIdx)).^2 .* psdScale;

    if opts.Verbose
        fprintf('  Window %3d / %d  (%.1f–%.1f s)\n', ...
            freqWinCount, nFreqWins, w.tStartSec, w.tStopSec);
    end
end

avgPsdL = sumPsdL / freqWinCount;
avgPsdR = sumPsdR / freqWinCount;

% Joint spectrum (sorted by eigenvalue)
jointLambda = [lambdaL; lambdaR];
jointPsd    = [avgPsdL; avgPsdR];
hemiLabel   = [repmat("L", nModesL, 1); repmat("R", nModesR, 1)];

[jointLambda, sortIdx] = sort(jointLambda, 'ascend');
jointPsd  = jointPsd(sortIdx, :);
hemiLabel = hemiLabel(sortIdx);

% Sorted per-hemisphere
[sortedLambdaL, sortIdxL] = sort(lambdaL, 'ascend');
[sortedLambdaR, sortIdxR] = sort(lambdaR, 'ascend');
sortedPsdL = avgPsdL(sortIdxL, :);
sortedPsdR = avgPsdR(sortIdxR, :);

% Binned joint PSD by rank
[binnedPsd, binRankCenters, binLambdaMean] = binPsdByRank( ...
    jointPsd, jointLambda, ModesPerBin=opts.ModesPerBin);

if opts.Verbose
    fprintf('Frequency: %d windows, PSD [%d × %d]/hemi, df=%.2f Hz\n', ...
        freqWinCount, size(avgPsdL), meta.sfreq / nFFT);
    fprintf('Joint spectrum: %d modes, %d bins (%d modes/bin)\n', ...
        numel(jointLambda), numel(binRankCenters), opts.ModesPerBin);
end

frequency.avgPsdL       = avgPsdL;
frequency.avgPsdR       = avgPsdR;
frequency.sortedPsdL    = sortedPsdL;
frequency.sortedPsdR    = sortedPsdR;
frequency.sortedLambdaL = sortedLambdaL;
frequency.sortedLambdaR = sortedLambdaR;
frequency.jointPsd      = jointPsd;
frequency.jointLambda   = jointLambda;
frequency.hemiLabel     = hemiLabel;
frequency.binnedPsd     = binnedPsd;
frequency.binRankCenters = binRankCenters;
frequency.binLambdaMean = binLambdaMean;
frequency.freqs         = freqs;
frequency.nWindows      = freqWinCount;

%% ---- 3. Band analyses (signed + envelope, from bands.mat) ----

if opts.Verbose, fprintf('\n--- Band analyses (signed + envelope) ---\n'); end

[bandDs, bandWinTbl] = makeWindowedDatastore( ...
    fullfile(subjectPath, "bands.mat"), meta.sfreq, meta.nSamples, ...
    WindowSec=opts.WindowSec, OverlapSec=opts.OverlapSec);

nBandWins = height(bandWinTbl);

% Accumulators — signed-band
sumSignedL = zeros(nModesL, nBands);
sumSignedR = zeros(nModesR, nBands);

% Accumulators — envelope
sumEnvL = zeros(nModesL, nBands);
sumEnvR = zeros(nModesR, nBands);

reset(bandDs);
bandWinCount = 0;

while hasdata(bandDs)
    w = read(bandDs);
    bandWinCount = bandWinCount + 1;

    for bi = 1:nBands
        bandSignal = squeeze(w.X(:, :, bi));             % [nCh × winSamp]
        envelope   = abs(hilbert(bandSignal'))';          % [nCh × winSamp]

        % Signed-band projection
        cL = eigen.lh.imagingKernel * bandSignal;
        cR = eigen.rh.imagingKernel * bandSignal;
        sumSignedL(:, bi) = sumSignedL(:, bi) + mean(cL.^2, 2);
        sumSignedR(:, bi) = sumSignedR(:, bi) + mean(cR.^2, 2);

        % Envelope projection
        eL = eigen.lh.imagingKernel * envelope;
        eR = eigen.rh.imagingKernel * envelope;
        sumEnvL(:, bi) = sumEnvL(:, bi) + mean(eL.^2, 2);
        sumEnvR(:, bi) = sumEnvR(:, bi) + mean(eR.^2, 2);
    end

    if opts.Verbose
        fprintf('  Window %3d / %d  (%.1f–%.1f s)\n', ...
            bandWinCount, nBandWins, w.tStartSec, w.tStopSec);
    end
end

signedBand.avgPowerL = sumSignedL / bandWinCount;
signedBand.avgPowerR = sumSignedR / bandWinCount;
signedBand.bandNames = opts.BandNames;
signedBand.nWindows  = bandWinCount;

envResult.avgPowerL = sumEnvL / bandWinCount;
envResult.avgPowerR = sumEnvR / bandWinCount;
envResult.bandNames = opts.BandNames;
envResult.nWindows  = bandWinCount;

if opts.Verbose
    fprintf('Band analyses: %d windows × %d bands, [%d × %d]/hemi\n', ...
        bandWinCount, nBands, nModesL, nBands);
end

%% ---- 4. Assemble output struct ----

results.subject    = subjectName;
results.meta       = meta;
results.eigenvalues.lh = lambdaL;
results.eigenvalues.rh = lambdaR;
results.frequency  = frequency;
results.signedBand = signedBand;
results.envelope   = envResult;
results.params     = struct( ...
    'WindowSec',   opts.WindowSec, ...
    'OverlapSec',  opts.OverlapSec, ...
    'MaxFreq',     opts.MaxFreq, ...
    'BandNames',   opts.BandNames, ...
    'ModesPerBin', opts.ModesPerBin);

%% ---- 5. Optional save ----

if opts.Save
    savePath = fullfile(subjectPath, "eigenmodeAnalysis.mat");
    save(savePath, "results", "-v7.3");
    if opts.Verbose
        fprintf('\nSaved: %s\n', savePath);
    end
end

if opts.Verbose
    fprintf('\n============================================================\n');
    fprintf('eigenmodeAnalysis complete — %s\n', subjectName);
    fprintf('============================================================\n');
end

end

%% ===== Local Functions =====

function [binnedPsd, binRankCenters, binLambdaMean] = binPsdByRank(psd, eigenvalues, opts)
%BINPSDBYRANK  Aggregate PSD by grouping consecutive rank-sorted modes.

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
