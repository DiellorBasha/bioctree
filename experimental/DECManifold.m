%% ========================================================================
% ManifoldDEC.m
% Discrete Exterior Calculus analysis + visualization on cortical manifold
% ========================================================================

bioctree_start

%% ------------------------------------------------------------------------
% Load cortical manifold
% ------------------------------------------------------------------------
fs6 = bct_fsaverage('lh', 'saved');
M = fs6.M;

F = double(M.Faces);
V = M.Vertices;

TR = triangulation(F, V);

Nv = size(V,1);
Nf = size(F,1);

% Face centroids
COM = (V(F(:,1),:) + V(F(:,2),:) + V(F(:,3),:)) / 3;

% --- Face normals (SAFE variable name) ---
faceNormals = cross( ...
    V(F(:,2),:) - V(F(:,1),:), ...
    V(F(:,3),:) - V(F(:,1),:) );

faceNormals = faceNormals ./ vecnorm(faceNormals,2,2);
faceNormals(~isfinite(faceNormals)) = 0;
%% ------------------------------------------------------------------------
% Scalar field w (0-form)
% ------------------------------------------------------------------------
params.source = 1000;
params.sigma  = 4;
params.metric = "geometry";

w = bct.brush.apply('patch_gaussian', M, params);
w = full(w(:));   % enforce column


%% ------------------------------------------------------------------------
% DEC construction
% ------------------------------------------------------------------------
DEC = DiscreteExteriorCalculus(F, V);
disp('initiated DEC')

%% ------------------------------------------------------------------------
% Gradient
% ------------------------------------------------------------------------
gradW = DEC.gradient(w);        % [Nf x 3]

gradW_unit = gradW ./ vecnorm(gradW,2,2);
gradW_unit(~isfinite(gradW_unit)) = 0;

%% ------------------------------------------------------------------------
% Tangent frame decomposition
% ------------------------------------------------------------------------
Nf_vec = cross( ...
    V(F(:,2),:) - V(F(:,1),:), ...
    V(F(:,3),:) - V(F(:,1),:) );
Nf_vec = Nf_vec ./ vecnorm(Nf_vec,2,2);

e1 = V(F(:,2),:) - V(F(:,1),:);
e1 = e1 - sum(e1 .* Nf_vec,2) .* Nf_vec;
e1 = e1 ./ vecnorm(e1,2,2);

e2 = cross(Nf_vec, e1, 2);

gx = sum(gradW .* e1, 2);
gy = sum(gradW .* e2, 2);

amplitude = hypot(gx, gy);
phase     = atan2(gy, gx);

%% ------------------------------------------------------------------------
% Divergence
% ------------------------------------------------------------------------
U = -gradW_unit;
divU = DEC.divergence(U);
divU = divU(:);

%% ------------------------------------------------------------------------
% Curl
% ------------------------------------------------------------------------
curlU = DEC.curl(U);
curlU = curlU(:);

%% ------------------------------------------------------------------------
% Advection (memory safe)
% ------------------------------------------------------------------------
advW_face = sum(U .* gradW, 2);
advW_face = advW_face(:);

advW  = accumarray(F(:), repmat(advW_face,3,1), [Nv 1], @sum, 0);
count = accumarray(F(:), 1, [Nv 1], @sum, 0);
advW  = advW ./ count;
advW(~isfinite(advW)) = 0;

%% ------------------------------------------------------------------------
% Laplacian
% ------------------------------------------------------------------------
lapW = DEC.laplacian(w);
lapW = lapW(:);

%% ========================================================================
% VISUALIZATIONS (DECLab-style, adapted)
% ========================================================================

ssf = 15;

%% --- Scalar field and gradient
figure('Position',[0 0 900 700])
subplot(2,2,1)
patch('Faces',F,'Vertices',V,'FaceVertexCData',w,...
      'FaceColor','interp','EdgeColor','none');
hold on
quiver3(COM(1:ssf:end,1),COM(1:ssf:end,2),COM(1:ssf:end,3), ...
        gradW_unit(1:ssf:end,1), ...
        gradW_unit(1:ssf:end,2), ...
        gradW_unit(1:ssf:end,3), ...
        1,'k','LineWidth',1);
axis equal off
camlight
title('Scalar field w and gradient')

