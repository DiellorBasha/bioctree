function [g, params] = heat(manifold, varargin)
%HEAT Heat kernel filter on manifold using wavenumber
%
%   g = heat(manifold) creates a heat diffusion kernel with default tau = 0.1
%   [g, params] = heat(manifold, ...) also returns filter parameters
%
%   g = heat(manifold, 'tau', tau) sets the diffusion time parameter
%   g = heat(manifold, 'k_max', kmax) sets explicit k_max
%
%   The heat kernel is defined in WAVENUMBER space:
%       g(k) = exp(-tau * k^2 / k_max^2)
%       where k = sqrt(lambda) is the wavenumber (rad/mm)
%
%   This is equivalent to: g(lambda) = exp(-tau * lambda / lambda_max)
%   but conceptually clearer in physical wavenumber space.
%
%   Inputs:
%     manifold    - bct.manifold.Manifold object with Resolution
%     'tau'       - Diffusion time parameter (default: 0.1)
%                   Higher tau → more diffusion (smoother, lowpass)
%                   Lower tau → less diffusion (preserves high frequencies)
%     'k_max'     - Override k_max (default: sqrt(lambda_max) from Resolution)
%
%   Returns:
%     g      - Function handle @(lambda) that evaluates the heat kernel
%     params - Structure with filter parameters:
%              .tau          - Diffusion time parameter
%              .k_max        - Maximum wavenumber
%              .k_band       - Suggested [0, cutoff] in wavenumber
%              .lambda_band  - Suggested [0, cutoff] in eigenvalue
%
%   Example:
%       % Create heat kernel filter with auto lambda_band
%       filt = bct.filters.Filter('Manifold');
%       filt.Manifold = B.Manifold;
%       [filt.g, params] = bct.filters.design.manifold.heat(B.Manifold, 'tau', 0.1);
%       filt.lambda_band = params.lambda_band;
%       filt.KernelType = 'heat';
%
%   See also: bct.filters.Filter, bct.filters.design.manifold.gaussian

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'tau', 0.1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'k_max', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
parse(p, manifold, varargin{:});

tau = p.Results.tau;
k_max = p.Results.k_max;

% Get k_max from manifold if not provided
if isempty(k_max)
    if isempty(manifold.Resolution)
        error('bct:filters:design:manifold:heat:NoResolution', ...
            'Manifold has no Resolution.');
    end
    lambda_max = manifold.Resolution.lambda_max;
    k_max = sqrt(lambda_max);  % Convert to wavenumber
end

% Create heat kernel function
% In wavenumber: g(k) = exp(-tau * k^2 / k_max^2)
% In eigenvalue: g(lambda) = exp(-tau * lambda / lambda_max)
lambda_max = k_max^2;
g = @(lambda) exp(-tau * lambda / lambda_max);

% Return parameters including suggested k_band and lambda_band
% Use cutoff where g(k) = 0.01 (1% of peak)
% exp(-tau * k^2 / k_max^2) = 0.01
% k_cutoff = k_max * sqrt(-log(0.01) / tau)
if nargout > 1
    params = struct();
    params.tau = tau;
    params.k_max = k_max;
    k_cutoff = k_max * sqrt(-log(0.01) / tau);
    k_cutoff = min(k_cutoff, k_max);
    params.k_band = [0, k_cutoff];
    params.lambda_band = [0, k_cutoff^2];  % Convert to lambda
end

end
