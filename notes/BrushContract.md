# bct.brush — Design Contract (Authoritative)

## 1. Purpose

`bct.brush` implements the **spatial selection layer** for interactive and programmatic selection of vertices, paths, and spatiotemporal patterns on manifolds. Brushes are **pure functions** that produce weighted selection fields, enabling:

- Interactive region painting and selection
- Trajectory definition and spatiotemporal activation patterns
- Data-driven masking and ROI (region of interest) definition
- Compositional selection operations

This contract commits to a single strategy:

> **Brushes are pure functions `w = brush(manifold, params)` that return weighted selection fields.  
> `bct.registry.brushes` describes semantics (categories, parameters, requirements).  
> `bct.runtime.brushes` provides session-aware dispatch and availability filtering.**

This yields:
- a discoverable catalog of selection primitives,
- clean separation between definition (registry) and execution (brush functions),
- composability with filters, operators, and UI systems.

---

## 2. Concepts and Definitions

### 2.1 Brush

A **brush** is a pure function with signature:

```matlab
w = brush(manifold, params)
```

where:
- `manifold` is a `bct.Manifold` object
- `params` is a struct with brush-specific parameters
- `w` is an `[N×1]` or `[N×T]` weighted selection field

Brushes are **stateless and pure**: calling the same brush with the same inputs produces identical outputs.

### 2.2 Selection field

A **selection field** is a sparse or dense numeric array encoding spatial or spatiotemporal weights:

- **Spatial**: `[N×1]` where `N` = number of vertices
- **Spatiotemporal**: `[N×T]` where `T` = number of time steps

Values typically range `[0, 1]` but may be unnormalized or complex depending on context.

### 2.3 Brush categories

Brushes are organized by **selection pattern**:

| Category | Pattern | Output | Example |
|----------|---------|--------|---------|
| **patch** | Unordered spatial region | `[N×1]` | Gaussian blob, spectral patch |
| **trajectory** | Ordered spatial path | `[N×1]` | Geodesic, spectral trajectory |
| **time** | Spatiotemporal evolution | `[N×T]` | Heat diffusion, wave propagation |
| **dynamic** | Context-dependent patterns | Variable | Future: data-driven, interactive |

### 2.4 Brush specification (BrushSpec)

A **BrushSpec** is metadata returned by `bct.registry.brushes()` that defines:

- Identity (`Id`, `Name`)
- Category (`patch`, `trajectory`, `time`, `dynamic`)
- Required/optional parameters with schemas
- Domain requirements (Manifold properties, FEM, Graph, etc.)
- Algorithm function handle
- Tags for filtering and discovery

---

## 3. Package Boundaries and Ownership

### 3.1 What belongs in `bct.brush`

`bct.brush` owns:

1. **Brush implementations**: organized by category
   - `+patch/`: unordered spatial selections
   - `+trajectory/`: ordered paths
   - `+time/`: spatiotemporal patterns
   - `+design/`: interactive brush designer UI (future)
   - `+utils/`: shared utilities

2. **Brush application**: `bct.brush.apply(id, manifold, params)`

3. **Selection utilities**: `bct.brush.embed(indices, N, weights)`

### 3.2 What does NOT belong in `bct.brush`

- Semantic catalog definitions (belong to `bct.registry.brushes`)
- Session-aware filtering (belongs to `bct.runtime.brushes`)
- Filter application (belongs to `bct.filter`)
- Kernel definitions (belong to `bct.kernel`)
- Representation construction (belongs to `Manifold.FEM()`, etc.)
- Signal ownership or caching
- UI state management beyond transient interaction

### 3.3 Registry and runtime integration points

- `bct.registry.brushes()` is the **authoritative catalog**
- `bct.runtime.brushes(context)` provides **session-aware availability**:
  - filters brushes by satisfied dependencies
  - provides UI-ready parameter schemas

---

## 4. Brush Implementation Contract

### 4.1 Canonical signature

All brush functions must follow:

```matlab
function w = brushname(manifold, params)
    arguments
        manifold (1,1) bct.Manifold
        params struct
    end
    
    % Implementation
    % ...
    
    % Return sparse selection field
    w = sparse(w);
end
```