% subplot(2,2,2)
% patch('Faces',F,'Vertices',V,'FaceVertexCData',amplitude,...
%       'FaceColor','interp','EdgeColor','none');
% axis equal off
% colorbar
% title('|∇w|')
subplot(2,2,2)
patch('Faces',F,'Vertices',V,...
      'FaceVertexCData',amplitude,...
      'FaceColor','flat',...
      'EdgeColor','none');
axis equal off
colorbar
title('|∇w| (face-based)')


subplot(2,2,3)
patch('Faces',F,'Vertices',V,'FaceVertexCData',phase,...
      'FaceColor','flat','EdgeColor','none');
axis equal off
colorbar
title('Gradient phase')

subplot(2,2,4)
histogram(amplitude,50)
title('|∇w| distribution')
%%
subplot(2,2,2)
ampV = accumarray( ...
    F(:), ...
    repmat(amplitude,3,1), ...
    [Nv 1], ...
    @mean, 0);

patch('Faces',F,'Vertices',V,...
      'FaceVertexCData',ampV,...
      'FaceColor','interp',...
      'EdgeColor','none');
axis equal off
colorbar
title('|∇w| (vertex-projected)')
%% --- Divergence
figure('Position',[0 0 900 300])
subplot(1,3,1)
patch('Faces',F,'Vertices',V,'FaceVertexCData',divU,...
      'FaceColor','interp','EdgeColor','none');
axis equal off
colorbar
title('Divergence')

subplot(1,3,2)
patch('Faces',F,'Vertices',V,'FaceVertexCData',abs(divU),...
      'FaceColor','interp','EdgeColor','none');
axis equal off
colorbar
title('|Divergence|')

subplot(1,3,3)
histogram(divU,1000)
title('Divergence distribution')

%% --- Curl
figure(1)
patch('Faces',F,'Vertices',V,'FaceVertexCData',curlU,...
      'FaceColor','flat','EdgeColor','none');
axis equal off
colorbar
title('Curl (vorticity)')

patch('Faces',F,'Vertices',V,'FaceVertexCData',abs(curlU),...
      'FaceColor','flat','EdgeColor','none');
axis equal off
colorbar
title('|Curl|')

subplot(1,3,3)
histogram(curlU,100)
title('Curl distribution')

%% --- Advection
figure(1)
patch('Faces',F,'Vertices',V,'FaceVertexCData',advW,...
      'FaceColor','interp','EdgeColor','none');
axis equal off
colorbar
title('Advection U · ∇w')

%% ========================================================================
% HELMHOLTZ–HODGE DECOMPOSITION
% ========================================================================
%% ========================================================================
% HELMHOLTZ–HODGE DECOMPOSITION (DECLab, corrected & safe)
% ========================================================================



% Perform Helmholtz–Hodge decomposition
[divU, rotU, harmU, scalarP, vectorP] = ...
    DEC.helmholtzHodgeDecomposition(U);

% Normalize vector fields for plotting
plotU     = normalizerow(U);
plotDivU  = normalizerow(divU);
plotRotU  = normalizerow(rotU);
plotHU    = normalizerow(harmU);

ssf = 15;

%% ------------------------------------------------------------------------
% Helper: face -> vertex projection (for visualization only)
% ------------------------------------------------------------------------
faceVec2vertMag = @(X) ...
    sqrt( ...
        sum( ...
            [ ...
                accumarray(F(:), repmat(X(:,1),3,1), [Nv 1], @mean, 0), ...
                accumarray(F(:), repmat(X(:,2),3,1), [Nv 1], @mean, 0), ...
                accumarray(F(:), repmat(X(:,3),3,1), [Nv 1], @mean, 0) ...
            ].^2, ...
        2) ...
    );


%% ------------------------------------------------------------------------
% Compute magnitudes for coloring
% ------------------------------------------------------------------------
U_mag    = faceVec2vertMag(U);
divU_mag = faceVec2vertMag(divU);
rotU_mag = faceVec2vertMag(rotU);
harmU_mag= faceVec2vertMag(harmU);

%% ========================================================================
% Visualization
% ========================================================================
%%

fig = figure('Position',[0 0 900 700],'Units','pixels');
ax = axes('Parent', fig);
hold(ax, 'on');

% --- Patch (surface) ---
hPatch = patch( ...
    'Faces', F, ...
    'Vertices', V, ...
    'FaceVertexCData', U_mag, ...   % initial data
    'FaceColor', 'interp', ...
    'EdgeColor', 'none', ...
    'Parent', ax );

