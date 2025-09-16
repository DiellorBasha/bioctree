function plotRippleSurface(Z, x2, y2, t, varargin)
% plotRippleSurface - Plot a snapshot of a ripple surface with optional flat overlays
%
% Inputs:
%   Z         - [Ny x Nx x T] 3D wave amplitude volume
%   x2, y2    - Meshgrid coordinates [Ny x Nx]
%   t         - Time vector (1 x T)
%
% Name-Value Options:
%   'TimeIndex'   - Time index to visualize (default: 1)
%   'LineX'       - x-coordinate for a vertical line (flat on surface)
%   'LineY'       - y-coordinate for a horizontal line (flat on surface)
%   'Points'      - [N x 2] matrix of (x, y) points to plot (flat)
%   'Title'       - Custom title (optional)

    % Parse inputs
    p = inputParser;
    addParameter(p, 'TimeIndex', 1, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'LineX', [], @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'LineY', [], @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'Points', [], @(x) isnumeric(x) && size(x,2) == 2);
    addParameter(p, 'Title', '', @ischar);
    parse(p, varargin{:});
    opts = p.Results;

    ti = opts.TimeIndex;
    zdata = Z(:,:,ti);
    baseZ = max(zdata(:)) + 0.1;  % Place overlays slightly below surface

    % Surface plot
    figure;
    h = surf(x2, y2, zdata, 'EdgeColor', 'none');
    zlim([-1 1]);
    axis equal tight;
    view(30, 45);
    camlight; lighting gouraud;
    xlabel('x'); ylabel('y'); zlabel('Amplitude');
    if ~isempty(opts.Title)
        title(opts.Title);
    else
        title(sprintf('Ripple Surface at t = %.3f s', t(ti)));
    end

    % Flat vertical line at fixed x
    if ~isempty(opts.LineX)
        yline = linspace(min(y2(:)), max(y2(:)), 100);
        xline = opts.LineX * ones(size(yline));
        zline = baseZ * ones(size(xline));
        hold on;
        plot3(xline, yline, zline, 'k-', 'LineWidth', 2);
    end

    % Flat horizontal line at fixed y
    if ~isempty(opts.LineY)
        xline = linspace(min(x2(:)), max(x2(:)), 100);
        yline = opts.LineY * ones(size(xline));
        zline = baseZ * ones(size(xline));
        hold on;
        plot3(xline, yline, zline, 'k-', 'LineWidth', 2);
    end

    % Flat sensor points
    if ~isempty(opts.Points)
        xp = opts.Points(:,1);
        yp = opts.Points(:,2);
        zp = baseZ * ones(size(xp));
        hold on;
        scatter3(xp, yp, zp, 60, 'r', 'filled');
    end
end
%% 


