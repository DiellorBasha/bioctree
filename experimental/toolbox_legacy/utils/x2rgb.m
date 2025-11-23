function RGB = x2rgb(x, varargin)
%X2RGB Map a scalar field x to RGB in [0,1].
%   RGB = X2RGB(x)                 % robust linear scaling (2–98 pct), parula
%   RGB = X2RGB(x, 'symmetric',1)  % zero-centered diverging scaling
%   RGB = X2RGB(x, 'colormap','parula')  % choose 'parula'|'turbo'|'jet'|...

% ---- options ----
p = inputParser;
addParameter(p, 'symmetric', false, @(b)islogical(b)||ismember(b,[0 1]));
addParameter(p, 'colormap',  'parula', @(s)ischar(s)||isstring(s));
addParameter(p, 'lo', [], @(v)isnumeric(v)&&isscalar(v));
addParameter(p, 'hi', [], @(v)isnumeric(v)&&isscalar(v));
parse(p, varargin{:});
sym  = logical(p.Results.symmetric);
cmapName = char(p.Results.colormap);
lo = p.Results.lo; hi = p.Results.hi;

% ---- flatten & sanitize ----
x = double(x(:));
finiteMask = isfinite(x);
x(~finiteMask) = 0;              % placeholder; will set to mid color later

% ---- scaling to [0,1] ----
if sym
    % zero-centered: map [-m, m] → [0,1]
    m = max(abs(x(finiteMask)));
    if m==0, xn = 0.5*ones(size(x)); else, xn = 0.5 + 0.5*(x./m); end
else
    % robust linear: clip to [lo, hi] (defaults: 2–98 percentiles)
    if isempty(lo) || isempty(hi)
        if any(finiteMask)
            lo = prctile(x(finiteMask), 2);
            hi = prctile(x(finiteMask), 98);
            if hi<=lo, lo = min(x(finiteMask)); hi = max(x(finiteMask)); end
        else
            lo = 0; hi = 1;
        end
    end
    denom = max(hi-lo, eps);
    xn = (x - lo) ./ denom;
end
xn = min(max(xn,0),1);           % clamp
xn(~finiteMask) = 0.5;           % NaN/Inf → mid color

% ---- colormap lookup ----
switch lower(cmapName)
    case 'parula',  C = parula(256);
    case 'turbo',   C = turbo(256);
    case 'jet',     C = jet(256);
    case 'hot',     C = hot(256);
    otherwise,      C = parula(256);
end
idx = 1 + round(xn*(size(C,1)-1));
RGB = C(idx,:);
end
