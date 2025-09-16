function [Z, x2, y2, t] = generateRippleSurface(Nx, Ny, T, f, lambda, alpha, origin, varargin)
% generateRippleSurface - Simulate a ripple wave on a 2D surface, optionally curved
%
% Inputs:
%   Nx, Ny     - Grid size in x and y directions
%   T          - Number of time steps
%   f          - Frequency of ripple (Hz)
%   lambda     - Wavelength (spatial units)
%   alpha      - Spatial decay factor
%   origin     - [x0, y0] center of ripple
%
% Optional Name-Value Pairs:
%   'Curved'         - true/false (default: false)
%   'CurvatureType'  - 'paraboloid', 'saddle', or custom ('paraboloid' default)
%   'CurvatureStrength' - curvature scaling (default: 0.1)
%
% Outputs:
%   Z    - [Ny x Nx x T] wave amplitude volume (with optional base curvature)
%   x2, y2 - meshgrid coordinates
%   t    - time vector

    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'Curved', false);
    addParameter(p, 'CurvatureType', 'paraboloid');
    addParameter(p, 'CurvatureStrength', 0.1);
    parse(p, varargin{:});
    curved = p.Results.Curved;
    ctype = p.Results.CurvatureType;
    cstrength = p.Results.CurvatureStrength;

    % Defaults
    if nargin < 7 || isempty(origin), origin = [0, 0]; end
    if nargin < 6 || isempty(alpha), alpha = 0.1; end
    if nargin < 5 || isempty(lambda), lambda = 2; end
    if nargin < 4 || isempty(f), f = 5; end
    if nargin < 3 || isempty(T), T = 300; end
    if nargin < 2 || isempty(Ny), Ny = 100; Nx = 100; end

    % Grids
    x = linspace(-10, 10, Nx);
    y = linspace(-10, 10, Ny);
    t = linspace(0, 1, T);
    [x2, y2] = meshgrid(x, y);

    % Base curvature
    baseZ = zeros(Ny, Nx);
    if curved
        switch lower(ctype)
            case 'paraboloid'
                    baseZ = -cstrength * (x2.^2 + y2.^2);  % Center-up dome
            case 'saddle'
                baseZ = cstrength * (x2.^2 - y2.^2);
            otherwise
                warning('Unknown CurvatureType. Proceeding with flat surface.');
        end
    end

    % Distance from origin
    x0 = origin(1); y0 = origin(2);
    r = sqrt((x2 - x0).^2 + (y2 - y0).^2);

    % Ripple generation
    A = 1;
    k = 2*pi / lambda;
    Z = zeros(Ny, Nx, T);
    for ti = 1:T
        ripple = A * sin(2*pi*f*t(ti) - k*r) .* exp(-alpha * r);
        Z(:,:,ti) = baseZ + ripple;
    end
end
