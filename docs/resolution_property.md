# Manifold Resolution Property

## Overview

The `Resolution` property provides convenient access to spatial resolution metrics computed from the manifold's **full maximum eigenvalue**. This represents the true Nyquist limit of the mesh geometry and tells you the finest spatial detail that the mesh can represent.

Unlike the computed basis (e.g., 600 modes), which gives a partial view, the Resolution property uses the **full maximum eigenvalue** computed via `eigs` on the complete Laplacian operator.

## Property Definition

```matlab
properties (Dependent)
    Resolution  % struct with: lambda_max, k (wavenumber), freq, wavelength
end
```

## Automatic Computation

**Resolution is automatically computed when you create a mesh Manifold:**

```matlab
% Resolution is populated immediately upon import
B = bct.io.import.mesh('path/to/mesh.pial');
R = B.Manifold.Resolution;  % Already available!

fprintf('Minimum wavelength: %.2f mm\n', R.wavelength);
```

During construction, `meshFourier(0)` is called automatically to:
- Compute Laplacian and MassMatrix
- Compute full maximum eigenvalue (for Resolution)
- Skip eigenmode computation (no k modes yet)

### Computing Eigenmodes

To perform frequency analysis, call `meshFourier(k)` with desired modes:

```matlab
% Compute 600 eigenmodes for spectral analysis
B.Manifold.meshFourier(600);

% Resolution remains the same (already computed during construction)
R = B.Manifold.Resolution;
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
- Uses the **full maximum eigenvalue** cached during `meshFourier()`
- Represents the true mesh resolution, not limited by computed modes

### Computation

The Resolution property getter checks for cached `lambda_max_full`:

```matlab
function R = get.Resolution(obj)
    % Check if full max lambda is cached
    if ~isfield(obj.Cache, 'lambda_max_full') || isempty(obj.Cache.lambda_max_full)
        R = struct('lambda_max', [], 'k', [], 'freq', [], 'wavelength', []);
        return;
    end
    
    % Get FULL maximum eigenvalue
    lambda_max = obj.Cache.lambda_max_full;
    
    % Convert to resolution metrics
    k = sqrt(lambda_max);           % Angular wavenumber
    freq = k / (2*pi);              % Spatial frequency
    wavelength = 1 / freq;          % Wavelength
    
    R = struct('lambda_max', lambda_max, 'k', k, 'freq', freq, 'wavelength', wavelength);
end
```

The full maximum eigenvalue is computed during `meshFourier()` using `eigs` on the normalized Laplacian:

```matlab
% In meshFourier():
N = size(Ls, 1);
lambda_max_opts = struct();
lambda_max_opts.tol = 5e-3;
lambda_max_opts.p = min(N, 10);  % Krylov subspace dimension
lambda_max_opts.disp = 0;        % silent

try
    lambda_max_full = eigs(Ls, 1, 'largestabs', lambda_max_opts);
    lambda_max_full = real(lambda_max_full) * 1.01;  % 1% safety margin
catch
    % Fallback to power iteration if eigs fails
    lambda_max_full = powerIterLargestEig(Ls, 20);
end
obj.Cache.lambda_max_full = lambda_max_full;
```
```matlab
end
obj.Cache.lambda_max_full = lambda_max_full;
```

### Dependencies

Uses:
- `obj.Cache.lambda_max_full` - Full maximum eigenvalue computed via `eigs`
- Automatically computed during `meshFourier(0)` on Manifold construction
- Reused when `meshFourier(k)` is called with k > 0

## Key Difference: Full vs Basis Resolution

**Important**: The Resolution property uses the **full maximum eigenvalue**, not the basis maximum:

```matlab
% Resolution computed automatically on construction
B = bct.io.import.mesh('path/to/mesh.pial');
full_max = B.Manifold.Resolution.lambda_max;  % True max (all modes)

% Later, compute 600 modes for frequency analysis
B.Manifold.meshFourier(600);
basis_max = max(B.Manifold.Eigenvalues);  % Eigenvalue of mode 600

% full_max >> basis_max (much larger!)
% Resolution.wavelength is the TRUE Nyquist limit of the mesh
```

The full maximum eigenvalue represents the **finest spatial detail the mesh geometry can support**, independent of how many modes you computed.

## Examples

### Example 1: Check Resolution

```matlab
B = bct.io.import.mesh('lh.pial');
B.Manifold.meshFourier(600);  % Computes 600 modes + full max lambda

R = B.Manifold.Resolution;

fprintf('Mesh can resolve features down to %.2f mm\n', R.wavelength);
% Output: Mesh can resolve features down to 2.34 mm (true Nyquist limit)
```

### Example 2: Design Signals Within Resolution

```matlab
% Get true mesh resolution
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

## Before meshFourier Computed

If `meshFourier()` hasn't been called yet, `Resolution` returns empty fields:

```matlab
B = bct.io.import.mesh('lh.pial');

R = B.Manifold.Resolution;
% R.lambda_max = []
% R.wavelength = []

% Compute eigenvalues (also computes full max lambda)
B.Manifold.meshFourier(600);

R = B.Manifold.Resolution;
% Now populated with FULL max eigenvalue:
% R.lambda_max = 18.234  (much larger than basis max!)
% R.wavelength = 2.34 mm (true Nyquist limit)
```

## Relationship to Other Functions

### vs. Basis Maximum

```matlab
% These are DIFFERENT:
R = B.Manifold.Resolution;
lambda_full = R.lambda_max;  // Full max via power iteration

lambda_basis = max(B.Manifold.Eigenvalues);  // Max of computed 600 modes

% lambda_full >> lambda_basis
% Resolution uses the FULL max, representing true mesh capability
```

### vs. bct.manifold.resolution function

```matlab
% Resolution property (uses full max)
R1 = B.Manifold.Resolution;

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
