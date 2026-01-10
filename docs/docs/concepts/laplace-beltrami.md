# Laplace-Beltrami Operator

## Introduction

The **Laplace-Beltrami operator** is the generalization of the Laplacian to curved manifolds. It is the foundation for spectral analysis on surfaces in Bioctree.

## Intuitive Understanding

### In 1D (Line)
The second derivative measures curvature:
$$\frac{d^2 f}{dx^2}$$

### In 2D Euclidean (Plane)
The Laplacian:
$$\Delta f = \frac{\partial^2 f}{\partial x^2} + \frac{\partial^2 f}{\partial y^2}$$

### On Manifolds (Curved Surfaces)
The Laplace-Beltrami operator $\Delta_{\mathcal{M}}$ extends this to arbitrary surfaces, accounting for curvature.

## Mathematical Definition

### Continuous Form

On a smooth manifold $\mathcal{M}$ with metric $g$:

$$
\Delta_{\mathcal{M}} f = \frac{1}{\sqrt{|g|}} \partial_i \left(\sqrt{|g|} g^{ij} \partial_j f\right)
$$

**Physical interpretation**: Measures how much a function differs from its local average.

### Discrete Form (Cotangent Laplacian)

For triangle meshes, the discrete Laplace-Beltrami matrix is:

$$
L_{ij} = \begin{cases}
\sum_{k \in \mathcal{N}(i)} w_{ik} & \text{if } i = j \\
-w_{ij} & \text{if } j \in \mathcal{N}(i) \\
0 & \text{otherwise}
\end{cases}
$$

where the weights are:

$$
w_{ij} = \frac{1}{2}(\cot \alpha_{ij} + \cot \beta_{ij})
$$

$\alpha_{ij}$ and $\beta_{ij}$ are angles opposite edge $(i,j)$ in adjacent triangles.

## Eigendecomposition

### The Eigenvalue Problem

$$
L \phi_i = \lambda_i M \phi_i
$$

where:
- $L$: Laplacian matrix [N × N]
- $M$: Mass matrix [N × N] (diagonal)
- $\lambda_i$: Eigenvalues (spatial frequencies)
- $\phi_i$: Eigenvectors (spatial modes)

### Properties of Eigenmodes

1. **Orthogonality**:
   $$\phi_i^T M \phi_j = \delta_{ij}$$

2. **Completeness**: Any function can be represented:
   $$f = \sum_{i=1}^{N} \hat{f}_i \phi_i$$

3. **Ordering**: $0 = \lambda_1 \le \lambda_2 \le \lambda_3 \le \cdots \le \lambda_N$

4. **Physical meaning**:
   - $\lambda_i$: Characteristic "frequency" of mode $i$
   - Small $\lambda_i$: Smooth, global patterns
   - Large $\lambda_i$: Oscillatory, local patterns

## Computation in Bioctree

### Basic Usage

```matlab
% Create manifold
M = bct.Manifold(V, F);

% Create BCT object
B = bct.bct.fromManifold(M);

% Compute first 100 eigenmodes
B.computeEigenbasis(100);

% Access eigenvalues and eigenvectors
lambdas = B.Lambda.eigenvalues;     % [100 × 1]
phi = B.Lambda.eigenvectors;        % [N × 100]
```

### Advanced Options

```matlab
% Use sparse solver (faster for K << N)
B.computeEigenbasis(100, 'Method', 'sparse');

% Specify tolerance
B.computeEigenbasis(100, 'Tolerance', 1e-8);

% Use GPU acceleration (if available)
B.computeEigenbasis(100, 'UseGPU', true);
```

## Visualization of Eigenmodes

### Low Frequency Modes (Smooth)

```matlab
% First 5 modes (after constant mode 0)
bct.show.eigenmodes(B, [1, 2, 3, 4, 5]);
```

**Mode 1** ($\lambda_1 = 0$): Constant function (DC component)  
**Mode 2-5**: Gradually increasing spatial oscillations

### High Frequency Modes (Oscillatory)

```matlab
% High modes show rapid spatial variation
bct.show.eigenmodes(B, [95, 96, 97, 98, 99, 100]);
```

## Physical Interpretation

### Heat Equation

The Laplace-Beltrami operator governs heat diffusion:

$$
\frac{\partial u}{\partial t} = -\Delta_{\mathcal{M}} u
$$

**Solution**:
$$
u(t) = \sum_{i=1}^{N} e^{-\lambda_i t} \hat{u}_i \phi_i
$$

- Low $\lambda_i$ modes decay slowly (persist over time)
- High $\lambda_i$ modes decay rapidly (smooth out quickly)

```matlab
% Simulate heat diffusion
initial_condition = zeros(N, 1);
initial_condition(100) = 1;  % Point heat source

% Diffuse over time
t = 0.1;
u_t = B.Lambda.heatDiffusion(initial_condition, t);

% Visualize
bct.show.signal(B, u_t);
```

### Wave Equation

The Laplace-Beltrami also appears in wave propagation:

$$
\frac{\partial^2 u}{\partial t^2} = -c^2 \Delta_{\mathcal{M}} u
$$

Eigenmodes are the **natural oscillation modes** of the surface.

## Spectral Transform

### Forward Transform (Manifold → Lambda)

Project signal onto eigenbasis:

$$
\hat{f}_i = \langle f, \phi_i \rangle_M = \sum_{j=1}^{N} f_j M_{jj} \phi_{ij}
$$

