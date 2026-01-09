# bct.eigenpairs Package Reference

The `bct.eigenpairs` package contains factory functions and algorithms for creating and manipulating Eigenpairs objects.

## Design Philosophy

Following the **EigenpairsContract**:
- **Eigenpairs class** owns meaning and invariants
- **bct.eigenpairs package** owns algorithms and workflows
- All functions return new objects (immutability)
- No circular dependencies

---

## Factory Functions

### `fromFEM`
Create Eigenpairs from FEM representation.

```matlab
E = bct.eigenpairs.fromFEM(fem, numModes)
E = bct.eigenpairs.fromFEM(fem, numModes, 'RemoveDC', true)
```

**Inputs:**
- `fem` - bct.FEM object
- `numModes` - Number of eigenmodes to compute

**Options:**
- `RemoveDC` - Remove DC mode (default: true)
- `EigsOpts` - Options passed to `eigs()`

**Returns:** `bct.Eigenpairs` object

**Example:**
```matlab
M = bct.Manifold(struct('V', V, 'F', F));
fem = M.FEM();
E = bct.eigenpairs.fromFEM(fem, 100);
```

---

## Algorithm Functions

### `solveGeneralized`
Solve generalized eigenproblem K*u = λ*M*u.

```matlab
[U, lambda] = bct.eigenpairs.solveGeneralized(K, M, numModes)
```

**Inputs:**
- `K` - Stiffness/operator matrix [N×N sparse]
- `M` - Mass matrix [N×N sparse]
- `numModes` - Number of modes to compute

**Returns:**
- `U` - Eigenvectors [N×k]
- `lambda` - Eigenvalues [k×1] (sorted ascending)

**Notes:**
- Uses `eigs(..., 'SM')` for smallest magnitude
- Enforces real/symmetric assumptions
- Warns on partial convergence

---

### `normalize`
Enforce M-orthonormality of eigenvectors.

```matlab
U_norm = bct.eigenpairs.normalize(U, M)
```

**Inputs:**
- `U` - Eigenvectors [N×k]
- `M` - Mass matrix [N×N sparse]

**Returns:**
- `U_norm` - M-orthonormal eigenvectors

**Ensures:** `U' * M * U = I`

---

### `removeDC`
Remove DC (constant) mode from eigenpairs.

```matlab
[U_noDC, lambda_noDC] = bct.eigenpairs.removeDC(U, lambda)
```

**Inputs:**
- `U` - Eigenvectors [N×k]
- `lambda` - Eigenvalues [k×1]

**Returns:**
- `U_noDC` - Eigenvectors without DC mode [N×(k-1)]
- `lambda_noDC` - Eigenvalues without DC mode [(k-1)×1]

**Notes:**
- Removes eigenmode with smallest |λ|
- Reports removed eigenvalue

---

## Validation & Transformation

### `validate`
Check Eigenpairs invariants.

```matlab
isValid = bct.eigenpairs.validate(E)
```

**Checks:**
1. Dimension consistency
2. M-orthonormality (U' * M * U = I)
3. Eigenvalue ordering (ascending)

**Returns:** `true` if all checks pass

---

### `reorder`
Change eigenvalue ordering.

```matlab
E_desc = bct.eigenpairs.reorder(E, 'descending')
E_asc = bct.eigenpairs.reorder(E, 'ascending')
E_custom = bct.eigenpairs.reorder(E, indices)
```

**Inputs:**
- `E` - bct.Eigenpairs object
- `ordering` - 'ascending', 'descending', or index vector

**Returns:** New Eigenpairs with reordered modes

**Example:**
```matlab
% Sort by contribution to signal
coeffs = E.project(signal);
[~, idx] = sort(abs(coeffs), 'descend');
E_significant = bct.eigenpairs.reorder(E, idx);
```

---

### `merge`
Combine two Eigenpairs objects.

```matlab
E_merged = bct.eigenpairs.merge(E1, E2)
```

**Inputs:**
- `E1`, `E2` - bct.Eigenpairs objects (same manifold)

**Returns:** New Eigenpairs with combined modes

**Notes:**
- Requires matching manifold ID and mass matrix
- Removes duplicate eigenvalues (tolerance: 1e-10)
- Re-sorts in ascending order

**Example:**
```matlab
E_low = bct.eigenpairs.fromFEM(fem, 100);
E_high = fem.eigenpairs(200);
E_all = bct.eigenpairs.merge(E_low, E_high);
```

---

## Workflow Examples

### Basic workflow
```matlab
% 1. Create FEM
M = bct.Manifold(struct('V', V, 'F', F));
fem = M.FEM();

% 2. Compute eigenpairs
E = bct.eigenpairs.fromFEM(fem, 100);

% 3. Validate
bct.eigenpairs.validate(E);

% 4. Use
coeffs = E.project(signal);
filtered = E.reconstruct(coeffs .* exp(-tau * E.Values));
```

### Custom eigenproblem
```matlab
% 1. Solve eigenproblem
[U, lambda] = bct.eigenpairs.solveGeneralized(K, M, k);

% 2. Process
[U, lambda] = bct.eigenpairs.removeDC(U, lambda);
U = bct.eigenpairs.normalize(U, M);

% 3. Create object
E = bct.Eigenpairs(lambda, U, M, ...
    'operator', "Custom", ...
    'basis', "P1-FEM", ...
    'manifoldID', manifoldID);

% 4. Validate
bct.eigenpairs.validate(E);
```

### Adaptive computation
```matlab
% Start with few modes
E1 = bct.eigenpairs.fromFEM(fem, 50);

% Check if sufficient
err = compute_error(E1);
if err > tol
    % Compute more
    E2 = bct.eigenpairs.fromFEM(fem, 150);
    E = bct.eigenpairs.merge(E1, E2);
end
```

---

## See Also

- [EigenpairsContract.md](../toolbox/+bct/EigenpairsContract.md) - Design principles
- [Eigenpairs.m](../toolbox/+bct/Eigenpairs.m) - Class definition
- [FEM.m](../toolbox/+bct/FEM.m) - FEM representation
- [test_eigenpairs_refactor.m](../tests/test_eigenpairs_refactor.m) - Test suite
