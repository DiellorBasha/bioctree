function H = gaussian2d(varargin)
%GAUSSIAN2D 2D Gaussian filter in (λ, ω) spectral domain
%
%   H = gaussian2d() creates a 2D Gaussian with default parameters
%   H = gaussian2d('lambda0', l0, 'omega0', w0) sets the center
%   H = gaussian2d('sigma_lambda', sl, 'sigma_omega', sw) sets widths
%
%   The 2D Gaussian filter is defined as:
%       H(λ, ω) = exp(-0.5 * [((λ-λ₀)/σ_λ)² + ((ω-ω₀)/σ_ω)²])
%
%   Inputs (Name-Value pairs):
%     'lambda0'      - Center eigenvalue (default: 500)
%     'omega0'       - Center angular frequency in rad/s (default: 2π*10)
%     'sigma_lambda' - Spatial spectral width (default: 100)
%     'sigma_omega'  - Temporal spectral width in rad/s (default: 2π*2)
%     'rho'          - Correlation coefficient (default: 0 for independence)
%
%   Returns:
%     H - Function handle @(lambda, omega) for 2D Gaussian filter
%
%   Example:
%       % Create 2D Gaussian centered at (λ=500, ω=20π rad/s)
%       H = bct.filters.design.joint.spectral.gaussian2d(...
%           'lambda0', 500, 'omega0', 2*pi*10, ...
%           'sigma_lambda', 100, 'sigma_omega', 2*pi*2);
%       
%       % Evaluate on grid
%       response = H(lambda_grid, omega_grid);
%
%   See also: bct.filters.design.joint.separable.spatial_temporal

% Parse inputs
p = inputParser;
addParameter(p, 'lambda0', 500, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'omega0', 2*pi*10, @(x) isnumeric(x) && x > 0);
addParameter(p, 'sigma_lambda', 100, @(x) isnumeric(x) && x > 0);
addParameter(p, 'sigma_omega', 2*pi*2, @(x) isnumeric(x) && x > 0);
addParameter(p, 'rho', 0, @(x) isnumeric(x) && abs(x) < 1);
parse(p, varargin{:});

lambda0 = p.Results.lambda0;
omega0 = p.Results.omega0;
sigma_lambda = p.Results.sigma_lambda;
sigma_omega = p.Results.sigma_omega;
rho = p.Results.rho;

% Create 2D Gaussian filter
if rho == 0
    % Independent case (separable)
    H = @(lambda, omega) exp(-0.5 * (((lambda - lambda0) / sigma_lambda).^2 + ...
                                      ((omega - omega0) / sigma_omega).^2));
else
    % Correlated case (non-separable)
    H = @(lambda, omega) gaussian2d_correlated(lambda, omega, lambda0, omega0, ...
                                                sigma_lambda, sigma_omega, rho);
end

end

function y = gaussian2d_correlated(lambda, omega, lambda0, omega0, sigma_lambda, sigma_omega, rho)
%GAUSSIAN2D_CORRELATED Evaluate correlated 2D Gaussian
    z_lambda = (lambda - lambda0) / sigma_lambda;
    z_omega = (omega - omega0) / sigma_omega;
    
    % Mahalanobis distance with correlation
    exponent = (z_lambda.^2 + z_omega.^2 - 2*rho*z_lambda.*z_omega) / (2*(1 - rho^2));
    
    y = exp(-exponent) / (2*pi*sigma_lambda*sigma_omega*sqrt(1 - rho^2));
end
