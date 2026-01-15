# Discrete Exterior Calculus (DEC)

## Introduction

**Discrete Exterior Calculus (DEC)** is a discrete analog of smooth exterior calculus that operates directly on simplicial complexes (triangle meshes). It provides a principled framework for discretizing differential forms and differential operators while preserving fundamental geometric and topological properties from the smooth theory.

In Bioctree, DEC operators form the foundation of differential geometry computations on manifolds, enabling vector calculus operations (gradient, divergence, curl) through composition of fundamental DEC operators.

## Differential Forms on Meshes

### The Hierarchy of Forms

DEC represents functions and vector fields as **differential forms** living on different parts of the mesh:

- **0-forms**: Functions on vertices (scalar field)
- **1-forms**: Functions on edges (circulation, line integrals)
- **2-forms**: Functions on faces (flux, area integrals)

```matlab
% Load manifold
M = bct.data.load('Id', 'fsaverage_rh_pial');
ops = M.operators();

% 0-form (scalar field on vertices)
omega0 = randn(M.numVertices(), 1);

% Apply exterior derivative: 0-form → 1-form
omega1 = ops.d0 * omega0;  % Edge circulation

% Apply exterior derivative: 1-form → 2-form
omega2 = ops.d1 * omega1;  % Face flux
```

### Geometric Interpretation

| Form | Domain | Geometric Object | Physical Meaning |
|------|--------|------------------|------------------|
| 0-form | Vertices | Point values | Temperature, potential |
| 1-form | Edges | Line integrals | Circulation, work |
| 2-form | Faces | Area integrals | Flux, flow rate |

## Exterior Derivative

### Mathematical Definition

The **exterior derivative** $d$ is the fundamental differential operator in exterior calculus. It generalizes gradient, curl, and divergence into a unified framework:

$$
d: \Omega^k \to \Omega^{k+1}
$$

In DEC, we have two exterior derivative operators:

#### d0: Vertices → Edges (0-form → 1-form)

$$
(d_0 \omega^0)_{ij} = \omega^0_j - \omega^0_i
$$

This measures the **difference** of a scalar field across an edge $(i,j)$.

**Matrix form**: $d_0$ is an $[E \times N]$ matrix where:
- $E$ = number of edges
- $N$ = number of vertices

```matlab
% Apply d0
omega0 = rand(M.numVertices(), 1);
omega1 = ops.d0 * omega0;  % [numEdges × 1]

% Check size
size(ops.d0)  % [E × N]
```

#### d1: Edges → Faces (1-form → 2-form)

$$
(d_1 \omega^1)_f = \sum_{e \in \partial f} s_{ef} \omega^1_e
$$

where $s_{ef} = \pm 1$ depending on edge orientation relative to face.

This measures the **circulation** around a face boundary.

**Matrix form**: $d_1$ is an $[F \times E]$ matrix where:
- $F$ = number of faces
- $E$ = number of edges

```matlab
% Apply d1
omega1 = rand(M.numEdges(), 1);
omega2 = ops.d1 * omega1;  % [numFaces × 1]

% Check size
size(ops.d1)  % [F × E]
```

### Key Property: d ∘ d = 0

A fundamental property of the exterior derivative:

$$
d_{k+1} \circ d_k = 0
$$

In our discrete setting:

$$
d_1 \cdot d_0 = 0
$$

This means: **the circulation of a gradient is always zero** (curl of gradient = 0).

```matlab
% Verify d1 · d0 = 0
omega0 = rand(M.numVertices(), 1);
result = ops.d1 * (ops.d0 * omega0);
norm(result)  % Should be numerically ~0
```

## Codifferential (Adjoint)

### Definition

The **codifferential** $\delta$ is the adjoint of the exterior derivative with respect to the inner product defined by the Hodge star:

$$
\delta = (-1)^{nk+n+1} \star d \star
$$

For 2D surfaces ($n=2$):

#### dd0: Edges → Vertices (1-form → 0-form)

Adjoint of $d_0$, analogous to **divergence**.

$$
\delta_0 = \star_0 d_0^\top \star_1
$$

**Matrix form**: $dd_0$ is an $[N \times E]$ matrix.

```matlab
% Apply dd0 (divergence-like operator)
omega1 = rand(M.numEdges(), 1);
omega0 = ops.dd0 * omega1;  % [numVertices × 1]

size(ops.dd0)  % [N × E]
```

#### dd1: Faces → Edges (2-form → 1-form)

Adjoint of $d_1$, analogous to boundary operator.

$$
\delta_1 = \star_1 d_1^\top \star_2
$$

**Matrix form**: $dd_1$ is an $[E \times F]$ matrix.

```matlab
% Apply dd1
omega2 = rand(M.numFaces(), 1);
omega1 = ops.dd1 * omega2;  % [numEdges × 1]

size(ops.dd1)  % [E × F]
```