**Hard requirements**:
- Function must be **pure** (no side effects, deterministic)
- Must validate required parameters
- Must use `bct.Manifold` API (no direct property access to deprecated fields)
- Must return sparse array when practical

### 4.2 Parameter conventions

**Required parameters**: Must throw namespaced error if missing
```matlab
if ~isfield(params, 'source')
    error('bct:brush:patch:gaussian:MissingParameter', ...
          'params.source (seed vertex) is required');
end
```

**Optional parameters**: Must provide sensible defaults
```matlab
if ~isfield(params, 'metric')
    params.metric = "geometry";  % default
end
```

**Parameter naming conventions**:
- `source` / `target`: vertex indices for path-based brushes
- `seed`: vertex index for patch-based brushes
- `sigma` / `tau`: width/scale parameters
- `kernel`: kernel type for spectral brushes
- `metric`: distance metric (`"geometry"`, `"fem"`, custom)
- `bandwidth`: spectral truncation for FEM-based brushes

### 4.3 Representation access patterns

Brushes access Manifold capabilities through **representation ports**:

**FEM representation** (for spectral brushes):
```matlab
fem = manifold.FEM();
E = fem.eigenpairs(k);
coeffs = E.project(signal);
w = E.reconstruct(filtered_coeffs);
```

**Graph representation** (for geometric brushes):
```matlab
graph = manifold.Graph();
path = graph.shortestPath(source, target, metric);
indices = graph.nearest(seed, radius, metric);
```

**Direct geometry** (when needed):
```matlab
V = manifold.Vertices;  % [N×3] coordinates
F = manifold.Faces;     % [M×3] connectivity
```

### 4.4 Output conventions

**Spatial brushes** (`[N×1]`):
- Sparse when practical (threshold small values)
- Normalized to `[0, 1]` unless semantically incorrect
- Non-negative unless complex analysis is explicit

**Spatiotemporal brushes** (`[N×T]`):
- Sparse when practical
- Columns represent time steps
- Each column follows spatial conventions

---

## 5. Brush Categories and Implementation Patterns

### 5.1 Patch brushes (`+patch/`)

**Purpose**: Create unordered spatial selections (blobs, regions)

**Common patterns**:
- Distance-based: Gaussian, nearest-neighbor
- Spectral: eigenmode filtering
- Data-driven: threshold, clustering (future)

**Example**: [gaussian.m](toolbox/+bct/+brush/+patch/gaussian.m)
```matlab
function w = gaussian(manifold, params)
    % Compute distances from source
    G = manifold.Graph().matlabGraph(params.metric);
    d = distances(G, params.source);
    
    % Apply Gaussian kernel
    w = exp(-d.^2 / (2*params.sigma^2));
    w(w < 1e-6) = 0;  % Sparsify
    w = sparse(w);
end
```

### 5.2 Trajectory brushes (`+trajectory/`)

**Purpose**: Create ordered spatial paths or corridors

**Common patterns**:
- Geodesic: shortest path
- Spectral-filtered: smooth paths respecting manifold structure
- Corridor: thickened paths with width parameter

**Example**: [geodesic.m](toolbox/+bct/+brush/+trajectory/geodesic.m)
```matlab
function w = geodesic(manifold, params)
    % Compute shortest path
    path = manifold.Graph().shortestPath(params.source, params.target, params.metric);
    
    % Optionally thicken to corridor
    if params.width > 0
        indices = expandPathToCorridor(manifold, path, params.width);
    else
        indices = path;
    end
    
    w = bct.brush.embed(indices, manifold.numVertices());
end
```

### 5.3 Time brushes (`+time/`)

**Purpose**: Create spatiotemporal patterns evolving over time

**Common patterns**:
- Heat diffusion along trajectory
- Wave propagation
- Spectral evolution with time-varying kernels

**Example**: [heat.m](toolbox/+bct/+brush/+time/heat.m)
```matlab
function w = heat(manifold, time, params)
    % Get eigenpairs
    E = manifold.FEM().eigenpairs(params.numModes);
    
    % Project initial pattern to spectral domain
    spectral_coeffs = E.project(initial_pattern);
    
    % Evolve with time-varying heat kernel
    w = zeros(manifold.numVertices(), time.N);
    for t = 1:time.N
        kernel = exp(-params.tau(t) * E.Values);
        w(:, t) = E.reconstruct(spectral_coeffs .* kernel);
    end
    
    w = sparse(w);
end
```

