# bct.spectral Package

Spectral analysis tools for time-varying signals on manifolds.

## Overview

The `bct.spectral` package provides tools for analyzing time-varying signals defined on triangulated surfaces using joint time-vertex spectral analysis. This extends classical Fourier analysis to signals living on manifolds, enabling analysis of both spatial (eigenmode) and temporal (frequency) structure.

## Core Concept

For a time-varying signal $X(v,t)$ defined on a manifold with $N$ vertices and $T$ time samples:

1. **Spatial basis**: Eigenvectors $U$ of the Laplace-Beltrami operator
2. **Temporal basis**: Fourier basis (DFT)
3. **Joint transform**: $\hat{X}(k,f) = U^T M X \cdot \text{FFT}$

Where:
- $k$ indexes eigenmodes (spatial frequencies)
- $f$ indexes temporal frequencies  
- $M$ is the mass matrix (for proper inner products)

This produces a 2D spectrum showing energy distribution in $(\lambda, \omega)$ space, where $\lambda$ represents eigenvalue (spatial scale) and $\omega$ represents temporal frequency.

## Functions

### Core Analysis

- **`jointSpectrum(M, F, options)`** - Compute joint lambda-omega spectrum
- **`plotJointSpectrum(spec, options)`** - Visualize joint spectrum

### Signal Generation

- **`generateTestSignal(M, components, t)`** - Generate signals with discrete spectral components
- **`generateBandedSignal(M, bands, t)`** - Generate signals with eigenmode and frequency bands (more realistic)
- **`makeBands(eigen, specs)`** - Helper to create band specifications from eigenvalue or eigenmode ranges

#### When to Use Each

**Discrete (`generateTestSignal`)**: For testing and validation
- Simple, well-defined spectral signature
- Good for verifying analysis pipeline
- Each component at exact eigenmode-frequency pair

**Banded (`generateBandedSignal`)**: For realistic simulations
- Distributed energy across eigenmode and frequency ranges
- Better models neural activity (alpha/beta/gamma bands)
- Gaussian amplitude distribution within bands

**makeBands Helper**: Simplifies band specification
- Specify by **eigenvalue range** (physically meaningful spatial scales)
- OR by **eigenmode indices** (direct)
- Converts eigenvalue → eigenmode automatically
- Validates and returns band structs for `generateBandedSignal`

### Typical Workflow

```matlab
% 1. Load manifold and compute eigenmodes
M = bct.data.load('Id', 'fsaverage_rh_pial');
eigen = M.eigenmodes(500);

% 2. Create or load time-varying signal
fs = 100; T = 10; nT = fs*T;
t = (0:1/fs:T-1/fs)';
X = randn(M.numVertices(), nT);  % Or your actual data

% 3. Make Field
F = bct.field.make('support', 'vertex', 'valueType', 'scalar', ...
                   'value', X, 'time', struct('t0', 0, 'dt', 1/fs, 'unit', 's'));

% 4. Compute joint spectrum
spec = bct.spectral.jointSpectrum(M, F);

% 5. Visualize
bct.spectral.plotJointSpectrum(spec, 'Scale', 'log');
```

## Input Requirements

### For `jointSpectrum`

- **Manifold**: Must have precomputed eigenmodes via `M.eigenmodes(K)`
- **Field**: Must be:
  - Time-varying (`bct.field.isTimeVarying(F) == true`)
  - Scalar valued (`valueType == 'scalar'`)
  - Vertex support (`support == 'vertex'`)
  - Valid time metadata (`F.time` struct with `t0`, `dt`, `unit`)

### For `plotJointSpectrum`

- Valid spectrum struct from `jointSpectrum`

## Output Structure

The `jointSpectrum` function returns a struct with:

```matlab
spectrum
├── magnitude         [K×F] - Magnitude spectrum
├── complex          [K×F] - Complex spectrum (if requested)
├── eigenvalues      [K×1] - Eigenvalues used
├── frequencies      [1×F] - Frequency axis (Hz)
├── eigenmodeAxis    [K×1] - Eigenmode indices
├── powerEigen       [K×1] - Marginal power (over frequencies)
├── powerFreq        [1×F] - Marginal power (over eigenmodes)
├── numEigenmodes    scalar - Number of eigenmodes K
├── numFrequencies   scalar - Number of frequencies F
├── samplingFreq     scalar - Temporal sampling rate (Hz)
├── timeStep         scalar - Temporal resolution (s)
└── numTimeSamples   scalar - Number of time samples
```

## Examples

### Basic Joint Spectrum

```matlab
M = bct.data.load('Id', 'fsaverage_rh_pial');
eigen = M.eigenmodes(1000);

% Generate signal
fs = 100; T = 10;
t = (0:1/fs:T-1/fs)';
X = bct.spectral.generateTestSignal(M, [100, 10.0, 1.0], t);  % Eigenmode 100, 10 Hz

% Create field
F = bct.field.make('support', 'vertex', 'valueType', 'scalar', ...
                   'value', X, 'time', struct('t0', 0, 'dt', 1/fs, 'unit', 's'));

% Analyze
spec = bct.spectral.jointSpectrum(M, F);
bct.spectral.plotJointSpectrum(spec);
```

### Custom Parameters

```matlab
% Use only first 500 eigenmodes, higher FFT resolution
spec = bct.spectral.jointSpectrum(M, F, ...
    'NumEigenmodes', 500, ...
    'TemporalFFT', 2048, ...
    'ReturnComplex', true);

% Focused visualization
bct.spectral.plotJointSpectrum(spec, ...
    'FreqRange', [0 50], ...
    'EigenRange', [1 300], ...
    'Scale', 'db', ...
    'MarkPeaks', true, ...
    'NumPeaks', 10);
```