## Hodge Star Operators

### Definition

The **Hodge star** $\star$ is a linear operator that encodes the metric structure of the manifold. It maps $k$-forms to $(n-k)$-forms where $n$ is the manifold dimension.

For surfaces ($n=2$):

| Operator | Mapping | Dimension |
|----------|---------|-----------|
| $\star_0$ | 0-form → 2-form | $[F \times N]$ |
| $\star_1$ | 1-form → 1-form | $[E \times E]$ |
| $\star_2$ | 2-form → 0-form | $[N \times F]$ |

### Geometric Meaning

- **$\star_0$**: Maps vertex values to dual face areas (Voronoi cells)
- **$\star_1$**: Maps edge values to dual edge values (relates primal/dual)
- **$\star_2$**: Maps face values to vertex values (face-to-vertex averaging)

```matlab
% Access Hodge stars
hd0 = ops.dec.hd0;   % [F × N]
hd1 = ops.dec.hd1;   % [E × E]
hd2 = ops.dec.hd2;   % [N × F]
```

### Inverse Hodge Stars

The inverse Hodge stars $\star^{-1}$ map in the opposite direction:

```matlab
% Access inverse Hodge stars
hdd0 = ops.dec.hdd0;  % [N × F]
hdd1 = ops.dec.hdd1;  % [E × E]
hdd2 = ops.dec.hdd2;  % [F × N]
```

## Vector Calculus via DEC

### Gradient

The **gradient** of a scalar field (0-form) produces a tangent vector field at faces.

$$
\nabla f = \sharp(d_0 f)
$$

where $\sharp$ is the sharp operator (converts 1-forms to tangent vectors).

```matlab
% Compute gradient using DEC
f = rand(M.numVertices(), 1);
grad_f = ops.gradient * f;  % [3*numFaces × 1]

% The gradient operator is: sharp ∘ d0
% It produces tangent2 vectors at face centers
```

**Implementation**:
```matlab
ops.gradient = sharp * d0
```

### Divergence

The **divergence** of a tangent vector field produces a scalar field at vertices.

$$
\nabla \cdot \mathbf{v} = \delta_0(\flat(\mathbf{v}))
$$

where $\flat$ is the flat operator (converts vectors to 1-forms).

```matlab
% Divergence operator: dd0 (primal route)
% For tangent vectors at faces → scalars at vertices
div_op = ops.divergence;  % [numVertices × 3*numFaces]
```

**Implementation**:
```matlab
ops.divergence = dd0 ∘ flat
```

### Curl

The **curl** measures rotation of a vector field.

For 2D tangent fields on surfaces:

$$
\nabla \times \mathbf{v} = \delta_1(\flat(\mathbf{v}))
$$

```matlab
% Curl operator (edge → face or face → scalar depending on context)
curl_op = ops.curl;
```

### Laplacian (Hodge Laplacian)

The **Hodge Laplacian** on $k$-forms:

$$
\Delta_k = \delta_{k+1} d_k + d_{k-1} \delta_k
$$

#### 0-form Laplacian (Laplace-Beltrami)

$$
\Delta_0 = \delta_0 d_0 = dd_0 \cdot d_0
$$

This is the **Laplace-Beltrami operator** on scalar fields.

```matlab
% 0-form Laplacian
Lap0 = ops.hodgelaplacian.kform0;  % [N × N]

% Equivalent to:
Lap0_manual = ops.dd0 * ops.d0;
```

#### 1-form Laplacian

$$
\Delta_1 = d_0 \delta_0 + \delta_1 d_1
$$

```matlab
% 1-form Laplacian (on edges)
Lap1 = ops.hodgelaplacian.kform1;  % [E × E]

% Computed as:
Lap1_manual = ops.d0 * ops.dd0 + ops.dd1 * ops.d1;
```

#### 2-form Laplacian

$$
\Delta_2 = d_1 \delta_1
$$

```matlab
% 2-form Laplacian (on faces)
Lap2 = ops.hodgelaplacian.kform2;  % [F × F]

% Computed as:
Lap2_manual = ops.d1 * ops.dd1;
```

## Musical Isomorphisms

DEC provides **musical isomorphisms** that convert between vector fields and differential forms:

### Flat Operator (♭)

Converts vector fields to differential forms:

- **flatPP**: Primal vectors → Primal 1-forms
- **flatDP**: Dual vectors → Primal 1-forms  
- **flatDD**: Dual vectors → Dual 1-forms

```matlab
% Access flat operators
flat_pp = ops.dec.flatPP;
flat_dp = ops.dec.flatDP;
flat_dd = ops.dec.flatDD;
```

### Sharp Operator (♯)

Converts differential forms to vector fields:

- **sharpPD**: Primal 1-forms → Dual vectors
- **sharpDD**: Dual 1-forms → Dual vectors

