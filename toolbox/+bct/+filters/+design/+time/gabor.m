function phi = gabor(varargin)
%GABOR Gabor wavelet filter in temporal frequency domain (omega)
%
%   phi = gabor() creates a Gabor wavelet with default parameters
%   phi = gabor('omega0', w0) sets the center angular frequency in rad/s
%   phi = gabor('sigma_t', st) sets the temporal width
%   phi = gabor('sigma_omega', sw) sets the angular frequency width
%
%   The Gabor wavelet in frequency domain is defined as:
%       phi(omega) = exp(-0.5 * ((omega - omega0) / sigma_omega)^2)
%
%   This is a Gaussian bandpass filter centered at omega0 (rad/s).
%
%   Inputs (Name-Value pairs):
%     'omega0'       - Center angular frequency in rad/s (default: 20π ≈ 62.8 rad/s, or 10 Hz)
%     'sigma_t'      - Temporal standard deviation in seconds (default: 0.1 s)
%     'sigma_omega'  - Angular frequency standard deviation in rad/s (default: 1/sigma_t)
%
%   Note: Only one of sigma_t or sigma_omega should be specified.
%         They are related by the uncertainty principle:
%         sigma_omega = 1 / sigma_t
%
%   Returns:
%     phi - Function handle @(omega) that evaluates the Gabor wavelet
%           in angular frequency domain (rad/s)
%
%   Example:
%       % Create Gabor filter at 10 Hz (omega0 = 20π rad/s) with 0.05s temporal width
%       filt = bct.filters.Filter('Time');
%       filt.g = bct.filters.design.time.gabor('omega0', 2*pi*10, 'sigma_t', 0.05);
%       filt.KernelType = 'gabor';
%       
%       % Evaluate at specific angular frequencies
%       response = filt.getResponse([2*pi*8, 2*pi*10, 2*pi*12]);
%       
%       % Plot response
%       filt.Time = B.Time;  % Assumes B.Time exists
%       filt.plotResponse();
%
%   See also: bct.filters.Filter, bct.filters.design.manifold.heat

% Parse inputs
p = inputParser;
addParameter(p, 'omega0', 2*pi*10, @(x) isnumeric(x) && x > 0);  % Default: 10 Hz = 20π rad/s
addParameter(p, 'sigma_t', 0.1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'sigma_omega', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
parse(p, varargin{:});

omega0 = p.Results.omega0;
sigma_t = p.Results.sigma_t;
sigma_omega = p.Results.sigma_omega;

% Compute sigma_omega from sigma_t if not provided
if isempty(sigma_omega)
    sigma_omega = 1 / sigma_t;
else
    % If both provided, warn about inconsistency
    if ~isempty(sigma_t) && abs(sigma_omega - 1/sigma_t) > 1e-6
        warning('bct:filters:design:time:gabor:InconsistentParams', ...
            'sigma_t and sigma_omega are inconsistent. Using sigma_omega = %g rad/s.', sigma_omega);
    end
end

% Create Gabor wavelet function in angular frequency domain
% phi(omega) = exp(-0.5 * ((omega - omega0) / sigma_omega)^2)
phi = @(omega) exp(-0.5 * ((omega - omega0) / sigma_omega).^2);

end
