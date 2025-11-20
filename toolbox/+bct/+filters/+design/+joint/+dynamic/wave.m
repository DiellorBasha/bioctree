function K = wave(manifold, varargin)
%WAVE Wave propagation propagator K(λ,t) on manifold
%
%   K = wave(manifold) creates wave propagation propagator
%   K = wave(manifold, 'c', c) sets wave speed
%
%   The wave propagation propagator in spectral domain:
%       K(λ, t) = cos(c * √λ * t)
%
%   For traveling waves on graphs/manifolds.
%
%   Inputs:
%     manifold - bct.manifold.Manifold object
%     'c'      - Wave speed (default: 1.0)
%                Larger c → faster propagation
%                Smaller c → slower propagation
%
%   Returns:
%     K - Function handle @(lambda, t) for wave propagator
%
%   Example:
%       % Create traveling wave filter
%       filt = bct.filters.Filter('Dynamic');
%       filt.Manifold = B.Manifold;
%       filt.Time = B.Time;
%       filt.g = bct.filters.design.joint.dynamic.wave(B.Manifold, 'c', 2.0);
%       filt.lambda_band = [4, 100];  % Medium-high spatial frequencies
%       
%       B.addFilter(filt);
%       B.Synthesize(1);
%       sig = B.Generate('label', 'traveling_wave');
%
%   See also: bct.filters.design.joint.dynamic.heat,
%             bct.filters.design.joint.dynamic.schrodinger

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'c', 1.0, @(x) isnumeric(x) && x > 0);
parse(p, manifold, varargin{:});

c = p.Results.c;

% Wave propagator: K(λ, t) = cos(c * √λ * t)
% Creates traveling waves with speed c
K = @(lambda, t) cos(c * sqrt(lambda) .* t);

end
