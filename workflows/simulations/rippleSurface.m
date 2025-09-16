
[Z, x, y, t] = generateRippleSurface(100, 100, 300, 5, 2, 0.1, [0, 0]);

% Select y index and convert to physical y-value
yIdx = 50;
yValue = y(yIdx);  % Row 60 corresponds to y = y(60)
x = linspace(-10, 10, 100);  % Columns

% Plot time series from sensors on line y = yValue
plotSensorLine(Z, yIdx, x);

%% 
videoOutFile = 'figures/ripple_animation2.mp4'
exportRippleVideo(Z, x, y, t, videoOutFile, 24);

%% 
close all
% Define mesh
x = linspace(-10, 10, 100);  % Columns
y = linspace(-10, 10, 100);  % Rows

% Select y index and convert to physical y-value
yIdx = 50;
yValue = y(yIdx);  % Row 60 corresponds to y = y(60)

% Masked x-coordinates for sensor sampling
xMaskCoords = [-9 -3 0 4 2 1 3.4];
xMaskCoords = sort([ ...
    linspace(-9, -5, 5), ...   % sparse left
    linspace(-5, -1, 5), ...  % dense middle-left
    linspace(-1, 4, 4), ...   % medium density middle-right
    linspace(4, 8, 5)          % sparse right
]);

% Plot time series from sensors on line y = yValue
plotSensorLine(Z, yIdx, x, ...
    'MaskCoords', xMaskCoords, ...
    'FigureName', 'sparse_masked');

% Create sensorCoords for plotting on surface
sensorCoords = [xMaskCoords(:), yValue * ones(length(xMaskCoords), 1)];


% Plot the surface with a horizontal line and sensor points
plotRippleSurface(Z, x2, y2, t, ...
    'TimeIndex', 1, ...
    'LineY', yValue, ...
    'Points', sensorCoords, ...
    'Title', 'Sensor Line and Points on Ripple Surface');


%% Ripple on a paraboloid

[Zr, x2r, y2r, tr] = generateRippleSurface(100, 100, 300, 5, 2, 0.1, [0, 0], ...
    'Curved', true, 'CurvatureType', 'paraboloid', 'CurvatureStrength', 0.08);
% Plot the surface with a horizontal line and sensor points
plotRippleSurface(Zr, x2r, y2r, tr);

% Plot time series from sensors on line y = yValue
plotSensorLine(Zr, yIdx, x);


exportRippleVideo(Zr, x2r, y2r, t, 'ripple_curved_animation.mp4', 24);

  fig = figure(1);
    h = surf(x2r, y2r, Zr(:,:,1), 'EdgeColor', 'none');
    zlim([-1 1]);
    axis equal tight;
    xlabel('x'); ylabel('y'); zlabel('Amplitude');
    view(30, 45);
    camlight; lighting gouraud;

    for ti = 1:size(Z,3)
        h.ZData = Zr(:,:,ti);
        title('Wave Propagation on Curved Surface');
        subtitle(sprintf('t = %.2f s', t(ti)));
        drawnow;

        frame = getframe(fig);
        writeVideo(v, frame);
    end

    %% 

[Zr, x2r, y2r, tr] = generateRippleSurface(100, 100, 300, 5, 2, 0.1, [0, 0], ...
    'Curved', true, 'CurvatureType', 'saddle', 'CurvatureStrength', 0.08);
% Plot the surface with a horizontal line and sensor points
plotRippleSurface(Zr, x2r, y2r, tr);

% Plot time series from sensors on line y = yValue
plotSensorLine(Zr, yIdx, x);


 v = VideoWriter('ripple_animation_saddle.mp4', 'MPEG-4');
 v.FrameRate = framerate;
    open(v);

  fig = figure(1);
    h = surf(x2r, y2r, Zr(:,:,1), 'EdgeColor', 'none');
    zlim([-1 1]);
    axis equal tight;
    xlabel('x'); ylabel('y'); zlabel('Amplitude');
    view(30, 45);
    camlight; lighting gouraud;

    % Set fixed axis limits
zmin = min(Zr(:));
zmax = max(Zr(:));
zlim([zmin, zmax]);         % or use a manual range like [-1, 1]


    for ti = 1:size(Z,3)
        h.ZData = Zr(:,:,ti);
        title('Wave Propagation on Curved Surface');
        subtitle(sprintf('t = %.2f s', t(ti)));
        drawnow;

        frame = getframe(fig);
        writeVideo(v, frame);
    end

       close(v);
    close(fig);

    %%
   %% -- New: generate and plot ripple on a sphere
    % generate spherical ripple (example parameters)
    [Zs, lonS, latS, tS, XYZs] = generateSphereRipple(120, 80, 200, 5, 2, 0.15, [0, 0], 'Radius', 10);
    
    % plot a single frame (time index 1)
    plotSphereRippleSurface(Zs, lonS, latS, tS, 'TimeIndex', 1);
    
    % optional: export a short movie using exportRippleVideo or a custom writer
    % for example:
    % exportRippleVideo(Zs, lonS, latS, tS, 'figures/ripple_sphere.mp4', 24);
    % ...existing code...