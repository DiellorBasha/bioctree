function exportLineWaveVideo(X, x, t, filename, framerate, varargin)
% exportLineWaveVideo  Animate wave dynamics on a 1-D line with side-by-side views.
%
% Layout: [ 1 tile (left) | 6 tiles (right) ]
% - Left  : either a line plot (default) or a colormap rectangle per 'LeftMode'
% - Right : space–time panel (image or time-series lines) per 'SpaceTimeMode'
%
% Inputs
%   X         [Nx x T]  amplitude over space x and time t
%   x         [Nx x 1]  spatial positions
%   t         [1  x T]  time vector
%   filename  e.g., 'line_wave.mp4'
%   framerate (default 24)
%
% Name-Value options (all optional)
%   'AmplitudeLimits' : [amin amax] for the left line plot x-axis; default symmetric from data
%   'ColorLimits'     : [cmin cmax] for colormap scaling (used by right image and left rectangle)
%   'Colormap'        : colormap for imagesc/rectangle (default 'parula')
%   'Title'           : main title prefix (default 'Wave on a Line')
%   'Quality'         : video quality (1–100, default 95)
%   'Save'            : 0 show live (default), 1 save video
%   'YLimits'         : (back-compat) mapped to AmplitudeLimits
%
%   % Right panel mode (already added):
%   'SpaceTimeMode'   : 'image' (default) | 'lines'
%   'NumLines'        : number of traces when SpaceTimeMode='lines' (default: min(Nx,100))
%   'TraceLineWidth'  : linewidth for traces (default 0.8)
%   'TraceColor'      : RGB triple (default [0 0 0])
%   'WiggleScale'     : vertical scale (position units per amplitude unit); auto if empty
%
%   % NEW left panel option:
%   'LeftMode'        : 'line' (default) | 'colormap'
%   'LeftRectWidth'   : integer width (columns) of the rectangle color bar (default 20)
%
% Example
%   exportLineWaveVideo(X, x, t, 'line_wave.mp4', 24, ...
%       'LeftMode','colormap', 'SpaceTimeMode','lines', 'Colormap','turbo');

    if nargin < 5 || isempty(framerate), framerate = 24; end

    p = inputParser;
    addParameter(p,'AmplitudeLimits',[]);
    addParameter(p,'ColorLimits',[]);
    addParameter(p,'Colormap','parula');
    addParameter(p,'Title','Wave on a Line');
    addParameter(p,'Quality',95);
    addParameter(p,'Save',0);
    % Back-compat
    addParameter(p,'YLimits',[]);
    % Right panel mode
    addParameter(p,'SpaceTimeMode','image');
    addParameter(p,'NumLines',[]);
    addParameter(p,'TraceLineWidth',0.8);
    addParameter(p,'TraceColor',[0 0 0]);
    addParameter(p,'WiggleScale',[]);
    % NEW left panel mode
    addParameter(p,'LeftMode','line');           % 'line' | 'colormap'
    addParameter(p,'LeftRectWidth',5);          % width (columns) of the rectangle
    parse(p,varargin{:});

    AmpL     = p.Results.AmplitudeLimits;
    if isempty(AmpL) && ~isempty(p.Results.YLimits), AmpL = p.Results.YLimits; end
    CL       = p.Results.ColorLimits;
    cmap     = p.Results.Colormap;
    ttl      = p.Results.Title;
    q        = p.Results.Quality;
    isSave   = p.Results.Save;

    modeST   = lower(string(p.Results.SpaceTimeMode));
    nLines   = p.Results.NumLines;
    lwTrace  = p.Results.TraceLineWidth;
    colTrace = p.Results.TraceColor;
    wigScale = p.Results.WiggleScale;

    leftMode = lower(string(p.Results.LeftMode));
    rectW    = max(1, round(p.Results.LeftRectWidth));

    % ---- validate sizes ----
    [Nx, T] = size(X);
    assert(isvector(x) && numel(x)==Nx, 'x must be Nx-by-1 matching rows of X.');
    assert(isvector(t) && numel(t)==T,  't must have length T matching columns of X.');
    x = x(:);            % ensure column
    t = t(:).';          % ensure row

    % ---- amplitude axis limits (symmetric by default) ----
    if isempty(AmpL)
        A = max(abs(X(:))); if A==0, A = 1; end
        AmpL = 1.05*[-A, A];
    end

    % ---- video writer ----
    if isSave
        try
            v = VideoWriter(filename, 'MPEG-4');
        catch
            warning('MPEG-4 profile unavailable; falling back to Motion JPEG AVI.');
            [pth,nam,ext] = fileparts(filename);
            if ~strcmpi(ext,'.avi'), filename = fullfile(pth,[nam '.avi']); end
            v = VideoWriter(filename, 'Motion JPEG AVI');
        end
        v.FrameRate = framerate;
        if isprop(v,'Quality'), v.Quality = q; end
        open(v);
    end

    % ---- figure & tiled layout: 1x7, left=1 tile, right=6 tiles ----
    if isSave
        fig = figure('Visible','off','Color','w','Position',[100 100 1200 500]);
    else
        fig = figure('Visible','on','Color','w','Position',[100 100 700 500]);
    end
    tl  = tiledlayout(fig,1,7,'TileSpacing','compact','Padding','compact');

    % ===================== Left panel =====================
    ax1 = nexttile(tl,1,[1 1]); hold(ax1,'on');
    hLine = []; hRect = [];

    switch leftMode
        case "line"
            hLine = plot(ax1, X(:,1), x, 'LineWidth', 2); % amplitude on x-axis, line coord on y-axis
            xline(ax1,0,'k:','LineWidth',0.75);
            grid(ax1,'on'); box(ax1,'on');
            xlabel(ax1,'Amplitude');
            ax1.YAxis.Visible = "off";
            xlim(ax1, AmpL);
            ylim(ax1, [x(1), x(end)]);
        case "colormap"
            % rectangle spanning x in Y and [0,1] in X; color from current time slice
            C0 = repmat(X(:,1), 1, rectW);
            hRect = imagesc(ax1, [0 1], [x(1) x(end)], C0); axis(ax1,'xy');
            colormap(ax1, cmap);
            % use ColorLimits if provided, else symmetric amplitude limits
            if ~isempty(CL), caxis(ax1, CL); else, caxis(ax1, AmpL); end
            % Clean look: hide axes ticks/labels; keep box for the rectangle frame
            ax1.XAxis.Visible = "off";
            ax1.YAxis.Visible = "off";
            box(ax1,'on');
            xlim(ax1, [0 1]);
            ylim(ax1, [x(1), x(end)]);
            axis tight
        otherwise
            error('LeftMode must be ''line'' or ''colormap''.');
    end

    % ===================== Right panel =====================
    ax2 = nexttile(tl,2,[1 6]); hold(ax2,'on');

    hCursor = [];
    if modeST == "image"
        hImg = imagesc(ax2, t, x, X); axis(ax2,'xy');
        colormap(ax2, cmap); colorbar(ax2);
        if ~isempty(CL), caxis(ax2, CL); end
        title(ax2, 'Space–time amplitude (cursor = current time)');
    elseif modeST == "lines"
        if isempty(nLines), nLines = min(Nx, 100); end
        idx = unique(round(linspace(1, Nx, nLines)));
        pos = x(idx);

        if isempty(wigScale)
            dx = median(diff(x)); if isempty(dx) || ~isfinite(dx), dx = 1; end
            A  = max(abs(X(:))); if A==0, A = 1; end
            wigScale = 0.45 * dx / A;
        end

        for m = 1:numel(idx)
            y = pos(m) + wigScale * X(idx(m),:);
            plot(ax2, t, y, 'Color', colTrace, 'LineWidth', lwTrace);
        end
        title(ax2, 'Space–time traces (cursor = current time)');
    else
        error('SpaceTimeMode must be ''image'' or ''lines''.');
    end

    xlabel(ax2,'Time');
    ax2.YAxis.Visible = "off";
    xlim(ax2,[t(1), t(end)]);
    ylim(ax2,[x(1), x(end)]);

    % time cursor on the right
    hCursor = plot(ax2, [t(1) t(1)], [x(1) x(end)], 'k--', 'LineWidth', 1.25);

    % ---- animate ----
    for ti = 1:T
        % Left panel update
        switch leftMode
            case "line"
                hLine.XData = X(:,ti);
            case "colormap"
                set(hRect, 'CData', repmat(X(:,ti), 1, rectW));
        end

        % Right panel cursor update
        tt = t(ti);
        hCursor.XData = [tt tt];

        % small per-frame stamp (on left)
        ax1.Subtitle.String = sprintf('t = %.3f s', tt);

        drawnow limitrate;
        frame = getframe(fig);
        if isSave
            writeVideo(v, frame);
        end
    end

    % ---- done ----
    if isSave
        close(v);
        close(fig);
        fprintf('✅ Video saved as %s (FPS=%g)\n', filename, v.FrameRate);
    else
        fprintf('✅ Plotting animation\n');
    end
end
