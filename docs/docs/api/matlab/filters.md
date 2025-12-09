# Filter API Reference

The `bct.Filter` class provides filtering operations on any domain.

## Constructor

```matlab
filt = bct.Filter(domain, kernel_type, Name, Value, ...);
```

**Parameters**:
- `domain`: Domain where filter operates (Manifold, Lambda, Time, Omega, Joint)
- `kernel_type`: String specifying kernel (see Kernel Types below)
- `Name, Value`: Kernel-specific parameters

## Kernel Types

### Fundamental Kernels

#### 'gaussian'
```matlab
filt = bct.Filter(domain, 'gaussian', ...
    'center', center_value, ...
    'sigma', bandwidth);
```

#### 'lowpass'
```matlab
filt = bct.Filter(domain, 'lowpass', 'cutoff', cutoff_value);
```

#### 'highpass'
```matlab
filt = bct.Filter(domain, 'highpass', 'cutoff', cutoff_value);
```

#### 'bandpass'
```matlab
filt = bct.Filter(domain, 'bandpass', ...
    'low', low_cutoff, ...
    'high', high_cutoff, ...
    'taper', true);  % Optional smooth transitions
```

#### 'notch'
```matlab
filt = bct.Filter(domain, 'notch', ...
    'center', center_value, ...
    'width', notch_width);
```

#### 'delta'
```matlab
filt = bct.Filter(domain, 'delta', 'x0', location);
```

### Special Kernels

#### 'separable' (Joint domains only)
```matlab
filt = bct.Filter(joint, 'separable', ...
    'spatial', spatial_filter, ...
    'temporal', temporal_filter);
```

#### 'wavepacket'
```matlab
filt = bct.Filter(joint, 'wavepacket', ...
    'velocity', group_velocity, ...
    'center_freq', center_frequency, ...
    'bandwidth', freq_bandwidth);
```

#### 'custom'
```matlab
filt = bct.Filter(domain, 'custom', 'kernel', kernel_values);
```

## Methods

### apply
Apply filter to signal.

```matlab
filtered_signal = filt.apply(original_signal);
```

**Parameters**:
- `original_signal`: bct.Signal object

**Returns**: bct.Signal object (filtered)

### evaluate
Get kernel values.

```matlab
kernel = filt.evaluate();
```

**Returns**: Array of filter weights

### plot
Visualize filter kernel.

```matlab
filt.plot();
filt.plot(Name, Value);
```

## Examples

### Spatial Smoothing
```matlab
spatial_filt = bct.Filter(B.Lambda, 'gaussian', ...
    'center', 0, 'sigma', 20);
smoothed = spatial_filt.apply(signal);
```

### Temporal Band-Pass
```matlab
alpha_filt = bct.Filter(B.Omega, 'bandpass', ...
    'low', 8, 'high', 12, 'taper', true);
alpha = alpha_filt.apply(signal);
```

### Joint Filtering
```matlab
joint = bct.Joint(B.Lambda, B.Omega);
joint_filt = bct.Filter(joint, 'gaussian', ...
    'center', [20, 10], 'sigma', [5, 2]);
result = joint_filt.apply(signal);
```

### Chain Filters
```matlab
% Apply multiple filters sequentially
sig1 = filter1.apply(signal);
sig2 = filter2.apply(sig1);
sig3 = filter3.apply(sig2);
```

## Performance Tips

1. **Use separable filters** for joint domains when possible
2. **Evaluate kernel once** if applying to multiple signals
3. **Prefer spectral domain** for spatial filtering (faster)

## See Also

- [Spatial Filters](../../filters/spatial.md)
- [Temporal Filters](../../filters/temporal.md)
- [Joint Filters](../../filters/joint-filters.md)
- [Fundamental Kernels Reference](../../concepts/overview.md)
