%% =========================
%  Manifold DEC Viewer Init
% =========================

%% ------------------------------------------------------------------------
% Figure and main grid
% ------------------------------------------------------------------------
app.fig = uifigure( ...
    'Name','Manifold DEC Viewer', ...
    'Color','k', ...
    'Position',[100 100 800 800]);

app.grid = uigridlayout(app.fig,[2 1]);
app.grid.RowHeight   = {'3x','1x'};
app.grid.ColumnWidth = {'1x'};

%% ------------------------------------------------------------------------
% UIAxes (visualization)
% ------------------------------------------------------------------------
app.ax = uiaxes(app.grid);
app.ax.Layout.Row    = 1;
app.ax.Layout.Column = 1;

% Axes appearance
app.ax.Color  = 'k';
app.ax.XColor = 'none';
app.ax.YColor = 'none';
app.ax.ZColor = 'none';
app.ax.Box    = 'off';

% Geometry correctness (DO NOT use axis equal/tight)
app.ax.DataAspectRatio     = [1 1 1];
app.ax.DataAspectRatioMode = 'manual';
app.ax.Projection          = 'perspective';

hold(app.ax,'on');

%% ------------------------------------------------------------------------
% Controls panel + grids
% ------------------------------------------------------------------------
app.ctrlPanel = uipanel(app.grid, ...
    'Title','Controls', ...
    'BackgroundColor',[0.15 0.15 0.15], ...
    'ForegroundColor',[1 1 1]);
app.ctrlPanel.Layout.Row = 2;

app.ctrlGrid = uigridlayout(app.ctrlPanel,[1 2]);
app.ctrlGrid.ColumnWidth = {'1x','1x'};
app.ctrlGrid.RowHeight   = {'1x'};

% Left: main control tabs
app.controlTabs = uitabgroup(app.ctrlGrid);
app.controlTabs.Layout.Row    = 1;
app.controlTabs.Layout.Column = 1;

app.tabBrushes   = uitab(app.controlTabs,'Title','Brushes');
app.tabOperators = uitab(app.controlTabs,'Title','Operators');
app.tabSpectral  = uitab(app.controlTabs,'Title','Spectral');

% Right: view tabs (vertical)
app.viewTabs = uitabgroup(app.ctrlGrid);
app.viewTabs.Layout.Row    = 1;
app.viewTabs.Layout.Column = 2;
app.viewTabs.TabLocation   = 'right';

app.tabViewData   = uitab(app.viewTabs,'Title','Data');
app.tabViewStyle  = uitab(app.viewTabs,'Title','Style');
app.tabViewLayers = uitab(app.viewTabs,'Title','Layers');

%% ------------------------------------------------------------------------
% Base cortex patch (geometry MUST come before camera & lighting)
% ------------------------------------------------------------------------
baseGray = [0.6 0.6 0.6];

app.hPatch = patch(app.ax, ...
    'Faces', F, ...
    'Vertices', V, ...
    'FaceColor', baseGray, ...
    'EdgeColor','none');

%% ------------------------------------------------------------------------
% Other graphics handles (initialized but hidden/empty)
% ------------------------------------------------------------------------
app.hQuiver = quiver3(app.ax, ...
    nan,nan,nan, nan,nan,nan, ...
    'Color','w', ...
    'LineWidth',1, ...
    'Visible','off');

app.hStream = gobjects(0);

app.hSeed = plot3(app.ax, nan,nan,nan, ...
    'ro','MarkerSize',8,'LineWidth',2,'Visible','off');

%% ------------------------------------------------------------------------
% Camera setup (NOW geometry exists)
% ------------------------------------------------------------------------
ctr = mean(V,1);
rad = max(vecnorm(V - ctr,2,2));

viewDir = [-1 0 0];   % lateral LH view

app.ax.CameraTarget   = ctr;
app.ax.CameraPosition = ctr + viewDir * (2.5 * rad);
app.ax.CameraUpVector = [0 0 1];
app.ax.CameraViewAngleMode = 'manual';

%% ------------------------------------------------------------------------
% Lighting & material (AFTER camera & patch exist)
% ------------------------------------------------------------------------
lighting(app.ax,'gouraud');
camlight(app.ax,'headlight');

set(app.hPatch, ...
    'FaceLighting','gouraud', ...
    'AmbientStrength',  0.35, ...
    'DiffuseStrength',  0.6, ...
    'SpecularStrength', 0.15, ...
    'SpecularExponent', 10);

%% ------------------------------------------------------------------------
% Controls callbacks (depend on handles)
% ------------------------------------------------------------------------
uiswitch(app.tabViewLayers, ...
    'Items',{'Off','On'}, ...
    'ValueChangedFcn', @(src,~) toggleStreamlines(src.Value, app));

uidropdown(app.tabViewData, ...
    'Items',{'None','w','|grad w|','div','curl'}, ...
    'ValueChangedFcn', @(src,~) updatePatchData(src.Value, app));
