function exportIcosphereVideo(V, F, X, t, filename, framerate, varargin)
% exportIcosphereVideo  Animate dynamics on an icosphere (triangle mesh).
% 
% Extended: show per-vertex time-series traces in a tiled layout alongside
% the 3D sphere animation (left = sphere, right = time-series). Behavior is
% backward-compatible when no trace options are provided.
%
% Inputs
%   V [N x 3], F [M x 3], X [N x T], t [1 x T]
%   filename (used only if Save=1), framerate (default 24)
%
% Name-Value (optional):
%   'ColorLimits',[cmin cmax]   'Colormap', cmapName or Nx3
%   'Title','...'               'Quality',95
%   'Save',0|1                  'ShowColorbar',true
%   'FaceAlpha',1               'EdgeAlpha',0
%   'EdgeColor',[.6 .7 .9]      'Lighting','gouraud'|'flat'|'none'
%   'View',[az el]              'BGColor',[1 1 1]
%   'FigurePosition',[x y w h]
%   'SpinAzimuthDegPerSec',0    'SpinElevationDegPerSec',0
%   'TimeText',true             'TimeTextPos',[x y z]
%   -- Time-series (new) --
%   'ShowTraces'      (default true)  - show right time-series panel
%   'NumTraces'       (default min(N,100))
%   'TraceIndices'    (vector)        - explicit vertex indices to plot
%   'TraceColor'      (RGB)           - color for traces (default [0 0 0])
%   'TraceLineWidth'  (default 0.8)
%   'WiggleScale'     (default auto scaled)
%   'SpaceTimeMode'   'image' (default) | 'lines'  % NEW: choose image (imagesc) or stacked wiggles
%
if nargin < 6 || isempty(framerate), framerate = 24; end

p = inputParser;
addParameter(p,'ColorLimits',[]);
addParameter(p,'Colormap',[]);
addParameter(p,'Title','Dynamics on Icosphere');
addParameter(p,'Quality',95);
addParameter(p,'Save',0);
addParameter(p,'ShowColorbar',true);
addParameter(p,'FaceAlpha',1.0);
addParameter(p,'EdgeAlpha',0.0);
addParameter(p,'EdgeColor',[0.6 0.7 0.9]);
addParameter(p,'Lighting','gouraud');
addParameter(p,'View',[45 20]);
addParameter(p,'BGColor',[1 1 1]);
addParameter(p,'FigurePosition',[]);
addParameter(p,'SpinAzimuthDegPerSec',0);
addParameter(p,'SpinElevationDegPerSec',0);
addParameter(p,'TimeText',true);
addParameter(p,'TimeTextPos',[]);
% time-series options
addParameter(p,'ShowTraces',true);
addParameter(p,'NumTraces',[]);
addParameter(p,'TraceIndices',[]);
addParameter(p,'TraceColor',[0 0 0]);
addParameter(p,'TraceLineWidth',0.8);
addParameter(p,'WiggleScale',[]);
% NEW: choose how to render time-series on right panel
addParameter(p,'SpaceTimeMode','image');   % 'image' | 'lines'
parse(p,varargin{:});

CL      = p.Results.ColorLimits;
cmap    = p.Results.Colormap;
ttl     = p.Results.Title;
q       = p.Results.Quality;
isSave  = p.Results.Save~=0;
showcb  = p.Results.ShowColorbar~=0;
fa      = p.Results.FaceAlpha;
ea      = p.Results.EdgeAlpha;
ec      = p.Results.EdgeColor;
lightMd = lower(string(p.Results.Lighting));
view0   = p.Results.View;
bg      = p.Results.BGColor;
pos     = p.Results.FigurePosition;
spinAz  = p.Results.SpinAzimuthDegPerSec;
spinEl  = p.Results.SpinElevationDegPerSec;
showTxt = p.Results.TimeText~=0;
txtPos  = p.Results.TimeTextPos;

