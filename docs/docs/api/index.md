# API Reference

Complete API documentation for Bioctree's MATLAB classes, functions, and HDF5 file format.

## Overview

The Bioctree API is organized into two main components:

1. **MATLAB API** - Object-oriented interface for signal processing
2. **HDF5 Specification** - Standardized file format for data storage

---

## MATLAB API

### [MATLAB API Overview](matlab/overview.md)
High-level overview of the class hierarchy and design patterns.

### Core Classes

#### [Bct Class](matlab/bct.md)
Main orchestrator class for all Bioctree operations.

**Key methods:**
- `fromMesh()` - Initialize from mesh data
- `computeEigenbasis()` - Calculate spectral basis
- `createSignal()` - Create signal objects
- `save()` / `load()` - I/O operations

#### [Manifold Class](matlab/manifold.md)
Represents cortical surface meshes and their geometric properties.

**Key properties:**
- `V` - Vertices (N×3 coordinates)
- `F` - Faces (M×3 triangles)
- `A` - Adjacency matrix
- `L` - Laplacian matrix

#### [JointDomain Class](matlab/joint-domain.md)
Tensor product domains for spatiotemporal analysis.

**Key features:**
- Combine Time × Lambda
- Support for filtering
- Transform operations
- Efficient computation

#### [Filter API](matlab/filters.md)
Filter design and application across all domains.

**Filter types:**
- Spatial filters (Manifold/Lambda)
- Temporal filters (Time/Omega)
- Joint filters (combined domains)
- Wave packet filters

---

## HDF5 File Format

### [HDF5 Specification](hdf5/specification.md)
Complete specification of the `.bct` file format.

**Includes:**
- File structure and hierarchy
- Dataset specifications
- Metadata requirements
- Version control
- Schema validation

### [HDF5 File I/O](hdf5/io.md)
Reading and writing `.bct` files in MATLAB.

**Operations:**
- Saving bct objects
- Loading bct files
- Accessing datasets
- Metadata handling
- Compatibility checks

---

## Quick Reference

### Common Workflows

```matlab
% Load and initialize
data = load('mesh.mat');
B = bct.bct.fromMesh(data.V, data.F);
B.computeEigenbasis(256);

% Create and filter signal
sig = bct.Signal(B.Manifold, signal_data);
filt = bct.Filter(B.Lambda, 'gaussian', 'center', 50);
filtered = filt.apply(sig);

% Save to file
B.save('analysis.bct');
```

### Class Hierarchy

```
bct.bct (orchestrator)
├── bct.Domain (abstract)
│   ├── bct.Manifold
│   ├── bct.Lambda
│   ├── bct.Time
│   ├── bct.Omega
│   └── bct.Joint
├── bct.Signal
├── bct.Filter
└── bct.Graph
```

---

## Additional Resources

- **[Concepts](../concepts/index.md)** - Understand the theory
- **[Tutorials](../tutorials/index.md)** - Learn through examples
- **[Examples](../examples/index.md)** - See complete workflows
- **[GitHub](https://github.com/DiellorBasha/bioctree)** - Source code and issues

## API Stability

- **Stable API**: Core classes (bct, Manifold, Lambda, Signal, Filter)
- **Evolving**: Joint domain operations, advanced filters
- **Experimental**: New transform methods, optimization features

Check the [Changelog](../about/changelog.md) for API changes between versions.