```matlab
% Spatial signal
f = signal_on_manifold;  % [N × 1]

% Transform to spectral domain
f_hat = B.Lambda.forward(f);  % [K × 1] coefficients

% Or using transform method
f_hat = B.Manifold.transform(f, B.Lambda);
```

### Inverse Transform (Lambda → Manifold)

Reconstruct from coefficients:

$$
f_j = \sum_{i=1}^{K} \hat{f}_i \phi_{ij}
$$

```matlab
% Spectral coefficients
f_hat = spectral_coeffs;  % [K × 1]

% Inverse transform
f = B.Lambda.inverse(f_hat);  % [N × 1]

% Or using transform method
f = B.Lambda.transform(f_hat, B.Manifold);
```

## Spectral Filtering

### In the Spectral Domain

Filtering is multiplication in the spectral domain:

$$
\widehat{(f \ast h)} = \hat{h} \odot \hat{f}
$$

```matlab
% Define filter kernel
h_lambda = zeros(100, 1);
h_lambda(1:30) = 1;  % Low-pass (keep first 30 modes)

% Filter in spectral domain
f_hat_filtered = h_lambda .* f_hat;

% Reconstruct
f_filtered = B.Lambda.inverse(f_hat_filtered);
```

### Using Filter Objects

```matlab
% Create low-pass filter
filt = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 30);

% Apply to signal (handles transforms automatically)
sig_filtered = filt.apply(sig_original);
```

## Properties of the Laplace-Beltrami Operator

### 1. Self-Adjoint
$$\langle \Delta_{\mathcal{M}} f, g \rangle = \langle f, \Delta_{\mathcal{M}} g \rangle$$

### 2. Non-Positive
$$\langle f, \Delta_{\mathcal{M}} f \rangle \le 0$$

All eigenvalues are non-negative: $\lambda_i \ge 0$

### 3. Kernel
$$\text{ker}(\Delta_{\mathcal{M}}) = \{\text{constant functions}\}$$

The first eigenvalue is always $\lambda_1 = 0$ with $\phi_1 = \text{constant}$.

### 4. Spectrum
The spectrum $\{\lambda_i\}$ characterizes the geometry:
- **Shape DNA**: Eigenvalues encode geometric information
- **Isospectral**: Different shapes can have same eigenvalues (rare)

## Comparison: Euclidean vs. Manifold

| Property | Euclidean $\mathbb{R}^2$ | Manifold $\mathcal{M}$ |
|----------|-------------------------|------------------------|
| Operator | $\Delta = \nabla^2$ | $\Delta_{\mathcal{M}}$ |
| Basis | Fourier $e^{i\mathbf{k}\cdot\mathbf{x}}$ | Eigenmodes $\phi_i$ |
| Frequencies | Wave numbers $\mathbf{k}$ | Eigenvalues $\lambda_i$ |
| Continuous | Yes | Discretized (mesh) |
| Isotropy | Yes | Depends on geometry |

## Numerical Considerations

### Number of Modes

**Rule of thumb**:
- **Exploration**: $K = N/100$ to $N/50$
- **Production**: $K = N/20$ to $N/10$
- **High fidelity**: $K = N/5$ to $N/2$

```matlab
N = size(V, 1);
K_explore = round(N / 100);
K_production = round(N / 20);
```

### Sparse vs. Dense Solvers

```matlab
% Dense (better for K > N/2)
B.computeEigenbasis(100, 'Method', 'dense');

% Sparse (better for K << N)
B.computeEigenbasis(100, 'Method', 'sparse');  % Default
```

### Numerical Stability

**Issue**: Ill-conditioned mass matrix  
**Solution**: Mass-lumping

```matlab
% Use lumped mass matrix (diagonal approximation)
B.computeEigenbasis(100, 'MassType', 'lumped');
```

## Applications

### 1. Spatial Smoothing

```matlab
% Low-pass filter removes high-frequency noise
smooth_filt = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 20);
smooth_signal = smooth_filt.apply(noisy_signal);
```

### 2. Edge Detection

```matlab
% High-pass filter enhances edges
edge_filt = bct.Filter(B.Lambda, 'highpass', 'cutoff', 50);
edges = edge_filt.apply(signal);
```

### 3. Multi-Scale Decomposition

```matlab
% Decompose into frequency bands
bands = [1, 20; 20, 40; 40, 60; 60, 80];
for i = 1:size(bands, 1)
    filt = bct.Filter(B.Lambda, 'bandpass', ...
        'low', bands(i,1), 'high', bands(i,2));
    band_signals{i} = filt.apply(signal);
end
```

### 4. Spectral Clustering

```matlab
% Use first k eigenmodes for clustering
k = 10;
features = B.Lambda.eigenvectors(:, 1:k);
idx = kmeans(features, num_clusters);
```

## Further Reading

- [Manifolds](manifolds.md): Geometric foundation
- [Graph Structure](graph-structure.md): Graph Laplacian connection
- [Spatial Filters](../filters/spatial.md): Practical filtering
- [Eigenbasis Tutorial](../tutorials/eigenbasis.md): Hands-on computation

## References

- Reuter et al. (2006). "Laplace-Beltrami spectra as 'Shape-DNA' of surfaces"
- Wardetzky et al. (2007). "Discrete Laplace operators: No free lunch"
- Crane et al. (2013). "Discrete Differential Geometry: An Applied Introduction"
