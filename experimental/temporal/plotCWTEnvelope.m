function fig = plotCWTEnvelope(bandStore, t, cwtInfo, opts)
%PLOTCWTENVELOPE Interactive band envelope comparison across channels.
%
%   plotCWTEnvelope(bandStore, t, cwtInfo)
%   plotCWTEnvelope(bandStore, t, cwtInfo, Name=Value)
%
%   Computes analytic envelopes (via Hilbert transform) for each band
%   reconstruction from continuousWaveletTransform, then plots them
%   overlaid or in subplots. Useful for comparing the temporal dynamics of
%   oscillatory power across bands.
%
%   Inputs:
%       bandStore - signalDatastore from continuousWaveletTransform.
%                   Each member is [nSamples x nBands].
%       t         - [nSamples x 1] time vector (seconds).
%       cwtInfo   - info struct from continuousWaveletTransform.
%
%   Name-Value Arguments:
%       Layout      - "overlay" (all bands on one axis) or "subplots"
%                     (one subplot per band) (default "overlay")
%       Smooth      - moving-average window in seconds for envelope
%                     smoothing (default 0 = no smoothing)
%       LogScale    - plot in dB: 10*log10(envelope) (default false)
%       Normalize   - z-score each band envelope (default false)
%       TimeRange   - [tStart tEnd] to zoom in (default [] = full)
%       Channels    - subset of channel indices (default all)
%       FigureName  - figure title (default "CWT Envelope Explorer")
%
%   Controls:
%       Right arrow / N  — next channel
%       Left arrow  / P  — previous channel
%
%   Example:
%       [bandStore, t, info] = continuousWaveletTransform(sds, Bands=bands);
%       plotCWTEnvelope(bandStore, t, info);
%       plotCWTEnvelope(bandStore, t, info, Layout="subplots", Smooth=0.5);
%
%   See also: continuousWaveletTransform, plotCWT, plotCWTSpectrogram

    arguments
        bandStore  (1,1) signalDatastore
        t          (:,1) double
        cwtInfo    (1,1) struct
        opts.Layout     (1,1) string {mustBeMember(opts.Layout, ...
                                      ["overlay","subplots"])} = "overlay"
        opts.Smooth     (1,1) double {mustBeNonnegative}       = 0
        opts.LogScale   (1,1) logical                          = false
        opts.Normalize  (1,1) logical                          = false
        opts.TimeRange  (1,:) double                           = []
        opts.Channels   (1,:) double                           = []
        opts.FigureName (1,1) string                           = "CWT Envelope Explorer"
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
        error('plotCWTEnvelope:NoChannels', 'No valid channels to plot.');
    end

    bandNames = cwtInfo.bandNames;
    nBands    = numel(bandNames);
    colors    = bandColors(nBands);
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

    % Create axes
    if opts.Layout == "subplots"
        axArr = gobjects(nBands, 1);
        for bi = 1:nBands
            axArr(bi) = subplot(nBands, 1, bi, 'Parent', fig);
        end
    else
        axArr = axes('Position',[0.08 0.10 0.88 0.85]);
    end

    currentIdx = 1;
    plotChannel(currentIdx);

    % ====== NESTED FUNCTIONS ======

    function plotChannel(idx)
        ci = chanIdx(idx);
        bMat = allData{ci};
        bMat = bMat(tMask, :);

        if opts.Layout == "subplots"
            for bi = 1:nBands
                ax = axArr(bi);
                cla(ax); hold(ax, 'on');

                env = computeEnvelope(bMat(:, bi));

                fill(ax, [tPlot; flipud(tPlot)], [env; zeros(size(env))], ...
                    colors(bi,:), 'FaceAlpha', 0.3, 'EdgeColor', 'none');
                plot(ax, tPlot, env, 'Color', colors(bi,:), 'LineWidth', 1.2);

                hold(ax, 'off');

                bRange = cwtInfo.bandRanges.(bandNames(bi));
                ylabel(ax, sprintf('%s\n[%g\u2013%g]', bandNames(bi), bRange(1), bRange(2)));

                if bi < nBands
                    set(ax, 'XTickLabel', []);
                else
                    xlabel(ax, 'Time (s)');
                end
            end
            sgtitle(fig, sprintf('Channel %d / %d: %s', idx, nChans, chanNames(ci)), ...
                'FontSize', 16);

        else  % overlay
            ax = axArr;
            cla(ax); hold(ax, 'on');

            legendEntries = gobjects(0);
            legendLabels  = strings(0);

            for bi = 1:nBands
                env = computeEnvelope(bMat(:, bi));
                h = plot(ax, tPlot, env, 'Color', colors(bi,:), 'LineWidth', 1.4);

                legendEntries(end+1) = h; %#ok<AGROW>
                bRange = cwtInfo.bandRanges.(bandNames(bi));
                legendLabels(end+1) = sprintf('%s [%g–%g Hz]', ...
                    bandNames(bi), bRange(1), bRange(2)); %#ok<AGROW>
            end

            hold(ax, 'off');
            xlabel(ax, 'Time (s)');

            if opts.LogScale
                ylabel(ax, 'Envelope (dB)');
            elseif opts.Normalize
                ylabel(ax, 'Envelope (z-score)');
            else
                ylabel(ax, 'Envelope');
            end

            title(ax, sprintf('Channel %d / %d: %s', idx, nChans, chanNames(ci)));
            legend(ax, legendEntries, legendLabels, 'Location','eastoutside', 'FontSize',14);
        end

        applyPlotDefaults(fig);
        hCounter.String = sprintf('%d / %d', idx, nChans);
    end

    function env = computeEnvelope(y)
        env = abs(hilbert(y));
        if smoothSamples > 0
            env = movmean(env, smoothSamples);
        end
        if opts.LogScale
            env = 10 * log10(max(env, eps));
        end
        if opts.Normalize
            env = (env - mean(env)) ./ max(std(env), eps);
        end
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

% =========================================================================
function c = bandColors(n)
    base = [
        0.20 0.40 0.80
        0.10 0.70 0.70
        0.20 0.75 0.20
        0.90 0.70 0.10
        0.90 0.35 0.10
        0.75 0.10 0.40
        0.50 0.20 0.80
        0.40 0.40 0.40
    ];
    if n <= size(base,1)
        c = base(1:n,:);
    else
        c = lines(n);
    end
end
