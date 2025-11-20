function phi = bandpass(freq_band, varargin)
%BANDPASS Bandpass filter in temporal frequency domain
%
%   phi = bandpass(freq_band) creates a bandpass filter in frequency (Hz)
%   phi = bandpass(freq_band, 'taper', type) sets the taper type
%   phi = bandpass(freq_band, 'omega', true) uses omega (rad/s) instead
%
%   The bandpass filter passes frequencies in [f_min, f_max] (Hz) or
%   [omega_min, omega_max] (rad/s) with optional tapering at edges.
%
%   Inputs:
%     freq_band - [f_min, f_max] in Hz or [omega_min, omega_max] in rad/s
%     'taper'   - Taper type: 'none', 'hann', 'hamming', 'tukey' (default: 'hann')
%     'width'   - Taper width as fraction of bandwidth (default: 0.1)
%     'omega'   - If true, freq_band is in rad/s (default: false for Hz)
%
%   Returns:
%     phi - Function handle @(x) where x is frequency (Hz) or omega (rad/s)
%
%   Example:
%       % Create bandpass filter [8, 12] Hz
%       filt = bct.filters.Filter('Time');
%       filt.g = bct.filters.design.time.bandpass([8, 12]);
%       filt.freq_band = [8, 12];
%       filt.KernelType = 'bandpass';
%
%   See also: bct.filters.Filter, bct.filters.design.time.lowpass

% Parse inputs
p = inputParser;
addRequired(p, 'freq_band', @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'taper', 'hann', @(x) ischar(x) || isstring(x));
addParameter(p, 'width', 0.1, @(x) isnumeric(x) && x > 0 && x < 0.5);
addParameter(p, 'omega', false, @islogical);
parse(p, freq_band, varargin{:});

f_min = min(freq_band);
f_max = max(freq_band);
taper_type = string(p.Results.taper);
taper_width = p.Results.width;

% Create bandpass filter function with tapering
bandwidth = f_max - f_min;
taper_size = taper_width * bandwidth;

% Define transition regions
lower_edge = f_min + taper_size;
upper_edge = f_max - taper_size;

phi = @(x) bandpass_kernel(x, f_min, f_max, lower_edge, upper_edge, taper_type);

end

function y = bandpass_kernel(x, f_min, f_max, lower_edge, upper_edge, taper_type)
%BANDPASS_KERNEL Evaluate bandpass filter with tapering
    y = zeros(size(x));
    
    % Passband
    passband = (x >= lower_edge) & (x <= upper_edge);
    y(passband) = 1;
    
    % Lower transition
    lower_trans = (x >= f_min) & (x < lower_edge);
    if any(lower_trans)
        t = (x(lower_trans) - f_min) / (lower_edge - f_min);
        y(lower_trans) = apply_taper(t, taper_type);
    end
    
    % Upper transition
    upper_trans = (x > upper_edge) & (x <= f_max);
    if any(upper_trans)
        t = (f_max - x(upper_trans)) / (f_max - upper_edge);
        y(upper_trans) = apply_taper(t, taper_type);
    end
end

function w = apply_taper(t, taper_type)
%APPLY_TAPER Apply taper window function
    switch taper_type
        case "none"
            w = ones(size(t));
        case "hann"
            w = 0.5 * (1 - cos(pi * t));
        case "hamming"
            w = 0.54 - 0.46 * cos(pi * t);
        case "tukey"
            w = 0.5 * (1 + cos(pi * (1 - t)));
        otherwise
            error('Unknown taper type: %s', taper_type);
    end
end
