function C = redblue(n)
%BCT.UI.COLOR.MAPS.REDBLUE  Diverging red-white-blue colormap
%
%   C = bct.ui.color.maps.redblue()
%   C = bct.ui.color.maps.redblue(n)
%
% Purpose
%   Returns a perceptually balanced diverging colormap that transitions:
%     blue -> white -> red
%
% Inputs
%   n (optional) - Number of colors (default = 256)
%
% Outputs
%   C - [n×3] double colormap in [0,1]
%
% Notes
%   - Pure function: deterministic and stateless.
%   - Designed for signed fields (e.g., eigenmodes, contrasts).
%
% See also: bct.ui.color.resolve, bct.registry.colormaps

    if nargin < 1 || isempty(n)
        n = 256;
    end

    % Validate n
    validateattributes(n, {'numeric'}, {'scalar','integer','positive'}, mfilename, 'n');
    n = double(n);

    % Endpoints chosen for perceptual balance
    bottom = [0.230, 0.299, 0.754];  % blue
    middle = [1.000, 1.000, 1.000];  % white
    top    = [0.706, 0.016, 0.150];  % red

    C = zeros(n, 3);
    mid = ceil(n/2);

    % Interpolate each channel through (blue -> white -> red)
    xk = [1, mid, n];
    xi = 1:n;

    for k = 1:3
        C(:,k) = interp1(xk, [bottom(k), middle(k), top(k)], xi, 'linear');
    end

    % Numerical safety (ensure valid range)
    C = max(0, min(1, C));
end
