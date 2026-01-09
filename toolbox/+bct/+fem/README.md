# bct.fem Package Reference

The `bct.fem` package contains FEM-specific numerical utilities and glue functions.

## Design Philosophy

Following the **FEMContract**:
- **FEM class** defines the variational function space and semantic operations
- **bct.fem package** contains numerical utilities and glue code
- FEM class delegates to package functions (no direct gptoolbox calls)
- No spectral logic here (that's in `bct.eigenpairs`)

---

## Package Structure

```
+bct/+fem/
├─ assembleMass.m          - Assemble FEM mass matrix
├─ assembleStiffness.m     - Assemble stiffness (cotangent) matrix
├─ eigensolve.m            - Thin wrapper for eigenpair computation
└─ applyLaplacian.m        - Numerical application of Laplacian
```

---

## Matrix Assembly (§3.1)

### `assembleMass`
Assemble FEM mass matrix from Manifold.

```matlab
M = bct.fem.assembleMass(Manifold)
M = bct.fem.assembleMass(Manifold, massType)
```

**Inputs:**
- `Manifold` - bct.Manifold object
- `massType` - 'voronoi' (default), 'barycentric', or 'full'

**Returns:** [N×N] sparse mass matrix

**Notes:**
- Uses gptoolbox `massmatrix()` as authoritative source
- 'voronoi' → lumped (diagonal) mass
- 'barycentric' → barycentric dual cell areas
- 'full' → consistent (non-diagonal) mass

---

### `assembleStiffness`
Assemble FEM stiffness (cotangent) matrix from Manifold.

```matlab
K = bct.fem.assembleStiffness(Manifold)
```

**Inputs:**
- `Manifold` - bct.Manifold object

**Returns:** [N×N] sparse stiffness matrix

**Notes:**
- Uses gptoolbox `cotmatrix()` as authoritative source
- Represents discrete Dirichlet energy: ⟨∇u, ∇v⟩
- Positive semi-definite on closed manifolds

---

## Eigenpair Delegation (§3.2)

### `eigensolve`
Compute eigenpairs of FEM Laplace-Beltrami operator.

```matlab
E = bct.fem.eigensolve(FEM, k)
```

**Inputs:**
- `FEM` - bct.FEM object
- `k` - Number of eigenpairs to compute

**Returns:** bct.Eigenpairs object

**Notes:**
- **Thin wrapper** that adapts FEM semantics
- Delegates all spectral logic to `bct.eigenpairs.fromFEM`
- No duplication of solver logic
- Sets proper metadata (operator, basis, manifoldID)

**Design rationale:**
This function exists to maintain clean separation:
- `bct.fem` knows about FEM semantics
- `bct.eigenpairs` knows about spectral algorithms
- No circular dependency

---

## Operator Application (§3.3)

### `applyLaplacian`
Apply Laplace-Beltrami operator to signal.

```matlab
y = bct.fem.applyLaplacian(Stiffness, Mass, x)
```

**Inputs:**
- `Stiffness` - [N×N] sparse stiffness matrix K
- `Mass` - [N×N] sparse mass matrix M
- `x` - [N×1] signal vector

**Returns:** y = L*x where L = M^(-1)*K

**Notes:**
- Numerical application (not spectral computation)
- Uses backslash for M^(-1) (direct solve)
- Suitable for iterative methods, preconditioning

---

## Usage Examples

### Construction workflow
```matlab
% 1. Create Manifold
M = bct.Manifold(struct('V', V, 'F', F));

% 2. Assemble matrices (via FEM constructor)
Mass = bct.fem.assembleMass(M, 'voronoi');
Stiffness = bct.fem.assembleStiffness(M);

% 3. Create FEM object (delegates to package)
fem = bct.FEM(M, 'MassType', 'voronoi');
```

### Direct matrix assembly
```matlab
% If you need matrices without creating FEM object
M = bct.Manifold(struct('V', V, 'F', F));
Mass = bct.fem.assembleMass(M);
Stiffness = bct.fem.assembleStiffness(M);

% Custom operator
L = Mass \ Stiffness;
```

### Eigenpair computation
```matlab
% Via FEM object (recommended)
fem = bct.FEM(M);
E = fem.eigenpairs(100);

% Direct call (if needed)
E = bct.fem.eigensolve(fem, 100);
```

### Operator application
```matlab
% Via FEM method (recommended)
y = fem.applyLaplacian(x);

% Direct call (if you have matrices)
y = bct.fem.applyLaplacian(Stiffness, Mass, x);
```

---

## Architecture Diagram

```
bct.FEM (class)
    │
    ├─ Constructor
    │   ├─► bct.fem.assembleMass()
    │   └─► bct.fem.assembleStiffness()
    │
    ├─ eigenpairs()
    │   └─► bct.fem.eigensolve()
    │        └─► bct.eigenpairs.fromFEM()
    │             └─► bct.eigenpairs.solveGeneralized()
    │
    └─ applyLaplacian()
        └─► bct.fem.applyLaplacian()
```

**Key principle:** FEM class delegates to package functions, which may delegate to other packages. Clean layering with no duplication.

---

## What NOT to Put Here

❌ **Spectral algorithms** → Use `bct.eigenpairs` package
❌ **DEC operations** → Use `bct.dec` package (if it exists)
❌ **Graph operations** → Use `bct.graph` package (if it exists)
❌ **Filters/kernels** → Use `bct.kernel` package
❌ **UI/visualization** → Use `bct.show` package

This package is for:
✅ FEM-specific numerical utilities
✅ Matrix assembly
✅ Thin semantic wrappers
✅ Glue code between FEM and other packages

---

## See Also

- [FEMContract.md](../FEMContract.md) - Design principles
- [FEM.m](../FEM.m) - FEM class definition
- [+eigenpairs/](../+eigenpairs/) - Spectral algorithms
- [Manifold.m](../Manifold.m) - Geometric substrate
