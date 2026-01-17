📌 SYSTEM OVERVIEW — BIOCTREE / BCT TOOLBOX

You are working inside a MATLAB-based scientific computing toolbox called bioctree, whose core computational engine is the bct package.

Your purpose is to write and maintain code for a spatiotemporal signal-processing system that analyzes fields (signals) defined on triangulated surfaces (manifolds), using finite element methods (FEM) , discrete exterior calculus (DEC) and spectral graph theory with the Laplace–Beltrami operator.

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

- `Manifold` — Triangulated surface with unified caching and lazy computation
- `Field` — Data-on-manifold with support semantics and type safety
- `Operator` — Wrapper for differential and transform operators with metadata

**Subpackages:**

- `+manifold` — Manifold operations: I/O, geometry, topology, operators, eigenmodes, health
  - `+geometry` — Geometric computations (normals, tangent frames, areas, curvature)
  - `+topology` — Topological analysis (edges, adjacency, halfedge structure)
  - `+operator` — FEM and DEC operator construction (mass, stiffness, derivatives)
  - `+eigen` — Eigenmode computation and spectral analysis utilities
  - `+health` — Mesh quality checking and repair (orientation, connectivity, scale)
  - `+metric` — Metric operations (rescaling, unit conversion)
  - `+query` — Spatial queries and nearest-neighbor searches
- `+field` — Field construction, validation, and manipulation
  - `+generate` — Field generation utilities
  - `+metric` — Field metrics and statistics
- `+operators` — High-level operator application interface
- `+filter` — Spectral filtering (synthesis, analysis, design, inverse)
- `+brush` — Localization windows and spatial modulation
  - `+design` — Brush design tools
  - `+dynamic` — Dynamic brushes
  - `+patch` — Patch-based operations
- `+kernel` — Spectral kernel generators (heat, wave, diffusion)
- `+registry` — Artifact registration system
  - `+operators` — Operator registry definitions
  - `+kernels` — Kernel registry definitions
  - `+colormaps` — Colormap registry
  - `+brushes` — Brush registry
- `+runtime` — Runtime resolution and caching
- `+data` — Catalog system and bundled mesh/field assets
- `+ui` — Visualization and interaction tools
  - `+manifold` — 3D surface visualization (WebGL-based)
  - `+eigenspectrum` — Eigenmode and spectrum visualization
  - `+color` — Color controls and colormaps
  - `+component` — UI component library
- `+config` — Configuration management
- `+install` — Installation and dependency management
- `+file` — File I/O utilities

📚 CORE ARCHITECTURAL PRINCIPLES

### 1. Manifold-Centric Design

The `bct.Manifold` class is the foundation. It represents a triangulated 2-manifold with:
- Vertices (V) and Faces (F) defining the mesh topology (immutable)
- Unified caching system for computed properties (geometry, topology, operators, eigenmodes)
- Lazy computation with automatic cache management
- Metric provenance tracking (units, rescaling status)

```matlab
M = bct.manifold.load();         % Load from catalog
ops = M.operators();             % Get all operators (mass, stiffness, DEC)
geom = M.geometry();             % Get all geometry (centroids, normals, tangents)
[lambda, U] = M.eigenmodes(100); % Compute 100 eigenmodes
```

### 2. Field Abstraction

Fields are signals defined on manifolds. The `bct.Field` class and `bct.field` package provide:
- **Support types**: `vertex`, `face`, `edge`, `halfedge`, `dualFace`, `dualVertex`
- **Value types**: `scalar`, `vector3`, `tangent2`, `complexScalar`, `complexVector3`
- **Time-varying fields**: Automatic time metadata handling
- **Schema validation**: Automatic type inference and manifold compatibility checking

```matlab
F = bct.field.load('Id', 'test_scalarField_vertex');  % Load from catalog
F = bct.field.make(M, values, 'support', 'vertex', 'valueType', 'scalar');  % Create field
F = bct.Field(M, values);  % Object-oriented interface with auto-inference
```

### 3. Operator System

Operators are computed via `bct.manifold.operator` functions and wrapped in `bct.Operator` objects:
- **FEM operators**: mass matrix, stiffness matrix, Laplace-Beltrami operator
- **DEC operators**: exterior derivatives (d0, d1), codifferentials (dd0, dd1), Hodge stars
- **Composition operators**: gradient, divergence, curl, Hodge Laplacian
- **Registry-based high-level interface**: `bct.operators.apply()` for field transformations

```matlab
% Access operators from Manifold
ops = M.operators();
L = ops.laplacebeltrami;  % [N×N] Laplace-Beltrami operator
d0 = ops.d0;              % Exterior derivative (vertex → edge)

% Apply to fields using bct.operators interface
gradF = bct.operators.apply('gradient', F);      % ∇: scalar(vertex) → tangent2(face)
divF = bct.operators.apply('divergence', vecF);  % ∇·: tangent2(face) → scalar(vertex)
lapF = bct.operators.apply('laplacian', F);      % Δ: scalar(vertex) → scalar(vertex)
```

