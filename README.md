# Initial Release: Bioctree (BCT) v1.0

## Summary

**Bioctree (BCT)** — a MATLAB framework for spatiotemporal analysis of signals defined on surfaces.

BCT treats surfaces as **manifolds** over which dynamics evolve, and signals as **fields** living on those manifolds. It provides a complete workflow parallel to temporal signal processing in electrophysiology:

- **Spectral operators** (eigenmodes of the Laplace-Beltrami operator) for decomposing manifold geometry
- **Spectral signal analysis** revealing local and global structure of field data
- **Differential operators** (gradient, divergence, curl) for field calculus on curved surfaces
- **Localization windows** (brush system) for spatially-targeted analysis and manipulation

While designed with cortical surface analysis in mind (MEG/EEG source localization, fMRI on surface meshes), BCT generalizes to any triangulated 2-manifold where spatiotemporal field dynamics are of interest.

---

## Overview

BCT enables researchers to analyze signals that live on surfaces rather than regular grids. The framework provides:

- **Manifold representation** via finite element methods (FEM) and discrete exterior calculus
- **Spectral decomposition** computing eigenmodes that form a natural basis for the surface geometry
- **Field abstraction** unifying scalar fields (vertex/face), vector fields (tangent), and tensor fields
- **Differential geometry** operators respecting the intrinsic curvature of the manifold
- **Localization tools** for spatial windowing and region-based analysis
- **Interactive visualization** with WebGL-powered 3D rendering and field mapping
- **Extensible architecture** via registries for operators, kernels, colormaps, and brushes

---

## Key Features

### Core Architecture

- **Manifold-centric design**: Triangulated surfaces as first-class objects with integrated FEM capabilities
- **FEM computation engine**: Cotangent Laplacian, mass matrices, and eigensolver integration
- **Graph operations**: Adjacency, Laplacian assembly, shortest paths, and geodesic distances
- **Modular operator system**: Registry-based operators with automatic domain/codomain resolution
- **Field abstraction**: Unified interface for scalar, vector, and tensor fields on vertices or faces

### Data Management

- **Unified catalog system** (`bct.data`) for bundled mesh and field assets
- **Manifold loading** supporting FreeSurfer, Brainstorm, GIFTI, and MATLAB formats
- **Field loading** with validation and type checking (scalar/vector, vertex/face support)
- **Test datasets** including fsaverage cortical surfaces (163,842 vertices)

### Geometry & Topology

- **Geometric operators**: Surface normals, tangent frames, centroids, cotangent weights
- **Topological analysis**: Halfedge structure, edge extraction, face adjacency
- **FEM operators**: Gradient (vertex→face), divergence (face→vertex), Laplacian
- **Differential geometry**: Frame fields for vector field analysis on curved surfaces

### Filtering & Spectral Analysis

- **Filter library** for manifold field filtering: heat diffusion, wavelets, and spectral kernels
- **Joint filters** isolating spatial and temporal frequencies for spatiotemporal decomposition
- **Nonseparable filters** with dispersion terms for traveling wave and velocity-selective analysis
- **Kernel generators** for custom filter design in spectral domain

### Visualization

- **3D manifold viewer** (`bct.ui.manifold.Viewer`) with Three.js rendering engine
- **Eigenspectrum inspector** for visualizing spatial eigenmodes
- **Colormap system** with 20+ built-in maps and custom LUT support
- **Interactive brushes** for manual region selection and field painting
- **Streamline visualization** for vector field flow patterns

### Extensibility

- **Registry system** for kernels, operators, colormaps, and UI components
- **Runtime resolution** with caching and provenance tracking
- **Schema validation** for all registered artifacts
- **Plugin architecture** for custom operators and visualizations

---

## Technical Highlights

### Package Structure

```
+bct/
├── +data/              # Catalog system and bundled assets
├── +fields/            # Field artifact management
├── +manifold/          # Mesh I/O and conversion
├── +geometry/          # Geometric computations
├── +topology/          # Topological analysis
├── +graph/             # Graph-theoretic operations
├── +operators/         # Differential and transform operators
├── +registry/          # Artifact registration system
├── +runtime/           # Runtime resolution and caching
├── +ui/                # Visualization and interaction
└── +kernel/            # Spectral kernel generators
```

