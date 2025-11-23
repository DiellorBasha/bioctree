# Signal Synthesis Architecture - New Design

## Overview

The signal synthesis system has been completely overhauled to follow **separation of concerns** and standard signal processing principles. The old monolithic `Synthesize` and `Generate` methods have been replaced with a modular architecture.

## Core Principle: Impulse Response

**In signal processing, a linear filter is fully characterized by its response to an impulse (Kronecker delta).**

The delta signal is 1 at a specific location and 0 everywhere else:
```matlab
δ(v) = { 1  if v = v0
       { 0  otherwise
```

## Architecture: Separation of Concerns

### 1. **Domain Classes Own Transforms**

Each domain has a `transform` property that handles conversion to/from its dual:

| Domain | Dual | Transform | Implementation |
|--------|------|-----------|----------------|
| **Manifold** ↔ **Lambda** | Graph Laplacian eigendecomposition | `MFT` / `IMFT` | `bct.factory.transforms.MFT/IMFT` |
| **Time** ↔ **Omega** | Temporal Fourier transform | `FFT` / `IFFT` | `bct.factory.transforms.FFT/IFFT` |

**Key APIs:**
```matlab
% Manifold -> Lambda (forward)
spectral_coeffs = B.Manifold.transform.forward(spatial_signal);

% Lambda -> Manifold (inverse)
spatial_signal = B.Lambda.transform.inverse(spectral_coeffs);

% Time -> Omega (forward)
freq_coeffs = B.Time.transform.forward(time_series);

% Omega -> Time (inverse)
time_series = B.Omega.transform.inverse(freq_coeffs);
```

**Design Note:** Transforms are initialized when dual domains are created and eigenbasis is computed.

### 2. **Filter Classes Define Kernels**

Filters evaluate kernels on domain grids without handling transforms or signals:

```matlab
designer = bct.filters.FilterDesigner(B);

% Spatial filter (Lambda domain)
filt = designer.lambda('heat', 'tau', 0.1);
H = filt.evaluate();  % Returns filter response on Lambda.axis

% Temporal filter (Omega domain)  
filt = designer.omega('gaussian', 'center', 20*2*pi, 'sigma', 5*2*pi);
H = filt.evaluate();  % Returns filter response on Omega.axis

% Joint filter (Lambda × Omega)
filt = designer.joint('gabor', 'center_x', 0.2, 'sigma_x', 0.05, ...
                      'center_y', 40*2*pi, 'sigma_y', 10*2*pi);
H = filt.evaluate();  % Returns [M×N] on Joint grid
```

**Responsibility:** Filters ONLY evaluate kernels. No transforms, no signal manipulation.

### 3. **Signal Classes Create and Hold Data**

The `Signal` class manages actual spatiotemporal data:

#### **Creating Delta (Impulse) Signals**

```matlab
% Spatial delta at vertex v0
delta = bct.Signal.createDelta(B.Manifold, v0);
% Result: [N×1] with delta.Data(v0) = 1

% Spatiotemporal delta at (v0, t0)
delta = bct.Signal.createDelta(B.Manifold, v0, B.Time, t0);
% Result: [N×T] with delta.Data(v0, t0) = 1

% Spatial delta constant across time
delta = bct.Signal.createDelta(B.Manifold, v0, B.Time);
% Result: [N×T] with delta.Data(v0, :) = 1
```

#### **Applying Filters with Transform**

```matlab
% Apply filter: source domain -> filter domain -> destination domain
filtered = signal.applyFilter(filter_obj, domain_src, domain_dst);
```

**Internal workflow:**
1. Forward transform: `coeffs = domain_src.transform.forward(signal.Data)`
2. Filter: `filtered_coeffs = coeffs .* filter.evaluate()`
3. Inverse transform: `result = domain_dst.transform.inverse(filtered_coeffs)`

**Responsibility:** Signals hold data and coordinate filtering workflows.

### 4. **BCT Orchestrates the Workflow**

Top-level convenience methods for common workflows:

