function C = cyclic(N)
%CYCLIC  Cyclic colormap for phase / angle data
%
%   C = bct.color.cyclic()
%   C = bct.color.cyclic(N)

    if nargin < 1 || isempty(N)
        N = 256;
    end

    % Phase parameter
    t = linspace(0,1,N)';

    % HSV hue cycle, constant saturation/value
    H = t;
    S = ones(N,1);
    V = ones(N,1);

    C = hsv2rgb([H S V]);
end
