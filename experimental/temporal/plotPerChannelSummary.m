function plotPerChannelSummary(result, frameInfo, opts)
%PLOTPERCHANNELSUMMARY Plot per-channel alpha detection summary.
%
%   plotPerChannelSummary(result, frameInfo)
%   plotPerChannelSummary(result, frameInfo, Name=Value)
%
%   Produces a 3-panel figure showing:
%     1) Channel-count heatmap: how many channels are active per frame
%     2) Global burst mask after channel merge
%     3) Active-channel raster (channels x frames)
%
%   Inputs:
%       result    - struct from detectPerChannelAlpha
%       frameInfo - struct from extractAlphaBandpower
%
%   Name-Value Arguments:
%       MaxChannelsRaster - max channels to show in raster (default 100)
%
%   Example:
%       result = detectPerChannelAlpha(sigs, fs, nSamples, alphaPow, fi, P);
%       plotPerChannelSummary(result, fi);
%
%   See also: detectPerChannelAlpha, plotAlphaDetection

    arguments
        result    (1,1) struct
        frameInfo (1,1) struct
        opts.MaxChannelsRaster (1,1) double = 100
    end

    tFrames = result.tFrames;

    figure('Name', 'Per-channel alpha detection summary');

    % Panel 1: Channel count per frame
    subplot(3,1,1);
    area(tFrames, result.chanCount, 'FaceAlpha', 0.5);
    xlabel('Time (s)');
    ylabel('# active channels');
    title('Active channel count per frame');

    if isfield(result.P, 'minChanFrac')
        nChans = size(result.active_ch, 1);
        if ~isempty(result.P.minChanCount)
            minC = result.P.minChanCount;
        else
            minC = max(1, ceil(result.P.minChanFrac * nChans));
        end
        yline(minC, '--r', sprintf('threshold (%d)', minC));
    end

    % Panel 2: Global mask
    subplot(3,1,2);
    stairs(tFrames, double(result.globalMask), 'LineWidth', 1);
    xlabel('Time (s)');
    ylabel('global mask');
    title('Global burst mask (channel-merged)');

    if ~isempty(result.win.startIdx)
        hold on;
        xline(result.win.start_s, '-g', 'win start', 'LineWidth', 1.5);
        xline(result.win.end_s,   '-g', 'win end',   'LineWidth', 1.5);
    end

    % Panel 3: Raster plot of active channels
    subplot(3,1,3);
    nShow = min(opts.MaxChannelsRaster, size(result.active_ch, 1));
    imagesc(tFrames, 1:nShow, result.active_ch(1:nShow, :));
    colormap(gca, [1 1 1; 0.2 0.4 0.8]);
    xlabel('Time (s)');
    ylabel('Channel index');
    title(sprintf('Active-channel raster (first %d channels)', nShow));
    set(gca, 'YDir', 'normal');
    applyPlotDefaults(gcf);
end
