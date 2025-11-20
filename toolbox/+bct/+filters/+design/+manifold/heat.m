function g = heat(manifold, varargin)
%HEAT Heat kernel filter on manifold spectral domain
%
%   g = heat(manifold) creates a heat diffusion kernel with default tau = 0.1
%   g = heat(manifold, 'tau', tau) sets the diffusion time parameter
%   g = heat(manifold, 'lambda_max', lmax) sets explicit lambda_max
%
%   The heat kernel is defined as:
%       g(lambda) = exp(-tau * lambda / lambda_max)
%
%   where lambda_max is the maximum eigenvalue (normalization factor).
%
%   Inputs:
%     manifold    - bct.manifold.Manifold object with Resolution
%     'tau'       - Diffusion time parameter (default: 0.1)
%                   Higher tau → more diffusion (smoother, lowpass)
%                   Lower tau → less diffusion (preserves high frequencies)
%     'lambda_max' - Override lambda_max (default: from manifold.Resolution)
%
%   Returns:
%     g - Function handle @(lambda) that evaluates the heat kernel
%
%   Example:
%       % Create heat kernel filter
%       filt = bct.filters.Filter('Manifold');
%       filt.Manifold = B.Manifold;
%       filt.g = bct.filters.design.manifold.heat(B.Manifold, 'tau', 0.05);
%       
%       % Evaluate at specific eigenvalues
%       response = filt.getResponse([0, 100, 500, 1000]);
%
%   See also: bct.filters.Filter, bct.filters.design.manifold.mexh

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'tau', 0.1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'lambda_max', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
parse(p, manifold, varargin{:});

tau = p.Results.tau;
lambda_max = p.Results.lambda_max;

% Get lambda_max from manifold if not provided
if isempty(lambda_max)
    if isempty(manifold.Resolution)
        error('bct:filters:design:manifold:heat:NoResolution', ...
            'Manifold has no Resolution. Call manifold.setResolution() first.');
    end
    lambda_max = manifold.Resolution.lambda_max;
end

% Create heat kernel function
% g(lambda) = exp(-tau * lambda / lambda_max)
g = @(lambda) exp(-tau * lambda / lambda_max);

end