### Core Classes

- `bct.Manifold`: Triangulated surface with FEM capabilities
- `bct.Graph`: Sparse graph representation with algorithms
- `bct.FEM`: Finite element matrices (stiffness, mass, gradient, divergence)
- `bct.Eigenpairs`: Eigendecomposition with metadata
- `bct.ui.manifold.Viewer`: WebGL 3D visualization

### Operator System

- **Field operators** with automatic type inference
- **Domain/codomain resolution** for operator chaining
- **Gradient**: `∇: scalar(vertex) → vector(face)`
- **Divergence**: `∇·: vector(face) → scalar(vertex)`
- **Laplacian**: `Δ: scalar(vertex) → scalar(vertex)`

---

## What's Included

### Bundled Assets

- **7 fsaverage surfaces**: Left/right hemispheres, white, pial, inflated, sphere
- **Test field data**: Scalar vertex field (1000 vertices)
- **Sample datasets** ready for immediate use

### External Dependencies

- MATLAB R2020a or later
- Optional: gptoolbox, brainstorm3, gifti (bundled in `external/`)

### Documentation

- Architecture notes in `notes/` directory
- Contract specifications for all major subsystems
- Example scripts in `demo/`
- Initialization via `bct.start`

---

## Installation & Usage

```matlab
% Initialize BCT
addpath('path/to/bioctree/toolbox')
bct.start

% Load a triangulated surface (manifold)
M = bct.manifold.load();

% Compute Laplace-Beltrami eigenmodes (spectral operators)
E = bct.graph.eigensolve(M, 100);

% Visualize eigenmode #10 (spectral basis function)
V = bct.ui.manifold.Viewer(M);
V.show(E.vectors(:, 10));

% Load or define a field on the manifold
F = bct.field.load();  % scalar field on vertices

% Apply differential operators
gradF = bct.operators.apply('gradient', F);    % ∇F: vertex→face vector field
divF  = bct.operators.apply('divergence', gradF); % ∇·(∇F): Laplacian

% Spectral analysis: project field onto eigenmodes
spectrum = E.vectors' * F.value;  % field decomposition in spectral domain

% Localized analysis using brush system
brush = bct.runtime.brushes('gaussian', M, 'center', seedVertex, 'width', 5);
localField = F.value .* brush.weights;  % spatially windowed field
```

---

## Future Roadmap

- **Level of detail (LOD) algorithms** using eigenmode truncation for adaptive resolution
- **Bioctree representation** combining spatial eigenmodes and temporal frequencies for hierarchical encoding
- **Multiresolution pyramid** for fast coarse-to-fine analysis and progressive transmission
- Advanced kernel generators (Gabor, spatiotemporal wavelets)
- Machine learning integration for pattern recognition on manifold domains
- Real-time data streaming support
- Python bindings via MATLAB Engine API

---

## Core Dependencies

BCT builds upon established computational geometry and graph signal processing libraries:

- **gptoolbox** — Geometry processing utilities for mesh operations, cotangent Laplacian construction, and discrete differential geometry primitives
- **DECLab** — Discrete Exterior Calculus framework providing differential operators (exterior derivative, Hodge star) on simplicial complexes
- **GSPBox** — Graph Signal Processing toolbox supplying spectral graph theory foundations, including eigensolvers and spectral filtering infrastructure

These dependencies are managed by `bct.install` and automatically initialized by `bct.start`. BCT extends these foundations with:
- Field-centric abstractions (scalar, vector, tensor fields)
- Unified operator registry with automatic type inference
- Spatiotemporal filtering (joint domain, nonseparable kernels)
- Interactive visualization and localization tools

---

## Breaking Changes

N/A — This is the initial release.

---

## Contributors

- Primary architecture and implementation
- FEM and spectral methods
- Visualization system
- Data management infrastructure

---

## License

[Specify your license here]

---

**This PR represents ~7.1M lines of new code across 1,503 files**, establishing the complete BCT framework from the ground up.
