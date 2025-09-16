function [Z, lon, lat, t, XYZ] = generateSphereRipple(nLon, nLat, nT, c, f, sigma, origin, varargin)
% generateSphereRipple  Generate time-varying ripple on a sphere
% 
% Syntax:
%   [Z, lon, lat, t, XYZ] = generateSphereRipple(nLon, nLat, nT, c, f, sigma, origin)
% Inputs:
%   nLon, nLat  - grid resolution (columns = longitude, rows = latitude)
%   nT          - number of time steps
%   c           - wave speed (units per second on sphere surface)
%   f           - temporal frequency (Hz)
%   sigma       - spatial envelope width (same units as radius)
%   origin      - [lat_deg, lon_deg] center of ripple in degrees
% Optional name-value:
%   'Radius'    - sphere radius (default 1)
%   'Duration'  - total time in seconds (default pi*Radius/c)
%
% Outputs:
%   Z           - (nLat x nLon x nT) ripple amplitude (normal displacement)
%   lon, lat    - longitude and latitude vectors (radians)
%   t           - time vector
%   XYZ         - (nLat x nLon x 3) Cartesian coordinates of grid points

p = inputParser;
addParameter(p,'Radius',1,@(x) isnumeric(x) && isscalar(x));
addParameter(p,'Duration',[],@(x) isempty(x) || (isnumeric(x) && isscalar(x)));
parse(p,varargin{:});
R = p.Results.Radius;
tmax = p.Results.Duration;

% angular grids
lon = linspace(-pi, pi, nLon);        % longitude
lat = linspace(-pi/2, pi/2, nLat);    % latitude (from -90 to 90 deg)
[Lon, Lat] = meshgrid(lon, lat);

% Cartesian coordinates
X = R * cos(Lat) .* cos(Lon);
Y = R * cos(Lat) .* sin(Lon);
Zcoord = R * sin(Lat);
XYZ = cat(3, X, Y, Zcoord);

% origin vector (convert degrees -> radians)
lat0 = deg2rad(origin(1));
lon0 = deg2rad(origin(2));
v0 = [cos(lat0)*cos(lon0), cos(lat0)*sin(lon0), sin(lat0)];

% unit vectors for grid points
Vx = cos(Lat).*cos(Lon);
Vy = cos(Lat).*sin(Lon);
Vz = sin(Lat);

% central angle (great-circle) via dot product
dotp = v0(1).*Vx + v0(2).*Vy + v0(3).*Vz;
dotp = min(max(dotp, -1), 1);
centralAngle = acos(dotp);          % radians
dist = R * centralAngle;            % geodesic distance along surface

% time vector
if isempty(tmax)
    tmax = pi * R / c;  % default: half-circumference travel time
end
t = linspace(0, tmax, nT);

% build ripple over time (vectorized)
Z = zeros(nLat, nLon, nT);
for ti = 1:nT
    tau = t(ti);
    envelope = exp(-((dist - c*tau)/sigma).^2);
    phase = 2*pi*f*(tau - dist./c);
    Z(:,:,ti) = envelope .* cos(phase);
end
end