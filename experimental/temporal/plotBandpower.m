function fig = plotBandpower(bandStore, tWindows, psdInfo, opts)
%PLOTBANDPOWER Interactive exploration of band-stratified PSD results.
%
%   plotBandpower(bandStore, tWindows, psdInfo)
%   plotBandpower(bandStore, tWindows, psdInfo, Name=Value)
%
%   Creates an interactive figure for exploring the output of
%   powerSpectrumDensity with Bands. Shows time-resolved bandpower traces
%   for each frequency band, one channel at a time, with keyboard/button
%   navigation between channels.
%
%   Inputs:
%       bandStore - signalDatastore from powerSpectrumDensity (Bands mode).
%                   Each member is [nWindows x nBands].
%       tWindows  - [1 x nWindows] window center times (seconds)
%       psdInfo   - info struct from powerSpectrumDensity (must have
%                   .bandNames and .bandRanges)
%
%   Name-Value Arguments:
%       LogScale    - plot in dB (10*log10) (default true)
%       Normalize   - z-score each band across time (default false)
%       Stacked     - offset bands vertically for readability (default false)
%       StackGap    - vertical gap between stacked traces (default 2)
%       Channels    - subset of channel indices to include (default all)
%       FigureName  - figure title (default "Bandpower Explorer")
%
%   Controls:
%       Right arrow / N  — next channel
%       Left arrow  / P  — previous channel
%       Buttons          — "< Prev" and "Next >"
%
%   Example:
%       bands.delta = [2 4]; bands.theta = [5 7]; bands.alpha = [8 12];
%       bands.beta  = [15 30]; bands.gamma1 = [30 59]; bands.gamma2 = [60 90];
%       [bandStore, tWindows, info] = powerSpectrumDensity(sds, Bands=bands);
%       plotBandpower(bandStore, tWindows, info);
%
%   See also: powerSpectrumDensity, readSourceSegment

    arguments
        bandStore  (1,1) signalDatastore
        tWindows   (1,:) double
        psdInfo    (1,1) struct
        opts.LogScale   (1,1) logical = false
        opts.Normalize  (1,1) logical = false
        opts.Stacked    (1,1) logical = false
        opts.StackGap   (1,1) double  = 2
        opts.Channels   (1,:) double  = []
        opts.FigureName (1,1) string  = "Bandpower Explorer"
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

    % ---- Subset channels if requested ----
    if isempty(opts.Channels)
        chanIdx = 1:nChansTotal;
    else
        chanIdx = opts.Channels;
        chanIdx(chanIdx < 1 | chanIdx > nChansTotal) = [];
    end
    nChans = numel(chanIdx);

    if nChans == 0
        error('plotBandpower:NoChannels', 'No valid channels to plot.');
    end

    bandNames = psdInfo.bandNames;
    nBands    = numel(bandNames);

    % ---- Build band color map ----
    colors = bandColors(nBands);

    % ---- Create figure ----
    fig = figure('Name', opts.FigureName, 'NumberTitle', 'off', ...
        'KeyPressFcn', @onKeyPress);

    % Navigation buttons
    uicontrol('Style','pushbutton', 'String','< Prev', ...
        'Units','normalized', 'Position',[0.01 0.01 0.08 0.04], ...
        'Callback', @(~,~) navigate(-1));
    uicontrol('Style','pushbutton', 'String','Next >', ...
        'Units','normalized', 'Position',[0.10 0.01 0.08 0.04], ...
        'Callback', @(~,~) navigate(1));

    % Channel counter text
    hCounter = uicontrol('Style','text', 'String','', ...
        'Units','normalized', 'Position',[0.20 0.01 0.15 0.04], ...
        'HorizontalAlignment','left', 'FontSize',14);

    ax = axes('Position',[0.08 0.10 0.88 0.85]);

    % ---- State ----
    currentIdx = 1;
    plotChannel(currentIdx);

    % ====== NESTED FUNCTIONS ======

    function plotChannel(idx)
        ci = chanIdx(idx);
        bp = allData{ci};  % [nWindows x nBands]

        cla(ax);
        hold(ax, 'on');

        legendLabels = strings(1, nBands);

        for bi = 1:nBands
            y = bp(:, bi);

            % Transform
            if opts.LogScale
                y = 10 * log10(max(y, eps));
            end
            if opts.Normalize
                y = (y - mean(y)) ./ max(std(y), eps);
            end
            if opts.Stacked
                y = y + (bi - 1) * opts.StackGap;
            end

            plot(ax, tWindows, y, 'Color', colors(bi,:), 'LineWidth', 1.2);

            if isfield(psdInfo, 'bandRanges')
                bRange = psdInfo.bandRanges.(bandNames(bi));
                legendLabels(bi) = sprintf('%s [%g–%g Hz]', bandNames(bi), bRange(1), bRange(2));
            else
                legendLabels(bi) = bandNames(bi);
            end
        end

        hold(ax, 'off');
        xlabel(ax, 'Time (s)');

        if opts.LogScale && ~opts.Normalize
            ylabel(ax, 'Bandpower (dB)');
        elseif opts.Normalize
            ylabel(ax, 'Bandpower (z-score)');
        else
            ylabel(ax, 'Bandpower');
        end

        title(ax, sprintf('Channel %d / %d: %s', idx, nChans, chanNames(ci)));
        legend(ax, legendLabels, 'Location', 'eastoutside', 'FontSize', 14);
        applyPlotDefaults(fig);
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
            case {'rightarrow', 'n'}
                navigate(1);
            case {'leftarrow', 'p'}
                navigate(-1);
        end
    end
end

% =========================================================================
%  HELPER
% =========================================================================
function c = bandColors(n)
%BANDCOLORS Distinct colors for frequency bands.
    base = [
        0.20 0.40 0.80   % delta  — blue
        0.10 0.70 0.70   % theta  — teal
        0.20 0.75 0.20   % alpha  — green
        0.90 0.70 0.10   % beta   — gold
        0.90 0.35 0.10   % gamma1 — orange
        0.75 0.10 0.40   % gamma2 — magenta
        0.50 0.20 0.80   % extra  — purple
        0.40 0.40 0.40   % extra  — gray
    ];
    if n <= size(base, 1)
        c = base(1:n, :);
    else
        c = lines(n);
    end
end
