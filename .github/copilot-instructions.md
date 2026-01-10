📌 SYSTEM OVERVIEW — BIOCTREE / BCT TOOLBOX

You are working inside a MATLAB-based scientific computing toolbox called bioctree, whose core computational engine is the bct package.

Your purpose is to write and maintain code for a spatiotemporal signal-processing system that analyzes fields (signals) defined on triangulated surfaces (manifolds), using finite element methods (FEM) and spectral graph theory with the Laplace–Beltrami operator.

**Core Philosophy:**
- Surfaces are **manifolds** over which dynamics evolve
- Signals are **fields** living on those manifolds (scalar, vector, or tensor)
- Workflow parallels temporal signal processing in electrophysiology
- Designed for cortical surface analysis (MEG/EEG, fMRI on surfaces) but generalizes to any 2-manifold

📦 PACKAGE STRUCTURE

The main package is:

```
toolbox/+bct/
```

It contains:

**Core Classes:**

- `Manifold` — Triangulated surface with integrated FEM capabilities
- `Graph` — Sparse graph representation with algorithms  
- `FEM` — Finite element matrices (stiffness, mass, gradient, divergence)
- `Eigenpairs` — Eigendecomposition with metadata and spectral operations
- `operators` — Operator application interface

**Subpackages:**

- `+data` — Catalog system and bundled mesh/field assets
- `+fields` — Field artifact management with validation
- `+manifold` — Mesh I/O and format conversion
- `+geometry` — Geometric computations (normals, frames, cotangent weights)
- `+topology` — Topological analysis (halfedge, edges, adjacency)
- `+graph` — Graph-theoretic operations (eigensolve, distances, paths)
- `+operators` — Differential and transform operators
- `+registry` — Artifact registration (operators, kernels, colormaps, brushes)
- `+runtime` — Runtime resolution and caching
- `+kernel` — Spectral kernel generators
- `+ui` — Visualization and interaction tools

📚 CORE ARCHITECTURAL PRINCIPLES

### 1. Manifold-Centric Design

The `bct.Manifold` class is the foundation. It represents a triangulated 2-manifold with:
- Vertices (V) and Faces (F) defining the mesh topology
- Integrated FEM computation (Laplacian, mass matrix, eigenmodes)
- Geometric properties (normals, frames, areas, cotangent weights)
- Metadata (name, source, hemisphere, etc.)

```matlab
M = bct.manifold.load();  % Load from catalog
E = bct.graph.eigensolve(M, 100);  % Compute eigenpairs
```

### 2. Field Abstraction

Fields are signals defined on manifolds. The `bct.fields` package manages:
- **Support**: `vertex` (values at mesh vertices) or `face` (values at face centers)
- **Value type**: `scalar` (one value per location) or `vector` (tangent vectors)
- **Validation**: Schema checking and manifold compatibility

```matlab
F = bct.fields.load();  % Load field from catalog
F = bct.fields.make(M, values, 'support', 'vertex', 'valueType', 'scalar');
```

### 3. Operator System

Operators are registered artifacts that transform fields. The `bct.operators` system provides:
- **Differential operators**: gradient, divergence, Laplacian, curl
- **Domain/codomain resolution**: Automatic type inference based on input field
- **Registry-based**: All operators registered in `+registry/+operators/`

```matlab
gradF = bct.operators.apply('gradient', F);  % ∇: scalar(vertex) → vector(face)
divF = bct.operators.apply('divergence', gradF);  % ∇·: vector(face) → scalar(vertex)
lapF = bct.operators.apply('laplacian', F);  % Δ: scalar(vertex) → scalar(vertex)
```

### 4. Spectral Analysis

Eigenmodes of the Laplace-Beltrami operator form a natural basis for the manifold:
- `bct.graph.eigensolve()` computes eigenpairs
- `bct.Eigenpairs` class encapsulates vectors, values, and metadata
- Spectral filtering applies kernels in eigenmode domain

```matlab
E = bct.graph.eigensolve(M, 100);
spectrum = E.vectors' * F.value;  % Project field onto eigenmodes
filtered = E.vectors * (kernel .* spectrum);  % Spectral filtering
```

### 5. Registry System

Extensibility through registries for:
- **Operators** (`+registry/+operators/`) — Differential, transform, field operators
- **Kernels** (`+registry/+kernels/`) — Spectral filter kernels
- **Colormaps** (`+registry/+colormaps/`) — Visualization color schemes
- **Brushes** (`+registry/+brushes/`) — Localization windows