### 5.4 Design brushes (`+design/`)

**Purpose**: Interactive brush construction and visualization (future)

**Scope**:
- UI components for brush parameter tuning
- Visual feedback systems
- Brush composition tools

**Status**: Architecture defined but implementation pending

---

## 6. Integration with bct.kernel

Spectral brushes leverage `bct.kernel` for kernel definitions:

```matlab
% Get kernel from registry
k = bct.kernel.bind(params.kernel, kernel_params);

% Apply to eigenvalues
kernel_response = k(eigenvalues);

% Filter in spectral domain
filtered_coeffs = spectral_coeffs .* kernel_response;
```

**Separation of concerns**:
- `bct.kernel`: defines mathematical kernels
- `bct.brush`: applies kernels to create spatial selections
- `bct.filter`: applies kernels to transform signals

---

## 7. Utility Functions

### 7.1 `bct.brush.embed(indices, N, weights)`

**Purpose**: Embed sparse indices into full selection field

```matlab
w = bct.brush.embed(indices, N, weights)
```

- `indices`: `[K×1]` vertex indices
- `N`: total number of vertices
- `weights`: optional `[K×1]` weights (default: all 1s)
- Returns: `[N×1]` sparse vector

**Usage**:
```matlab
% Binary selection
w = bct.brush.embed([10; 20; 30], 1000);

% Weighted selection
w = bct.brush.embed([10; 20; 30], 1000, [0.5; 0.8; 1.0]);
```

### 7.2 `bct.brush.apply(id, manifold, params)`

**Purpose**: Universal brush dispatcher

```matlab
w = bct.brush.apply(id, manifold, params)
```

- Looks up brush in registry
- Validates parameters
- Executes brush function
- Returns selection field

**Usage**:
```matlab
params = struct('source', 100, 'sigma', 5.0, 'metric', "geometry");
w = bct.brush.apply('patch_gaussian', M, params);
```

---

## 8. Registry Integration (`bct.registry.brushes`)

The registry must provide, at minimum:

### 8.1 Required fields per brush

```matlab
spec = struct(...
    'Id',          "patch_gaussian", ...           % Unique identifier
    'Name',        "Gaussian Patch", ...           % Display name
    'Category',    "patch", ...                    % patch|trajectory|time|dynamic
    'Algorithm',   @bct.brush.patch.gaussian, ...  % Function handle
    'ParamNames',  ["source","sigma","metric"], ...% Required parameters
    'ParamSchema', struct(...                      % Parameter validation
        'source', struct('type', 'integer', 'range', [1, Inf]), ...
        'sigma',  struct('type', 'numeric', 'range', [0, Inf]), ...
        'metric', struct('type', 'string', 'values', ["geometry","fem"])), ...
    'Defaults',    struct('metric', "geometry"), ...% Default values
    'Requires',    ["Graph"], ...                  % Representation requirements
    'OutputDims',  "spatial", ...                  % spatial|spatiotemporal
    'Tags',        ["geometric","smooth","distance-based"], ...
    'Description', "Gaussian-weighted spatial selection" ...
);
```

### 8.2 Category taxonomy (required)

| Category | Description | Output Shape | Examples |
|----------|-------------|--------------|----------|
| `patch` | Spatial region | `[N×1]` | Gaussian, spectral, nearest |
| `trajectory` | Spatial path | `[N×1]` | Geodesic, spectral trajectory |
| `time` | Spatiotemporal | `[N×T]` | Heat, wave, time-spectral |
| `dynamic` | Context-dependent | Variable | Interactive, data-driven |

### 8.3 Requirement declarations

Brushes declare representation dependencies:
- `"Graph"`: requires `manifold.Graph()` available
- `"FEM"`: requires `manifold.FEM()` available
- `"DEC"`: requires `manifold.DEC()` available
- `"Eigenpairs"`: requires eigenbasis computable

Runtime filters unavailable brushes based on manifold capabilities.

---

