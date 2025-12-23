# BCT Performance Tests

This directory contains performance and timing tests for the BCT toolbox.

## Purpose

Performance tests verify that critical operations complete within acceptable time bounds and that the system scales appropriately with input size. Unlike unit tests which verify correctness, performance tests verify efficiency.

## Running Performance Tests

```matlab
% Run all performance tests
results = runtests('tests/performance');

% Run specific performance test
results = runtests('tests/performance/test_perf_ManifoldConstruction.m');

% Run with verbose output
results = runtests('tests/performance', 'OutputDetail', 'Verbose');
```

## Test Organization

### test_perf_ManifoldConstruction.m

Tests for `bct.Manifold` construction performance:

- **Construction time**: Verifies construction completes within time bounds
  - Small meshes (100-1k vertices): < 0.2s
  - Medium meshes (10k vertices): < 0.5s  
  - Large meshes (163k vertices, fsaverage6): < 3.5s

- **Scaling**: Verifies construction time scales linearly with mesh size

- **Lazy initialization**: Verifies FEM and eigenpairs are NOT computed during construction
  - FEM should be created lazily on first `M.FEM()` call
  - Eigensolver should only run on explicit `fem.eigenpairs(k)` call

- **Caching**: Verifies representations are cached after first access

- **Memory footprint**: Verifies Manifold only stores V, F, E arrays (no heavy matrices)

## Performance Requirements

From FEM and Eigenpairs policy:

> **The FEM eigensolver ("eigs" function, solveGeneralized etc.) should NOT be initiated on construction but computed lazily.**

This means:
- `bct.Manifold(V, F)` - Should be fast (dominated by edge extraction)
- `M.FEM()` - Creates FEM object and assembles mass/stiffness matrices
- `fem.eigenpairs(k)` - Triggers eigensolver (computationally expensive)

## Expected Performance Characteristics

### Manifold Construction
- Dominated by edge computation: `unique([F(:,[1 2]); F(:,[2 3]); F(:,[3 1])])`
- Should scale roughly O(M log M) where M = number of faces
- No matrix assembly, no eigensolves, no heavy computation

### FEM Access
- First access: Assembles mass and stiffness matrices using gptoolbox
- Subsequent access: Returns cached object (near-instantaneous)
- Should take longer than Manifold construction

### Eigenpair Computation
- Only triggered by explicit `fem.eigenpairs(k)` call
- Uses MATLAB's `eigs()` sparse eigenvalue solver
- Most expensive operation in the pipeline
- Should take significantly longer than FEM setup

## Interpreting Results

### Good Performance Profile
```
[PERF] Manifold construction (163842 vertices): 0.317 s
[PERF] Edge computation: 0.317 s
[PERF] Full construction: 0.317 s
[PERF] Overhead ratio: 1.00x

[PERF] First FEM access: 2.145 s
[PERF] Second FEM access: 0.000015 s
[PERF] Speedup: 143000x

[PERF] Eigensolve (100 modes): 8.234 s
```

### Bad Performance Profile (Eager Computation)
```
[PERF] Manifold construction (163842 vertices): 12.456 s  ❌ Too slow
[PERF] Edge computation: 0.317 s
[PERF] Full construction: 12.456 s
[PERF] Overhead ratio: 39.30x  ❌ Excessive overhead

[PERF] First FEM access: 0.000023 s  ❌ Too fast (already computed)
```

## Adding New Performance Tests

1. Inherit from `BaseBctTest` for setup/utilities
2. Use descriptive test method names: `testConstructionTimeScaling`
3. Log performance metrics with `fprintf('[PERF] ...')`
4. Use `verifyLessThan` for timing assertions
5. Test multiple input sizes with `TestParameter`
6. Document expected performance bounds in comments

Example:
```matlab
function testMyOperation(testCase)
    % Test that myOperation completes in reasonable time
    
    data = testCase.loadTestMesh();
    
    tic;
    result = myOperation(data);
    elapsed = toc;
    
    fprintf('  [PERF] myOperation: %.3f s\n', elapsed);
    
    testCase.verifyLessThan(elapsed, 1.0, ...
        'Operation should complete in < 1s');
end
```

## See Also

- `tests/unit/` - Correctness tests
- `tests/integration/` - End-to-end workflow tests
- `tests/unit/BaseBctTest.m` - Base class for all tests