### 4. Spectral Analysis

Eigenmodes of the Laplace-Beltrami operator form a natural basis for the manifold:
- `bct.manifold.eigenmodes()` computes eigenpairs via generalized eigenvalue problem
- Eigenvectors are M-orthonormal: U' * M * U = I
- Spectral filtering via `bct.filter` package (synthesis, analysis, design, inverse)
- Kernel-based filtering with registered kernels (heat, wave, diffusion)

```matlab
% Compute eigenmodes
[lambda, U] = bct.manifold.eigenmodes(M, 100);

% Project field onto eigenmodes
Mass = M.massmatrix();
spectrum = U' * Mass * F.value;  % Spectral coefficients

% Spectral filtering
tau = 10;
kernel = exp(-lambda * tau);      % Heat kernel
filtered = U * (kernel .* spectrum);  % Apply filter in spectral domain
```

### 5. Discrete Exterior Calculus (DEC)

Full DEC machinery integrated into operator system:
- **Differential forms**: 0-forms (vertices), 1-forms (edges), 2-forms (faces)
- **Exterior derivatives**: d0 (0→1), d1 (1→2)
- **Codifferentials**: dd0 (1→0), dd1 (2→1)
- **Hodge stars**: Map between primal and dual forms
- **Vector calculus**: gradient, divergence, curl via DEC composition

```matlab
ops = M.operators();
d0 = ops.dec.d0;         % Exterior derivative d0
hd1 = ops.dec.hd1;       % Hodge star *₁
grad = ops.gradient;     % Gradient = sharp ∘ d0
div = ops.divergence;    % Divergence = dd0
curl = ops.curl;         % Curl = dd1 (edge → face)
```

### 6. Registry System

Extensibility through registries for:
- **Operators** (`+registry/+operators/`) — Differential, transform, field operators
- **Kernels** (`+registry/+kernels/`) — Spectral filter kernels
- **Colormaps** (`+registry/+colormaps/`) — Visualization color schemes
- **Brushes** (`+registry/+brushes/`) — Localization windows

Each registry has:
- `defs.m` — Registry definitions
- `schema.m` — Validation schema
- Accessor functions in `+registry/` for runtime resolution

### 7. Manifold Health System

Comprehensive mesh quality checking and repair via `+manifold/+health`:
- **Checks**: orientation, connectivity, scale, topology
- **Measures**: quantitative metrics for each check type
- **Repairs**: automatic fixes (orient consistently/outward, split components, rescale)

```matlab
% Check manifold health
issues = M.check();  % Run all checks
issues = M.check('Checks', {'oriented', 'connectivity'});  % Specific checks

% Repair issues
M_fixed = M.repair(issues);  % Automatic repair
M_fixed = M.repair('Repairs', {'orientOutward', 'splitComponents'});  % Manual selection
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
F = bct.field.load('Id', 'test_scalarField_vertex');
```

📚 DOCUMENTATION STRUCTURE

**IMPORTANT**: The documentation folder structure uses standard mkdocs conventions:

```
docs/                          # Documentation project root
├── mkdocs.yml                 # MkDocs configuration
├── docs/                      # Markdown content directory (docs_dir)
│   ├── index.md              # Homepage
│   ├── documentation.md      # Table of contents
│   ├── getting-started/      # Getting started guides
│   ├── concepts/             # Conceptual documentation
│   ├── filters/              # Filter documentation
│   ├── tutorials/            # Step-by-step tutorials
│   ├── api/                  # API reference
│   ├── examples/             # Example gallery
│   ├── about/                # Project information
│   ├── assets/               # Static assets for docs
│   │   ├── models/          # 3D mesh exports (.obj + .json)
│   │   ├── data/            # Field data exports (.json)
│   │   └── images/          # Documentation images
│   ├── javascripts/          # Custom JS (three.js viewer)
│   ├── stylesheets/          # Custom CSS
│   └── viewer/               # Three.js viewer embed
├── site/                      # Generated HTML output (git ignored)
└── overrides/                 # Theme customization (currently disabled)
```

**Documentation terminology**:
- Refer to `docs/` as the "**documentation project**" or "**mkdocs root**"
- Refer to `docs/docs/` as the "**content directory**" or "**markdown files**"
- Refer to `docs/site/` as the "**build output**" or "**generated site**"

**When writing documentation**:
- All markdown files go in `docs/docs/` and subdirectories
- Add pages to navigation in `docs/mkdocs.yml` under the `nav:` section
- Export 3D assets to `docs/docs/assets/models/` using `bct.manifold.exportForDocs()`
- Export field data to `docs/docs/assets/data/` using `bct.field.exportForDocs()`
- The mkdocs server auto-reloads markdown changes, but requires restart for `mkdocs.yml` changes

