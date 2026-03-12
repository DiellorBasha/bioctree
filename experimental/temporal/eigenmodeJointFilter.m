%% eigenmodeJointFilter — Joint spectral-temporal filtering of broadband MEG
%
%  Applies a separable joint spectral-temporal filter to broadband MEG
%  sensor data projected onto eigenmodes.  The joint kernel is a product
%  of a spatial spectral kernel h(λ) evaluated on eigenvalues and a
%  temporal wavelet ψ(f) evaluated on FFT frequencies:
%
%      K(λ, f) = h(λ) · ψ(f)
%
%  Pipeline (per time window):
%    1. Load broadband sensor data X [nCh × winSamp]
%    2. Apply Hanning window and FFT to get X̂ [nCh × nFFT]
%    3. Project to eigenmodes: Ĉ = ImagingKernel * X̂  [nModes × nFreqs]
%    4. Apply joint kernel:   Ĉ_filt = h(λ) · ψ(f) .* Ĉ
%    5. Reconstruct to vertex space: Ŝ = U * Ĉ_filt  [nVert × nFreqs]
%    6. IFFT to time domain: S = ifft(Ŝ)  [nVert × winSamp]
%
%  Prerequisite: run buildEigenProjection() once per subject.
%
%  See also eigenmodeFilter, eigenmodeAnalysis, makeWindowedDatastore,
%           bct.filter.design, plotJointFilterResults

%% 1) Configuration

analysisRoot  = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
subjectName   = "sub-0002";
subjectPath   = fullfile(analysisRoot, subjectName);

% Spatial filter
spatialKernel = "SpectralMexicanHat";   % kernel ID from bct.kernel.dictionary
nScales       = 6;                       % 1 lowpass + 5 bandpass
nBandpass     = nScales - 1;

% Temporal filter
temporalKernel = "Morlet";   % "Morlet" | "Gaussian" | "Boxcar"
centerFreqHz   = 20;         % center frequency (Hz)
bandwidthHz    = 4;          % FWHM bandwidth (Hz)

% FFT / windowing
maxFreqHz  = 60;
windowSec  = 4;
overlapSec = 2;

% Save
savePath = "";   % set to a .mat path to save result

fprintf('=== eigenmodeJointFilter ===\n');
fprintf('Subject  : %s\n', subjectPath);
fprintf('Spatial  : %s  (%d scales)\n', spatialKernel, nScales);
fprintf('Temporal : %s  center=%.1f Hz,  bw=%.1f Hz\n', ...
    temporalKernel, centerFreqHz, bandwidthHz);

%% 2) Load data

provenance = load(fullfile(subjectPath, "provenance.mat")).provenance;
eigen      = load(fullfile(subjectPath, "eigen.mat")).eigen;
fsav       = load(fullfile(analysisRoot, "group", "fsaverage5.mat"));
U_lh = fsav.fsaverage5.lh.eigen.eigenvectors.value;   % [nVertL × nModesL]
U_rh = fsav.fsaverage5.rh.eigen.eigenvectors.value;   % [nVertR × nModesR]

sfreq    = provenance.sfreq;
nSamples = provenance.nSamples;
nModesL  = eigen.lh.nModes;
nModesR  = eigen.rh.nModes;
lambdaL  = eigen.lh.eigenvalues(:);
lambdaR  = eigen.rh.eigenvalues(:);
nVertL   = size(U_lh, 1);
nVertR   = size(U_rh, 1);

fprintf('Eigen    : lh [%d modes],  rh [%d modes]\n', nModesL, nModesR);
fprintf('Verts    : lh %d,  rh %d\n', nVertL, nVertR);
fprintf('Signal   : %d samples at %.0f Hz (%.1f s)\n', ...
    nSamples, sfreq, nSamples / sfreq);

%% 3) Windowed datastore (broadband sensors.mat)

[segDs, winTbl] = makeWindowedDatastore( ...
    fullfile(subjectPath, "sensors.mat"), sfreq, nSamples, ...
    WindowSec=windowSec, OverlapSec=overlapSec);
nWindows = height(winTbl);
winSamp  = winTbl.samplesPerWin(1);

fprintf('Windows  : %d × %.0f s  (%.0f%% overlap)\n', ...
    nWindows, windowSec, overlapSec / windowSec * 100);

%% 4) FFT setup

nFFT     = 2^nextpow2(winSamp);
freqsAll = (0:nFFT/2) * (sfreq / nFFT);
keepIdx  = freqsAll <= maxFreqHz;
freqs    = freqsAll(keepIdx);
nFreqs   = numel(freqs);

