# BCT Domain Transform System

## Overview

The BCT (Brain Connectivity Toolbox) domain architecture includes automatic transform initialization for converting signals between dual domains. Each domain has a `transform` property that provides forward and inverse operations.

## Domain Pairs and Transforms

### 1. Time ↔ Omega (FFT/IFFT)

**Automatic initialization:** Transforms are set immediately when Time domain is created.

```matlab
% Create Time domain (automatically creates Omega dual and transforms)
t = linspace(0, 1.99, 200)';
fs = 100;  % Hz
timeDomain = bct.Time(t, fs);
omegaDomain = timeDomain.dual;

% Transform signal from Time → Omega
signal = sin(2*pi*5*t);  % 5 Hz signal
spectrum = timeDomain.transform.forward(signal);  % FFT

% Transform back from Omega → Time
reconstructed = omegaDomain.transform.forward(spectrum);  % IFFT
```

**Key points:**
- `timeDomain.transform` is an FFT object
- `omegaDomain.transform` is an IFFT object
- Use `.forward()` for both directions (FFT forward = Time → Omega, IFFT forward = Omega → Time)

### 2. Manifold ↔ Lambda (MFT/IMFT)

**Delayed initialization:** Transforms are empty until eigenvectors are computed.

```matlab
% Create mesh
[V, F] = icosphere(2);  % 162 vertices
B = bct.bct.fromMesh(V, F);

% Initially, transforms are empty (placeholder eigenvectors)
assert(isempty(B.Manifold.transform));
assert(isempty(B.Lambda.transform));

% Compute eigenvectors
numModes = 50;
[U, lambda] = bct.Manifold.meshFourier(V, F, numModes);

% Update Lambda with eigenvectors
B.Lambda.U = U;
B.Lambda.lambda = lambda;

% Re-initialize transforms now that eigenvectors exist
B.Manifold.initializeTransform();
B.Lambda.initializeTransform();

% Now transforms are available
assert(~isempty(B.Manifold.transform));  % MFT
assert(~isempty(B.Lambda.transform));    % IMFT

% Transform signal from Manifold → Lambda
spatialSignal = randn(162, 1);  % Signal on vertices
spectralCoeffs = B.Manifold.transform.forward(spatialSignal);  % MFT

% Transform back from Lambda → Manifold
reconstructed = B.Lambda.transform.forward(spectralCoeffs);  % IMFT
```

**Key points:**
- `B.Manifold.transform` is an MFT object (when eigenvectors computed)
- `B.Lambda.transform` is an IMFT object (when eigenvectors computed)
- Use `.forward()` for both directions (MFT forward = Manifold → Lambda, IMFT forward = Lambda → Manifold)
- Must call `initializeTransform()` again after computing eigenvectors

## Transform Semantics

All transform objects follow a consistent pattern:

- **`.forward()`**: Transforms in the "natural" direction of the transform
  - FFT: Time → Omega
  - IFFT: Omega → Time
  - MFT: Manifold → Lambda
  - IMFT: Lambda → Manifold

- **`.inverse()`**: Transforms in the opposite direction
  - FFT.inverse: Omega → Time (same as IFFT.forward)
  - IFFT.inverse: Time → Omega (same as FFT.forward)
  - MFT.inverse: Lambda → Manifold (same as IMFT.forward)
  - IMFT.inverse: Manifold → Lambda (same as MFT.forward)

**Recommendation:** Always use `.forward()` with the appropriate domain's transform for clarity.

## Transform Classes

Located in `toolbox/+bct/+factory/+transforms/`:

- **TransformBase**: Abstract base class with `forward` and `inverse` function handles
- **FFT**: Time → Omega via `fft(x, [], 1)`
- **IFFT**: Omega → Time via `ifft(X, [], 1)`
- **MFT**: Manifold → Lambda via `c = U' * (M * x)` (Mesh Fourier Transform)
- **IMFT**: Lambda → Manifold via `x = U * c` (Inverse Mesh Fourier Transform)

## Implementation Details

### MFT (Mesh Fourier Transform)

- **Forward:** `c = U' * (M * x)` - Space to spectral coefficients
- **Inverse:** `x = U * c` - Spectral coefficients to space
- **Requires:**
  - `U`: Eigenvectors from Lambda domain (via `lambda.eigenvectors()`)
  - `M`: Mass matrix from Manifold domain (via `manifold.M()`)

### IMFT (Inverse Mesh Fourier Transform)

- **Forward:** `x = U * c` - Spectral coefficients to space
- **Inverse:** `c = U' * (M * x)` - Space to spectral coefficients
- **Requires:**
  - Same `U` and `M` as MFT
  - Note: IMFT.forward = MFT.inverse, IMFT.inverse = MFT.forward

## Eigendecomposition Workflow

The complete workflow for setting up MFT/IMFT:

```matlab
% 1. Create bct object (transforms initially empty)
[V, F] = icosphere(2);
B = bct.bct.fromMesh(V, F);

% 2. Compute eigenvectors
[U, lambda] = bct.Manifold.meshFourier(V, F, 50);

% 3. Update Lambda domain
B.Lambda.U = U;
B.Lambda.lambda = lambda;

% 4. Re-initialize transforms
B.Manifold.initializeTransform();
B.Lambda.initializeTransform();

% 5. Use transforms
signal = randn(size(V,1), 1);
coeffs = B.Manifold.transform.forward(signal);
reconstructed = B.Lambda.transform.forward(coeffs);
```

## Testing

Run `test_domain_transforms.m` to verify:
- ✓ FFT/IFFT initialization and inverse operations
- ✓ MFT/IMFT placeholder behavior before eigendecomposition
- ✓ MFT/IMFT functionality after eigendecomposition
- ✓ Complete bct object with all four domains

## Notes

1. **DC component removal:** `meshFourier` removes the DC (constant) mode, so the number of returned eigenvectors may be less than requested.

2. **Placeholder eigenvectors:** Lambda domain has empty eigenvectors (`[]`) until `meshFourier` is called. During this time, `initializeTransform()` sets transforms to `[]`.

3. **Re-initialization:** After computing eigenvectors, you must call `initializeTransform()` again on both Manifold and Lambda domains to create the transforms.

4. **Transform metadata:** Each transform object has a `metadata` property with information about the transform type, number of modes, and eigenvalues (for MFT/IMFT).