% time-series params
showTraces = p.Results.ShowTraces;
numTraces  = p.Results.NumTraces;
traceIdx   = p.Results.TraceIndices;
traceColor = p.Results.TraceColor;
traceLW    = p.Results.TraceLineWidth;
wigScale   = p.Results.WiggleScale;
modeST     = lower(string(p.Results.SpaceTimeMode));

% ---- validate sizes ----
[N, T] = size(X);
assert(size(V,1)==N, 'X must have as many rows as vertices in V.');
assert(isvector(t) && numel(t)==T, 't must match columns of X.');
t = t(:).';

% ---- default color limits / colormap ----
if isempty(CL)
    A = max(abs(X(:))); if A==0, A=1; end
    CL = 1.05*[-A, A];
end
if isempty(cmap)
    if ~isempty(which('turbo'))
        cmap = 'turbo';
    else
        cmap = 'parula';
    end
end

% ---- video writer ----
if isSave
    try
        v = VideoWriter(filename, 'MPEG-4');
    catch
        warning('MPEG-4 unavailable; falling back to Motion JPEG AVI.');
        [pth,nam,ext] = fileparts(filename);
        if ~strcmpi(ext,'.avi'), filename = fullfile(pth,[nam '.avi']); end
        v = VideoWriter(filename, 'Motion JPEG AVI');
    end
    v.FrameRate = framerate;
    if isprop(v,'Quality'), v.Quality = q; end
    open(v);
end

% ---- figure/axes ----
if isempty(pos)
    if isSave, pos = [100 100 1200 700]; else, pos = [100 100 1000 700]; end
end
vis = 'on'; if isSave, vis = 'off'; end
fig = figure(1);
clf
fig.Visible=vis;
fig.Color=bg;
fig.Position = pos;
%fig = figure('Visible', vis, 'Color', bg, 'Position', pos);

% Use tiled layout: left = sphere, right = time-series
if showTraces
    tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
    ax = nexttile(tl,1); hold(ax,'on');       % sphere on left
    axis(ax,'vis3d'); 
    ax_ts = nexttile(tl,2); hold(ax_ts,'on'); % time-series on right
    box(ax_ts,'on');
    axis(ax_ts,'tight'); 
else
    ax = axes('Parent',fig); hold(ax,'on');
    axis(ax,'vis3d'); axis(ax,'off'); view(ax, view0(1), view0(2));
end



% if showTraces, prepare traces or image
if showTraces
    if isempty(numTraces), numTraces = min(N,100); end
    if ~isempty(traceIdx)
        idx = unique(traceIdx(:)).';
        idx = idx(idx>=1 & idx<=N);
        if isempty(idx), error('TraceIndices contained no valid indices.'); end
        if numel(idx) > numTraces
            idx = idx(1:numTraces);
        end
    else
        idx = unique(round(linspace(1, N, numTraces)));
    end
    numTraces = numel(idx);

    switch modeST
        case "image"
            % imagesc of selected vertices x time (rows = vertices, cols = time)
            hImg = imagesc(ax_ts, t, 1:numTraces, X(idx,:)); axis(ax_ts,'tight');
            colormap(ax_ts, cmap);
            if ~isempty(CL), caxis(ax_ts, CL); end
            colorbar(ax_ts);
            xlabel(ax_ts,'Time (s)');
            xlim(ax_ts, [t(1), t(end)]);
            ylim(ax_ts, [0.5, numTraces+0.5]);
            
            title(ax_ts, 'Vertex × Time');
            % cursor line
            hCursorTS = plot(ax_ts, [t(1) t(1)], [1 numTraces], 'k--', 'LineWidth', 1.5);
        case "lines"
            % stacked wiggle traces (y positions are 1..numTraces)
            if isempty(wigScale)
                A = max(abs(X(:))); if A==0, A = 1; end
                wigScale = 0.45 * (1 / A);
            end
            ybase = (1:numTraces)'; % stack indices
            hTraces = gobjects(numTraces,1);
            for m = 1:numTraces
                y = ybase(m) + wigScale * X(idx(m),:);
                hTraces(m) = plot(ax_ts, t, y, 'Color', traceColor, 'LineWidth', traceLW);
            end
            xlim(ax_ts, [t(1), t(end)]);
            ylim(ax_ts, [0.5, numTraces+0.5]);
            xlabel(ax_ts, 'Time (s)');
            yticks(ax_ts, 1:numTraces);
            yticklabels(ax_ts, cellstr(string(idx)));
            title(ax_ts, 'Vertex time-series');
            
            % time cursor
            hCursorTS = plot(ax_ts, [t(1) t(1)], ylim(ax_ts), 'k--', 'LineWidth', 1.5);
            
        otherwise
            error('SpaceTimeMode must be ''image'' or ''lines''.');
    end

    % ---- lock time-series axes to prevent autoscaling when updating cursor ----
    if exist('ax_ts','var') && isgraphics(ax_ts)
        set(ax_ts, ...
            'XLim', [t(1) t(end)], 'XLimMode','manual', ...
            'YLim', get(ax_ts,'YLim'), 'YLimMode','manual', ...
            'ActivePositionProperty','position', ...   % avoid layout shifts
            'NextPlot','add');                         % keep cursor/overlays without replacing image
        if exist('hCursorTS','var') && isgraphics(hCursorTS)
            set(hCursorTS, 'Clipping', 'on');         % avoid expanding view when cursor extends
        end
    end
