function plotGlobalROIs(alphaMask, sigs, fs, frameInfo, opts)
%PLOTGLOBALROIS Plot signalMask ROIs overlaid on signals.
%
%   plotGlobalROIs(alphaMask, sigs, fs, frameInfo)
%   plotGlobalROIs(alphaMask, sigs, fs, frameInfo, Name=Value)
%
%   Visualizes alpha ROIs from a signalMask object on:
%     - The global alpha power index (upsampled to sample rate)
%     - Selected individual MEG channels
%
%   Inputs:
%       alphaMask - signalMask object (from detectGlobalAlpha or detectPerChannelAlpha)
%       sigs      - [nChans x nSamples] signal matrix
%       fs        - sampling rate (Hz)
%       frameInfo - struct from extractAlphaBandpower
%
%   Name-Value Arguments:
%       AlphaGlobal    - [1 x nFrames] global alpha index (for overview plot)
%       ChannelIndices - indices of channels to plot individually (default [1 50 100 150 200 250])
%       ChannelNames   - {nChans x 1} cell of channel names (optional)
%
%   Example:
%       plotGlobalROIs(result.alphaMask, data.sigs, data.fs, fi, ...
%           AlphaGlobal=result.alphaGlobal, ChannelNames=data.chanNames);
%
%   See also: plotAlphaDetection, detectGlobalAlpha

    arguments
        alphaMask
        sigs       (:,:) double
        fs         (1,1) double
        frameInfo  (1,1) struct
        opts.AlphaGlobal    (1,:) double = []
        opts.ChannelIndices (1,:) double = [1 50 100 150 200 250]
        opts.ChannelNames   (:,1) cell = {}
    end

    nSamples = size(sigs, 2);
    nChans   = size(sigs, 1);

    if isempty(alphaMask)
        warning('plotGlobalROIs:NoMask', 'Empty signalMask — nothing to plot.');
        return
    end

    % ---- Overview: alpha power index upsampled to sample rate ----
    if ~isempty(opts.AlphaGlobal)
        hopSize   = frameInfo.hopSize;
        frameSize = frameInfo.frameSize;
        nFrames   = numel(opts.AlphaGlobal);

        alphaGlobal_samp = zeros(1, nSamples);
        for k = 1:nFrames
            s0 = (k-1) * hopSize + 1;
            s1 = min(nSamples, s0 + frameSize - 1);
            alphaGlobal_samp(s0:s1) = opts.AlphaGlobal(k);
        end

        figure('Name', 'Global alpha ROIs over alpha index');
        plotsigroi(alphaMask, alphaGlobal_samp);
        title('Global alpha ROIs over alpha power index');
    end

    % ---- Individual channels ----
    chIdx = opts.ChannelIndices;
    chIdx = chIdx(chIdx >= 1 & chIdx <= nChans);

    for ii = 1:numel(chIdx)
        ci = chIdx(ii);
        x  = sigs(ci, :);

        if ~isempty(opts.ChannelNames)
            chName = opts.ChannelNames{ci};
        else
            chName = sprintf('ch%d', ci);
        end

        figure('Name', sprintf('Alpha ROIs — %s', chName));
        plotsigroi(alphaMask, x);
        title(sprintf('Global alpha ROIs — channel %d (%s)', ci, chName));
    end
end
