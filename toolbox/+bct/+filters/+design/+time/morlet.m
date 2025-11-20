function phi = morlet(varargin)
%MORLET Morlet wavelet filter in temporal frequency domain
%
%   phi = morlet() creates a Morlet wavelet with default parameters
%   phi = morlet('omega0', w0) sets the center angular frequency
%   phi = morlet('sigma', s) sets the frequency width
%
%   The Morlet wavelet in frequency domain is defined as:
%       phi(omega) = exp(-0.5 * ((omega - omega0) / sigma)^2)
%              - exp(-0.5 * (omega0 / sigma)^2) * exp(-0.5 * (omega / sigma)^2)
%
%   The second term ensures zero mean in time domain.
%
%   Inputs (Name-Value pairs):
%     'omega0' - Center angular frequency in rad/s (default: 6 rad/s)
%     'sigma'  - Frequency width in rad/s (default: 1 rad/s)
%     'f0'     - Alternative: center frequency in Hz (converts to omega0)
%
%   Returns:
%     phi - Function handle @(omega) in angular frequency domain
%
%   Example:
%       % Create Morlet wavelet at 10 Hz
%       filt = bct.filters.Filter('Time');
%       filt.g = bct.filters.design.time.morlet('f0', 10);
%       filt.KernelType = 'morlet';
%
%   See also: bct.filters.Filter, bct.filters.design.time.gabor

% Parse inputs
p = inputParser;
addParameter(p, 'omega0', 6, @(x) isnumeric(x) && x > 0);
addParameter(p, 'sigma', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'f0', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
parse(p, varargin{:});

omega0 = p.Results.omega0;
sigma = p.Results.sigma;
f0 = p.Results.f0;

% Convert f0 to omega0 if provided
if ~isempty(f0)
    omega0 = 2 * pi * f0;
end

% Admissibility correction factor
correction = exp(-0.5 * (omega0 / sigma)^2);

% Create Morlet wavelet function
phi = @(omega) exp(-0.5 * ((omega - omega0) / sigma).^2) - ...
               correction * exp(-0.5 * (omega / sigma).^2);

% Set negative values to zero (causal part only for positive frequencies)
phi = @(omega) max(morlet_eval(omega, omega0, sigma, correction), 0);

end

function y = morlet_eval(omega, omega0, sigma, correction)
    y = exp(-0.5 * ((omega - omega0) / sigma).^2) - ...
        correction * exp(-0.5 * (omega / sigma).^2);
end