% --- Quiver (vector field) ---
hQuiver = quiver3( ...
    ax, ...
    COM(1:ssf:end,1), COM(1:ssf:end,2), COM(1:ssf:end,3), ...
    plotU(1:ssf:end,1), plotU(1:ssf:end,2), plotU(1:ssf:end,3), ...
    1, 'k', 'LineWidth', 1 );

% Axes / camera setup (ONCE)
axis(ax, 'equal'); axis(ax, 'tight'); axis(ax, 'off');
camlight(ax, 'headlight');

ax.CameraPosition = [-1016.2, 279.1, 338.8];
ax.CameraTarget   = [25.3279, 25.8489, -19.6839];
ax.CameraUpVector = [0 0 1];
ax.CameraViewAngleMode = 'manual';

%%

% -------------------------------------------------------------------------
% Full vector field
% -------------------------------------------------------------------------
patch('Faces',F,'Vertices',V,'FaceVertexCData',U_mag,...
      'FaceColor','interp','EdgeColor','none',...
      'SpecularStrength',0.1,'DiffuseStrength',0.1,'AmbientStrength',0.8);
hold on
quiver3(COM(1:ssf:end,1),COM(1:ssf:end,2),COM(1:ssf:end,3), ...
        plotU(1:ssf:end,1),plotU(1:ssf:end,2),plotU(1:ssf:end,3), ...
        1,'k','LineWidth',1);
hold off
axis equal tight off
camlight
title('Full Vector Field |U|');
colorbar

% -------------------------------------------------------------------------
% Curl-free (gradient / irrotational) part
% -------------------------------------------------------------------------
clf
patch('Faces',F,'Vertices',V,'FaceVertexCData',scalarP,...
      'FaceColor','interp','EdgeColor','none',...
      'SpecularStrength',0.1,'DiffuseStrength',0.1,'AmbientStrength',0.8);
hold on
quiver3(COM(1:ssf:end,1),COM(1:ssf:end,2),COM(1:ssf:end,3), ...
        plotDivU(1:ssf:end,1),plotDivU(1:ssf:end,2),plotDivU(1:ssf:end,3), ...
        1,'k','LineWidth',1);
hold off
axis equal tight off
camlight
title('Curl-Free Component (Scalar Potential)');
colorbar

% -------------------------------------------------------------------------
% Divergence-free (rotational) part
% -------------------------------------------------------------------------
patch('Faces',F,'Vertices',V,'FaceVertexCData',vectorP,...
      'FaceColor','flat','EdgeColor','none',...
      'SpecularStrength',0.1,'DiffuseStrength',0.1,'AmbientStrength',0.8);
hold on
quiver3(COM(1:ssf:end,1),COM(1:ssf:end,2),COM(1:ssf:end,3), ...
        plotRotU(1:ssf:end,1),plotRotU(1:ssf:end,2),plotRotU(1:ssf:end,3), ...
        1,'k','LineWidth',1);
hold off
axis equal tight off
camlight
title('Divergence-Free Component (Vector Potential)');
colorbar

% -------------------------------------------------------------------------
% Harmonic part
% -------------------------------------------------------------------------
subplot(2,2,4);
patch('Faces',F,'Vertices',V,'FaceVertexCData',harmU_mag,...
      'FaceColor','interp','EdgeColor','none',...
      'SpecularStrength',0.1,'DiffuseStrength',0.1,'AmbientStrength',0.8);
hold on
quiver3(COM(1:ssf:end,1),COM(1:ssf:end,2),COM(1:ssf:end,3), ...
        plotHU(1:ssf:end,1),plotHU(1:ssf:end,2),plotHU(1:ssf:end,3), ...
        1,'k','LineWidth',1);
hold off
axis equal tight off
camlight
title('Harmonic Component');
colorbar

sgtitle('Helmholtz–Hodge Decomposition (DECLab)');


%%
%% ========================================================================
% Handle-based visualization for Helmholtz–Hodge components
% ========================================================================

% Assumes these already exist:
% F, V, COM, ssf
% U_mag, scalarP, vectorP, harmU_mag
% plotU, plotDivU, plotRotU, plotHU

