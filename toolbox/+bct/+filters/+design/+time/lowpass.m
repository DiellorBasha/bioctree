function phi = lowpass(f_cutoff, varargin)
%LOWPASS Lowpass filter in temporal frequency domain
%
%   phi = lowpass(f_cutoff) creates a lowpass filter with cutoff frequency
%   phi = lowpass(f_cutoff, 'taper', type) sets the taper type
%
%   Inputs:
%     f_cutoff - Cutoff frequency in Hz (or rad/s if omega=true)
%     'taper'  - Taper type: 'none', 'hann', 'hamming', 'butter' (default: 'hann')
%     'width'  - Transition width as fraction of cutoff (default: 0.2)
%     'order'  - Butterworth filter order if taper='butter' (default: 4)
%     'omega'  - If true, f_cutoff is in rad/s (default: false for Hz)
%
%   Returns:
%     phi - Function handle @(x) where x is frequency (Hz) or omega (rad/s)
%
%   Example:
%       % Create lowpass filter at 30 Hz
%       filt = bct.filters.Filter('Time');
%       filt.g = bct.filters.design.time.lowpass(30);
%       filt.KernelType = 'lowpass';
%
%   See also: bct.filters.Filter, bct.filters.design.time.bandpass

% Parse inputs
p = inputParser;
addRequired(p, 'f_cutoff', @(x) isnumeric(x) && x > 0);
addParameter(p, 'taper', 'hann', @(x) ischar(x) || isstring(x));
addParameter(p, 'width', 0.2, @(x) isnumeric(x) && x > 0);
addParameter(p, 'order', 4, @(x) isnumeric(x) && x > 0);
addParameter(p, 'omega', false, @islogical);
parse(p, f_cutoff, varargin{:});

taper_type = string(p.Results.taper);
taper_width = p.Results.width;
order = p.Results.order;

% Create lowpass filter function
if taper_type == "butter"
    % Butterworth lowpass
    phi = @(x) 1 ./ (1 + (x / f_cutoff).^(2*order));
else
    % Tapered lowpass
    transition_width = taper_width * f_cutoff;
    transition_start = f_cutoff - transition_width;
    
    phi = @(x) lowpass_kernel(x, f_cutoff, transition_start, taper_type);
end

end

function y = lowpass_kernel(x, f_cutoff, transition_start, taper_type)
%LOWPASS_KERNEL Evaluate lowpass filter with tapering
    y = ones(size(x));
    
    % Transition region
    trans = (x >= transition_start) & (x <= f_cutoff);
    if any(trans)
        t = (f_cutoff - x(trans)) / (f_cutoff - transition_start);
        y(trans) = apply_taper(t, taper_type);
    end
    
    % Stopband
    y(x > f_cutoff) = 0;
end

function w = apply_taper(t, taper_type)
%APPLY_TAPER Apply taper window function
    switch taper_type
        case "none"
            w = ones(size(t));
        case "hann"
            w = 0.5 * (1 + cos(pi * (1 - t)));
        case "hamming"
            w = 0.54 + 0.46 * cos(pi * (1 - t));
        case "tukey"
            w = 0.5 * (1 + cos(pi * (1 - t)));
        otherwise
            error('Unknown taper type: %s', taper_type);
    end
end
