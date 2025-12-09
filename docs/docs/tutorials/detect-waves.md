# Detect Traveling Waves

Advanced tutorial for detecting and tracking traveling waves on cortical surfaces.

## Prerequisites

- Loaded mesh with eigenbasis
- Spatiotemporal signal data
- Understanding of wave packet filters

## Complete Workflow

```matlab
% 1. Setup
B = bct.bct.fromMesh(V, F);
B.computeEigenbasis(100);
B.Manifold.Time = bct.Time(200, 250);  % 200 samples, 250 Hz

% 2. Load data
signal = bct.Signal(B.Manifold, meg_source_data, 'meg');

% 3. Compute dispersion
B.computeDispersion(signal);

% 4. Create detection filter
joint = bct.Joint(B.Lambda, B.Omega);
detector = bct.Filter(joint, 'wavepacket', ...
    'velocity', 0.5, ...
    'center_freq', 10, ...
    'bandwidth', 2);

% 5. Detect waves
waves = detector.apply(signal);

% 6. Extract phase and direction
phase = angle(hilbert(waves.Data, [], 2));
[direction, speed] = B.Manifold.phaseGradient(phase);

% 7. Visualize
bct.show.wavefront(B, phase, 'TimePoints', 50:150);
```

## Advanced Analysis

### Multi-Velocity Detection

```matlab
velocities = [0.2, 0.5, 0.8];

for i = 1:length(velocities)
    filt = bct.Filter(joint, 'wavepacket', ...
        'velocity', velocities(i), 'center_freq', 10, 'bandwidth', 2);
    
    components{i} = filt.apply(signal);
end

% Compare velocities
figure;
for i = 1:length(velocities)
    subplot(1, length(velocities), i);
    bct.show.signal(B, components{i}, 'TimePoint', 100);
    title(sprintf('v = %.1f m/s', velocities(i)));
end
```

## Further Reading

- [Wave Packets Concept](../concepts/wave-packets.md)
- [Dispersion](../concepts/dispersion.md)
