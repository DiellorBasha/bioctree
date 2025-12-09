# Wave Packet Filters

Specialized filters for detecting and extracting traveling wave packets on cortical surfaces.

## Overview

Wave packet filters combine spatial localization, temporal frequency selectivity, and propagation velocity to detect coherent spatiotemporal patterns.

## Basic Wave Packet Filter

```matlab
% Create wave packet filter
wp_filt = bct.Filter(joint, 'wavepacket', ...
    'velocity', 0.5, ...        % Group velocity (m/s)
    'center_freq', 10, ...      % Central frequency (Hz)
    'bandwidth', 2, ...         % Frequency bandwidth (Hz)
    'spatial_sigma', 0.02);     % Spatial extent (m)

% Apply to signal
wp_response = wp_filt.apply(signal);
```

## Parameters

- **velocity**: Target group velocity (m/s or eigenmode/s)
- **center_freq**: Dominant temporal frequency (Hz)
- **bandwidth**: Frequency spread (Hz)
- **spatial_sigma**: Spatial localization (meters or eigenmodes)

## Velocity-Selective Filtering

```matlab
% Decompose by propagation speed
velocities = [0.2, 0.5, 0.8, 1.2];  % m/s

for i = 1:length(velocities)
    wp = bct.Filter(joint, 'wavepacket', ...
        'velocity', velocities(i), ...
        'center_freq', 10, ...
        'bandwidth', 2);
    
    components{i} = wp.apply(signal);
end
```

## Dispersion-Aware Wave Packets

```matlab
% Use empirical dispersion relation
B.computeDispersion(signal);

% Filter respects dispersion
wp_disp = bct.Filter(joint, 'wavepacket', ...
    'dispersion', B.Lambda.dispersion, ...
    'velocity', 0.5, ...
    'center_freq', 10, ...
    'bandwidth', 2);
```

## Applications

### Alpha Traveling Waves

```matlab
% Detect alpha-band traveling waves
alpha_wp = bct.Filter(joint, 'wavepacket', ...
    'velocity', 0.3, ...        % Typical alpha velocity
    'center_freq', 10, ...      % Alpha peak
    'bandwidth', 2, ...
    'spatial_sigma', 0.05);     % ~5cm extent

alpha_waves = alpha_wp.apply(meg_signal);

% Visualize as movie
bct.show.wavepacket_movie(B, alpha_waves);
```

### Multi-Frequency Waves

```matlab
% Detect waves at multiple frequencies
freqs = [6, 10, 15, 20];  % Hz

for i = 1:length(freqs)
    wp = bct.Filter(joint, 'wavepacket', ...
        'velocity', 0.5, ...
        'center_freq', freqs(i), ...
        'bandwidth', 2);
    
    waves{i} = wp.apply(signal);
end
```

## Further Reading

- [Wave Packets Concept](../concepts/wave-packets.md)
- [Wave Packet Tutorial](../tutorials/wavepacket.md)
- [Detection Example](../examples/wavepackets.md)