% Hanning window for PSD estimation
hannWin  = hanning(winSamp, 'periodic')';
winNorm  = sum(hannWin.^2);
psdScale = 2 / (winNorm * sfreq) * ones(1, nFreqs);
psdScale([1 end]) = 1 / (winNorm * sfreq);

fprintf('FFT      : nFFT=%d,  %d freq bins (0–%.1f Hz,  df=%.2f Hz)\n', ...
    nFFT, nFreqs, freqs(end), freqs(2) - freqs(1));

%% 5) Design spatial filterbank h(λ)

scalesL = logScales(lambdaL, nBandpass);
scalesR = logScales(lambdaR, nBandpass);

FL = bct.filter.design(lambdaL, spatialKernel, "tau", scalesL);
FR = bct.filter.design(lambdaR, spatialKernel, "tau", scalesR);

spatialWeightsL = [makeLowpass(lambdaL), FL.weights];  % [nModesL × nScales]
spatialWeightsR = [makeLowpass(lambdaR), FR.weights];  % [nModesR × nScales]

scaleLabels = ["lowpass", compose("scale %d", 1:nBandpass)];

fprintf('Spatial  : LH [%d × %d],  RH [%d × %d]  (incl. lowpass)\n', ...
    size(spatialWeightsL), size(spatialWeightsR));

%% 6) Design temporal kernel ψ(f)

temporalWeights = designTemporalKernel( ...
    freqs, temporalKernel, centerFreqHz, bandwidthHz);

fprintf('Temporal : [1 × %d],  peak at %.1f Hz,  passband ≈ %.1f–%.1f Hz\n', ...
    nFreqs, freqs(find(temporalWeights == max(temporalWeights), 1)), ...
    freqs(find(temporalWeights > 0.5*max(temporalWeights), 1, 'first')), ...
    freqs(find(temporalWeights > 0.5*max(temporalWeights), 1, 'last')));

%% 7) Build joint kernels K(λ, f) = h(λ) · ψ(f)

jointKernelL = zeros(nModesL, nFreqs, nScales);
jointKernelR = zeros(nModesR, nFreqs, nScales);
for si = 1:nScales
    jointKernelL(:, :, si) = spatialWeightsL(:, si) .* temporalWeights;
    jointKernelR(:, :, si) = spatialWeightsR(:, si) .* temporalWeights;
end

fprintf('Joint    : LH [%d × %d × %d],  RH [%d × %d × %d]\n', ...
    size(jointKernelL), size(jointKernelR));

%% 7b) Visualize joint kernels

tempLabel = sprintf('%s  (%.0f Hz, bw %.0f Hz)', ...
    temporalKernel, centerFreqHz, bandwidthHz);

% --- Standard orientation (freq on x, eigenmode on y) ---
[figsStd, maskStd] = plotJointKernels( ...
    jointKernelL, spatialWeightsL, lambdaL, freqs, scaleLabels, ...
    TemporalWeights=temporalWeights, TemporalLabel=tempLabel);

% --- Transposed (eigenmode on x, freq on y) ---
[figsTr, maskTr] = plotJointKernels( ...
    jointKernelL, spatialWeightsL, lambdaL, freqs, scaleLabels, ...
    TemporalWeights=temporalWeights, TemporalLabel=tempLabel, ...
    Transpose=true);

% --- Grayscale mask (transposed) ---
[figsMask, maskGray] = plotJointKernels( ...
    jointKernelL, spatialWeightsL, lambdaL, freqs, scaleLabels, ...
    TemporalWeights=temporalWeights, TemporalLabel=tempLabel, ...
    Style="mask", Transpose=true);
%%
% Export all figures
figDir = fullfile(subjectPath, "figures");
if ~isfolder(figDir), mkdir(figDir); end

exportgraphics(figsStd(1),  fullfile(figDir, "jointKernel_heatmaps2.png"),     Resolution=300);
exportgraphics(figsStd(2),  fullfile(figDir, "jointKernel_marginals2.png"),     Resolution=300);
exportgraphics(figsTr(1),   fullfile(figDir, "jointKernel_heatmaps_T2.png"),   Resolution=300);
exportgraphics(figsTr(2),   fullfile(figDir, "jointKernel_marginals_T2.png"),  Resolution=300);
exportgraphics(figsMask(1), fullfile(figDir, "jointKernel_mask_heatmaps2.png"), Resolution=300);
exportgraphics(figsMask(2), fullfile(figDir, "jointKernel_mask_marginals2.png"),Resolution=300);