## 9. Runtime Integration (`bct.runtime.brushes`)

### 9.1 Purpose

Runtime provides **session-aware brush availability**:
- Filters by satisfied dependencies
- Validates manifold compatibility
- Provides UI-ready parameter schemas

### 9.2 Core runtime functions

**`bct.runtime.brushes.dictionary(context)`**
- Returns map: `BrushId` → `BrushSpec`
- Filters by `context.manifold` capabilities
- Only returns brushes whose requirements are satisfied

**`bct.runtime.brushes.resolve(id, context)`**
- Returns fully-configured brush specification
- Validates parameter schema against context
- Provides default parameter values

**`bct.runtime.brushes.list(category, context)`**
- Returns available brush IDs filtered by category
- Respects context constraints

### 9.3 Context structure

```matlab
context = struct(...
    'manifold', M, ...              % bct.Manifold object
    'representations', struct(...   % Available representations
        'FEM', true, ...
        'Graph', true, ...
        'DEC', false), ...
    'eigenpairs', struct(...       % Eigenpair availability
        'computed', true, ...
        'numModes', 100) ...
);
```

---

## 10. Error Handling and Diagnostics

All errors must be namespaced and diagnostic:

**Missing required parameter**:
```matlab
error('bct:brush:patch:gaussian:MissingParameter', ...
      'params.source is required');
```

**Unknown brush**:
```matlab
error('bct:brush:UnknownBrush', ...
      'Brush "%s" not found in registry', id);
```

**Unsatisfied dependency**:
```matlab
error('bct:brush:DependencyMissing', ...
      'Brush "%s" requires Graph representation', id);
```

**Invalid parameter value**:
```matlab
error('bct:brush:InvalidParameter', ...
      'params.sigma must be positive, got: %f', params.sigma);
```

---

## 11. Performance and Numerical Considerations

### 11.1 Sparsity

- Use sparse arrays when selection is localized
- Threshold small values (< 1e-6) for sparsity
- Document when dense output is necessary

### 11.2 Vectorization

- Avoid loops over vertices where possible
- Use matrix operations for efficiency
- Batch process time steps in spatiotemporal brushes

### 11.3 Caching

