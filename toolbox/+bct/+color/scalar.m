function C = scalar(colorIndex, N)
%SCALAR  Unsigned scalar intensity colormap
%
%   C = bct.color.scalar()
%   C = bct.color.scalar(colorIndex)
%   C = bct.color.scalar(colorIndex, N)
%
%   Produces an intensity-only colormap (0→1) optionally tinted
%   by a categorical color selected by index.

    if nargin < 1 || isempty(colorIndex)
        colorIndex = 0;   % 0 means pure grayscale
    end
    if nargin < 2 || isempty(N)
        N = 256;
    end

    % Intensity ramp
    t = linspace(0,1,N)';

    if colorIndex == 0
        % Pure grayscale
        C = [t t t];
        return
    end

    % Select base color from internal palette
    base = bct.color.internal.pickColor(colorIndex);

    % Apply intensity
    C = t .* base;

    % Safety clamp
    C = min(max(C,0),1);
end