%% ------------------------------------------------------------------------
% Create figure and axes ONCE
% ------------------------------------------------------------------------
fig = figure('Position',[0 0 900 700],'Units','pixels');
ax  = axes('Parent', fig);
hold(ax, 'on');
set(ax,'Color','k')
%% ------------------------------------------------------------------------
% Create PATCH object ONCE
% ------------------------------------------------------------------------
hPatch = patch( ...
    'Faces', F, ...
    'Vertices', V, ...
    'FaceVertexCData', U_mag, ...        % initial data
    'FaceColor', 'interp', ...
    'EdgeColor', 'none', ...
    'SpecularStrength', 0.1, ...
    'DiffuseStrength', 0.1, ...
    'AmbientStrength', 0.8, ...
    'Parent', ax );

%% ------------------------------------------------------------------------
% Create QUIVER object ONCE
% ------------------------------------------------------------------------
hQuiver = quiver3( ...
    ax, ...
    COM(1:ssf:end,1), COM(1:ssf:end,2), COM(1:ssf:end,3), ...
    plotU(1:ssf:end,1), plotU(1:ssf:end,2), plotU(1:ssf:end,3), ...
    1, 'k', 'LineWidth', 1 );

%% ------------------------------------------------------------------------
% Axes, lighting, camera (ONCE)
% ------------------------------------------------------------------------
axis(ax,'equal');
axis(ax,'tight');
axis(ax,'off');

camlight(ax,'headlight');
material(ax,'dull');   % overall lighting model

cb = colorbar(ax);
title(ax,'Full Vector Field |U|');

ax.CameraPosition = [-1016.2, 279.1, 338.8];
ax.CameraTarget   = [25.3279, 25.8489, -19.6839];
ax.CameraUpVector = [0 0 1];
ax.CameraViewAngleMode = 'manual';

drawnow;

%% ========================================================================
% UPDATE FUNCTIONS (just inline code blocks)
% ========================================================================

%% ------------------------------------------------------------------------
% 1. FULL VECTOR FIELD
% ------------------------------------------------------------------------
set(hPatch, ...
    'FaceVertexCData', U_mag, ...
    'FaceColor', 'interp', ...
    'SpecularStrength', 0.1, ...
    'DiffuseStrength', 0.1, ...
    'AmbientStrength', 0.8);

set(hQuiver, ...
    'UData', plotU(1:ssf:end,1), ...
    'VData', plotU(1:ssf:end,2), ...
    'WData', plotU(1:ssf:end,3));

title(ax,'Full Vector Field |U|');
cb.Label.String = '|U|';

drawnow;

%% ------------------------------------------------------------------------
% 2. CURL-FREE (IRROTATIONAL) COMPONENT
% ------------------------------------------------------------------------
set(hPatch, ...
    'FaceVertexCData', scalarP, ...
    'FaceColor', 'interp', ...
    'SpecularStrength', 0.05, ...
    'DiffuseStrength', 0.15, ...
    'AmbientStrength', 0.8);

set(hQuiver, ...
    'UData', plotDivU(1:ssf:end,1), ...
    'VData', plotDivU(1:ssf:end,2), ...
    'WData', plotDivU(1:ssf:end,3));

title(ax,'Curl-Free Component (Scalar Potential)');
cb.Label.String = 'Scalar potential';

drawnow;

%% ------------------------------------------------------------------------
% 3. DIVERGENCE-FREE (ROTATIONAL) COMPONENT
% ------------------------------------------------------------------------
set(hPatch, ...
    'FaceVertexCData', vectorP, ...
    'FaceColor', 'flat', ...
    'SpecularStrength', 0.2, ...
    'DiffuseStrength', 0.05, ...
    'AmbientStrength', 0.7);

set(hQuiver, ...
    'UData', plotRotU(1:ssf:end,1), ...
    'VData', plotRotU(1:ssf:end,2), ...
    'WData', plotRotU(1:ssf:end,3));

title(ax,'Divergence-Free Component (Vector Potential)');
cb.Label.String = 'Vector potential';

drawnow;

%% ------------------------------------------------------------------------
% 4. HARMONIC COMPONENT
% ------------------------------------------------------------------------
set(hPatch, ...
    'FaceVertexCData', harmU_mag, ...
    'FaceColor', 'interp', ...
    'SpecularStrength', 0.15, ...
    'DiffuseStrength', 0.1, ...
    'AmbientStrength', 0.75);

