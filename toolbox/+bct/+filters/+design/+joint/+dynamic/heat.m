function K = heat(manifold, varargin)
%HEAT Heat diffusion propagator K(λ,t) on manifold
%
%   K = heat(manifold) creates heat diffusion propagator
%   K = heat(manifold, 'D', D) sets diffusion coefficient
%
%   The heat diffusion propagator in spectral domain:
%       K(λ, t) = exp(-D * λ * t)
%
%   For thermal diffusion/dispersion on graphs/manifolds.
%
%   Inputs:
%     manifold - bct.manifold.Manifold object
%     'D'      - Diffusion coefficient (default: 0.01)
%                Larger D → faster spreading
%                Smaller D → slower spreading
%
%   Returns:
%     K - Function handle @(lambda, t) for heat propagator
%
%   Example:
%       % Create dispersing blob filter
%       filt = bct.filters.Filter('Dynamic');
%       filt.Manifold = B.Manifold;
%       filt.Time = B.Time;
%       filt.g = bct.filters.design.joint.dynamic.heat(B.Manifold, 'D', 0.01);
%       filt.lambda_band = [1, 25];  % Medium spatial scales
%       
%       B.addFilter(filt);
%       B.Synthesize(1);
%       sig = B.Generate('label', 'dispersing_blob');
%
%   See also: bct.filters.design.joint.dynamic.schrodinger,
%             bct.filters.design.joint.dynamic.wave

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'D', 0.01, @(x) isnumeric(x) && x > 0);
parse(p, manifold, varargin{:});

D = p.Results.D;

% Heat diffusion propagator: K(λ, t) = exp(-D * λ * t)
% Causes initial conditions to spread/diffuse over time
K = @(lambda, t) exp(-D * lambda .* t);

end
