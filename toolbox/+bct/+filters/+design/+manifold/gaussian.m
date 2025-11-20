function g = gaussian(manifold, varargin)
%GAUSSIAN Gaussian filter on manifold spectral domain
%
%   g = gaussian(manifold) creates a Gaussian filter with default parameters
%   g = gaussian(manifold, 'lambda0', l0) sets the center eigenvalue
%   g = gaussian(manifold, 'sigma', s) sets the spectral width
%   g = gaussian(manifold, 'lambda_max', lmax) sets explicit lambda_max
%
%   The Gaussian filter is defined as:
%       g(lambda) = exp(-0.5 * ((lambda - lambda0) / sigma)^2)
%
%   This is a bandpass filter centered at lambda0 with spectral width sigma.
%   When lambda0 = 0, it becomes a lowpass filter.
%
%   Inputs:
%     manifold     - bct.manifold.Manifold object with Resolution
%     'lambda0'    - Center eigenvalue (default: 0 for lowpass)
%     'sigma'      - Spectral width (default: lambda_max/10)
%     'lambda_max' - Override lambda_max (default: from manifold.Resolution)
%
%   Returns:
%     g - Function handle @(lambda) that evaluates the Gaussian filter
%
%   Example - Lowpass Gaussian:
%       % Create lowpass filter (centered at lambda = 0)
%       filt = bct.filters.Filter('Manifold');
%       filt.Manifold = B.Manifold;
%       filt.g = bct.filters.design.manifold.gaussian(B.Manifold, 'sigma', 100);
%       filt.KernelType = 'gaussian';
%       filt.plotResponse();
%
%   Example - Bandpass Gaussian:
%       % Create bandpass filter centered at lambda = 500
%       filt = bct.filters.Filter('Manifold');
%       filt.Manifold = B.Manifold;
%       filt.g = bct.filters.design.manifold.gaussian(B.Manifold, ...
%                                                      'lambda0', 500, ...
%                                                      'sigma', 50);
%       filt.KernelType = 'gaussian';
%       
%       % Evaluate at specific eigenvalues
%       response = filt.getResponse([400, 500, 600]);
%
%   See also: bct.filters.Filter, bct.filters.design.manifold.heat,
%             bct.filters.design.manifold.mexh

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'lambda0', 0, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'sigma', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
addParameter(p, 'lambda_max', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
parse(p, manifold, varargin{:});

lambda0 = p.Results.lambda0;
sigma = p.Results.sigma;
lambda_max = p.Results.lambda_max;

% Get lambda_max from manifold if not provided
if isempty(lambda_max)
    if isempty(manifold.Resolution)
        error('bct:filters:design:manifold:gaussian:NoResolution', ...
            'Manifold has no Resolution. Call manifold.setResolution() first.');
    end
    lambda_max = manifold.Resolution.lambda_max;
end

% Default sigma is lambda_max/10
if isempty(sigma)
    sigma = lambda_max / 10;
end

% Create Gaussian filter function
% g(lambda) = exp(-0.5 * ((lambda - lambda0) / sigma)^2)
g = @(lambda) exp(-0.5 * ((lambda - lambda0) / sigma).^2);

end
