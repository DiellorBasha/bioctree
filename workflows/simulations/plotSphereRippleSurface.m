function plotSphereRippleSurface(Z, lon, lat, t, varargin)
% plotSphereRippleSurface  Simple visualization of sphere ripple frames
% Usage:
%   plotSphereRippleSurface(Z, lon, lat, t, 'TimeIndex', 1, 'Points', [lat lon; ...])
p = inputParser;
addParameter(p,'TimeIndex',1,@(x) isnumeric(x) && isscalar(x));
addParameter(p,'Points',[],@(x) isempty(x) || (isnumeric(x) && size(x,2)==2));
addParameter(p,'Colormap',jet,@ischarOrFunc);
parse(p,varargin{:});
opts = p.Results;

% prepare coordinates
[Lon, Lat] = meshgrid(lon, lat);
R = 1; % assume unit sphere plotting; if different radius used, scale XYZ before calling
X = R * cos(Lat) .* cos(Lon);
Y = R * cos(Lat) .* sin(Lon);
Zcoord = R * sin(Lat);

frame = squeeze(Z(:,:,opts.TimeIndex));

fig = figure;
h = surf(X, Y, Zcoord + 0.4*frame, frame, 'EdgeColor','none'); % offset normal by amplitude
axis equal off
colormap(opts.Colormap);
shading interp
lighting gouraud
camlight headlight
title(sprintf('Sphere ripple t = %.3f s', t(opts.TimeIndex)));

% overlay sensor points (lat,lon in degrees)
if ~isempty(opts.Points)
    pts = opts.Points;
    latp = deg2rad(pts(:,1));
    lonp = deg2rad(pts(:,2));
    xp = R * cos(latp).*cos(lonp);
    yp = R * cos(latp).*sin(lonp);
    zp = R * sin(latp);
    hold on
    scatter3(xp, yp, zp, 60, 'k', 'filled');
end
end

function ok = ischarOrFunc(x)
ok = ischar(x) || isa(x,'function_handle') || (isstring(x) && isscalar(x));
end