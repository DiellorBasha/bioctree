# bct.dec — Discrete Exterior Calculus Operators

This package provides pure functional operators for Discrete Exterior Calculus (DEC) on manifolds.

## Design Principles

1. **DECLab is the mathematical authority** — all operators use DECLab backend primitives
2. **bct.DEC is a thin wrapper** — the class holds the backend, does no computation
3. **Operators are pure functions** — stateless, side-effect free
4. **Eigenpairs delegate to bct.eigenpairs** — no eigensolver logic in DEC

## Package Structure

### Primitive Accessors
Access DECLab backend operators:
- `d0(DEC)` — Exterior derivative 0→1
- `d1(DEC)` — Exterior derivative 1→2
- `star0(DEC)` — Hodge star for 0-forms
- `star1(DEC)` — Hodge star for 1-forms
- `star2(DEC)` — Hodge star for 2-forms

### Core Operators
Apply operators to data:
- `gradient(DEC, f0)` — Compute gradient (0-form → 1-form)
- `divergence(DEC, a1)` — Compute divergence (1-form → 0-form)
- `curl(DEC, a1)` — Compute curl (1-form → 2-form)

### Laplacians
Form-degree specific Laplacians:
- `laplacian0(DEC)` — Scalar Laplacian on vertices
- `laplacian1(DEC)` — Vector Laplacian on edges
- `laplacian2(DEC)` — Density Laplacian on faces

### Spectral
Eigensolvers:
- `eigensolve(DEC, formDegree, k)` — Compute eigenpairs (delegates to bct.eigenpairs)

## Usage Example

```matlab
% Create Manifold
M = bct.Manifold(V, F);

% Get DEC representation
D = M.DEC();

% Compute gradient of scalar field
f = randn(M.numVertices(), 1);
grad_f = bct.dec.gradient(D, f);

% Compute 0-form eigenpairs
E = bct.dec.eigensolve(D, 0, 50);
```

## Conventions

### Form Degrees
- **0-form**: Vertex-based scalar fields [V×1]
- **1-form**: Edge-based oriented fields [E×1]
- **2-form**: Face-based density fields [F×1]

### Operator Signatures
All operators follow: `output = bct.dec.operator(DEC, input, ...)`
- First argument is always bct.DEC instance
- Second argument is primary data
- Additional arguments are explicit parameters

### Inner Products
Hodge stars define the inner products:
- 0-forms use `star0` (vertex areas)
- 1-forms use `star1` (edge lengths)
- 2-forms use `star2` (face areas)

## Integration

### Registry
All DEC operators are registered in `bct.registry.operators()` with:
- `domain = "dec"`
- `representation = "bct.DEC"`
- Proper form-degree typing

### Runtime
DEC operators appear in `bct.runtime.operators(context)` when:
- DECLab is available
- DEC representation exists in context

## Testing

Test coverage includes:
- Shape tests (correct dimensions)
- Consistency tests (d²=0, etc.)
- Adjointness tests (divergence = -gradient*)
- Spectral tests (orthonormality under Hodge stars)

## References

- Desbrun et al., "Discrete Exterior Calculus" (2005)
- DECLab: https://github.com/DillonCislo/DECLab
- bct.DEC class documentation
- bct.eigenpairs package documentation