Each registry has:
- `defs.m` — Registry definitions
- `schema.m` — Validation schema
- `list.m` — Query registered items
- `validate.m` — Schema validation

### 6. Runtime Resolution

The `+runtime` package handles:
- Lazy loading and caching of registered artifacts
- Provenance tracking for operators
- Dynamic binding of kernels to manifolds
- Inspector resolution for UI components

```matlab
op = bct.runtime.operators('gradient');  % Resolve operator
kernel = bct.runtime.kernels('heat', M, 't', 10);  % Bind kernel to manifold
```

📂 DATA LOCATIONS

**Mesh catalog:**
```
toolbox/+bct/+data/assets/mesh/
├── fsaverage_lh_white.mat
├── fsaverage_rh_white.mat
├── fsaverage_lh_pial.mat
├── fsaverage_rh_pial.mat
├── fsaverage_lh_inflated.mat
├── fsaverage_rh_inflated.mat
└── fsaverage_lh_sphere.mat
```

**Field catalog:**
```
toolbox/+bct/+data/assets/fields/
└── scalarField.mat
```

**Catalog index:**
```
toolbox/+bct/+data/index.m
```

Contains struct array with mesh and field metadata. Access via:
```matlab
catalog = bct.data.index();
M = bct.data.load('Id', 'fsaverage_rh_pial');
F = bct.fields.load('Id', 'test_scalarField_vertex');
```

🧪 TESTING FRAMEWORK

All tests must go under:

```
tests/
```

Use MATLAB's `matlab.unittest` framework.

Requirements:
- Unit tests for core classes (Manifold, Graph, FEM, Eigenpairs)
- Unit tests for operators (gradient, divergence, curl)
- Unit tests for data loading (manifold.load, fields.load)
- Integration tests for complete workflows
- Performance tests (eigensolver, FEM assembly)

📚 DOCUMENTATION REQUIREMENTS

All documentation must go under:

```
docs/
```

Documentation must describe:
- Manifold-field paradigm
- FEM and spectral methods
- Operator system and registry
- Field types and validation
- Visualization tools
- API references
- Usage examples

Additional notes in:
```
notes/
```

Contains contract specifications for subsystems (see `notes/*.md`).

⚙ DEPENDENCIES

Bioctree builds upon:

- **gptoolbox** — Geometry processing (mesh operations, cotangent Laplacian, discrete differential geometry)
- **DECLab** — Discrete Exterior Calculus (differential operators on simplicial complexes)
- **GSPBox** — Graph Signal Processing (spectral graph theory, eigensolvers, spectral filtering)

Dependencies are bundled in:
```
external/
```

And listed in:
```
config/bct_dependencies.json
```

Initialize via:
```matlab
bct_start  % Adds all paths and initializes dependencies
```

🖥 VISUALIZATION

**3D Viewer:**
```
toolbox/+bct/+ui/+manifold/Viewer.m
```

WebGL-based Three.js rendering with:
- Interactive 3D mesh visualization
- Field mapping with colormaps
- Eigenmode inspection
- Brush-based localization

```matlab
V = bct.ui.manifold.Viewer(M);
V.show(fieldData);  % Display scalar field on manifold
```

**Eigenspectrum Inspector:**
```
toolbox/+bct/+ui/+eigenspectrum/Viewer.m
```

Visualize eigenmodes and eigenvalue spectrum.

🎯 CODING AGENT EXPECTATIONS

When generating code, you must:

1. **Use Manifold-centric design**: All geometry operations start with `bct.Manifold`
2. **Respect field abstraction**: Use `bct.fields` for all field operations
3. **Use operator registry**: Apply operators via `bct.operators.apply()`, not direct computation
4. **Follow package structure**: Place code in correct subpackage (+geometry, +topology, +graph, etc.)
5. **Validate schemas**: All registered artifacts must pass schema validation
6. **Write unit tests**: Test all new functions in `tests/`
7. **Document in notes/**: Add contract specifications for new subsystems
8. **Maintain clean OOP style**: Use MATLAB classes with properties, methods, and validation
9. **Avoid duplication**: Leverage existing FEM, Graph, and Eigenpairs functionality
10. **Handle metadata**: Preserve provenance and metadata through all operations

**Deprecated concepts (DO NOT USE):**
- `@Domain`, `@Lambda`, `@Omega`, `@Time`, `@Joint` classes (removed)
- `@Signal` class (replaced by field abstraction)
- `@bct` orchestrator class (replaced by package-level functions)
- Domain dual relationships (replaced by spectral projection)

You must write code that integrates CLEANLY with the current Manifold-Field architecture described above.
