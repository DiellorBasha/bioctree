function phi = hilbert(varargin)
%HILBERT Hilbert transform filter in frequency domain
%
%   phi = hilbert() creates a Hilbert transform filter
%   phi = hilbert('omega', true) for omega (rad/s) parameterization
%
%   The Hilbert transform in frequency domain:
%       H(omega) = -i * sign(omega)
%   
%   For practical implementation with real-valued magnitude:
%       |H(omega)| = 1 for omega > 0
%       |H(omega)| = 0 for omega <= 0
%
%   This extracts the analytic signal (positive frequencies only).
%
%   Inputs (Name-Value pairs):
%     'omega'     - If true, uses omega (rad/s); if false, uses f (Hz)
%     'two_sided' - If true, returns ±1 for ±omega (default: false)
%
%   Returns:
%     phi - Function handle @(x) where x is frequency or omega
%
%   Example:
%       % Create Hilbert transform filter
%       filt = bct.filters.Filter('Time');
%       filt.g = bct.filters.design.time.hilbert('omega', true);
%       filt.KernelType = 'hilbert';
%
%   See also: bct.filters.Filter, bct.filters.design.time.bandpass

% Parse inputs
p = inputParser;
addParameter(p, 'omega', false, @islogical);
addParameter(p, 'two_sided', false, @islogical);
parse(p, varargin{:});

two_sided = p.Results.two_sided;

if two_sided
    % Two-sided Hilbert: sign function
    phi = @(x) sign(x);
else
    % One-sided (analytic signal): step function
    phi = @(x) double(x > 0);
end

end
