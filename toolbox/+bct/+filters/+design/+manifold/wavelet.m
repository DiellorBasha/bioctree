function g = wavelet(manifold, varargin)
%WAVELET Laplace-Beltrami wavelet on manifold spectral domain
%
%   g = wavelet(manifold) creates a wavelet with default parameters
%   g = wavelet(manifold, 'scale', s) sets the scale parameter
%   g = wavelet(manifold, 'lambda0', l0) sets the center eigenvalue
%
%   Laplace-Beltrami wavelets are localized in both space and frequency
%   on the manifold, defined in the spectral domain as:
%       g(lambda) = sqrt(lambda) * exp(-lambda / (2*scale^2))
%
%   Inputs:
%     manifold     - bct.manifold.Manifold object with Resolution
%     'scale'      - Wavelet scale parameter (default: sqrt(lambda_max)/5)
%     'lambda0'    - Center eigenvalue for bandpass version (optional)
%
%   Returns:
%     g - Function handle @(lambda) that evaluates the wavelet
%
%   Example:
%       % Create Laplace-Beltrami wavelet
%       filt = bct.filters.Filter('Manifold');
%       filt.Manifold = B.Manifold;
%       filt.g = bct.filters.design.manifold.wavelet(B.Manifold, 'scale', 10);
%       filt.KernelType = 'wavelet';
%       filt.plotResponse();
%
%   See also: bct.filters.Filter, bct.filters.design.manifold.heat

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'scale', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
addParameter(p, 'lambda0', [], @(x) isempty(x) || (isnumeric(x) && x >= 0));
parse(p, manifold, varargin{:});

scale = p.Results.scale;
lambda0 = p.Results.lambda0;

% Get lambda_max from manifold
if isempty(manifold.Resolution)
    error('bct:filters:design:manifold:wavelet:NoResolution', ...
        'Manifold has no Resolution. Call manifold.setResolution() first.');
end
lambda_max = manifold.Resolution.lambda_max;

% Default scale
if isempty(scale)
    scale = sqrt(lambda_max) / 5;
end

% Create wavelet function
if isempty(lambda0)
    % Standard Laplace-Beltrami wavelet
    g = @(lambda) sqrt(max(lambda, 0)) .* exp(-lambda / (2*scale^2));
else
    % Bandpass wavelet centered at lambda0
    g = @(lambda) sqrt(max(lambda, 0)) .* exp(-((lambda - lambda0).^2) / (2*scale^2));
end

end
