function [g, params] = gaussian(manifold, varargin)
%GAUSSIAN Gaussian filter on manifold spectral domain using wavenumber
%
%   g = gaussian(manifold) creates a Gaussian filter with default parameters
%   [g, params] = gaussian(manifold, ...) also returns filter parameters
%
%   g = gaussian(manifold, 'k0', k) sets the center wavenumber (rad/mm)
%   g = gaussian(manifold, 'sigma_k', s) sets the wavenumber width (rad/mm)
%   g = gaussian(manifold, 'lambda0', l0) sets center eigenvalue (deprecated)
%   g = gaussian(manifold, 'sigma', s) sets eigenvalue width (deprecated)
%
%   The Gaussian filter is defined in WAVENUMBER space:
%       g(k) = exp(-0.5 * ((k - k0) / sigma_k)^2)
%       where k = sqrt(lambda) is the wavenumber (rad/mm)
%
%   This produces physically meaningful spatial filtering with:
%   - Smooth, stable bandpass characteristics
%   - Linear frequency response
%   - No high-frequency artifacts
%
%   Inputs:
%     manifold     - bct.manifold.Manifold object with Resolution
%     'k0'         - Center wavenumber in rad/mm (default: 0 for lowpass)
%     'sigma_k'    - Wavenumber width in rad/mm (default: k_max/10)
%     'lambda0'    - (deprecated) Center eigenvalue
%     'sigma'      - (deprecated) Eigenvalue width
%     'k_max'      - Override k_max (default: from manifold.Resolution)
%
%   Returns:
%     g      - Function handle @(lambda) that evaluates the Gaussian filter
%     params - Structure with filter parameters:
%              .lambda0      - Center eigenvalue
%              .sigma        - Spectral width
%              .lambda_band  - Suggested [min, max] support (3-sigma rule)
%
%   Example - Lowpass Gaussian:
%       % Create lowpass filter (centered at lambda = 0)
%       filt = bct.filters.Filter('Manifold');
%       filt.Manifold = B.Manifold;
%       [filt.g, params] = bct.filters.design.manifold.gaussian(B.Manifold, 'sigma', 100);
%       filt.lambda_band = params.lambda_band;  % Auto-set from params
%       filt.KernelType = 'gaussian';
%
%   Example - Bandpass Gaussian:
%       % Create bandpass filter centered at lambda = 500
%       filt = bct.filters.Filter('Manifold');
%       filt.Manifold = B.Manifold;
%       [filt.g, params] = bct.filters.design.manifold.gaussian(B.Manifold, ...
%                                                                'lambda0', 500, ...
%                                                                'sigma', 50);
%       filt.lambda_band = params.lambda_band;  % [350, 650] (3-sigma)
%       filt.KernelType = 'gaussian';
%
%   See also: bct.filters.Filter, bct.filters.design.manifold.heat,
%             bct.filters.design.manifold.mexh

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'k0', 0, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'sigma_k', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
addParameter(p, 'k_max', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
% Deprecated lambda-based parameters
addParameter(p, 'lambda0', [], @(x) isempty(x) || (isnumeric(x) && x >= 0));
addParameter(p, 'sigma', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
parse(p, manifold, varargin{:});

k0 = p.Results.k0;
sigma_k = p.Results.sigma_k;
k_max = p.Results.k_max;
lambda0_deprecated = p.Results.lambda0;
sigma_deprecated = p.Results.sigma;

% Handle deprecated lambda-based parameters
if ~isempty(lambda0_deprecated)
    warning('bct:filters:design:manifold:gaussian:DeprecatedParam', ...
        'lambda0 is deprecated. Use k0=sqrt(lambda0) instead.');
    k0 = sqrt(lambda0_deprecated);
end
if ~isempty(sigma_deprecated)
    warning('bct:filters:design:manifold:gaussian:DeprecatedParam', ...
        'sigma is deprecated. Use sigma_k for wavenumber width.');
    % Approximate conversion: sigma_k ≈ sigma / (2*sqrt(lambda0))
    if k0 > 0
        sigma_k = sigma_deprecated / (2*k0);
    else
        sigma_k = sqrt(sigma_deprecated);
    end
end

% Get k_max from manifold if not provided
if isempty(k_max)
    if isempty(manifold.Resolution)
        error('bct:filters:design:manifold:gaussian:NoResolution', ...
            'Manifold has no Resolution.');
    end
    lambda_max = manifold.Resolution.lambda_max;
    k_max = sqrt(lambda_max);  % Convert to wavenumber
end

% Default sigma_k is k_max/10
if isempty(sigma_k)
    sigma_k = k_max / 10;
end

% Create Gaussian filter function in WAVENUMBER space
% g(lambda) evaluates at k = sqrt(lambda)
% This ensures smooth, physically meaningful spatial filtering
g = @(lambda) exp(-0.5 * ((sqrt(lambda) - k0) ./ sigma_k).^2);

% Return parameters including k_band and lambda_band
if nargout > 1
    params = struct();
    params.k0 = k0;
    params.sigma_k = sigma_k;
    params.k_band = [max(0, k0 - 3*sigma_k), k0 + 3*sigma_k];  % 3-sigma in k
    % Convert to lambda_band: lambda = k^2
    params.lambda_band = params.k_band.^2;
    params.lambda0 = k0^2;  % For reference
end

end