```matlab
% Access sharp operators
sharp_pd = ops.dec.sharpPD;
sharp_dd = ops.dec.sharpDD;
```

## Complete DEC Operator Suite

Access all DEC operators through the Manifold:

```matlab
M = bct.data.load('Id', 'fsaverage_rh_pial');
ops = M.operators();

% Exterior derivatives
d0 = ops.d0;      % [E × N]
d1 = ops.d1;      % [F × E]

% Codifferentials
dd0 = ops.dd0;    % [N × E]
dd1 = ops.dd1;    % [E × F]

% Hodge stars
hd0 = ops.dec.hd0;    % [F × N]
hd1 = ops.dec.hd1;    % [E × E]
hd2 = ops.dec.hd2;    % [N × F]

% Inverse Hodge stars
hdd0 = ops.dec.hdd0;  % [N × F]
hdd1 = ops.dec.hdd1;  % [E × E]
hdd2 = ops.dec.hdd2;  % [F × N]

% Musical isomorphisms
flatPP = ops.dec.flatPP;
flatDP = ops.dec.flatDP;
flatDD = ops.dec.flatDD;
sharpPD = ops.dec.sharpPD;
sharpDD = ops.dec.sharpDD;

% Vector calculus operators (compositions)
gradient = ops.gradient;         % [3*F × N]
divergence = ops.divergence;     % [N × 3*F]
curl = ops.curl;                 % [F × E]

% Hodge Laplacians
lap0 = ops.hodgelaplacian.kform0;  % [N × N]
lap1 = ops.hodgelaplacian.kform1;  % [E × E]
lap2 = ops.hodgelaplacian.kform2;  % [F × F]
```

## Example: Heat Diffusion via DEC

```matlab
% Load manifold
M = bct.data.load('Id', 'fsaverage_rh_pial');
ops = M.operators();

% Initial condition (0-form on vertices)
f0 = zeros(M.numVertices(), 1);
f0(1000) = 1.0;  % Point source

% Time parameters
dt = 0.01;
nsteps = 100;

% Discrete heat equation: df/dt = -Δf
% Forward Euler: f(t+dt) = f(t) - dt * Δf(t)
Lap0 = ops.hodgelaplacian.kform0;

f = f0;
for t = 1:nsteps
    f = f - dt * (Lap0 * f);
end

% Visualize
V = bct.ui.manifold.Viewer(M);
V.show(f);
```

## Example: Vector Field Calculus

```matlab
% Create a tangent vector field at faces
M = bct.data.load('Id', 'fsaverage_rh_pial');
ops = M.operators();

% Random tangent vectors at face centers
vec_field = randn(3 * M.numFaces(), 1);

% Compute divergence
div_field = ops.divergence * vec_field;  % [N × 1] scalar at vertices

% Compute curl
curl_field = ops.curl * (ops.dec.flatPP * vec_field);  % Edge-based

% Verify that div(curl(v)) should be small (modulo numerical error)
div_curl = ops.divergence * (ops.dec.sharpPD * curl_field);
max(abs(div_curl))  % Should be near 0
```

## Properties and Guarantees

DEC preserves several fundamental properties from smooth exterior calculus:

1. **Stokes' Theorem**: $\int_{\partial \Omega} \omega = \int_{\Omega} d\omega$
   - Discrete integration and differentiation satisfy discrete Stokes theorem exactly
   
2. **De Rham Cohomology**: Kernel and image structure of $d$ operators preserved
   - $\text{ker}(d_{k+1}) \supseteq \text{im}(d_k)$
   
3. **Metric Independence**: Exterior derivative $d$ is independent of metric
   - Only Hodge star $\star$ depends on metric
   
4. **Exactness**: $d \circ d = 0$ holds exactly in discrete setting
   - No numerical approximation error in this fundamental identity

## Comparison: DEC vs FEM

| Aspect | DEC | FEM |
|--------|-----|-----|
| **Basis** | Forms on simplices | Nodal basis functions |
| **Derivatives** | Combinatorial (exact) | Approximation (derivative of basis) |
| **Stokes' Theorem** | Exact | Approximate |
| **Metric** | Enters via Hodge star | Enters via integration |
| **Natural for** | Topology, cohomology | Boundary value problems |

## Further Reading

- **Desbrun et al. (2005)**: "Discrete Exterior Calculus" - Foundational paper
- **Hirani (2003)**: PhD thesis on DEC for computational electromagnetism
- **Crane et al. (2013)**: "Geodesics in Heat" - DEC application
- **Mohamed et al. (2016)**: "Discrete Differential Geometry" - Comprehensive reference

## See Also

- [Laplace-Beltrami Operator](laplace-beltrami.md) - Spectral properties
- [Manifolds](manifolds.md) - Mesh representation
- API Reference: `bct.manifold.operator.dec`
