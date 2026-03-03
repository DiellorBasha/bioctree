function result = detectGlobalAlpha(sigs, fs, nSamples, alphaPow, frameInfo, P)
%DETECTGLOBALALPHA Global alpha burst detection pipeline.
%
%   result = detectGlobalAlpha(sigs, fs, nSamples, alphaPow, frameInfo, P)
%
%   Detects alpha bursts using a GLOBAL strategy: computes a single
%   alpha-power index by taking the median across channels, then applies
%   smoothing, robust z-scoring, hysteresis detection, signalMask cleanup,
%   and selects the longest burst window.
%
%   Inputs:
%       sigs      - [nChans x nSamples] signal matrix
%       fs        - sampling rate (Hz)
%       nSamples  - total number of samples
%       alphaPow  - [nChans x nFrames] alpha bandpower (from extractAlphaBandpower)
%       frameInfo - struct from extractAlphaBandpower (.hopSize, .frameSize, .nFrames, .tFrames)
%       P         - parameter struct (from defaultParams or user-modified)
%
%   Output:
%       result - struct with fields:
%           .alphaGlobal  [1 x nFrames] global alpha index (median log power)
%           .z            [1 x nFrames] robust z-score
%           .burstMask    [1 x nFrames] logical burst mask (pre-signalMask)
%           .alphaMask    signalMask object (post cleanup)
%           .roiLimits    [M x 2] cleaned ROI time limits (seconds)
%           .win          struct from selectWindow (.startIdx, .endIdx, etc.)
%           .sigsWin      [nChans x nWinSamples] selected signal window
%           .tFrames      [1 x nFrames] frame time axis
%           .P            parameter struct used
%
%   Example:
%       P = defaultParams(Preset="global");
%       [alphaPow, fi] = extractAlphaBandpower(data.sigs, data.fs);
%       result = detectGlobalAlpha(data.sigs, data.fs, data.nSamples, alphaPow, fi, P);
%
%   See also: detectPerChannelAlpha, extractAlphaBandpower, defaultParams

    arguments
        sigs      (:,:) double
        fs        (1,1) double
        nSamples  (1,1) double
        alphaPow  (:,:) double
        frameInfo (1,1) struct
        P         (1,1) struct
    end

    hopSize   = frameInfo.hopSize;
    frameSize = frameInfo.frameSize;
    nFrames   = frameInfo.nFrames;
    tFrames   = frameInfo.tFrames;

    smoothFrames = max(3, round(P.smooth_s / (hopSize / fs)));

    % 1) Global alpha index + robust z-score
    [z, alphaSmoothed] = computeRobustZscore(alphaPow, ...
        SmoothFrames = smoothFrames, ...
        GlobalMedian = true);

    % Also keep the raw global index for plotting
    alphaGlobal = median(log(alphaPow + eps), 1);

    % 2) Hysteresis detection
    [burstMask, onF, offF] = detectBurstsHysteresis(z, P.thrOn, P.thrOff);

    % 3) Convert to sample ROIs
    roiTable = frameToSampleROIs(onF, offF, hopSize, frameSize, fs, nSamples);

    % 4) Build signalMask with cleanup
    [alphaMask, roiLimits] = buildAlphaMask(roiTable, fs, ...
        MinLength_s      = P.minLength_s, ...
        MergeDistance_s   = P.mergeDistance_s, ...
        LeftExtension_s  = P.leftExtension_s, ...
        RightExtension_s = P.rightExtension_s);

    % 5) Select window
    if isempty(roiLimits)
        warning('detectGlobalAlpha:NoROIs', ...
            'No alpha ROIs survived cleanup. Relax parameters.');
        win     = struct('startIdx',[], 'endIdx',[], 'start_s',[], ...
            'end_s',[], 'dur_s',[], 'roiIdx',[]);
        sigsWin = [];
    else
        win = selectWindow(roiLimits, fs, nSamples, ...
            FinalPad_s       = P.finalPad_s, ...
            MinSelectedWin_s = P.minSelectedWin_s);
        sigsWin = sigs(:, win.startIdx:win.endIdx);

        fprintf('detectGlobalAlpha: window %.3f–%.3f s (%.3f s)\n', ...
            win.start_s, win.end_s, win.dur_s);
    end

    % Pack result
    result.alphaGlobal  = alphaGlobal;
    result.z            = z;
    result.burstMask    = burstMask;
    result.alphaMask    = alphaMask;
    result.roiLimits    = roiLimits;
    result.win          = win;
    result.sigsWin      = sigsWin;
    result.tFrames      = tFrames;
    result.P            = P;
end
