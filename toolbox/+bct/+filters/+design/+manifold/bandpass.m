function g = bandpass(manifold, lambda_band, varargin)
%BANDPASS Bandpass filter on manifold spectral domain
%
%   g = bandpass(manifold, lambda_band) creates a bandpass filter
%   g = bandpass(manifold, lambda_band, 'taper', type) sets the taper type
%
%   The bandpass filter passes eigenvalues in [lambda_min, lambda_max]
%   with optional tapering at the edges.
%
%   Inputs:
%     manifold    - bct.manifold.Manifold object with Resolution
%     lambda_band - [lambda_min, lambda_max] passband
%     'taper'     - Taper type: 'none', 'hann', 'hamming', 'tukey' (default: 'hann')
%     'width'     - Taper width as fraction of bandwidth (default: 0.1)
%
%   Returns:
%     g - Function handle @(lambda) that evaluates the bandpass filter
%
%   Example:
%       % Create bandpass filter [100, 500] with Hann taper
%       filt = bct.filters.Filter('Manifold');
%       filt.Manifold = B.Manifold;
%       filt.g = bct.filters.design.manifold.bandpass(B.Manifold, [100, 500]);
%       filt.lambda_band = [100, 500];
%       filt.KernelType = 'bandpass';
%
%   See also: bct.filters.Filter, bct.filters.design.manifold.gaussian

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addRequired(p, 'lambda_band', @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'taper', 'hann', @(x) ischar(x) || isstring(x));
addParameter(p, 'width', 0.1, @(x) isnumeric(x) && x > 0 && x < 0.5);
parse(p, manifold, lambda_band, varargin{:});

lambda_min = min(lambda_band);
lambda_max = max(lambda_band);
taper_type = string(p.Results.taper);
taper_width = p.Results.width;

% Validate manifold
if isempty(manifold.Resolution)
    error('bct:filters:design:manifold:bandpass:NoResolution', ...
        'Manifold has no Resolution. Call manifold.setResolution() first.');
end

% Create bandpass filter function with tapering
bandwidth = lambda_max - lambda_min;
taper_size = taper_width * bandwidth;

% Define transition regions
lower_edge = lambda_min + taper_size;
upper_edge = lambda_max - taper_size;

g = @(lambda) bandpass_kernel(lambda, lambda_min, lambda_max, lower_edge, upper_edge, taper_type);

end

function y = bandpass_kernel(lambda, lambda_min, lambda_max, lower_edge, upper_edge, taper_type)
%BANDPASS_KERNEL Evaluate bandpass filter with tapering
    y = zeros(size(lambda));
    
    % Passband (no taper region)
    passband = (lambda >= lower_edge) & (lambda <= upper_edge);
    y(passband) = 1;
    
    % Lower transition
    lower_trans = (lambda >= lambda_min) & (lambda < lower_edge);
    if any(lower_trans)
        t = (lambda(lower_trans) - lambda_min) / (lower_edge - lambda_min);
        y(lower_trans) = apply_taper(t, taper_type);
    end
    
    % Upper transition
    upper_trans = (lambda > upper_edge) & (lambda <= lambda_max);
    if any(upper_trans)
        t = (lambda_max - lambda(upper_trans)) / (lambda_max - upper_edge);
        y(upper_trans) = apply_taper(t, taper_type);
    end
    
    % Stopband
    y(lambda < lambda_min) = 0;
    y(lambda > lambda_max) = 0;
end

function w = apply_taper(t, taper_type)
%APPLY_TAPER Apply taper window function
    switch taper_type
        case "none"
            w = ones(size(t));
        case "hann"
            w = 0.5 * (1 - cos(pi * t));
        case "hamming"
            w = 0.54 - 0.46 * cos(pi * t);
        case "tukey"
            w = 0.5 * (1 + cos(pi * (1 - t)));
        otherwise
            error('Unknown taper type: %s', taper_type);
    end
end
