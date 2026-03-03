function fig = plotCWT(bandStore, t, cwtInfo, opts)
%PLOTCWT Interactive exploration of CWT band reconstructions.
%
%   plotCWT(bandStore, t, cwtInfo)
%   plotCWT(bandStore, t, cwtInfo, Name=Value)
%
%   Creates an interactive figure for exploring the output of
%   continuousWaveletTransform. Shows time-domain band reconstructions
%   for each frequency band, one channel at a time, with keyboard/button
%   navigation between channels.
%
%   Inputs:
%       bandStore - signalDatastore from continuousWaveletTransform.
%                   Each member is [nSamples x nBands].
%       t         - [nSamples x 1] time vector (seconds) from
%                   continuousWaveletTransform.
%       cwtInfo   - info struct from continuousWaveletTransform (must have
%                   .bandNames and .bandRanges).
%
%   Name-Value Arguments:
%       Envelope    - overlay analytic envelope via hilbert() (default false)
%       Normalize   - z-score each band across time (default false)
%       Stacked     - offset bands vertically for readability (default false)
%       StackGap    - vertical gap between stacked traces, in units of
%                     per-band standard deviation (default 4)
%       TimeRange   - [tStart tEnd] to zoom in (default [] = full)
%       Channels    - subset of channel indices to include (default all)
%       FigureName  - figure title (default "CWT Band Explorer")
%
%   Controls:
%       Right arrow / N  — next channel
%       Left arrow  / P  — previous channel
%       Buttons          — "< Prev" and "Next >"
%
%   Example:
%       bands.delta = [2 4]; bands.theta = [5 7]; bands.alpha = [8 12];
%       bands.beta  = [15 30]; bands.gamma1 = [30 59];
%       [bandStore, t, info] = continuousWaveletTransform(sds, Bands=bands);
%       plotCWT(bandStore, t, info);
%       plotCWT(bandStore, t, info, Envelope=true, Stacked=true);
%
%   See also: continuousWaveletTransform, plotCWTEnvelope, plotCWTSpectrogram

    arguments
        bandStore  (1,1) signalDatastore
        t          (:,1) double
        cwtInfo    (1,1) struct
        opts.Envelope   (1,1) logical = false
        opts.Normalize  (1,1) logical = false
        opts.Stacked    (1,1) logical = false
        opts.StackGap   (1,1) double  = 4
        opts.TimeRange  (1,:) double  = []
        opts.Channels   (1,:) double  = []
        opts.FigureName (1,1) string  = "CWT Band Explorer"
    end

    % ---- Read all channel data into memory ----
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
        error('plotCWT:NoChannels', 'No valid channels to plot.');
    end

    bandNames = cwtInfo.bandNames;
    nBands    = numel(bandNames);
    colors    = bandColors(nBands);

    % ---- Time range trimming ----
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
        'HorizontalAlignment','left', 'FontSize',9);

    ax = axes('Position',[0.08 0.10 0.88 0.85]);

    currentIdx = 1;
    plotChannel(currentIdx);

    % ====== NESTED FUNCTIONS ======

    function plotChannel(idx)
        ci = chanIdx(idx);
        bMat = allData{ci};   % [nSamples x nBands]
        bMat = bMat(tMask, :);

        cla(ax);
        hold(ax, 'on');

        legendEntries = gobjects(0);
        legendLabels  = strings(0);

        for bi = 1:nBands
            y = bMat(:, bi);

            if opts.Normalize
                y = (y - mean(y)) ./ max(std(y), eps);
            end
            if opts.Stacked
                y = y + (bi - 1) * opts.StackGap;
            end

            h = plot(ax, tPlot, y, 'Color', colors(bi,:), 'LineWidth', 1);

            if opts.Envelope
                env = abs(hilbert(bMat(:, bi)));
                if opts.Normalize
                    env = (env - mean(env)) ./ max(std(env), eps);
                end
                if opts.Stacked
                    env = env + (bi - 1) * opts.StackGap;
                end
                plot(ax, tPlot, env, 'Color', colors(bi,:), ...
                    'LineWidth', 1.8, 'LineStyle', '-');
            end

            legendEntries(end+1) = h; %#ok<AGROW>
            bRange = cwtInfo.bandRanges.(bandNames(bi));
            legendLabels(end+1) = sprintf('%s [%g–%g Hz]', ...
                bandNames(bi), bRange(1), bRange(2)); %#ok<AGROW>
        end

        hold(ax, 'off');
        grid(ax, 'on');
        xlabel(ax, 'Time (s)');

        if opts.Normalize
            ylabel(ax, 'Amplitude (z-score)');
        else
            ylabel(ax, 'Amplitude');
        end

        title(ax, sprintf('Channel %d / %d: %s', idx, nChans, chanNames(ci)));
        legend(ax, legendEntries, legendLabels, 'Location','eastoutside', 'FontSize',8);
        hCounter.String = sprintf('%d / %d', idx, nChans);
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
        0.20 0.40 0.80   % delta  — blue
        0.10 0.70 0.70   % theta  — teal
        0.20 0.75 0.20   % alpha  — green
        0.90 0.70 0.10   % beta   — gold
        0.90 0.35 0.10   % gamma1 — orange
        0.75 0.10 0.40   % gamma2 — magenta
        0.50 0.20 0.80   % purple
        0.40 0.40 0.40   % gray
    ];
    if n <= size(base,1)
        c = base(1:n,:);
    else
        c = lines(n);
    end
end
