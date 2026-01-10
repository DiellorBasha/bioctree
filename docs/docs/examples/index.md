# Examples Index

Real-world examples demonstrating Bioctree capabilities.

## Available Examples

### [Wave Packets](wavepackets.md)
Detect and analyze traveling waves in MEG/EEG data.

**Topics**:
- Alpha wave detection
- Wave velocity estimation
- Phase tracking
- Multi-velocity decomposition

### [Time-Frequency Analysis](time-frequency.md)
Joint spectral-temporal decomposition.

**Topics**:
- Multi-band decomposition
- Oscillation detection
- Event-related analysis
- Time-varying spectral content

### [Spatiotemporal Analysis](spatiotemporal.md)
Complete pipeline for cortical signal analysis.

**Topics**:
- Data loading and preprocessing
- Spatial filtering
- Temporal filtering
- Joint domain analysis
- Visualization

## Quick Examples

### Example 1: Basic Filtering
```matlab
B = bct.bct.fromMesh(V, F);
B.computeEigenbasis(100);

sig = bct.Signal(B.Manifold, data, 'signal');
filt = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 30);
filtered = filt.apply(sig);

bct.show.signal(B, filtered);
```

### Example 2: Alpha Band Extraction
```matlab
% Temporal filter for alpha band
alpha_filt = bct.Filter(B.Omega, 'bandpass', 'low', 8, 'high', 12);
alpha_sig = alpha_filt.apply(meg_signal);
```

### Example 3: Wave Detection
```matlab
joint = bct.Joint(B.Lambda, B.Omega);
wp_filt = bct.Filter(joint, 'wavepacket', ...
    'velocity', 0.5, 'center_freq', 10, 'bandwidth', 2);
waves = wp_filt.apply(signal);
```

## Running Examples

All examples are located in `examples/` directory:

```matlab
% Navigate to bioctree root
cd /path/to/bioctree

% Run initialization
bioctree_start

% Run example
run examples/demo_fundamental_kernels.m
```