### Multi-Component Signal

```matlab
% Define components: [eigenmode, frequency, amplitude]
components = [
    50,   5.0,  1.0;
    200, 10.0,  0.8;
    500, 15.0,  0.6;
];

U = M.eigenmodes(1000).eigenvectors.value;
X = zeros(M.numVertices(), length(t));

for i = 1:size(components, 1)
    spatial = U(:, components(i,1));
    temporal = components(i,3) * cos(2*pi*components(i,2)*t);
    X = X + spatial * temporal';
end

F = bct.field.make('support', 'vertex', 'valueType', 'scalar', ...
                   'value', X, 'time', struct('t0', 0, 'dt', 1/fs, 'unit', 's'));

spec = bct.spectral.jointSpectrum(M, F);
bct.spectral.plotJointSpectrum(spec, 'MarkPeaks', true);
```

### Banded Signal (Realistic Brain Activity)

```matlab
% Define spectral-temporal bands (more realistic for neural data)
bands(1).eigenmodeRange = [1, 100];      % Low spatial freq
bands(1).freqRange = [8, 12];            % Alpha band
bands(1).amplitude = 1.0;

bands(2).eigenmodeRange = [150, 300];    % Mid spatial freq
bands(2).freqRange = [15, 30];           % Beta band
bands(2).amplitude = 0.7;

bands(3).eigenmodeRange = [400, 700];    % High spatial freq
bands(3).freqRange = [30, 50];           % Low gamma
bands(3).amplitude = 0.5;

% Generate signal with random components within each band
X = bct.spectral.generateBandedSignal(M, bands, t, 'NumComponents', 15);

F = bct.field.make('support', 'vertex', 'valueType', 'scalar', ...
                   'value', X, 'time', struct('t0', 0, 'dt', 1/fs, 'unit', 's'));

spec = bct.spectral.jointSpectrum(M, F);
bct.spectral.plotJointSpectrum(spec, 'Layout', 'full');
```

### Using makeBands Helper (Recommended)

```matlab
% Get eigenmode structure
eigen = M.eigenmodes(1000);

% Specify bands by EIGENVALUE (physically meaningful spatial scales)
specs(1).eigenvalueRange = [0, 0.01];     % Large spatial scales (global patterns)
specs(1).freqRange = [8, 12];             % Alpha band
specs(1).amplitude = 1.0;

specs(2).eigenvalueRange = [0.01, 0.05];  % Mid spatial scales (regional)
specs(2).freqRange = [15, 30];            % Beta band  
specs(2).amplitude = 0.7;

specs(3).eigenvalueRange = [0.05, 0.15];  % Small spatial scales (local)
specs(3).freqRange = [30, 50];            % Low gamma
specs(3).amplitude = 0.5;

% Convert to band structs (eigenvalue → eigenmode mapping)
bands = bct.spectral.makeBands(eigen, specs);
% Displays summary table showing eigenvalue → eigenmode → frequency mapping

% Generate signal
X = bct.spectral.generateBandedSignal(M, bands, t, 'NumComponents', 15);

F = bct.field.make('support', 'vertex', 'valueType', 'scalar', ...
                   'value', X, 'time', struct('t0', 0, 'dt', 1/fs, 'unit', 's'));

spec = bct.spectral.jointSpectrum(M, F);
bct.spectral.plotJointSpectrum(spec, 'Layout', 'full');
```

**Why use eigenvalue ranges?**
- More physically meaningful (eigenvalue ∝ spatial scale)
- Transferable across different meshes  
- Easier to interpret (λ=0.01 means similar scale on any mesh)
- Standard in spectral graph theory literature

## Applications

### Neuroimaging
- Analyzing MEG/EEG source activity on cortical surface
- Time-frequency analysis of fMRI signals on surfaces
- Oscillatory dynamics in brain networks

### General Surface Dynamics
- Wave propagation on deformable surfaces
- Reaction-diffusion systems on manifolds
- Spatiotemporal pattern formation

## Technical Notes

### Normalization
- Eigenvectors are M-orthonormal: $U^T M U = I$
- FFT normalized by $1/\sqrt{N_{FFT}}$ when `Normalize=true`
- Power spectra use $|X_{hat}|^2$

### Computational Complexity
- Graph Fourier Transform: $O(K \cdot N \cdot T)$
- Temporal FFT: $O(K \cdot T \log T)$
- Total: $O(K \cdot N \cdot T + K \cdot T \log T)$

### Memory Requirements
For $N$ vertices, $K$ eigenmodes, $T$ time samples:
- Eigenvectors: $N \times K$ double (primary cost)
- Signal: $N \times T$ double
- Spectrum: $K \times T$ complex
- Typical: ~8MB per 10K vertices × 100 modes × 1000 samples

## See Also

- `bct.filter` - Spectral filtering
- `bct.Manifold.eigenmodes` - Eigenmode computation
- `bct.field` - Field abstraction
- External: GSPBox `gsp_jft` (Graph Signal Processing Toolbox)

## References

1. Shuman, D. I., et al. (2013). "The emerging field of signal processing on graphs." *IEEE Signal Processing Magazine*.
2. Grassi, F., Loukas, A., Perraudin, N., & Ricaud, B. (2017). "A time-vertex signal processing framework." *IEEE Transactions on Signal Processing*.