end

% configure sphere axes
axis(ax,'equal'); axis(ax,'off'); view(ax, view0(1), view0(2));
% Apply colormap (name or Nx3)
if ischar(cmap) || (isstring(cmap) && isscalar(cmap))
    colormap(ax, char(cmap));
else
    colormap(ax, cmap);
end
caxis(ax, CL);

% ---------- replaced: create a fixed, figure-level colorbar so it doesn't resize ----------
if showcb
    % get sphere axis position in figure normalized units
    axPos = get(ax, 'Position');   % [x y w h]

    % horizontal colorbar below the sphere tile
    cbH = 0.035;                            % thin height
    cbW = 0.70 * axPos(3);                  % width relative to sphere tile
    cbX = axPos(1) + 0.5*axPos(3) - cbW/2;  % center under sphere tile

    % <-- moved down slightly by increasing the gap (cbGap) -->
    cbGap = 0.03;                           % gap between sphere tile and colorbar (was 0.01)
    cbY = axPos(2) - cbH - cbGap;          % use cbGap for vertical offset

    % fallback if gap would go negative (place above tile)
    if cbY < 0
        cbY = axPos(2) + axPos(4) + 0.01;
    end

    % create independent axes for the horizontal colorbar (not managed by tiledlayout)
    cbax = axes('Parent', fig, 'Position', [cbX, cbY, cbW, cbH], ...
                'Box', 'on', 'YTick', [], 'XColor', [0 0 0], 'YColor', 'none', ...
                'Color', 'none');

    % build horizontal gradient image (cols -> colors)
    ncol = 256;
    grad = linspace(CL(1), CL(2), ncol);      % row vector
    gradImg = repmat(grad, 2, 1);             % narrow image (2 rows, ncol cols)

    % map color values across X axis, keep Y small
    imagesc([CL(1) CL(2)], [0 1], gradImg, 'Parent', cbax);
    set(cbax, 'YDir', 'normal');

    % apply colormap and ticks on X
    colormap(cbax, cmap);
    % horizontal ticks only (Amplitude). hide any Y-axis ticks/labels.
    xt = linspace(CL(1), CL(2), 5);
    xticks(cbax, xt);
    xticklabels(cbax, arrayfun(@(v) num2str(v,'%.3g'), xt, 'UniformOutput', false));
    set(cbax, 'YTick', [], 'YTickLabel', {}, 'YColor', 'none', 'Box', 'on');
    xlabel(cbax, 'Amplitude');
    % keep this axes out of tiledlayout control
    cbax.ActivePositionProperty = 'position';
    cbax.Position = [cbX, cbY, cbW, cbH];
