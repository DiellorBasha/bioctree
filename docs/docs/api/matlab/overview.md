# MATLAB API Overview

Comprehensive reference for all Bioctree classes and functions.

## Package Structure

```
+bct/
├── @bct/                  % Main orchestrator class
├── @Domain/               % Abstract base for all domains
├── @Manifold/             % Mesh/graph geometry
├── @Lambda/               % Spectral domain
├── @Time/                 % Temporal domain
├── @Omega/                % Frequency domain
├── @Joint/                % Tensor product domains
├── @Signal/               % Signals on domains
├── @Filter/               % Filter kernels
├── @Graph/                % Graph operations
├── +filters/              % Filter subpackage
│   └── +kernels/         % Fundamental kernels
├── +io/                   % File I/O (BCT format)
├── +show/                 % Visualization
├── +sim/                  % Simulations
└── +internal/             % Utilities

```

## Core Classes

### bct.bct
Main orchestrator for all operations.

**Constructor**:
```matlab
B = bct.bct.fromMesh(V, F);
B = bct.bct.fromGraph(W);
```

**Key Methods**:
- `computeEigenbasis(K)` - Compute K eigenmodes
- `addSignal(signal)` - Add signal to collection
- `getJointDomain(d1, d2)` - Create tensor product domain

**Properties**:
- `Manifold` - Geometry
- `Lambda` - Spectral domain
- `Time` - Temporal domain (if set)
- `Omega` - Frequency domain (if set)
- `Signals` - Signal array

### bct.Domain (Abstract)
Base class for all domains.

**Required Methods** (must implement in subclasses):
- `size()` - Dimension of domain
- `axes()` - Coordinate axes
- `dual()` - Dual domain

### bct.Manifold
Geometric mesh or graph.

**Constructor**:
```matlab
M = bct.Manifold(V, F);            % From vertices and faces
M = bct.Manifold.fromGraph(W);     % From adjacency matrix
```

**Properties**:
- `V` - Vertices [N × 3]
- `F` - Faces [M × 3]
- `N` - Number of vertices
- `Edges` - Edge list
- `Time` - Temporal dimension (optional)

**Methods**:
- `cotLaplacian()` - Compute Laplace-Beltrami matrix
- `massMatrix()` - Compute mass matrix
- `plot()` - Visualize mesh
- `transform(signal, target_domain)` - Transform signal

### bct.Lambda
Spectral domain (eigenmode space).

**Constructor**:
```matlab
Lambda = bct.Lambda.fromManifold(M, num_modes);
```

**Properties**:
- `eigenvalues` - Spatial frequencies [K × 1]
- `eigenvectors` - Eigenmodes [N × K]
- `K` - Number of modes

**Methods**:
- `forward(signal)` - Manifold → Lambda transform
- `inverse(coeffs)` - Lambda → Manifold transform
- `plotDispersion()` - Visualize dispersion relation

### bct.Signal
Signals defined on domains.

**Constructor**:
```matlab
sig = bct.Signal(domain, data, label);
```

**Properties**:
- `Data` - Signal values
- `Domain` - Domain where signal lives
- `Label` - String identifier

**Dependent Properties**:
- `IsStatic` - True if no time dimension
- `IsDynamic` - True if has time dimension
- `IsVector` - True if vector-valued

### bct.Filter
Filter kernels on domains.

**Constructor**:
```matlab
filt = bct.Filter(domain, kernel_type, param1, value1, ...);
```

**Methods**:
- `apply(signal)` - Filter a signal
- `evaluate()` - Get kernel values
- `plot()` - Visualize kernel

## Subpackages

### +filters.kernels
Fundamental kernel functions:
- `gaussian()` - Gaussian kernel
- `lowpass()` - Ideal low-pass
- `highpass()` - Ideal high-pass
- `bandpass()` - Band-pass filter
- `delta()` - Dirac delta
- `box()` - Box/rectangular window
- `hamming()` - Hamming window

### +io
BCT file operations:
- `bct.create(name)` - Create new BCT file
- `bct.open(filename)` - Open existing BCT file

### +show
Visualization functions:
- `signal(B, sig)` - Show signal on mesh
- `eigenmodes(B, modes)` - Show eigenmodes
- `wavepacket_movie(B, wp)` - Animate wave packets
- `phase(B, phase_data)` - Phase map

## Function Reference

### Transforms
```matlab
% Forward transforms
f_hat = domain1.transform(f, domain2);

% Examples
spectral = B.Manifold.transform(spatial, B.Lambda);
frequency = B.Time.transform(temporal, B.Omega);
```

### Filtering
```matlab
% Create and apply filter
filt = bct.Filter(domain, type, parameters);
filtered_signal = filt.apply(original_signal);
```

## Further Reading

- [bct Class](bct.md) - Detailed bct documentation
- [Manifold Class](manifold.md) - Manifold reference
- [Filters](filters.md) - Filter system details
- [HDF5 Specification](../hdf5/specification.md) - BCT file format