set(hQuiver, ...
    'UData', plotHU(1:ssf:end,1), ...
    'VData', plotHU(1:ssf:end,2), ...
    'WData', plotHU(1:ssf:end,3));

title(ax,'Harmonic Component');
cb.Label.String = '|U_{harm}|';

drawnow;

%% ------------------------------------------------------------------------
% Global title (optional)
% ------------------------------------------------------------------------
sgtitle(fig,'Helmholtz–Hodge Decomposition (DECLab)');
%%
set(hPatch, ...
    'FaceVertexCData', U_mag, ...
    'FaceColor', 'interp', ...
    'SpecularStrength', 0.1, ...
    'DiffuseStrength', 0.1, ...
    'AmbientStrength', 0.8);
hold(ax,'on')
hStream = plot3(ax, ...
    curve(:,1), curve(:,2), curve(:,3), ...
    'k-', 'LineWidth', 2);

% Mark the seed explicitly
plot3(ax, V(seedVertex,1), V(seedVertex,2), V(seedVertex,3), ...
      'ro', 'MarkerSize', 8, 'LineWidth', 2);

hold(ax,'on')

for s = 1:numel(curves)
    c = curves{s};
    plot3(ax, c(:,1), c(:,2), c(:,3), ...
        'k-', 'LineWidth', 1);
end

% Mark the original source
plot3(ax, V(seedVertex,1), V(seedVertex,2), V(seedVertex,3), ...
      'ro', 'MarkerSize', 8, 'LineWidth', 2);

hold(ax,'off')


nStreams = numel(curves);
hStream  = gobjects(nStreams,1);   % preallocate handles

for s = 1:nStreams
    c = curves{s};
    hStream(s) = plot3(ax, ...
        c(:,1), c(:,2), c(:,3), ...
        'k-', 'LineWidth', 1);
end
baseColor=[0.8 0.8 0.8];
set(hPatch, ...
    'FaceVertexCData', baseColor, ...
    'FaceColor', 'interp', ...
    'SpecularStrength', 0.1, ...
    'DiffuseStrength', 0.1, ...
    'AmbientStrength', 0.8);

%%

app.fig = uifigure( ...
    'Name','M DEC Viewer', ...
    'Color','k', ...
    'Position',[100 100 800 800]);

app.grid = uigridlayout(app.fig);

% Row heights: 75% visualization, 25% controls
app.grid.RowHeight = {'3x', '1x'};
app.grid.ColumnWidth = {'1x'};
app.ax = uiaxes(app.grid);
app.ax.Layout.Row = 1;
app.ax.Layout.Column = 1;

% Appearance
app.ax.Color  = 'k';
app.ax.XColor = 'none';
app.ax.YColor = 'none';
app.ax.ZColor = 'none';
app.ax.Box    = 'off';
hold(app.ax,'on')

% Geometry (correct replacement for axis equal)
app.ax.DataAspectRatio = [1 1 1];
app.ax.DataAspectRatioMode = 'manual';
% Limits (set once)
app.ax.XLim = [min(V(:,1)) max(V(:,1))];
app.ax.YLim = [min(V(:,2)) max(V(:,2))];
app.ax.ZLim = [min(V(:,3)) max(V(:,3))];

hold(app.ax,'on')
% Controls
app.ctrlPanel = uipanel(app.grid);
app.ctrlPanel.Layout.Row = 2;

ctrlGrid = uigridlayout(app.ctrlPanel,[1 1]);

app.tabs = uitabgroup(ctrlGrid);
app.ctrlPanel.BorderType='none';
app.tabBrushes  = uitab(app.tabs, 'Title','Brushes');
app.tabOperators= uitab(app.tabs, 'Title','Operators');
app.tabSpectral = uitab(app.tabs, 'Title','Spectral');

brushGrid = uigridlayout(app.tabBrushes, [2 4]);
brushGrid.RowHeight = {'fit','fit'};
brushGrid.ColumnWidth = {'1x','1x','1x','1x'};

uilabel(brushGrid,'Text','Brush Type','FontColor','w');
uidropdown(brushGrid,'Items',{'Gaussian','Disk','Ring'});

uilabel(brushGrid,'Text','Sigma','FontColor','w');
uislider(brushGrid,'Limits',[1 20],'Value',4);

