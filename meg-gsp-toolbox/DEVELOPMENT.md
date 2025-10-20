# MEG-GSP Toolbox Development Guide

## Project Status

This is the **initial implementation framework** for the MEG-GSP toolbox. The following components have been implemented:

### ✅ Completed Components

1. **Project Structure** - Complete MATLAB package layout with proper organization
2. **Setup Infrastructure** - Installation scripts and dependency management
3. **I/O Module** (`+meg_gsp/io/`)
   - `loadBrainstormSource.m` - Load Brainstorm source results and anatomy
   - `exportDerivedMaps.m` - Export results to multiple formats (MAT, CSV, VTK)

4. **Graph Construction** (`+meg_gsp/graph/`)
   - `fromCortex.m` - Build GSPBOX graphs from cortical meshes
   - `ensureLaplacian.m` - Compute normalized/combinatorial Laplacians
   - Support for geodesic, cotangent, and uniform edge weights

5. **Differential Operators** (`+meg_gsp/ops/`)
   - `graphGradient.m` - Graph gradient ∇G with proper adjoint properties
   - `graphDivergence.m` - Graph divergence as adjoint of gradient
   - Mathematical correctness validated with unit tests

6. **Testing Framework** (`tests/`)
   - `TestGraphOps.m` - Comprehensive unit tests for graph operators
   - Validates adjoint relationships and mathematical properties

7. **Demo Scripts** (`scripts/`)
   - `demo_alphaband_analysis.m` - Complete alpha-band analysis workflow
   - Shows integration of all implemented components

8. **Documentation**
   - `COPILOT_INSTRUCTIONS.md` - Comprehensive implementation guide
   - Mathematical framework and coding standards defined

### 🚧 Components to Implement Next

The copilot instructions provide complete guidance for implementing:

1. **Transforms Module** (`+meg_gsp/transforms/`)
   - Joint Fourier Transform (JFT/iJFT)
   - Short Time-Vertex Fourier Transform (STVFT)
   - Spectral Time-Vertex Wavelet Transform (STVWT)

2. **Filtering Module** (`+meg_gsp/filters/`)
   - Separable and non-separable joint filters
   - Fast Fourier-Chebyshev (FFC) algorithm
   - Heat and wave filter families

3. **Dynamic Graph Wavelets** (`+meg_gsp/dgw/`)
   - Heat, wave, and causal damped kernels
   - DGW dictionary construction and sparse coding

4. **Visualization Module** (`+meg_gsp/viz/`)
   - High-quality cortical surface plotting
   - Time series animation and spectral visualization

5. **Additional Operators** (`+meg_gsp/ops/`)
   - `graphTotalVariation.m`
   - `timeDiff.m` and temporal operators
   - `jointLaplacian.m` for time-vertex analysis

## Getting Started as a Developer

### 1. Environment Setup

```matlab
% Navigate to toolbox directory
cd('meg-gsp-toolbox')

% Run setup script
run scripts/setup.m

% Initialize GSPBOX submodule (if using git)
% git submodule update --init --recursive
```

### 2. Running the Demo

```matlab
% Test the current implementation
run scripts/demo_alphaband_analysis.m
```

### 3. Running Unit Tests

```matlab
% Run all tests
results = runtests('tests/unit');
table(results)

% Run specific test
runtests('tests/unit/TestGraphOps.m')
```

### 4. Development Workflow

1. **Study the copilot instructions**: Read `COPILOT_INSTRUCTIONS.md` thoroughly
2. **Follow the mathematical framework**: Implement equations exactly as specified
3. **Write tests first**: Create unit tests before implementing functions
4. **Validate with demos**: Update demo scripts to showcase new features
5. **Document thoroughly**: Include equation references and examples

## Architecture Overview

### Package Structure
```
+meg_gsp/
├── io/           # Brainstorm interface
├── graph/        # Graph construction and Laplacians
├── ops/          # Differential operators (∇G, div, TV)
├── transforms/   # Spectral transforms (GFT, JFT, STVFT/WT)
├── filters/      # Joint filtering (separable/non-separable, FFC)
├── dgw/          # Dynamic graph wavelets
├── viz/          # Visualization utilities
├── utils/        # Helper functions
└── examples/     # Runnable examples
```

### Mathematical Framework

The toolbox implements the joint time-vertex framework:

- **Joint Laplacian**: `LJ = LT ⊗ I + I ⊗ LG`
- **Joint Fourier Transform**: `X̂ = U_G^T * X * U_T`
- **Total Variation**: `TV_J(X) = ||∇J X||_{p,q}`
- **DGW Kernels**: Heat, wave, and causal damped variants

### Key Design Principles

1. **Mathematical Fidelity**: Exact implementation of published equations
2. **Computational Efficiency**: Sparse matrices, vectorized operations
3. **Robust I/O**: Handle real Brainstorm data with error checking
4. **Comprehensive Testing**: Unit tests for all mathematical properties
5. **Clear Documentation**: Reference equations in every function

## Implementation Priorities

### Phase 1: Core Functionality (Current)
- ✅ Graph construction and basic operators
- ✅ I/O for Brainstorm integration
- ✅ Testing framework and documentation

### Phase 2: Spectral Analysis
- 🚧 Joint transforms (JFT, STVFT, STVWT)
- 🚧 Basic filtering capabilities
- 🚧 Visualization module

### Phase 3: Advanced Features
- 🚧 Dynamic graph wavelets
- 🚧 FFC algorithm for efficient filtering
- 🚧 Sparse coding and event detection

### Phase 4: Production Ready
- 🚧 Performance optimization
- 🚧 GPU acceleration options
- 🚧 Comprehensive documentation and tutorials

## Contributing Guidelines

### Code Quality Standards

1. **Input Validation**: Use `inputParser` for all public functions
2. **Error Messages**: Include context and suggestions
3. **Documentation**: H1 line, examples, and equation references
4. **Testing**: Unit tests for mathematical properties
5. **Performance**: Target N≈15k vertices, T≈2000 time points

### Mathematical Correctness

- Validate adjoint relationships: `<∇G x, y> = <x, div_G y>`
- Check Parseval relations: `||X||² = ||JFT(X)||²`
- Verify stability conditions for wave kernels
- Test reconstruction accuracy for all transforms

### Commit Message Format

```
module: brief description

- Detailed change 1
- Detailed change 2

Refs: equation references from papers
Tests: describe test coverage
```

## Resources

### Required Reading
1. **COPILOT_INSTRUCTIONS.md** - Complete implementation guide
2. Grassi et al. "A Time-Vertex Signal Processing Framework"
3. GSPBOX documentation and source code

### Mathematical References
- Discrete calculus on graphs (Shuman et al.)
- Time-vertex signal processing (Grassi et al.)
- Dynamic graph wavelets (DGW papers)
- Laplace-Beltrami discretization (Desbrun et al.)

### MATLAB Resources
- Signal Processing Toolbox documentation
- Sparse matrix best practices
- `matlab.unittest` framework guide
- Package/namespace (+folder) conventions

## Future Extensions

### Potential Enhancements
- Multi-layer cortical graphs (laminar analysis)
- GPU acceleration for large-scale processing
- Real-time processing capabilities
- Integration with other neuroimaging toolboxes

### Research Applications
- Epileptic spike detection and localization
- Traveling wave analysis in neural oscillations
- Functional connectivity on cortical surfaces
- Source reconstruction quality assessment

---

**Note**: This is a research-grade scientific computing project requiring strong MATLAB skills and understanding of graph signal processing theory. Start with the copilot instructions and work systematically through each module.