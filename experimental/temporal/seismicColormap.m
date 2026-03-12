function cmap = seismicColormap(n)
%SEISMICCOLORMAP  Blue–white–red diverging colormap (seismic).
%
%   cmap = seismicColormap()       returns 256 entries
%   cmap = seismicColormap(n)      returns n entries
%
%   Matches the seismic colormap from geometry-processing-js:
%     dark blue [0 0 0.3] → blue [0 0 1] → white [1 1 1]
%                         → red [1 0 0] → dark red [0.5 0 0]
%
%   Suitable for diverging data centered at zero (e.g. eigenmodes).
%
%   See also parula, colormap

    if nargin < 1, n = 256; end

    % Anchor positions and RGB values (matching JS seismic colormap)
    anchors = [
        0.00,  0.0, 0.0, 0.30   % dark blue
        0.25,  0.0, 0.0, 1.00   % blue
        0.50,  1.0, 1.0, 1.00   % white
        0.75,  1.0, 0.0, 0.00   % red
        1.00,  0.5, 0.0, 0.00   % dark red
    ];

    t = anchors(:, 1);
    R = anchors(:, 2);
    G = anchors(:, 3);
    B = anchors(:, 4);

    xi = linspace(0, 1, n)';
    cmap = [interp1(t, R, xi), interp1(t, G, xi), interp1(t, B, xi)];
    cmap = max(min(cmap, 1), 0);  % clamp to [0, 1]
end