% Save editable MATLAB .fig files
savefig(figsStd(1),  fullfile(figDir, "jointKernel_heatmaps2.fig"),      'compact');
savefig(figsStd(2),  fullfile(figDir, "jointKernel_marginals2.fig"),     'compact');
savefig(figsTr(1),   fullfile(figDir, "jointKernel_heatmaps_T2.fig"),    'compact');
savefig(figsTr(2),   fullfile(figDir, "jointKernel_marginals_T2.fig"),   'compact');
savefig(figsMask(1), fullfile(figDir, "jointKernel_mask_heatmaps2.fig"), 'compact');
savefig(figsMask(2), fullfile(figDir, "jointKernel_mask_marginals2.fig"),'compact');

fprintf('Exported 6 joint-kernel figures (.png + .fig) -> %s\n', figDir);
%% 8) Main loop: project → FFT → joint filter → IFFT → reconstruct

% Accumulators
sumSrcL = zeros(nVertL, nScales);
sumSrcR = zeros(nVertR, nScales);
sumPsdL = zeros(nModesL, nFreqs);
sumPsdR = zeros(nModesR, nFreqs);

% Example window storage (first window only)
exampleSrcL = [];
exampleSrcR = [];
exampleT    = [];
bestScale   = 1;

reset(segDs);
winCount = 0;

while hasdata(segDs)
    w = read(segDs);
    winCount = winCount + 1;

    Xw = w.X .* hannWin;                             % [nCh × winSamp]

    % Project to eigenmodes and FFT
    cHatL = fft(eigen.lh.imagingKernel * Xw, nFFT, 2);  % [nModesL × nFFT]
    cHatR = fft(eigen.rh.imagingKernel * Xw, nFFT, 2);  % [nModesR × nFFT]

    % Truncate to positive frequencies
    cHatL = cHatL(:, keepIdx);   % [nModesL × nFreqs]
    cHatR = cHatR(:, keepIdx);   % [nModesR × nFreqs]

    % Accumulate unfiltered eigenmode PSD
    sumPsdL = sumPsdL + abs(cHatL).^2 .* psdScale;
    sumPsdR = sumPsdR + abs(cHatR).^2 .* psdScale;

    % Apply joint filter at each scale and reconstruct to vertices
    for si = 1:nScales
        filtCL = jointKernelL(:, :, si) .* cHatL;   % [nModesL × nFreqs]
        filtCR = jointKernelR(:, :, si) .* cHatR;   % [nModesR × nFreqs]

        modePowerL = mean(abs(filtCL).^2, 2);        % [nModesL × 1]
        modePowerR = mean(abs(filtCR).^2, 2);        % [nModesR × 1]

        sumSrcL(:, si) = sumSrcL(:, si) + U_lh.^2 * modePowerL;
        sumSrcR(:, si) = sumSrcR(:, si) + U_rh.^2 * modePowerR;
    end

    % Save first window's full filtered time series for visualization
    if winCount == 1
        exampleT = (w.sampleStart:w.sampleStop) / sfreq;

        [~, bestScale] = max(squeeze(sum(sum( ...
            abs(jointKernelL .* reshape(cHatL, nModesL, nFreqs, 1)).^2, 1), 2)));

        filtCL_ex = jointKernelL(:, :, bestScale) .* cHatL;
        filtCR_ex = jointKernelR(:, :, bestScale) .* cHatR;

        fullSpecL = zeros(nModesL, nFFT);
        fullSpecR = zeros(nModesR, nFFT);
        fullSpecL(:, keepIdx) = filtCL_ex;
        fullSpecR(:, keepIdx) = filtCR_ex;

        cTimeL = real(ifft(fullSpecL, nFFT, 2));
        cTimeR = real(ifft(fullSpecR, nFFT, 2));
        cTimeL = cTimeL(:, 1:winSamp);
        cTimeR = cTimeR(:, 1:winSamp);

        exampleSrcL = U_lh * cTimeL;   % [nVertL × winSamp]
        exampleSrcR = U_rh * cTimeR;   % [nVertR × winSamp]
    end

    fprintf('  Window %3d / %d  (%.1f–%.1f s)\n', ...
        winCount, nWindows, w.tStartSec, w.tStopSec);
end

%% 9) Normalize averages

avgSrcL   = sumSrcL / winCount;   % [nVertL × nScales]
avgSrcR   = sumSrcR / winCount;
srcPowerL = sqrt(avgSrcL);        % RMS source amplitude
srcPowerR = sqrt(avgSrcR);
avgPsdL   = sumPsdL / winCount;   % [nModesL × nFreqs]
avgPsdR   = sumPsdR / winCount;

fprintf('Done: %d windows.  Source maps: LH [%s],  RH [%s]\n', ...
    winCount, join(string(size(srcPowerL)), '×'), ...
    join(string(size(srcPowerR)), '×'));

%% 10) Assemble result struct

result.srcPowerL = srcPowerL;
result.srcPowerR = srcPowerR;
result.avgSrcL   = avgSrcL;
result.avgSrcR   = avgSrcR;

