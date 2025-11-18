# Manifold Resolution Property

## Overview

The `Resolution` property provides convenient access to spatial resolution metrics computed from the manifold's maximum eigenvalue. This tells you the finest spatial detail that the mesh can represent.

## Property Definition

```matlab
properties (Dependent)
    Resolution  % struct with: lambda_max, k (wavenumber), freq, wavelength
end
```

## Usage

### Basic Access

```matlab
% After computing eigenvalues
B.Manifold.meshFourier(600);

% Get resolution
R = B.Manifold.Resolution;

fprintf('Minimum wavelength: %.2f mm\n', R.wavelength);
```

### Resolution Fields

The `Resolution` struct contains:

| Field | Description | Units |
|-------|-------------|-------|
| `lambda_max` | Maximum eigenvalue | 1/units² |
| `k` | Angular wavenumber | rad/units |
| `freq` | Spatial frequency | cycles/units |
| `wavelength` | Minimum wavelength | units |

### Units

Units depend on the coordinate system of `Manifold.V`:
- If vertices in meters → wavelength in meters
- If vertices in mm → wavelength in mm
- FreeSurfer surfaces typically in mm

## Implementation Details

### Dependent Property

`Resolution` is a **dependent property** that:
- Computes values on-the-fly when accessed
- Does not store values (always fresh)
- Updates automatically when eigenvalues change

### Computation

```matlab
function R = get.Resolution(obj)
    if isempty(obj.Eigenvalues)
        % Return empty struct
        R = struct('lambda_max', [], 'k', [], 'freq', [], 'wavelength', []);
        return;
    end
    
    % Get max eigenvalue from cached basis
    lambda_max = bct.manifold.maxLambda(obj, 'basis');
    
    % Convert to resolution metrics
    k = sqrt(lambda_max);           % Angular wavenumber
    freq = k / (2*pi);              % Spatial frequency
    wavelength = 1 / freq;          % Wavelength
    
    R = struct('lambda_max', lambda_max, 'k', k, 'freq', freq, 'wavelength', wavelength);
end
```

### Dependencies

Uses:
- `bct.manifold.maxLambda(M, 'basis')` - Gets maximum eigenvalue
- `obj.Eigenvalues` - Cached eigenvalues from `meshFourier`

## Examples

### Example 1: Check Resolution

```matlab
B = bct.io.import.mesh('lh.pial');
B.Manifold.meshFourier(600);

R = B.Manifold.Resolution;

fprintf('Mesh can resolve features down to %.2f mm\n', R.wavelength);
% Output: Mesh can resolve features down to 2.34 mm
```

### Example 2: Design Signals Within Resolution

```matlab
% Get resolution
R = B.Manifold.Resolution;

% Design signal at 50% of max resolution (safe margin)
safe_wavelength = 2 * R.wavelength;
safe_freq = 1 / safe_wavelength;

% Create narrowband signal
spec.type = 'narrowband';
spec.f0 = safe_freq;
spec.bw_abs = safe_freq * 0.1;

B = bct.sim.synth_mesh_signal(B, spec);
```

### Example 3: Compare Mesh Quality

```matlab
subjects = {'sub-001', 'sub-002', 'sub-003'};

for i = 1:length(subjects)
    path = sprintf('data/%s/surf/lh.pial', subjects{i});
    B = bct.io.import.mesh(path);
    B.Manifold.meshFourier(600);
    
    R = B.Manifold.Resolution;
    fprintf('%s: %.2f mm resolution\n', subjects{i}, R.wavelength);
end

% Output:
% sub-001: 2.31 mm resolution
% sub-002: 2.45 mm resolution  ← Coarser mesh
% sub-003: 2.28 mm resolution
```

### Example 4: Validate Simulation Parameters

```matlab
% Check if target frequency is within mesh resolution
target_freq = 0.5;  % cycles/mm

R = B.Manifold.Resolution;

if target_freq > R.freq
    warning('Target frequency %.2f exceeds mesh resolution %.2f cycles/mm', ...
        target_freq, R.freq);
else
    fprintf('Target frequency within mesh capabilities ✓\n');
end
```

## Before Eigenvalues Computed

If eigenvalues haven't been computed yet, `Resolution` returns empty fields:

```matlab
B = bct.io.import.mesh('lh.pial');

R = B.Manifold.Resolution;
% R.lambda_max = []
% R.wavelength = []

% Compute eigenvalues first
B.Manifold.meshFourier(600);

R = B.Manifold.Resolution;
% Now populated:
% R.lambda_max = 0.182
% R.wavelength = 2.34
```

## Relationship to Other Functions

### vs. bct.manifold.maxLambda

```matlab
% These are equivalent:
lambda1 = B.Manifold.Resolution.lambda_max;
lambda2 = bct.manifold.maxLambda(B.Manifold, 'basis');

assert(lambda1 == lambda2);
```

### vs. bct.manifold.resolution

```matlab
% Property access (convenient)
R1 = B.Manifold.Resolution;

% Function call (more flexible)
R2 = bct.manifold.resolution(B.Manifold, 'manifold', 'basis');

% Same result:
assert(R1.lambda_max == R2.lambda);
assert(R1.wavelength == R2.wavelength);
```

The property is more convenient for quick access, while the function offers more options (e.g., 'full' scope for full Laplacian eigenvalues).

## Physical Interpretation

### What does "resolution" mean?

The **wavelength** tells you the **smallest spatial pattern** the mesh can accurately represent.

- **Smaller wavelength** = finer resolution = can represent more detail
- **Larger wavelength** = coarser resolution = limited detail

### Nyquist-like limit

Just like temporal sampling has a Nyquist frequency (fs/2), meshes have a spatial Nyquist limit determined by:
1. Vertex spacing
2. Laplacian eigenvalues
3. Number of modes computed

The `Resolution.wavelength` represents this spatial Nyquist limit.

### Rule of thumb

For reliable signal representation, target wavelengths should be:
- **2× to 3× larger** than `Resolution.wavelength`
- This provides safety margin for accurate representation

```matlab
R = B.Manifold.Resolution;

% Conservative target
safe_wavelength = 3 * R.wavelength;

fprintf('Use wavelengths >= %.2f mm for reliable results\n', safe_wavelength);
```

## See Also

- `bct.manifold.maxLambda` - Get maximum eigenvalue
- `bct.manifold.resolution` - Convert between lambda/freq/wavelength
- `Manifold.meshFourier` - Compute eigenvalues
- `bct.sim.synth_mesh_signal` - Generate signals with spectral control