```matlab
% Create impulse (convenience wrapper)
delta = B.createImpulse(v0);           % Spatial
delta = B.createImpulse(v0, t0);       % Spatiotemporal

% High-level synthesis
response = B.synthesizeFilteredSignal(filter, input_signal);
```

**Responsibility:** BCT manages domain relationships and provides high-level API.

## Workflow Examples

### Example 1: Spatial Filter Impulse Response

```matlab
% Setup
B = bct.bct();
B.Manifold = bct.Manifold(vertices, faces);
B = B.computeEigenbasis(100);

% Create impulse
delta = B.createImpulse(50);  % Impulse at vertex 50

% Create spatial filter
designer = bct.filters.FilterDesigner(B);
filt = designer.lambda('heat', 'tau', 0.1);

% Apply filter using transforms
response = delta.applyFilter(filt, B.Manifold, B.Lambda);
% Workflow: Manifold --(MFT)--> Lambda --(filter)--> Lambda --(IMFT)--> Manifold

% Visualize
B.showSignal(response);
```

### Example 2: Temporal Bandpass Filter

```matlab
% Setup time domain
B.Time = bct.Time(0:0.01:2, 100);

% Create temporal impulse (constant spatial, delta temporal)
delta = B.createImpulse(100, 50);  % Vertex 100, time index 50

% Create bandpass filter (alpha band: 8-12 Hz)
filt = designer.temporal('gaussian', ...
    'center', 10*2*pi, ...   % 10 Hz center
    'sigma', 2*2*pi);        % 2 Hz bandwidth

% Apply filter
response = delta.applyFilter(filt, B.Time, B.Omega);
% Workflow: Time --(FFT)--> Omega --(filter)--> Omega --(IFFT)--> Time
```

### Example 3: Joint Spatiotemporal Filter

```matlab
% Create joint domain
B = B.createJoint('Lambda', 'Omega');

% Create Gabor filter (traveling wave selector)
filt = designer.joint('gabor', ...
    'center_x', 0.3,      % k0 = 0.3 rad/mm (wavelength ~21 mm)
    'sigma_x', 0.05, ...  % Spatial bandwidth
    'center_y', 15*2*pi, ... % f0 = 15 Hz
    'sigma_y', 3*2*pi);   % Temporal bandwidth

% Evaluate filter (for visualization)
H = filt.evaluate();  % [M×N] on Lambda×Omega grid

% Note: Joint filtering requires 2D transforms (future work)
% For now, use separable filtering:
%   1. Apply spatial filter
%   2. Apply temporal filter
```

## Comparison: Old vs New

### OLD (Deprecated)

```matlab
% Monolithic, unclear responsibilities
B.Synthesize(FilterHandle, [], 'Lambda', 'Omega');
sig = B.Generate('coeffs', coeffs, 'method', 'spectral');
```

**Problems:**
- Mixed concerns (transforms + filtering + signal generation)
- Hard to test individual components
- Unclear which domain owns what
- Difficult to extend

### NEW (Current)

```matlab
% Clear separation of concerns
delta = B.createImpulse(v0);
filt = designer.lambda('heat', 'tau', 0.1);
response = delta.applyFilter(filt, B.Manifold, B.Lambda);
```

**Benefits:**
- Each class has ONE responsibility
- Easy to test (mock transforms, filters independently)
- Domain transforms are reusable
- Follows signal processing conventions
- Extensible (add new transforms/filters without breaking existing code)

## Class Responsibilities Summary

| Class | Owns | Responsibility | No Access To |
|-------|------|----------------|--------------|
| **Domain** | `.transform` property | Convert to/from dual domain | Filters, Signals |
| **Filter** | `.evaluate()` method | Kernel evaluation on domain grid | Transforms, Signals |
| **Signal** | `.Data`, `.createDelta()` | Hold data, create impulses, coordinate filtering | Direct transform calls (delegates to Domain) |
| **BCT** | Domain management | Orchestrate workflow, convenience API | Filter internals |

## Transform Initialization

Transforms are automatically initialized when:

