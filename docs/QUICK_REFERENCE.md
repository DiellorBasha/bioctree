# Quick Reference: Bct Signal Synthesis

## Three-Step Workflow

```matlab
% STEP 1: Design Filter
filt = B.designFilter([10, 50], 'wavelength', 'band', 'label', 'alpha');

% STEP 2: Synthesize Spectral Coefficients
B.Synthesize('alpha', 'envelope', 'gaussian', 't0', 1.0);

% STEP 3: Generate Signal
sig = B.Generate('label', 'alpha_wave');
```

## Method Signatures

### designFilter
```matlab
filt = B.designFilter(range, quantity, kernelType, 'param', value, ...)
```
**Quantities**: `'lambda'`, `'wavelength'`, `'wavenumber'`, `'freq'`  
**Kernels**: `'ideal'`, `'band'`, `'heat'`, `'mexican_hat'`  
**Params**: `'label'`, `'add'`, `'taper'`, `'time'`, etc.

### Synthesize
```matlab
B.Synthesize(filter_identifier, 'param', value, ...)
```
**Params**:
- `'numModes'` - Number of spatial modes
- `'envelope'` - `'none'` or `'gaussian'`
- `'t0'`, `'sigma_t'` - Envelope parameters
- `'velocity'` - Wave speed in mm/s (0 = standing)
- `'direction'` - Direction [x y z]

### Generate
```matlab
sig = B.Generate('param', value, ...)
```
**Params**:
- `'label'` - Signal label
- `'add'` - Add to B.Signals (default: true)
- `'symmetric'` - Force real output (default: true)

## Filter Management

```matlab
% List all filters
B.listFilters();

% Get filter
filt = B.getFilter('label');    % by label
filt = B.getFilter(3);          % by index

% Remove filter
B.removeFilter('label');
B.removeFilter(3);

% Clear all
B.clearFilterbank();
```

## Common Patterns

### Standing Wave
```matlab
B.designFilter([10, 50], 'wavelength', 'band', 'label', 'my_filter');
B.Synthesize('my_filter');  % velocity=0 by default
sig = B.Generate('label', 'my_signal');
```

### Traveling Wave
```matlab
B.designFilter([20, 40], 'wavelength', 'band', 'label', 'wave');
B.Synthesize('wave', 'velocity', 5, 'direction', [1 0 0]);
sig = B.Generate('label', 'traveling');
```

### Wave Packet
```matlab
B.designFilter([15, 35], 'wavelength', 'band', 'label', 'packet');
B.Synthesize('packet', ...
    'envelope', 'gaussian', ...
    't0', 1.0, ...          % center at 1s
    'sigma_t', 0.2);        % spread 0.2s
sig = B.Generate('label', 'packet_signal');
```

### Using Different Quantities
```matlab
% Wavelength (mm)
B.designFilter([10, 50], 'wavelength', 'band', 'label', 'f1');

% Wavenumber (rad/mm)
B.designFilter([0.1, 1.0], 'wavenumber', 'band', 'label', 'f2');

% Spatial frequency (cycles/mm)
B.designFilter([0.02, 0.15], 'freq', 'band', 'label', 'f3');

% Lambda (eigenvalue)
B.designFilter([0.01, 0.5], 'lambda', 'heat', 'label', 'f4', 'time', 1.0);
```

## Signal Access

```matlab
% After Generate:
sig = B.Signals(end);           % Last added signal
data = sig.Data;                % [N × T] matrix
time_series = data(vertex_idx, :);  % Time series at vertex
snapshot = data(:, time_idx);   % Spatial snapshot at time

% Signal properties
N = sig.N;                      % Number of vertices
T = sig.T;                      % Number of time points
label = sig.Label;              % Signal label
manifold = sig.Manifold;        % Reference to manifold
```

## Prerequisites

```matlab
% Bct object must have:
B.Manifold    % with eigendecomposition (U, λ, M)
B.Time        % with T and fs set

% Example setup:
B = bct('data.h5');
B.Time = bct.manifold.Time(500, 250);  % 500 samples at 250 Hz
```

## Spectral Grid Access

```matlab
% After Synthesize:
coeffs = B.SpectralGrid.coeffs;         % [K × T] spectral coefficients
lambdas = B.SpectralGrid.lambda_band;   % [K × 1] eigenvalues used
t = B.SpectralGrid.t;                   % [T × 1] time vector
filter_used = B.SpectralGrid.filter_used;       % Filter identifier
params = B.SpectralGrid.synthesis_params;       % Synthesis parameters
```

## Error Handling

All methods validate prerequisites and provide clear error messages:
- `'bct:NoManifold'` - Manifold not set
- `'bct:NoTime'` - Time not set
- `'bct:NoFilters'` - Filterbank empty
- `'bct:FilterNotFound'` - Invalid filter identifier
- `'bct:NoSpectralGrid'` - Call Synthesize first
- `'bct:NoCoefficients'` - No spectral coefficients

## Complete Example

```matlab
% Load data
B = bct('cortex.h5');
B.Time = bct.manifold.Time(1000, 500);  % 2s at 500 Hz

% Design alpha-band filter (8-12 Hz spatial equivalent)
% For 6mm wavelength at 10 Hz: λ ≈ 6mm
B.designFilter([5, 50], 'wavelength', 'band', ...
    'label', 'alpha_spatial', ...
    'taper', 'hann');

% Synthesize traveling wave packet
B.Synthesize('alpha_spatial', ...
    'envelope', 'gaussian', ...
    't0', 1.0, ...              % Center at 1 second
    'sigma_t', 0.15, ...        % 150ms spread
    'velocity', 8, ...          % 8 mm/s propagation
    'direction', [1 0 0], ...   % Anteroposterior
    'numModes', 150);           % Use 150 modes

% Generate signal
sig = B.Generate('label', 'alpha_traveling_wave', 'add', true);

% Visualize
fprintf('Signal: %s\n', sig.Label);
fprintf('Size: %d vertices × %d time points\n', sig.N, sig.T);
fprintf('Range: [%.4f, %.4f]\n', min(sig.Data(:)), max(sig.Data(:)));

% Plot time series at a vertex
figure; plot(B.Time.t, sig.Data(100, :));
xlabel('Time (s)'); ylabel('Amplitude');
title(sprintf('%s at vertex 100', sig.Label));
```
