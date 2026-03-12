function hFig = plotSourceTimecourse(data, tVec, opts)
%PLOTSOURCETIMECOURSE Plot source-space time series with interactive cursor.
%
%   hFig = plotSourceTimecourse(data, tVec)
%   hFig = plotSourceTimecourse(data, tVec, Name=Value)
%
%   Displays source-space data as a heatmap (image) with a vertical cursor
%   marking the selected time point. Designed to pair with viewer.setScalar
%   for synchronized cortical surface visualization.
%
%   Inputs:
%       data - [nVertices × nSamples] source timecourse matrix
%              (e.g. alphaLeftWin from WK * cwtBands.alpha)
%       tVec - [1 × nSamples] or [nSamples × 1] time vector in seconds
%
%   Name-Value Arguments:
%       TimePoint    - initial cursor time in seconds (default: middle)
%       Title        - figure title (default "Source Timecourse")
%       CLim         - color limits [cmin cmax]. Default: symmetric around 0
%       Colormap     - colormap name or matrix (default "RdBu_r" style)
%       MaxVertices  - max vertices to display (default 500, downsamples)
%       YLabel       - y-axis label (default "Vertex")
%       Callback     - function handle called on click: f(tSeconds, tIndex)
%                      Use this to update viewer.setScalar on click.
%
%   Output:
%       hFig - figure handle
%
%   Examples:
%       %% Basic usage
%       plotSourceTimecourse(alphaLeftWin, tWin);
%
%       %% With cursor and viewer callback
%       plotSourceTimecourse(alphaLeftWin, tWin, ...
%           TimePoint=12.0, ...
%           Title="Alpha source (left hemi)", ...
%           Callback=@(t,i) viewer.setScalar(alphaLeftWin(:,i)));
%
%       %% Click on the plot to move cursor and update viewer
%
%   See also: readCWTBand, buildProjectionMatrix, bct.ui.manifold.Viewer

    arguments
        data     (:,:) double
        tVec     (1,:) double
        opts.TimePoint  (1,1) double  = NaN
        opts.Title      (1,1) string  = "Source Timecourse"
        opts.CLim       (1,:) double  = []
        opts.Colormap                 = []
        opts.MaxVertices (1,1) double {mustBePositive} = 500
        opts.YLabel     (1,1) string  = "Vertex"
        opts.Callback                 = []
    end

    [nVert, nSamp] = size(data);
    tVec = tVec(:)';

    if numel(tVec) ~= nSamp
        error('plotSourceTimecourse:DimMismatch', ...
            'tVec has %d elements but data has %d columns.', numel(tVec), nSamp);
    end

    % ---- Downsample vertices if too many ----
    if nVert > opts.MaxVertices
        step = ceil(nVert / opts.MaxVertices);
        dispData = data(1:step:end, :);
        vertIdx = 1:step:nVert;
    else
        dispData = data;
        vertIdx = 1:nVert;
    end
    nDispVert = size(dispData, 1);

    % ---- Color limits ----
    if isempty(opts.CLim)
        cMax = prctile(abs(dispData(:)), 99);
        cLim = [-cMax, cMax];
    else
        cLim = opts.CLim;
    end

    % ---- Default cursor ----
    if isnan(opts.TimePoint)
        cursorT = tVec(round(nSamp/2));
    else
        cursorT = opts.TimePoint;
    end

    % ---- Create figure ----
    hFig = figure('Name', opts.Title, 'NumberTitle', 'off', ...
        'Color', 'w', 'Position', [100 100 1000 500]);

    ax = axes(hFig, 'Position', [0.08 0.12 0.86 0.80]);
    imagesc(ax, tVec, 1:nDispVert, dispData, cLim);
    axis(ax, 'xy');
    xlabel(ax, 'Time (s)');
    ylabel(ax, opts.YLabel);
    title(ax, opts.Title);

    % ---- Colormap ----
    if isempty(opts.Colormap)
        % Diverging blue-white-red
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

    % Time label
    hLabel = text(ax, cursorT, nDispVert * 1.02, sprintf('t = %.3f s', cursorT), ...
        'Color', 'r', 'FontSize', 14, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'Clipping', 'off');
    hold(ax, 'off');
    applyPlotDefaults(hFig);

    % ---- Store state in figure UserData ----
    state.data      = data;
    state.tVec      = tVec;
    state.hCursor   = hCursor;
    state.hLabel    = hLabel;
    state.nDispVert = nDispVert;
    state.callback  = opts.Callback;
    state.ax        = ax;
    hFig.UserData   = state;

    % ---- Click interaction ----
    hFig.WindowButtonDownFcn = @onFigClick;

    % ---- Set initial cursor ----
    moveCursor(hFig, cursorT);
end


function moveCursor(hFig, tSec)
    s = hFig.UserData;
    
    % Snap to nearest sample
    [~, idx] = min(abs(s.tVec - tSec));
    tSnapped = s.tVec(idx);
    
    % Update cursor line
    s.hCursor.Value = tSnapped;
    
    % Update label
    s.hLabel.Position(1) = tSnapped;
    s.hLabel.String = sprintf('t = %.3f s', tSnapped);
    
    % Fire callback
    if ~isempty(s.callback)
        try
            s.callback(tSnapped, idx);
        catch ME
            warning('plotSourceTimecourse:CallbackError', ...
                'Callback error: %s', ME.message);
        end
    end
end


function onFigClick(hFig, ~)
    s = hFig.UserData;
    cp = s.ax.CurrentPoint;
    tClicked = cp(1,1);
    
    % Only respond to clicks within axes time range
    tRange = s.tVec([1 end]);
    if tClicked >= tRange(1) && tClicked <= tRange(2)
        moveCursor(hFig, tClicked);
    end
end
