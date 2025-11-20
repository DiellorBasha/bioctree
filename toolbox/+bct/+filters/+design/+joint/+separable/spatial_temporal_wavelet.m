function H = spatial_temporal_wavelet(manifold, varargin)
%SPATIAL_TEMPORAL_WAVELET Separable wavelet filter H(λ,ω)
%
%   H = spatial_temporal_wavelet(manifold) creates a separable wavelet
%   H = spatial_temporal_wavelet(manifold, 'scale_s', s, 'scale_t', t)
%
%   The separable wavelet filter combines Laplace-Beltrami wavelets
%   on the manifold with Morlet wavelets in time:
%       H(λ, ω) = Ψ_spatial(λ) * Ψ_temporal(ω)
%
%   Inputs:
%     manifold  - bct.manifold.Manifold object
%     'scale_s' - Spatial scale (default: sqrt(lambda_max)/5)
%     'scale_t' - Temporal scale in seconds (default: 0.1)
%     'omega0'  - Center frequency in rad/s (default: 2π*10)
%
%   Returns:
%     H - Function handle @(lambda, omega) for joint wavelet filter
%
%   Example:
%       H = bct.filters.design.joint.separable.spatial_temporal_wavelet(...
%           B.Manifold, 'scale_s', 10, 'omega0', 2*pi*8);
%
%   See also: bct.filters.design.manifold.wavelet,
%             bct.filters.design.time.morlet

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'scale_s', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
addParameter(p, 'scale_t', 0.1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'omega0', 2*pi*10, @(x) isnumeric(x) && x > 0);
parse(p, manifold, varargin{:});

scale_s = p.Results.scale_s;
scale_t = p.Results.scale_t;
omega0 = p.Results.omega0;

% Create spatial wavelet
Psi_spatial = bct.filters.design.manifold.wavelet(manifold, 'scale', scale_s);

% Create temporal wavelet
sigma_omega = 1 / scale_t;
Psi_temporal = bct.filters.design.time.morlet('omega0', omega0, 'sigma', sigma_omega);

% Create separable joint wavelet
H = @(lambda, omega) Psi_spatial(lambda) .* Psi_temporal(omega);

end