else
    cbax = [];
end

% ---- patch (per-vertex colors) ----
h = patch('Faces',F, 'Vertices',V, ...
          'FaceVertexCData', zeros(size(X,1),1), ...
          'FaceColor','interp', 'EdgeColor',ec, 'EdgeAlpha',ea, ...
          'FaceAlpha',fa, 'Parent',ax);

% Lighting
switch lightMd
    case "gouraud"
        lighting(ax,'gouraud'); camlight(ax,'headlight'); material(h,'dull');
    case "flat"
        lighting(ax,'flat');    camlight(ax,'headlight'); material(h,'dull');
    otherwise
        % none
end

if showTxt
    % place annotation near top-left of the sphere tile (uses normalized fig coords)
    axPos = get(ax, 'Position');          % [x y w h] in normalized figure coords
    annX = axPos(1) + 0.02*axPos(3);
    annW = max(0.12, 0.18*axPos(3));
    annH = max(0.04, 0.06*axPos(4));
    annY = axPos(2) + axPos(4) - annH - 0.02*axPos(4);
    ht = annotation(fig, 'textbox', [annX annY annW annH], ...
        'String', sprintf('t = %.3f s', t(1)), ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'EdgeColor', 'none', 'BackgroundColor', [1 1 1 0.75], ...
        'HorizontalAlignment','left', 'VerticalAlignment','middle', ...
        'Interpreter','none');
end

if ~strcmp(ttl, 'off')
% create a fixed, figure-level title (annotation) so it does not move with the camera
axPos = get(ax, 'Position');            % normalized [x y w h] of the sphere tile
annW = min(0.6, 0.8 * axPos(3));
annH = 0.06;
annX = axPos(1) + 0.5*axPos(3) - annW/2; % center above the sphere tile
annY = axPos(2) + axPos(4);
if annY>1 
    annY=0.75 ;
end
hTitleAnn = annotation(fig, 'textbox', [annX annY annW annH], ...
    'String', ttl, ...
    'FontSize', 16, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'EdgeColor', 'none', 'BackgroundColor', 'none');
end

ax.XLimitMethod='tight';
ax.YLimitMethod='tight';
ax.ZLimitMethod='tight';

set(ax_ts, ...
  'XLimMode','manual', 'YLimMode','manual', 'ZLimMode','manual', ...
  'CLimMode','manual');  
%ax.CLim = [min(X(:))  max(X(:))];
% ---- animate ----
for ti = 1:T
    set(h, 'FaceVertexCData', X(:,ti));
    if spinAz~=0 || spinEl~=0
        daz = spinAz / framerate;   % degrees per frame
        del = spinEl / framerate;
        % correct camorbit usage: rotate camera around the axes' CameraTarget in data coords
        camorbit(ax, daz, del, 'data');
    end
    if showTxt
        ht.String = sprintf('t = %.3f s', t(ti));
    end
    % update right-panel (time-series)
    if showTraces
        switch modeST
            case "image"
                % update image's CData (rows=vertices sampled, cols=time)
                set(hImg, 'CData', X(idx,:));
                % move vertical cursor
                
                hCursorTS.XData = [t(ti) t(ti)];
                hCursorTS.YData = [1 numTraces];
                
            case "lines"
                % update only cursor (lines show full time-series)
                hCursorTS.XData = [t(ti) t(ti)];
                hCursorTS.YData = ylim(ax_ts);
        end
    end

    drawnow limitrate;
    if isSave
        writeVideo(v, getframe(fig));
    end
end

% ---- close ----
if isSave
    close(v); close(fig);
    fprintf('✅ Video saved: %s (FPS=%g)\n', filename, v.FrameRate);
else
    fprintf('✅ Finished animation preview\n');
end
end
