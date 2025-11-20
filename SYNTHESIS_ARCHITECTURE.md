# Bct Signal Synthesis Architecture

## Overview

The Bct class now provides a complete workflow for synthesizing spatiotemporal signals on graph manifolds using spectral filtering. The synthesis follows a three-step pipeline:

1. **Filter Design** - Define spectral characteristics
2. **Synthesis** - Generate spectral coefficients
3. **Generation** - Reconstruct spatial-temporal signal

## Architecture Components

### 1. Filterbank Property
- **Type**: Array of `bct.filters.Filter` or `bct.filters.JointFilter` objects
- **Purpose**: Store multiple filter designs for different spectral bands
- **Access**: `B.Filterbank(i)` or via label using `B.getFilter('label')`

### 2. SpectralGrid Property
Enhanced to store:
- `lambda_grid` [K × T] - Eigenvalue grid
- `t_grid` [K × T] - Time grid  
- `lambda_band` [K × 1] - Eigenvalues used
- `t` [T × 1] - Time vector
- `coeffs` [K × T] - **NEW**: Spectral coefficients A_kl
- `filter_used` - Filter identifier used for synthesis
- `synthesis_params` - Parameters from Synthesize call

### 3. Filter Design Methods

#### designFilter(range, quantity, kernelType, ...)
Create spatial filters using different spectral quantities:
- **Quantities**: lambda, wavelength, wavenumber, freq
- **Kernels**: 'ideal', 'band', 'heat', 'mexican_hat'
- **Conversion**: Automatically converts to eigenvalues using `Manifold.Resolution`

```matlab
% Design bandpass for 10-50mm wavelengths
filt = B.designFilter([10, 50], 'wavelength', 'band', 'taper', 'hann');

% Design using wavenumber
filt = B.designFilter([0.1, 1], 'wavenumber', 'band');

% Design heat diffusion
filt = B.designFilter([0.01, 0.5], 'lambda', 'heat', 'time', 1.0);
```

#### designJointFilter(spatial_range, spatial_quantity, temporal_range, temporal_quantity, ...)
Create joint mesh-time filters:
- **Types**: 'diffusion', 'wave', 'separable'
- **Uses**: `bct.filters.design.diffusion`, `.wave`, `.separable`

```matlab
% Alpha band diffusion: 10-50mm, 8-12 Hz
filt = B.designJointFilter([10, 50], 'wavelength', [8, 12], 'frequency', ...
    'type', 'diffusion', 'label', 'alpha_diffusion');
```

### 4. Synthesis Method

#### Synthesize(filter_identifier, ...)
Generate spectral coefficients A_kl based on filter specifications.

**Process:**
1. Extract filter's lambda_band and freq_band (if joint)
2. Build SpectralGrid with appropriate modes
3. Compute spatial power P_space(k) from filter kernel g(λ)
4. Compute temporal power P_time(l) from freq_band
5. Create joint power: P_joint = P_space ⊗ P_time
6. Generate random phases: A_kl = √P_joint · exp(iφ)
7. Apply temporal envelope (optional)
8. Apply traveling wave phase shifts (optional)

**Parameters:**
- `'envelope'` - 'none' or 'gaussian' for wave packets
- `'t0'`, `'sigma_t'` - Gaussian envelope parameters
- `'velocity'` - Traveling wave speed (mm/s), 0 = standing wave
- `'direction'` - Wave propagation direction [x y z]
- `'numModes'` - Override auto mode selection

```matlab
% Standing wave with Gaussian envelope
B.Synthesize('alpha_band', 'envelope', 'gaussian', 't0', 1.0, 'sigma_t', 0.2);

% Traveling wave at 5 mm/s in X direction
B.Synthesize('beta_band', 'velocity', 5, 'direction', [1 0 0]);
```

### 5. Generation Method

#### Generate(...)
Reconstruct spatial-temporal signal from spectral coefficients.

**Process (follows synth_mesh_timesignal.m lines 103-113):**
1. **Inverse temporal FFT**: A_kl [K × T] → A_time [K × T]
   ```matlab
   A_time = ifft(A_kl, [], 2, 'symmetric');
   ```

2. **Inverse graph Fourier**: A_time → x_wt [N × T]
   ```matlab
   x_wt = U * A_time;  % U: [N × K] eigenvectors
   ```

3. **Mass normalization**: Apply M^(1/2)
   ```matlab
   S = spdiags(sqrt(d), 0, N, N);
   xrec = S * x_wt;
   ```

**Returns**: `bct.signal.Signal` object with data [N × T]

**Parameters:**
- `'label'` - Signal label (default: auto-generated)
- `'add'` - Add to B.Signals (default: true)
- `'symmetric'` - Force real output via symmetric IFFT (default: true)

```matlab
sig = B.Generate('label', 'my_wave', 'add', true);
% Access: sig.Data [N × T], sig.Label, sig.Manifold
```

## Complete Workflow Example

```matlab
% Setup
B = bct('data.h5');
B.Time = bct.manifold.Time(500, 250);  % 2s at 250 Hz

% Design alpha-band spatial filter (10-50mm wavelength)
filt = B.designFilter([10, 50], 'wavelength', 'band', ...
    'label', 'alpha', 'taper', 'hann');

% Synthesize traveling wave packet
B.Synthesize('alpha', ...
    'envelope', 'gaussian', ...
    't0', 1.0, ...
    'sigma_t', 0.2, ...
    'velocity', 5, ...
    'direction', [1 0 0]);

% Generate signal
sig = B.Generate('label', 'alpha_wave');

% Signal is now available
fprintf('Generated %d × %d signal\n', sig.N, sig.T);
plot(sig.Data(1, :));  % Time series at vertex 1
```

## Filter Management

```matlab
% List all filters
B.listFilters();

% Get filter by label or index
filt = B.getFilter('alpha');
filt = B.getFilter(2);

% Remove filter
B.removeFilter('beta');
B.removeFilter(3);

% Clear all filters
B.clearFilterbank();
```

## Implementation Details

### Quantity Conversions
Uses `Manifold.Resolution` object for conversions:
- **wavelength → lambda**: `res.wavelength2lambda(range)`
- **wavenumber → lambda**: `res.k2lambda(range)`  
- **freq → lambda**: `res.freq2lambda(range)`

### Helper Functions (private)
- `convertQuantityString(str)` - String to enum conversion
- `convertToLambda(range, quantity)` - Convert any spatial quantity to λ
- `convertToFrequency(range, quantity)` - Convert temporal quantity to Hz

### Spectral Grid Structure
After `buildSpectralGrid([λmin, λmax])`:
- Selects modes where λmin ≤ λ ≤ λmax
- Creates joint grid using `ndgrid(λ_vec, t_vec)`
- Rows = spatial modes, Columns = time points

After `Synthesize`:
- Adds `coeffs` field with A_kl [K × T]
- Stores filter_used and synthesis_params for traceability

## Dependencies

- **bct.manifold.Manifold** - Graph/mesh structure with eigendecomposition
- **bct.manifold.Time** - Time parameters (T, fs)
- **bct.filters.Filter** - Spatial filter design
- **bct.filters.JointFilter** - Joint mesh-time filters
- **bct.resolution.Quantity** - Enum for spectral quantities
- **bct.signal.Signal** - Signal container

## References

- Spectral synthesis based on `bct.sim.synth_mesh_timesignal`
- Filter design uses `bct.filters.Filter.setBand()` and `.design()`
- Reconstruction follows inverse graph Fourier transform
- Mass normalization via M^(1/2) for proper signal scaling
