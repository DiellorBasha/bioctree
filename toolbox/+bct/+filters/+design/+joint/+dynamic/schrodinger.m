function K = schrodinger(manifold, varargin)
%SCHRODINGER Schrödinger equation propagator K(λ,t) on manifold
%
%   K = schrodinger(manifold) creates Schrödinger propagator
%   K = schrodinger(manifold, 'hbar', h, 'mass', m) sets parameters
%
%   The Schrödinger propagator in spectral domain:
%       K(λ, t) = exp(-i * (ħ*λ / (2*m)) * t)
%
%   For quantum diffusion on graphs/manifolds.
%
%   Inputs:
%     manifold - bct.manifold.Manifold object
%     'hbar'   - Reduced Planck constant (default: 1)
%     'mass'   - Effective mass (default: 1)
%
%   Returns:
%     K - Function handle @(lambda, t) for Schrödinger propagator
%
%   Example:
%       K = bct.filters.design.joint.dynamic.schrodinger(B.Manifold);
%       response = K(lambda_vals, t_vals);
%
%   See also: bct.filters.design.joint.dynamic.heat,
%             bct.filters.design.joint.dynamic.wave

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'hbar', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'mass', 1, @(x) isnumeric(x) && x > 0);
parse(p, manifold, varargin{:});

hbar = p.Results.hbar;
m = p.Results.mass;

% Schrödinger propagator: K(λ, t) = exp(-i * (ħλ / (2m)) * t)
% For real-valued magnitude: |K(λ, t)| = 1 (unitary evolution)
% For practical implementation, use cos part or full complex
K = @(lambda, t) exp(-1i * (hbar * lambda / (2 * m)) .* t);

% If real-valued response needed, use magnitude
% K = @(lambda, t) ones(size(lambda .* t));  % Constant magnitude

end
