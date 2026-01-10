# Concepts Overview

This section introduces the mathematical and computational foundations of Bioctree. Understanding these concepts will help you design better analyses and interpret results correctly.

## The Big Picture

Bioctree combines three major areas:

1. **Spectral Geometry**: Analysis of signals on manifolds using eigenmodes
2. **Graph Signal Processing**: Extension of Fourier analysis to graphs
3. **Time-Frequency Analysis**: Joint decomposition in space, time, and frequency

## Core Mathematical Framework

### Domains and Dual Spaces

At the heart of Bioctree is the concept of **domain duality**:

```
Domain ←→ Dual Domain
   ↕          ↕
Signal ←→ Transformed Signal
```

Every domain has a dual, and transforms move signals between them:

| Domain | Space | Dual | Dual Space | Transform |
|--------|-------|------|------------|-----------|
| Manifold | Vertices | Lambda | Eigenmodes | Spectral |
| Time | Samples | Omega | Frequencies | Fourier |
| Graph | Nodes | Spectrum | Graph Freq | Graph Fourier |

### The Fundamental Equation

For a signal $f$ on manifold $\mathcal{M}$, the spectral decomposition is:

$$
f = \sum_{i=1}^{N} \hat{f}_i \phi_i
$$

Where:
- $\phi_i$ are eigenvectors of the Laplace-Beltrami operator
- $\hat{f}_i$ are spectral coefficients
- $N$ is the number of vertices

This is analogous to the Fourier series, but on arbitrary surfaces.

## Key Concepts by Topic

### 1. [Manifolds](manifolds.md)

Learn about:
- Surface representation (vertices and faces)
- Mesh topology
- Differential geometry on discrete meshes
- The role of the cotangent Laplacian

**Key takeaway**: Manifolds are the geometric substrate where signals live.

### 2. [Laplace-Beltrami Operator](laplace-beltrami.md)

Understand:
- The continuous and discrete Laplace-Beltrami operators
- Eigendecomposition and eigenmodes
- Physical interpretation (heat diffusion)
- Numerical computation via FEM

**Key takeaway**: The Laplace-Beltrami operator defines "frequency" on curved surfaces.

### 3. [Graph Structure](graph-structure.md)

Explore:
- Graphs as discrete manifolds
- Adjacency and Laplacian matrices
- Graph Fourier transform
- Connection to mesh processing

**Key takeaway**: Graphs generalize signal processing to arbitrary network topologies.

### 4. [Joint Spectral Domain](joint-spectrum.md)

Discover:
- Tensor products of domains
- Joint spectral-temporal analysis
- 2D and higher-dimensional filters
- Separable vs. non-separable kernels

**Key takeaway**: Joint domains enable multidimensional signal decomposition.

### 5. [Wave Packets](wave-packets.md)

Dive into:
- Traveling waves on manifolds
- Wave packet transforms
- Localization in space and frequency
- Applications to neural oscillations

**Key takeaway**: Wave packets detect coherent spatiotemporal patterns.

### 6. [Dispersion](dispersion.md)

Master:
- Dispersion relations $\omega = \omega(\lambda)$
- Group velocity $v_g = d\omega/d\lambda$
- Phase velocity $v_p = \omega/\lambda$
- Detecting traveling waves

**Key takeaway**: Dispersion characterizes how waves propagate on surfaces.

## Conceptual Hierarchy

```
Manifold Geometry
    ↓
Laplace-Beltrami Operator
    ↓
Eigendecomposition
    ↓
Spectral Domain (Lambda)
    ↓
Filtering & Transforms
    ↓
    ├─→ Spatial Analysis
    ├─→ Spectral Analysis
    ├─→ Temporal Analysis
    └─→ Joint Analysis
         ↓
    Wave Packets & Dispersion
```

## Notation Guide

Throughout the documentation, we use consistent notation:

### Spatial/Geometric
- $\mathcal{M}$: Manifold
- $V$: Vertex set, $V = \{v_i\}_{i=1}^{N}$
- $F$: Face set
- $N$: Number of vertices
- $\mathbf{x}_i$: Position of vertex $i$ in $\mathbb{R}^3$

### Operators
- $\Delta$: Laplace-Beltrami operator
- $L$: Graph Laplacian matrix
- $M$: Mass matrix
- $W$: Adjacency/weight matrix

### Spectral
- $\lambda_i$: $i$-th eigenvalue
- $\phi_i$ or $\mathbf{u}_i$: $i$-th eigenvector
- $\hat{f}$: Spectral coefficients of signal $f$
- $\Lambda$: Spectral domain

### Temporal
- $t$: Time
- $T$: Number of time points
- $f_s$: Sampling frequency
- $\omega$: Angular frequency
- $\Omega$: Frequency domain

