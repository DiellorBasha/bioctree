function g = mexh(manifold, varargin)
%MEXH Mexican hat wavelet filter on manifold spectral domain
%
%   g = mexh(manifold) creates a Mexican hat wavelet with default sx = 0.1
%   g = mexh(manifold, 'sx', sx) sets the spectral width parameter
%   g = mexh(manifold, 'lambda0', l0) sets the center eigenvalue
%   g = mexh(manifold, 'lambda_max', lmax) sets explicit lambda_max
%
%   The Mexican hat (Ricker) wavelet is defined as:
%       g(lambda) = (1 - t^2) * exp(-t^2 / 2)
%   where:
%       t = (lambda - lambda0) / (sx * lambda_max)
%
%   This is a bandpass filter centered at lambda0 with spectral width
%   controlled by sx.
%
%   Inputs:
%     manifold     - bct.manifold.Manifold object with Resolution
%     'sx'         - Spectral width parameter (default: 0.1)
%                    Smaller sx → narrower bandpass
%                    Larger sx → wider bandpass
%     'lambda0'    - Center eigenvalue (default: lambda_max/2)
%     'lambda_max' - Override lambda_max (default: from manifold.Resolution)
%
%   Returns:
%     g - Function handle @(lambda) that evaluates the Mexican hat wavelet
%
%   Example:
%       % Create Mexican hat filter centered at lambda = 500
%       filt = bct.filters.Filter('Manifold');
%       filt.Manifold = B.Manifold;
%       filt.g = bct.filters.design.manifold.mexh(B.Manifold, ...
%                                                  'sx', 0.05, ...
%                                                  'lambda0', 500);
%       
%       % Plot response
%       filt.KernelType = 'mexh';
%       filt.plotResponse();
%
%   See also: bct.filters.Filter, bct.filters.design.manifold.heat

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'sx', 0.1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'lambda0', [], @(x) isempty(x) || (isnumeric(x) && x >= 0));
addParameter(p, 'lambda_max', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
parse(p, manifold, varargin{:});

sx = p.Results.sx;
lambda0 = p.Results.lambda0;
lambda_max = p.Results.lambda_max;

% Get lambda_max from manifold if not provided
if isempty(lambda_max)
    if isempty(manifold.Resolution)
        error('bct:filters:design:manifold:mexh:NoResolution', ...
            'Manifold has no Resolution. Call manifold.setResolution() first.');
    end
    lambda_max = manifold.Resolution.lambda_max;
end

% Default lambda0 is midpoint
if isempty(lambda0)
    lambda0 = lambda_max / 2;
end

% Create Mexican hat wavelet function
% g(lambda) = (1 - t^2) * exp(-t^2 / 2)
% where t = (lambda - lambda0) / (sx * lambda_max)
g = @(lambda) mexican_hat_kernel(lambda, lambda0, sx, lambda_max);

end

function y = mexican_hat_kernel(lambda, lambda0, sx, lambda_max)
%MEXICAN_HAT_KERNEL Evaluate Mexican hat wavelet
    t = (lambda - lambda0) / (sx * lambda_max);
    y = (1 - t.^2) .* exp(-t.^2 / 2);
    % Ensure non-negative
    y = max(y, 0);
end
