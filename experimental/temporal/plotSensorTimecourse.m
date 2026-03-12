function hFig = plotSensorTimecourse(data, sfreq, opts)
%PLOTSENSORTIMECOURSE Plot sensor-space channel data with interactive cursor.
%
%   hFig = plotSensorTimecourse(data, sfreq)
%   hFig = plotSensorTimecourse(data, sfreq, Name=Value)
%
%   Displays sensor-space data (e.g. CWT band amplitudes, Hilbert envelopes,
%   or raw channel data) as a heatmap with a vertical cursor. Designed to
%   pair with plotSourceTimecourse and viewer.setScalar for synchronized
%   exploration of sensor and source activity.
%
%   Inputs:
%       data  - [nChannels × nSamples] sensor data matrix
%       sfreq - sampling frequency (Hz)
%
%   Name-Value Arguments:
%       TimeOffset   - time of the first sample in seconds (default 0)
%       TimePoint    - initial cursor time in seconds (default: middle)
%       TimeRange    - [tStart tEnd] to display subset (default: all)
%       ChannelNames - [nChannels × 1] string array (default: numbered)
%       Title        - figure title (default "Sensor Timecourse")
%       CLim         - color limits [cmin cmax] (default: symmetric 99th pctl)
%       Colormap     - colormap name or matrix (default: diverging blue-red)
%       MaxChannels  - max channels to display (default 270)
%       YLabel       - y-axis label (default "Channel")
%       Callback     - function handle called on click: f(tSeconds, tIndex)
%
%   Output:
%       hFig - figure handle
%
%   Examples:
%       %% Basic — show all channels of alpha CWT band
%       plotSensorTimecourse(cwtBands.alpha, sfreq, ...
%           Title="Alpha band (sensor)");
%
%       %% With time window matching source plot
%       plotSensorTimecourse(cwtBands.alpha, sfreq, ...
%           TimeRange=[10 14], TimePoint=12.0, ...
%           Title="Alpha band (sensor)", ...
%           ChannelNames=chanNames);
%
%       %% Synchronized with source viewer
%       plotSensorTimecourse(cwtBands.alpha, sfreq, ...
%           TimeRange=[10 14], TimePoint=12.0, ...
%           Callback=@(t,i) viewer.setScalar(alphaLeftWin(:, ...
%               round((t - 10) * sfreq) + 1)));
%
%   See also: plotSourceTimecourse, readCWTBand, readBandMatrix

    arguments
        data     (:,:) double
        sfreq    (1,1) double {mustBePositive}
        opts.TimeOffset   (1,1) double  = 0
        opts.TimePoint    (1,1) double  = NaN
        opts.TimeRange    (1,:) double  = []
        opts.ChannelNames               = []
        opts.Title        (1,1) string  = "Sensor Timecourse"
        opts.CLim         (1,:) double  = []
        opts.Colormap                   = []
        opts.MaxChannels  (1,1) double {mustBePositive} = 270
        opts.YLabel       (1,1) string  = "Channel"
        opts.Callback                   = []
    end

    [nChan, nSamp] = size(data);

    % ---- Full time vector ----
    tFull = opts.TimeOffset + (0:nSamp-1) / sfreq;

    % ---- Apply time range ----
    if ~isempty(opts.TimeRange)
        t1 = opts.TimeRange(1);
        t2 = opts.TimeRange(end);
        iRange = (tFull >= t1 & tFull <= t2);
        dispData = data(:, iRange);
        tVec = tFull(iRange);
    else
        dispData = data;
        tVec = tFull;
    end
    nDispSamp = size(dispData, 2);

    % ---- Channel names ----
    if isempty(opts.ChannelNames)
        chanLabels = string(1:nChan);
    else
        chanLabels = string(opts.ChannelNames(:));
    end

    % ---- Downsample channels if too many ----
    if nChan > opts.MaxChannels
        step = ceil(nChan / opts.MaxChannels);
        dispData = dispData(1:step:end, :);
        chanLabels = chanLabels(1:step:end);
    end
    nDispChan = size(dispData, 1);

    % ---- Color limits ----
    if isempty(opts.CLim)
        cMax = prctile(abs(dispData(:)), 99);
        if cMax == 0, cMax = 1; end
        cLim = [-cMax, cMax];
    else
        cLim = opts.CLim;
    end

    % ---- Default cursor ----
    if isnan(opts.TimePoint)
        cursorT = tVec(round(nDispSamp/2));
    else
        cursorT = opts.TimePoint;
    end

    % ---- Create figure ----
    hFig = figure('Name', opts.Title, 'NumberTitle', 'off', ...
        'Color', 'w', 'Position', [100 550 1000 400]);

    ax = axes(hFig, 'Position', [0.08 0.14 0.86 0.78]);
    imagesc(ax, tVec, 1:nDispChan, dispData, cLim);
    axis(ax, 'xy');
    xlabel(ax, 'Time (s)');
    ylabel(ax, opts.YLabel);
    title(ax, opts.Title);

    % ---- Y tick labels (show subset to avoid clutter) ----
    if nDispChan <= 30
        ax.YTick = 1:nDispChan;
        ax.YTickLabel = chanLabels;
    else
        nTicks = min(20, nDispChan);
        tickIdx = round(linspace(1, nDispChan, nTicks));
        ax.YTick = tickIdx;
        ax.YTickLabel = chanLabels(tickIdx);
        ax.FontSize = 14;
    end

    % ---- Colormap ----
    if isempty(opts.Colormap)
        n = 256;
        r = [linspace(0.2, 1, n/2), ones(1, n/2)];
        g = [linspace(0.2, 1, n/2), linspace(1, 0.2, n/2)];
        b = [ones(1, n/2), linspace(1, 0.2, n/2)];
        cmap = [r' g' b'];
        colormap(ax, cmap);
    elseif ischar(opts.Colormap) || isstring(opts.Colormap)
        colormap(ax, opts.Colormap);
    else
        colormap(ax, opts.Colormap);
    end

    cb = colorbar(ax);
    cb.Label.String = 'Amplitude';

    % ---- Cursor line ----
    hold(ax, 'on');
    hCursor = xline(ax, cursorT, 'r-', 'LineWidth', 2);
    hLabel = text(ax, cursorT, nDispChan * 1.03, sprintf('t = %.3f s', cursorT), ...
        'Color', 'r', 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'Clipping', 'off');
    hold(ax, 'off');
    applyPlotDefaults(hFig);

    % ---- Store state ----
    state.data     = data;
    state.tVec     = tVec;
    state.tFull    = tFull;
    state.sfreq    = sfreq;
    state.hCursor  = hCursor;
    state.hLabel   = hLabel;
    state.nDispChan = nDispChan;
    state.callback = opts.Callback;
    state.ax       = ax;
    hFig.UserData  = state;

    % ---- Click handler ----
    hFig.WindowButtonDownFcn = @onFigClick;

    % ---- Set initial cursor ----
    moveCursor(hFig, cursorT);
end


function moveCursor(hFig, tSec)
    s = hFig.UserData;

    [~, idx] = min(abs(s.tVec - tSec));
    tSnapped = s.tVec(idx);

    s.hCursor.Value = tSnapped;
    s.hLabel.Position(1) = tSnapped;
    s.hLabel.String = sprintf('t = %.3f s', tSnapped);

    if ~isempty(s.callback)
        try
            s.callback(tSnapped, idx);
        catch ME
            warning('plotSensorTimecourse:CallbackError', ...
                'Callback error: %s', ME.message);
        end
    end
end


function onFigClick(hFig, ~)
    s = hFig.UserData;
    cp = s.ax.CurrentPoint;
    tClicked = cp(1,1);

    tRange = s.tVec([1 end]);
    if tClicked >= tRange(1) && tClicked <= tRange(2)
        moveCursor(hFig, tClicked);
    end
end