### Signals & Filters
- $f$: Signal on manifold
- $h$: Filter kernel
- $f \ast h$: Filtered signal (convolution)
- $\odot$: Element-wise multiplication

## Mathematical Prerequisites

To fully understand Bioctree concepts, familiarity with the following is helpful:

### Essential
- Linear algebra (eigenvalues, eigenvectors, matrix operations)
- Fourier analysis (basic transform theory)
- Calculus (derivatives, integrals)

### Helpful
- Differential geometry (manifolds, curvature)
- Numerical methods (finite elements, sparse solvers)
- Signal processing (filtering, spectral analysis)

### Advanced (for deep understanding)
- Functional analysis (Hilbert spaces, operators)
- Riemannian geometry (metrics, geodesics)
- Harmonic analysis (generalized Fourier theory)

## Intuitive Analogies

### Manifold ↔ Image
Think of a cortical surface like a 2D image, but curved:
- Image pixels → Manifold vertices
- Image gradients → Tangent vectors on surface
- Image smoothing → Heat diffusion on manifold

### Eigenmodes ↔ Musical Modes
Like vibrating drum heads:
- Low eigenmodes → Deep bass notes (smooth, global patterns)
- High eigenmodes → High treble (sharp, local features)
- Eigenvalues → Frequencies of vibration

### Spectral Filtering ↔ Audio EQ
Just like adjusting bass/treble:
- Low-pass filter → Remove details, keep smooth features
- High-pass filter → Detect edges, remove smooth background
- Band-pass filter → Focus on specific spatial scales

## Common Questions

### Q: Why use eigenmodes instead of standard Fourier?

**A**: Standard Fourier assumes periodic, Euclidean domains (like a torus). Cortical surfaces are:
- Non-periodic (finite extent)
- Non-Euclidean (curved)
- Irregular (non-uniform sampling)

Eigenmodes naturally adapt to the geometry.

### Q: How many eigenmodes do I need?

**A**: It depends on:
- **Mesh resolution**: Finer meshes need more modes
- **Signal complexity**: Smooth signals need fewer modes
- **Rule of thumb**: Start with $K \approx N/100$ to $N/10$

### Q: What's the difference between Manifold and Graph domains?

**A**: 
- **Manifold**: 2D surface embedded in 3D, has geometric properties (angles, areas)
- **Graph**: Abstract network, only connectivity matters

Bioctree uses manifolds when geometry is important (e.g., cortical surfaces), graphs for pure connectivity.

### Q: Can I use bioctree for non-brain data?

**A**: Absolutely! Any data on meshes or graphs:
- 3D shape analysis
- Social network dynamics
- Sensor network data
- Traffic flow on road networks
- Climate data on Earth's surface

## Visualization of Concepts

### Low vs. High Eigenmodes

```
Eigenmode 1 (λ₁ = 0):     Eigenmode 100 (λ₁₀₀ >> 0):
┌────────────┐            ┌────────────┐
│  ████████  │            │ ▒█▒█▒█▒█▒█ │
│  ████████  │            │ █▒█▒█▒█▒█▒ │
│  ████████  │            │ ▒█▒█▒█▒█▒█ │
│  ████████  │            │ █▒█▒█▒█▒█▒ │
└────────────┘            └────────────┘
Constant (DC)             Checkerboard
Smooth, global            Sharp, local
```

### Domain Transforms

```
Manifold Domain          Lambda Domain
f(vertex)                f̂(eigenmode)
     │                        ▲
     │  Forward Transform     │
     └────────────────────────┘
     ┌────────────────────────┐
     │  Inverse Transform     │
     ▼                        │
```

## Next Steps

Choose your path based on interest:

**For theoreticians**: Start with [Laplace-Beltrami](laplace-beltrami.md) for the mathematical foundation.

**For practitioners**: Jump to [Manifolds](manifolds.md) for hands-on mesh concepts.

**For neuroscientists**: Check out [Wave Packets](wave-packets.md) for traveling wave analysis.

**For graph enthusiasts**: Explore [Graph Structure](graph-structure.md) for network signal processing.

## Related Resources

### Within Documentation
- [Spatial Filters](../filters/spatial.md): Apply these concepts to filtering
- [Eigenbasis Tutorial](../tutorials/eigenbasis.md): Compute eigenmodes step-by-step
- [API Reference](../api/matlab/overview.md): Implementation details

### External Resources
- [Discrete Differential Geometry](http://www.cs.cmu.edu/~kmcrane/Projects/DDG/) (Keenan Crane)
- [Graph Signal Processing](https://arxiv.org/abs/1211.0053) (Shuman et al.)
- [Spectral Methods in MATLAB](https://people.maths.ox.ac.uk/trefethen/spectral.html) (Trefethen)
