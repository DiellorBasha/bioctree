# Temporal Filters

Temporal filters process the time-series aspect of spatiotemporal signals, operating in the Time or Omega (frequency) domains.

## Overview

Temporal filtering in Bioctree follows standard time-series and frequency-domain filtering theory, integrated with the spatial domain framework.

## Filter Domains

### Time Domain
Direct temporal operations:
```matlab
filt = bct.Filter(B.Time, 'gaussian', 'center', 100, 'sigma', 10);
```

### Omega Domain (Frequency)
Most temporal filtering (like spatial → Lambda):
```matlab
filt = bct.Filter(B.Omega, 'bandpass', 'low', 8, 'high', 12);
```

## Common Temporal Filters

### 1. Band-Pass (Oscillation Extraction)

```matlab
% Alpha band (8-12 Hz)
alpha_filt = bct.Filter(B.Omega, 'bandpass', 'low', 8, 'high', 12);
alpha_signal = alpha_filt.apply(signal);

% Beta band (13-30 Hz)
beta_filt = bct.Filter(B.Omega, 'bandpass', 'low', 13, 'high', 30);

% With smooth transitions (recommended)
alpha_smooth = bct.Filter(B.Omega, 'bandpass', ...
    'low', 8, 'high', 12, 'taper', true);
```

**Neurophysiological bands**:
- Delta: 0.5-4 Hz
- Theta: 4-8 Hz
- Alpha: 8-12 Hz
- Beta: 13-30 Hz
- Gamma: 30-100+ Hz

### 2. Low-Pass (Anti-Aliasing, Smoothing)

```matlab
% Remove high frequencies
lp_filt = bct.Filter(B.Omega, 'lowpass', 'cutoff', 40);
smooth_time = lp_filt.apply(signal);
```

### 3. High-Pass (DC Removal, Baseline)

```matlab
% Remove slow drifts
hp_filt = bct.Filter(B.Omega, 'highpass', 'cutoff', 1);
detrended = hp_filt.apply(signal);
```

### 4. Notch (Line Noise)

```matlab
% Remove 50 Hz line noise (Europe)
notch_50 = bct.Filter(B.Omega, 'notch', 'center', 50, 'width', 2);

% 60 Hz (North America)
notch_60 = bct.Filter(B.Omega, 'notch', 'center', 60, 'width', 2);

% Apply
clean = notch_60.apply(signal);
```

## Practical Examples

### Example 1: Multi-Band Decomposition

```matlab
% Define frequency bands
bands = struct();
bands.delta = [0.5, 4];
bands.theta = [4, 8];
bands.alpha = [8, 12];
bands.beta = [13, 30];
bands.gamma_low = [30, 60];

% Extract each band
decomposed = struct();
for name = fieldnames(bands)'
    band = bands.(name{1});
    filt = bct.Filter(B.Omega, 'bandpass', ...
        'low', band(1), 'high', band(2), 'taper', true);
    decomposed.(name{1}) = filt.apply(signal);
end
```

### Example 2: Event-Related Filtering

```matlab
% Filter around event frequency
event_freq = 2;  % Events at 2 Hz
event_filt = bct.Filter(B.Omega, 'bandpass', ...
    'low', event_freq - 0.5, ...
    'high', event_freq + 0.5);

event_related = event_filt.apply(signal);
```

### Example 3: Downsampling with Anti-Aliasing

```matlab
% Target sampling rate
fs_new = 125;  % Hz (from 250 Hz)

% Low-pass at Nyquist of new rate
lp = bct.Filter(B.Omega, 'lowpass', 'cutoff', fs_new/2);
filtered = lp.apply(signal);

% Downsample
downsample_factor = round(B.Manifold.Time.fs / fs_new);
downsampled = filtered.Data(:, 1:downsample_factor:end);
```

## Further Reading

- [Spatial Filters](spatial.md)
- [Joint Filters](joint-filters.md)
- [Omega Domain](../api/matlab/overview.md)