**Asset export functions**:
```matlab
% Export manifold for three.js viewer
M = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
bct.manifold.exportForDocs(M, 'fsaverage_rh_pial', ...
    'ExportNormals', true, 'ExportTangents', true);

% Export field data for visualization
F = bct.Field(M, values);
bct.field.exportForDocs(F, 'field_name.json');
```

🧪 TESTING FRAMEWORK

**Production Tests:**
```
tests/
```

Use MATLAB's `matlab.unittest` framework for production tests. These are official, publication-ready test files.

Requirements:
- Unit tests for core classes (Manifold, Field, Operator)
- Unit tests for operators (gradient, divergence, curl)
- Unit tests for data loading (bct.data.load, bct.field.load)
- Integration tests for complete workflows
- Performance tests (eigensolver, FEM assembly)

**Development Tests:**
```
dev/test/
```

**IMPORTANT**: During development, Copilot must write temporary test files in `dev/test/` directory, NOT in `tests/`. These development test files serve an important purpose: they allow you to test and refine code during development without polluting the production test suite. Only write production tests in `tests/` when explicitly instructed by the user.

**Canonical Testing Manifold:**

**CRITICAL**: All tests (development and production) must use the canonical testing manifold:

```matlab
M = bct.data.load('Id', 'fsaverage_rh_pial');
```

- **Never use icosphere or other synthetic meshes for testing**
- The `fsaverage_rh_pial` manifold is the standard test surface from the mesh catalog
- Located at `toolbox/+bct/+data/assets/mesh/fsaverage_rh_pial.mat`
- Provides realistic cortical surface geometry for validation
- Ensures consistency across all test files

Example test structure:
```matlab
% Load canonical test manifold
M = bct.data.load('Id', 'fsaverage_rh_pial');

% Test your functionality
ops = M.operators();
assert(~isempty(ops.laplacebeltrami));
```

📚 DOCUMENTATION REQUIREMENTS

**Production Documentation:**
```
docs/
```

Official publication documentation using mkdocs. Must describe:
- Manifold-field paradigm
- FEM and spectral methods
- Operator system and registry
- Field types and validation
- Visualization tools
- API references
- Usage examples

**IMPORTANT**: Do NOT add documentation files to `docs/` during development. This folder contains official publication documentation for bct. 

**Development Notes and Summaries:**
```
notes/
```

**IMPORTANT**: Any summaries, explanations, or documentation needed during development must go into `notes/`. This directory contains contract specifications and development documentation for subsystems (see `notes/*.md`).

🎬 DEMONSTRATION SCRIPTS

**Production Demos:**
```
demo/
```

Official demonstration scripts that will be published with the repository.

**Development Demos:**
```
dev/demo/
```

**IMPORTANT**: During development, Copilot must write temporary demo files in `dev/demo/` directory, NOT in `demo/`. These development demos allow you to validate and demonstrate functionality during development. Only write production demos in `demo/` when explicitly instructed by the user.

**Default Demo Manifold:**

**Unless specified otherwise**, all demos (development and production) must use the canonical manifold:

```matlab
M = bct.data.load('Id', 'fsaverage_rh_pial');
```

- This ensures consistency across all demonstrations
- Provides realistic cortical surface for visual demonstrations
- Users can easily reproduce demos with the bundled catalog asset
- Only use alternative manifolds when explicitly requested or when demonstrating specific features (e.g., sphere topology)

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
2. **Respect field abstraction**: Use `bct.field` for all field operations
3. **Use operator registry**: Apply operators via `bct.operators.apply()`, not direct computation
4. **Follow package structure**: Place code in correct subpackage (+geometry, +topology, +operator, etc.)
5. **Validate schemas**: All registered artifacts must pass schema validation
6. **Write development tests**: During development, test all new functions in `dev/test/` (NOT `tests/`)
7. **Write development demos**: During development, demonstrate functionality in `dev/demo/` (NOT `demo/`)
8. **Document in notes/**: During development, add summaries and specifications in `notes/` (NOT `docs/`)
9. **Use canonical test manifold**: Load `M = bct.data.load('Id', 'fsaverage_rh_pial');` for all tests and demos
10. **Maintain clean OOP style**: Use MATLAB classes with properties, methods, and validation
11. **Handle metadata**: Preserve provenance and metadata through all operations
12. **Production files only when requested**: Write to `tests/`, `demo/`, or `docs/` only when explicitly instructed by the user

**Deprecated concepts (DO NOT USE):**
- `@Domain`, `@Lambda`, `@Omega`, `@Time`, `@Joint` classes (removed)
- `@Signal` class (replaced by field abstraction)
- `@bct` orchestrator class (replaced by package-level functions)
- Domain dual relationships (replaced by spectral projection)

You must write code that integrates CLEANLY with the current Manifold-Field architecture described above.
