function fig = plotCWTSpectrogram(bandStore, t, cwtInfo, opts)
%PLOTCWTSPECTROGRAM Time-frequency heatmap of CWT band power per channel.
%
%   plotCWTSpectrogram(bandStore, t, cwtInfo)
%   plotCWTSpectrogram(bandStore, t, cwtInfo, Name=Value)
%
%   Displays a pseudo-spectrogram where each row is a frequency band and
%   the color represents instantaneous power (envelope²). This gives a
%   compact time-frequency view of the CWT band decomposition output.
%
%   Inputs:
%       bandStore - signalDatastore from continuousWaveletTransform.
%                   Each member is [nSamples x nBands].
%       t         - [nSamples x 1] time vector (seconds).
%       cwtInfo   - info struct from continuousWaveletTransform.
%
%   Name-Value Arguments:
%       Smooth      - moving-average window in seconds for power smoothing
%                     (default 0.25). Set 0 for raw instantaneous power.
%       LogScale    - plot power in dB: 10*log10(power) (default true)
%       CLim        - color axis limits [cMin cMax]. Default [] = auto
%                     percentile-based scaling (2nd–98th pctl).
%       Colormap    - colormap name (default "parula")
%       TimeRange   - [tStart tEnd] to zoom in (default [] = full)
%       Channels    - subset of channel indices (default all)
%       FigureName  - figure title (default "CWT Spectrogram")
%
%   Controls:
%       Right arrow / N  — next channel
%       Left arrow  / P  — previous channel
%
%   Example:
%       [bandStore, t, info] = continuousWaveletTransform(sds, Bands=bands);
%       plotCWTSpectrogram(bandStore, t, info);
%       plotCWTSpectrogram(bandStore, t, info, Smooth=0.5, LogScale=true);
%
%   See also: continuousWaveletTransform, plotCWT, plotCWTEnvelope

    arguments
        bandStore  (1,1) signalDatastore
        t          (:,1) double
        cwtInfo    (1,1) struct
        opts.Smooth     (1,1) double {mustBeNonnegative}  = 0.25
        opts.LogScale   (1,1) logical                     = true
        opts.CLim       (1,:) double                      = []
        opts.Colormap   (1,1) string                      = "parula"
        opts.TimeRange  (1,:) double                      = []
        opts.Channels   (1,:) double                      = []
        opts.FigureName (1,1) string                      = "CWT Spectrogram"
    end

    % ---- Read all data ----
    reset(bandStore);
    chanNames = sdsGetChannelNames(bandStore);
    allData = {};
    while hasdata(bandStore)
        d = read(bandStore);
        if iscell(d), d = d{1}; end
        allData{end+1} = d; %#ok<AGROW>
    end
    reset(bandStore);

    nChansTotal = numel(allData);

    % ---- Subset channels ----
    if isempty(opts.Channels)
        chanIdx = 1:nChansTotal;
    else
        chanIdx = opts.Channels;
        chanIdx(chanIdx < 1 | chanIdx > nChansTotal) = [];
    end
    nChans = numel(chanIdx);

    if nChans == 0
        error('plotCWTSpectrogram:NoChannels', 'No valid channels to plot.');
    end

    bandNames = cwtInfo.bandNames;
    nBands    = numel(bandNames);
    fs        = cwtInfo.sfreq;

    % ---- Smoothing kernel ----
    if opts.Smooth > 0
        smoothSamples = max(round(opts.Smooth * fs), 1);
    else
        smoothSamples = 0;
    end

    % ---- Time range ----
    if ~isempty(opts.TimeRange)
        tMask = (t >= opts.TimeRange(1)) & (t <= opts.TimeRange(2));
    else
        tMask = true(size(t));
    end
    tPlot = t(tMask);

    % ---- Build Y-axis labels: band center frequencies ----
    bandCenters = zeros(nBands, 1);
    bandLabels  = strings(nBands, 1);
    for bi = 1:nBands
        bRange = cwtInfo.bandRanges.(bandNames(bi));
        bandCenters(bi) = mean(bRange);
        bandLabels(bi) = sprintf('%s\n[%g–%g]', bandNames(bi), bRange(1), bRange(2));
    end

    % ---- Create figure ----
    fig = figure('Name', opts.FigureName, 'NumberTitle', 'off', ...
        'KeyPressFcn', @onKeyPress);

    uicontrol('Style','pushbutton', 'String','< Prev', ...
        'Units','normalized', 'Position',[0.01 0.01 0.08 0.04], ...
        'Callback', @(~,~) navigate(-1));
    uicontrol('Style','pushbutton', 'String','Next >', ...
        'Units','normalized', 'Position',[0.10 0.01 0.08 0.04], ...
        'Callback', @(~,~) navigate(1));
    hCounter = uicontrol('Style','text', 'String','', ...
        'Units','normalized', 'Position',[0.20 0.01 0.15 0.04], ...
        'HorizontalAlignment','left', 'FontSize',14);

    ax = axes('Position',[0.10 0.12 0.82 0.80]);

    currentIdx = 1;
    plotChannel(currentIdx);

    % ====== NESTED FUNCTIONS ======

    function plotChannel(idx)
        ci = chanIdx(idx);
        bMat = allData{ci};
        bMat = bMat(tMask, :);  % [nSamples x nBands]
        nT = size(bMat, 1);

        % Compute instantaneous power (envelope²)
        powerMat = zeros(nT, nBands);
        for bi = 1:nBands
            env = abs(hilbert(bMat(:, bi)));
            if smoothSamples > 0
                env = movmean(env, smoothSamples);
            end
            powerMat(:, bi) = env.^2;
        end

        % Log scale
        if opts.LogScale
            powerMat = 10 * log10(max(powerMat, eps));
        end

        % Downsample time axis for display if > 2000 points
        maxPts = 2000;
        if nT > maxPts
            step = ceil(nT / maxPts);
            tDown = tPlot(1:step:end);
            pDown = powerMat(1:step:end, :);
        else
            tDown = tPlot;
            pDown = powerMat;
        end

        % Image: rows = bands (Y), columns = time (X)
        % imagesc expects [nRows x nCols] with rows = Y
        imgData = pDown';  % [nBands x nTime]

        cla(ax);
        imagesc(ax, tDown, 1:nBands, imgData);
        set(ax, 'YDir', 'normal');

        % Y-axis labels
        set(ax, 'YTick', 1:nBands, 'YTickLabel', bandLabels);

        % Color limits
        if ~isempty(opts.CLim)
            caxis(ax, opts.CLim);
        else
            vals = imgData(:);
            vals = vals(isfinite(vals));
            if ~isempty(vals)
                cLow  = prctile(vals, 2);
                cHigh = prctile(vals, 98);
                if cLow < cHigh
                    caxis(ax, [cLow cHigh]);
                end
            end
        end

        colormap(ax, opts.Colormap);
        cb = colorbar(ax);
        if opts.LogScale
            cb.Label.String = 'Power (dB)';
        else
            cb.Label.String = 'Power';
        end

        xlabel(ax, 'Time (s)');
        ylabel(ax, 'Band');
        title(ax, sprintf('Channel %d / %d: %s', idx, nChans, chanNames(ci)));
        hCounter.String = sprintf('%d / %d', idx, nChans);
        applyPlotDefaults(fig);
    end

    function navigate(step)
        newIdx = currentIdx + step;
        if newIdx >= 1 && newIdx <= nChans
            currentIdx = newIdx;
            plotChannel(currentIdx);
        end
    end

    function onKeyPress(~, evt)
        switch evt.Key
            case {'rightarrow','n'}, navigate(1);
            case {'leftarrow','p'},  navigate(-1);
        end
    end
end
