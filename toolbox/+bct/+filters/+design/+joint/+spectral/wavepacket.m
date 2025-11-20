function H = wavepacket(varargin)
%WAVEPACKET Wave packet filter in (λ, ω) spectral domain
%
%   H = wavepacket() creates a wave packet with default parameters
%   H = wavepacket('dispersion', @(lambda) ...) sets dispersion relation
%
%   Wave packets represent localized wave-like disturbances with a
%   specific dispersion relation ω = ω(λ):
%       H(λ, ω) = exp(-0.5 * [((λ-λ₀)/σ_λ)² + ((ω-ω(λ))/σ_ω)²])
%
%   Inputs (Name-Value pairs):
%     'lambda0'      - Center eigenvalue (default: 500)
%     'sigma_lambda' - Spatial spectral width (default: 100)
%     'sigma_omega'  - Temporal spectral width in rad/s (default: 2π*2)
%     'dispersion'   - Dispersion relation @(lambda) -> omega (default: sqrt)
%     'group_velocity' - Group velocity for linear dispersion (alternative)
%
%   Returns:
%     H - Function handle @(lambda, omega) for wave packet filter
%
%   Example:
%       % Wave packet with dispersion ω = c*sqrt(λ)
%       c = 0.1;
%       H = bct.filters.design.joint.spectral.wavepacket(...
%           'lambda0', 500, ...
%           'dispersion', @(lambda) c * sqrt(lambda), ...
%           'sigma_lambda', 50);
%
%   See also: bct.filters.design.joint.dynamic.wave

% Parse inputs
p = inputParser;
addParameter(p, 'lambda0', 500, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'sigma_lambda', 100, @(x) isnumeric(x) && x > 0);
addParameter(p, 'sigma_omega', 2*pi*2, @(x) isnumeric(x) && x > 0);
addParameter(p, 'dispersion', @(lambda) sqrt(lambda), @(x) isa(x, 'function_handle'));
addParameter(p, 'group_velocity', [], @(x) isempty(x) || isnumeric(x));
parse(p, varargin{:});

lambda0 = p.Results.lambda0;
sigma_lambda = p.Results.sigma_lambda;
sigma_omega = p.Results.sigma_omega;
dispersion = p.Results.dispersion;
v_g = p.Results.group_velocity;

% Use linear dispersion if group velocity specified
if ~isempty(v_g)
    omega0 = dispersion(lambda0);
    dispersion = @(lambda) omega0 + v_g * (lambda - lambda0);
end

% Create wave packet filter
H = @(lambda, omega) exp(-0.5 * (((lambda - lambda0) / sigma_lambda).^2 + ...
                                  ((omega - dispersion(lambda)) / sigma_omega).^2));

end
