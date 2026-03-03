function result = detectPerChannelAlpha(sigs, fs, nSamples, alphaPow, frameInfo, P)
%DETECTPERCHANNELALPHA Per-channel alpha detection with global channel merge.
%
%   result = detectPerChannelAlpha(sigs, fs, nSamples, alphaPow, frameInfo, P)
%
%   Detects alpha bursts INDEPENDENTLY per channel, then merges across
%   channels using a minimum-channel-count threshold to define GLOBAL
%   alpha events. Applies signalMask cleanup at both per-channel and
%   global stages.
%
%   Inputs:
%       sigs      - [nChans x nSamples] signal matrix
%       fs        - sampling rate (Hz)
%       nSamples  - total number of samples
%       alphaPow  - [nChans x nFrames] alpha bandpower
%       frameInfo - struct from extractAlphaBandpower
%       P         - parameter struct (from defaultParams(Preset="perchannel"))
%
%   Output:
%       result - struct with fields:
%           .z_ch           [nChans x nFrames] per-channel z-scores
%           .active_ch      [nChans x nFrames] per-channel active mask (post cleanup)
%           .chanCount      [1 x nFrames] number of active channels per frame
%           .globalMask     [1 x nFrames] logical global burst mask
%           .alphaMaskGlobal signalMask object (global, post cleanup)
%           .roiLimits      [M x 2] global ROI time limits (seconds)
%           .win            struct from selectWindow
%           .sigsWin        selected signal window
%           .tFrames        frame time axis
%           .roiPerChan     {nChans x 1} cell of per-channel ROI limits
%           .P              parameter struct used
%
%   Example:
%       P = defaultParams(Preset="perchannel");
%       [alphaPow, fi] = extractAlphaBandpower(data.sigs, data.fs);
%       result = detectPerChannelAlpha(data.sigs, data.fs, data.nSamples, alphaPow, fi, P);
%
%   See also: detectGlobalAlpha, extractAlphaBandpower, defaultParams

    arguments
        sigs      (:,:) double
        fs        (1,1) double
        nSamples  (1,1) double
        alphaPow  (:,:) double
        frameInfo (1,1) struct
        P         (1,1) struct
    end

    [nChans, ~] = size(sigs);
    hopSize   = frameInfo.hopSize;
    frameSize = frameInfo.frameSize;
    nFrames   = frameInfo.nFrames;
    tFrames   = frameInfo.tFrames;

    smoothFrames = max(3, round(P.smooth_s / (hopSize / fs)));

    % 1) Per-channel smoothing + robust z-score
    [z_ch, ~] = computeRobustZscore(alphaPow, ...
        SmoothFrames = smoothFrames, ...
        GlobalMedian = false);

    % 2) Per-channel hysteresis detection
    [burstMask_ch, onIdxCell, offIdxCell] = detectBurstsHysteresis(z_ch, P.thrOn, P.thrOff);

    % 3) Per-channel ROI cleanup + rasterize to active mask
    active_ch   = false(nChans, nFrames);
    roiPerChan  = cell(nChans, 1);

    for ci = 1:nChans
        if isempty(onIdxCell{ci})
            continue
        end

        roiTable = frameToSampleROIs(onIdxCell{ci}, offIdxCell{ci}, ...
            hopSize, frameSize, fs, nSamples);

        if isempty(roiTable)
            continue
        end

        [~, roiLims] = buildAlphaMask(roiTable, fs, ...
            MinLength_s      = P.minLength_s, ...
            MergeDistance_s   = P.mergeDistance_s, ...
            LeftExtension_s  = P.leftExtension_s, ...
            RightExtension_s = P.rightExtension_s);

        roiPerChan{ci} = roiLims;

        % Rasterize cleaned ROIs back to frame grid
        for r = 1:size(roiLims, 1)
            a = roiLims(r, 1);
            b = roiLims(r, 2);
            active_ch(ci, :) = active_ch(ci, :) | (tFrames >= a & tFrames <= b);
        end
    end

    % 4) Merge channels -> global frame mask
    chanCount = sum(active_ch, 1);

    if ~isempty(P.minChanCount)
        minC = P.minChanCount;
    else
        minC = max(1, ceil(P.minChanFrac * nChans));
    end

    globalMask = (chanCount >= minC);

    % Convert global frame mask -> ROIs
    d = diff([false, globalMask, false]);
    gonF  = find(d ==  1);
    goffF = find(d == -1) - 1;

    if isempty(gonF)
        warning('detectPerChannelAlpha:NoGlobalROIs', ...
            'No global alpha events after channel merge. Lower minChanFrac or thresholds.');
        result = packEmpty(tFrames, z_ch, active_ch, chanCount, globalMask, P);
        return
    end

    % Frame -> sample ROIs for global mask
    globalRoiTable = frameToSampleROIs(gonF, goffF, hopSize, frameSize, fs, nSamples);

    % Relabel as "alphaGlobal"
    globalRoiTable.roiLab = repmat(categorical("alphaGlobal"), height(globalRoiTable), 1);

    % 5) Global signalMask cleanup
    srcTbl = table(globalRoiTable.roiTime, globalRoiTable.roiLab);
    alphaMaskGlobal = signalMask( ...
        srcTbl, ...
        "SampleRate",     fs, ...
        "MinLength",      max(1, round(P.globalMinLength_s * fs)), ...
        "MergeDistance",   max(0, round(P.globalMergeDistance_s * fs)), ...
        "LeftExtension",  max(0, round(P.globalLeftExt_s * fs)), ...
        "RightExtension", max(0, round(P.globalRightExt_s * fs)));

    globalOut      = roimask(alphaMaskGlobal);
    globalLimits_t = globalOut{:, 1};

    if isempty(globalLimits_t)
        warning('detectPerChannelAlpha:AllPruned', ...
            'All global ROIs removed by cleanup. Relax global parameters.');
        result = packEmpty(tFrames, z_ch, active_ch, chanCount, globalMask, P);
        result.alphaMaskGlobal = alphaMaskGlobal;
        return
    end

    % 6) Select longest window
    win = selectWindow(globalLimits_t, fs, nSamples, ...
        FinalPad_s       = P.finalPad_s, ...
        MinSelectedWin_s = P.minSelectedWin_s);

    sigsWin = sigs(:, win.startIdx:win.endIdx);

    fprintf('detectPerChannelAlpha: window %.3f–%.3f s (%.3f s)\n', ...
        win.start_s, win.end_s, win.dur_s);

    % Pack result
    result.z_ch            = z_ch;
    result.active_ch       = active_ch;
    result.chanCount       = chanCount;
    result.globalMask      = globalMask;
    result.alphaMaskGlobal = alphaMaskGlobal;
    result.roiLimits       = globalLimits_t;
    result.win             = win;
    result.sigsWin         = sigsWin;
    result.tFrames         = tFrames;
    result.roiPerChan      = roiPerChan;
    result.P               = P;
end

% ---- Helper for empty results ----
function result = packEmpty(tFrames, z_ch, active_ch, chanCount, globalMask, P)
    result.z_ch            = z_ch;
    result.active_ch       = active_ch;
    result.chanCount       = chanCount;
    result.globalMask      = globalMask;
    result.alphaMaskGlobal = signalMask.empty;
    result.roiLimits       = [];
    result.win             = struct('startIdx',[], 'endIdx',[], 'start_s',[], ...
        'end_s',[], 'dur_s',[], 'roiIdx',[]);
    result.sigsWin         = [];
    result.tFrames         = tFrames;
    result.roiPerChan      = {};
    result.P               = P;
end