result.coeffSpectrumL = avgPsdL;
result.coeffSpectrumR = avgPsdR;

result.jointKernelL = jointKernelL;
result.jointKernelR = jointKernelR;

% Example window
result.example.srcL       = exampleSrcL;
result.example.srcR       = exampleSrcR;
result.example.tAxis      = exampleT;
result.example.scaleIdx   = bestScale;
result.example.scaleLabel = scaleLabels(bestScale);

% Spatial filterbank metadata
result.spatialFilter.kernelName   = spatialKernel;
result.spatialFilter.nScales      = nScales;
result.spatialFilter.scaleLabels  = scaleLabels;
result.spatialFilter.scalesL      = scalesL;
result.spatialFilter.scalesR      = scalesR;
result.spatialFilter.weightsL     = spatialWeightsL;
result.spatialFilter.weightsR     = spatialWeightsR;
result.spatialFilter.eigenvaluesL = lambdaL;
result.spatialFilter.eigenvaluesR = lambdaR;
result.spatialFilter.FL           = FL;
result.spatialFilter.FR           = FR;

% Temporal kernel metadata
result.temporalFilter.kernelType   = temporalKernel;
result.temporalFilter.centerFreqHz = centerFreqHz;
result.temporalFilter.bandwidthHz  = bandwidthHz;
result.temporalFilter.weights      = temporalWeights;
result.temporalFilter.freqs        = freqs;

% Processing metadata
result.meta.subjectPath = subjectPath;
result.meta.windowSec   = windowSec;
result.meta.overlapSec  = overlapSec;
result.meta.maxFreqHz   = maxFreqHz;
result.meta.nWindows    = winCount;
result.meta.nVertL      = nVertL;
result.meta.nVertR      = nVertR;
result.meta.nModesL     = nModesL;
result.meta.nModesR     = nModesR;
result.meta.nFreqs      = nFreqs;
result.meta.freqs       = freqs;
result.meta.sfreq       = sfreq;
result.meta.nSamples    = nSamples;
result.meta.nFFT        = nFFT;
result.meta.createdAt   = datetime("now");

%% 11) Optional save

if savePath ~= ""
    saveDir = fileparts(savePath);
    if saveDir ~= "" && ~isfolder(saveDir)
        mkdir(saveDir);
    end
    save(savePath, '-struct', 'result', '-v7.3');
    fprintf('Saved -> %s\n', savePath);
end

fprintf('\n=== eigenmodeJointFilter complete ===\n');

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function psi = designTemporalKernel(freqs, kernelType, centerHz, bwHz)
%DESIGNTEMPORALKERNEL  Construct temporal frequency-domain kernel ψ(f).
%
%   Returns a [1 × nFreqs] real vector in [0, 1] representing the
%   temporal filter response evaluated at the given frequency axis.
%
%   Supported kernels:
%     "Morlet"   — Gaussian envelope in frequency centered at f0
%                   σ_f = bwHz / (2√(2ln2))  (FWHM = bwHz)
%     "Gaussian" — Same as Morlet (real part only — no complex phase)
%     "Boxcar"   — Rectangular passband [f0 - bw/2, f0 + bw/2]

    freqs = freqs(:)';
    switch kernelType
        case {"Morlet", "Gaussian"}
            % Gaussian in frequency domain with FWHM = bwHz
            sigmaF = bwHz / (2 * sqrt(2 * log(2)));
            psi = exp(-(freqs - centerHz).^2 / (2 * sigmaF^2));

        case "Boxcar"
            fLow  = centerHz - bwHz / 2;
            fHigh = centerHz + bwHz / 2;
            psi   = double(freqs >= fLow & freqs <= fHigh);

        otherwise
            error('eigenmodeJointFilter:BadKernel', ...
                'Unknown temporal kernel: %s', kernelType);
    end

    % Normalize peak to 1
    psi = psi / max(psi);
end

function scales = logScales(eigenvalues, N)
%LOGSCALES  Log-spaced wavelet scales.
    lpfactor = 20;
    t1 = 1;  t2 = 2;
    lmax = max(eigenvalues);
    lmin = lmax / lpfactor;
    smin = t1 / lmax;
    smax = t2 / lmin;
    scales = exp(linspace(log(smax), log(smin), N));
end

function w = makeLowpass(eigenvalues)
%MAKELOWPASS  Exponential low-pass kernel.
    lpfactor = 20;
    lmax = max(eigenvalues);
    lmin = lmax / lpfactor;
    lminfac = 0.4 * lmin;
    w = 1.2 * exp(-1) * exp(-(eigenvalues / lminfac).^4);
end