Brushes themselves must not cache results (they're pure functions).
Caching may be implemented at higher layers:
- UI systems cache brush results for interaction
- Runtime may memoize expensive computations

### 11.4 Large mesh considerations

For meshes with N > 100k vertices:
- Prefer spectral methods with limited modes (k << N)
- Use spatial truncation for geometric methods
- Consider block processing for spatiotemporal patterns

---

## 12. Composition and Advanced Patterns

### 12.1 Brush combination

Brushes can be combined using standard operations:

```matlab
w1 = bct.brush.apply('patch_gaussian', M, params1);
w2 = bct.brush.apply('patch_spectral', M, params2);

% Union (max)
w_union = max(w1, w2);

% Intersection (min)
w_intersect = min(w1, w2);

% Weighted blend
w_blend = alpha * w1 + (1-alpha) * w2;
```

### 12.2 Sequential application

```matlab
% Create base selection
w1 = bct.brush.apply('trajectory_geodesic', M, params1);

% Modulate with spectral filter
k = bct.kernel.bind('Gaussian', struct('sigma', 10));
E = M.FEM().eigenpairs(100);
coeffs = E.project(w1);
filtered_coeffs = coeffs .* k(E.Values);
w2 = E.reconstruct(filtered_coeffs);
```

### 12.3 Time-varying spatial brushes (future)

```matlab
% Define brush parameter trajectory
params_traj = @(t) struct('source', source, 'sigma', sigma_t(t));

% Apply at each time step
w = zeros(N, T);
for t = 1:T
    w(:, t) = bct.brush.apply('patch_gaussian', M, params_traj(t));
end
```

---

## 13. Testing Requirements

Minimum unit tests:

1. **All registered brushes execute without error**
   ```matlab
   for each brush in registry:
       w = brush(test_manifold, valid_params);
       assert(size(w, 1) == test_manifold.numVertices());
   ```

2. **Parameter validation**
   ```matlab
   % Missing required parameter throws
   assertError(@() brush(M, struct()), 'bct:brush:*:MissingParameter');
   
   % Invalid parameter value throws
   assertError(@() brush(M, struct('sigma', -1)), 'bct:brush:*:InvalidParameter');
   ```

3. **Output format**
   ```matlab
   % Spatial brushes return [N×1]
   assert(isvector(w) && numel(w) == N);
   
   % Spatiotemporal brushes return [N×T]
   assert(ismatrix(w) && size(w, 1) == N);
   
   % Sparse when appropriate
   assert(issparse(w) || nnz(w) / numel(w) > 0.5);
   ```

4. **Representation requirements**
   ```matlab
   % Brush requiring FEM fails gracefully on manifold without FEM
   assertError(@() spectral_brush(manifold_no_fem, params), ...
               'bct:brush:*:DependencyMissing');
   ```

5. **Determinism**
   ```matlab
   w1 = brush(M, params);
   w2 = brush(M, params);
   assert(isequal(w1, w2), 'Brush must be deterministic');
   ```

---

## 14. Documentation Standards

Each brush function must include:

1. **Purpose**: One-line description
2. **Syntax**: Function signature
3. **Parameters**: Required and optional with types
4. **Output**: Description and dimensions
5. **Description**: Algorithm overview
6. **Examples**: Minimal working example
7. **See also**: Related brushes and functions

Example template:
```matlab
function w = brushname(manifold, params)
%BCT.BRUSH.CATEGORY.BRUSHNAME  Short description
%
%   w = bct.brush.category.brushname(manifold, params)
%
%   Required params
%   ---------------
%   params.field1 : description
%   params.field2 : description
%
%   Optional params
%   ---------------
%   params.field3 : description (default: value)
%
%   Output
%   ------
%   w : [N×1] or [N×T] weighted selection field
%
%   Description:
%   Detailed explanation of algorithm and behavior.
%
%   Example:
%   --------
%   params = struct('source', 100, 'sigma', 5.0);
%   w = bct.brush.category.brushname(M, params);
%
%   See also: bct.brush.apply, bct.brush.category.other
```

---

## 15. Migration Path and Backward Compatibility

### 15.1 Current state (pre-integration)

- Brushes exist in `+bct/+brush/` with standalone registry
- No integration with main `bct.registry` / `bct.runtime`
- Direct function calls or via `bct.brush.apply()`

### 15.2 Target state (post-integration)

- Brushes registered in `bct.registry.brushes()`
- Runtime provides session-aware filtering
- Maintains backward compatibility with existing API
- `bct.brush.apply()` becomes thin wrapper over runtime dispatch

### 15.3 Transition strategy

1. Create `bct.registry.brushes()` alongside existing `bct.brush.registry()`
2. Implement `bct.runtime.brushes.*` infrastructure
3. Update `bct.brush.apply()` to use runtime when available
4. Deprecate standalone registry after migration period
5. Update documentation and examples

---

## 16. Future Extensions

### 16.1 Interactive brush designer

UI component for real-time brush parameter tuning:
- Visual feedback on manifold
- Parameter sliders and controls
- Brush composition tools

**Scope**: `+bct/+brush/+design/`

### 16.2 Data-driven brushes

Brushes that adapt to data characteristics:
- Clustering-based selection
- Saliency-driven weighting
- Machine learning integration

**Category**: `dynamic`

### 16.3 Brush algebra

Formal operations on brushes:
- Union, intersection, complement
- Morphological operations (dilate, erode)
- Boolean combinations

### 16.4 Brush serialization

Save/load brush configurations:
- Parameter presets
- Brush history
- Reproducibility support

---

## 17. Summary

The brush layer provides **spatial and spatiotemporal selection primitives**:

- **Brushes are pure functions**: `w = brush(manifold, params)`
- **Registry defines semantics**: `bct.registry.brushes()`
- **Runtime provides dispatch**: `bct.runtime.brushes(context)`
- **Three main categories**: patch, trajectory, time
- **Representation-agnostic**: uses FEM, Graph, DEC through ports
- **Composable**: works with kernels, filters, operators

This design is:
- Discoverable (registry)
- Performant (sparse, vectorized)
- Extensible (new categories and brushes)
- Testable (pure functions)
- UI-friendly (runtime parameter schemas)