1. **Lambda domain created** (as Manifold's dual)
   - Manifold.transform = `MFT` (forward: space → spectral)
   - Lambda.transform = `IMFT` (inverse: spectral → space)
   
2. **Eigenbasis computed** via `B.computeEigenbasis(k)`
   - Fills `Lambda.lambda` (eigenvalues)
   - Fills `Lambda.U` (eigenvectors)
   - Enables MFT/IMFT transforms

3. **Omega domain created** (as Time's dual)
   - Time.transform = `FFT` (forward: time → frequency)
   - Omega.transform = `IFFT` (inverse: frequency → time)

**Check transform availability:**
```matlab
if isempty(B.Manifold.transform)
    % Need to compute eigenbasis first
    B = B.computeEigenbasis(100);
end
```

## Future Extensions

### 2D Transforms for Joint Domain

Currently, Joint filtering requires manual 2D transform implementation:

```matlab
% Future API (when 2D transforms implemented):
delta_st = B.createImpulse(v0, t0);  % Spatiotemporal delta
filt_joint = designer.joint('gabor', ...);
response = delta_st.applyFilter(filt_joint, B.Joint, B.Joint);
```

**Implementation needs:**
- 2D MFT (spatial eigenbasis ⊗ temporal FFT)
- Proper tensor product handling
- Efficient computation for large grids

### Additional Filters

Easy to add new kernels in `bct.filters.kernels`:\n- `mexican_hat` ✅ (already implemented)
- `morlet_wavelet` (for time-frequency analysis)
- `von_mises` (for directional filtering)
- `anisotropic_diffusion` (for edge-preserving smoothing)

### Signal Types

Easy to extend Signal class:
- Vector-valued signals (already supported: `[N×3]`, `[N×T×3]`)
- Complex-valued signals (for phase information)
- Tensor signals (stress, strain fields)

## Code Examples

See complete working examples:
- `examples/example_signal_synthesis_workflow.m` - Full demonstration
- `test_filter_designer_system.m` - Filter system testing
- `example_bct_filter_workflow.m` - Filter creation and evaluation

## Migration Guide

### If you were using `B.Synthesize(...)`:

**Before:**
```matlab
B.Synthesize(FilterHandle, SignalHandle, 'Lambda', 'Omega');
```

**After:**
```matlab
% Create filter explicitly
designer = bct.filters.FilterDesigner(B);
filt = designer.spatial('your_kernel', 'param', value);

% Create input signal (or use impulse)
input_sig = B.createImpulse(vertex_index);

% Apply filter
output_sig = B.synthesizeFilteredSignal(filt, input_sig);
```

### If you were using `B.Generate(...)`:

**Before:**
```matlab
sig = B.Generate('coeffs', coeffs, 'domain', 'Lambda');
```

**After:**
```matlab
% Coefficients are in spectral domain (Lambda)
% Use inverse transform to get spatial signal
spatial_data = B.Lambda.transform.inverse(coeffs);

% Wrap in Signal object
sig = bct.Signal(B.Manifold, spatial_data, 'Generated Signal');
```

## Testing

Test each component independently:

```matlab
% Test Domain transforms
x_spatial = randn(B.Manifold.N, 1);
x_spectral = B.Manifold.transform.forward(x_spatial);
x_reconstructed = B.Lambda.transform.inverse(x_spectral);
assert(norm(x_spatial - x_reconstructed) < 1e-10, 'Transform roundtrip failed');

% Test Filter evaluation
filt = designer.lambda('heat', 'tau', 0.1);
H = filt.evaluate();
assert(all(H >= 0) && all(H <= 1), 'Heat kernel must be in [0,1]');

% Test Signal delta creation
delta = bct.Signal.createDelta(B.Manifold, 50);
assert(sum(delta.Data) == 1, 'Delta sum must equal 1');
assert(delta.Data(50) == 1, 'Delta must be 1 at impulse vertex');
```

## References

- Filter class: `toolbox/+bct/+filters/Filter.m`
- Signal class: `toolbox/+bct/@Signal/Signal.m`
- Domain class: `toolbox/+bct/@Domain/Domain.m`
- Transform factory: `toolbox/+bct/+factory/+transforms/`
- BCT orchestration: `toolbox/+bct/@bct/bct.m`
