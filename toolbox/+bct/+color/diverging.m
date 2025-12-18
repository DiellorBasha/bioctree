function C = diverging(colorIndex, N)
%DIVERGING  Signed diverging colormap (zero-centered)
%
%   C = bct.color.diverging()
%   C = bct.color.diverging(colorIndex)
%   C = bct.color.diverging(colorIndex, N)
%
%   Creates a diverging colormap that blends from negative color through
%   white/neutral at zero to positive color.

    if nargin < 1 || isempty(colorIndex)
        colorIndex = 1;
    end
    if nargin < 2 || isempty(N)
        N = 256;
    end

    % Parameter in [-1, 1]
    t = linspace(-1, 1, N)';

    % Base colors for positive and negative
    [negColor, posColor] = bct.color.internal.pickDivergingPair(colorIndex);

    % Create diverging colormap through white
    C = zeros(N, 3);
    
    % Negative half: blend from full negative color to white
    negIdx = t <= 0;
    nNeg = sum(negIdx);
    if nNeg > 0
        tNeg = linspace(1, 0, nNeg)';  % 1 at min, 0 at zero
        for i = 1:3
            C(negIdx, i) = (1-tNeg) + tNeg * negColor(i);
        end
    end
    
    % Positive half: blend from white to full positive color
    posIdx = t > 0;
    nPos = sum(posIdx);
    if nPos > 0
        tPos = linspace(0, 1, nPos)';  % 0 at zero, 1 at max
        for i = 1:3
            C(posIdx, i) = (1-tPos) + tPos * posColor(i);
        end
    end

    C = min(max(C, 0), 1);
end
