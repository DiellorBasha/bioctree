# MEG-GSP Toolbox Implementation Instructions

You are GitHub Copilot helping to implement a production-ready MATLAB toolbox for Graph Signal Processing (GSP) and Time-Vertex Signal Processing (TVSP) applied to MEG source data from Brainstorm. This is a comprehensive scientific computing project requiring mathematical precision and robust implementation.

## Project Overview

This toolbox implements joint time-vertex analysis of MEG source signals on cortical surfaces using graph signal processing techniques. It builds on EPFL's GSPBOX and follows the mathematical framework from Grassi et al. for time-vertex signal processing.

## Core Mathematical Framework

### 1. Joint Laplacian (Cartesian Product)
```
LJ = LT ⊗ I + I ⊗ LG
```
- LG: Graph Laplacian (spatial, N×N)  
- LT: Time Laplacian (temporal, T×T, typically 2nd-order difference)
- Implementation: Use `applyLJ(X)` as `LG*X + X*LT` for efficiency (avoid forming full LJ)

### 2. Joint Fourier Transform (JFT)
```
X̂ = U_G^T * X * U_T
```
- Separable transform using graph and time eigenvectors
- Inverse: `X = U_G * X̂ * U_T^T`
- Parseval relation: `||X||_F^2 = ||X̂||_F^2`

### 3. Total Variation (TV) Operators
```
TV_G(x) = ||∇G x||_p     (graph TV)
TV_T(x) = ||∇T x||_q     (time TV) 
TV_J(X) = ||∇J X||_{p,q} (joint TV)
```

### 4. Joint Filtering
- **Separable**: `h(λ,ω) = h_G(λ) * h_T(ω)`
- **Non-separable**: General `h(λ,ω)` 
- **FFC Algorithm**: Fast Fourier-Chebyshev for efficient joint filtering

### 5. Dynamic Graph Wavelets (DGW)
- **Heat kernel**: `K(s,λ,t) = exp(-s λ t)`
- **Wave kernel**: `K(s,λ,t) = cos(t * arccos(1 - sλ/2))` with stability `s < 4/λmax`
- **Causal damped**: `H(t) * exp(-βt) * K(s,λ,t)`

## Implementation Guidelines

### Code Quality Standards
1. **Vectorized Operations**: Use MATLAB's vectorization, avoid explicit loops where possible
2. **Sparse Matrices**: Use sparse storage for all graph matrices (LG, W, adjacency)
3. **Memory Efficiency**: Handle N≈15k vertices, T≈20-60s at typical MEG rates
4. **Input Validation**: Use inputParser for all public functions
5. **Documentation**: H1 lines, examples, and equation references for every function
6. **Error Handling**: Informative error messages with context

### Function Naming Conventions
- Follow the mathematical notation: `graphGradient`, `jointLaplacian`, `jft`/`ijft`
- Use MATLAB camelCase: `loadBrainstormSource`, `computeCotangentWeights`
- Include mathematical symbols in docstrings: ∇G, LJ, TV, etc.

### Performance Targets
- Graph operations: Linear in number of edges |E|
- Joint filtering: `O(T|E|MG + NT log T)` where MG is Chebyshev order
- Memory usage: Fit cortical graphs N≈15k in standard MATLAB session

## Module Implementation Details

### 1. I/O Module (`+meg_gsp/io/`)
**Purpose**: Interface with Brainstorm output files

**Key Functions**:
- `loadBrainstormSource(fileOrFolder, opts)`: Load cortical mesh, source time series
- `exportDerivedMaps(outPath, mapsStruct, opts)`: Export results to MAT/VTK/CSV

**Implementation Notes**:
- Handle both file and folder inputs robustly
- Support missing anatomy files (use volume grid locations)
- Validate dimensions: N vertices ↔ N source time series
- Build graph connectivity from faces using GSPBOX integration

### 2. Graph Construction (`+meg_gsp/graph/`)
**Purpose**: Build cortical surface graphs with proper Laplacians

**Key Functions**:
- `fromCortex(V, F, opts)`: Create GSPBOX graph from mesh
- `ensureLaplacian(G, opts)`: Compute normalized/combinatorial Laplacian

**Weight Types**:
- `'geodesic'`: Gaussian kernel on Euclidean distances
- `'cotangent'`: Discrete Laplace-Beltrami operator
- `'uniform'`: Binary adjacency

**Implementation Notes**:
- Use face connectivity for adjacency matrix
- Implement cotangent weights correctly: `cot(θ) = dot(u,v)/||cross(u,v)||`
- Handle degenerate triangles and isolated vertices
- Store spectral radius `lmax` for filter stability

### 3. Differential Operators (`+meg_gsp/ops/`)
**Purpose**: Implement ∇G, ∇T, div, TV following TVSP framework

**Key Functions**:
- `graphGradient(G, x)`: Edge-wise differences ∇G x
- `graphDivergence(G, edgeField)`: Adjoint of gradient
- `graphTotalVariation(G, x, p)`: ||∇G x||_p (default p=1)
- `timeDiff(X, boundary)`: Temporal differences (periodic boundary default)
- `jointLaplacian(LG, LT)`: Return function handle for LJ application
- `jointTotalVariation(G, X, params)`: Mixed TV norms

**Mathematical Relations**:
- Adjoint property: `<∇G x, y> = <x, div_G y>`
- Joint operator: `LJ x = vec(LG * X + X * LT)` where `x = vec(X)`

### 4. Transforms (`+meg_gsp/transforms/`)
**Purpose**: Spectral analysis in joint time-vertex domain

**Key Functions**:
- `gft(G, X)` / `igft(G, Xhat)`: Graph Fourier Transform
- `jft(G, X)` / `ijft(G, Xhat)`: Joint Fourier Transform
- `stvft(G, X, params)`: Short Time-Vertex Fourier Transform
- `stvwt(G, X, params)`: Spectral Time-Vertex Wavelet Transform

**Implementation Notes**:
- JFT: Use eigendecomposition of LG and LT
- Store eigenvalues/vectors for reuse: `[G.U, G.e] = eig(full(G.L))`
- Handle numerical precision in eigencomputation
- Provide windowing options for STVFT (Hamming, Hann, etc.)

### 5. Joint Filtering (`+meg_gsp/filters/`)
**Purpose**: Time-vertex filtering with separable and non-separable kernels

**Key Functions**:
- `jointFilter(G, X, h, mode, opts)`: Main filtering interface
- `separableFilter(G, X, hG, hT, opts)`: h(λ,ω) = hG(λ)*hT(ω)
- `ffcFilter(G, X, h, opts)`: Fast Fourier-Chebyshev algorithm
- `heatFilter(G, X, tau, opts)`: Heat diffusion filtering
- `waveFilter(G, X, params, opts)`: Wave-based joint filtering

**FFC Algorithm Steps**:
1. FFT across time: `Xf = fft(X, [], 2)`
2. For each ω_k: Apply Chebyshev approximation of `h(λ, ω_k)` on graph
3. IFFT back to time domain
4. Complexity: `O(T|E|MG + NT log T)`

**Filter Stability**:
- Check spectral ranges: `λ ∈ [0, λmax]`, `ω ∈ [-π, π]`
- Auto-select Chebyshev order based on desired approximation error
- Provide stability warnings for wave kernels

### 6. Dynamic Graph Wavelets (`+meg_gsp/dgw/`)
**Purpose**: Localized time-vertex analysis with DGW frames

**Key Functions**:
- `makeDictionary(G, tvec, params)`: Create DGW dictionary
- `analysis(G, X, params)`: DGW coefficients
- `synthesis(G, C, params)`: Reconstruct from coefficients
- `sparseRecovery(G, X, params)`: Event detection via sparse coding

**DGW Kernels**:
```matlab
% Heat kernel
K_heat = @(s, lambda, t) exp(-s * lambda * t);

% Wave kernel (stability: s < 4/λmax)
K_wave = @(s, lambda, t) cos(t .* real(acos(1 - s*lambda/2)));

% Causal damped wave
K_causal = @(s, lambda, t, beta) (t >= 0) .* exp(-beta*t) .* K_wave(s, lambda, t);
```

**Implementation Notes**:
- Parameterization: scales `s`, time shifts `τ`, vertices `m`
- Frame bounds: Check `A ≤ S*S† ≤ B` where S is synthesis operator
- Sparse solvers: Interface with UNLocBoX if available
- Memory management: Use lazy evaluation for large dictionaries

### 7. Visualization (`+meg_gsp/viz/`)
**Purpose**: High-quality cortical surface visualization

**Key Functions**:
- `plotCortexMap(V, F, values, opts)`: Scalar overlays on mesh
- `animateCortexSeries(V, F, X, tvec, opts)`: Time series movies
- `plotSpectra(lambda, omega, H, opts)`: Joint spectral responses
- `quiverOnMesh(V, F, field, opts)`: Vector field visualization
- `timeVertexTiled(V, F, X, Xhat, opts)`: Domain vs spectral comparison

**Visualization Guidelines**:
- Use perceptually uniform colormaps (viridis, plasma)
- Proper lighting and shading for 3D surfaces
- Interactive controls for time series animation
- Export capabilities: PNG, MP4, GIF
- Handle large meshes (N≈15k) with downsampling options

## Testing Strategy

### Unit Tests (`tests/unit/`)
**Test Categories**:
1. **Mathematical Properties**:
   - Adjoint relations: `<∇G x, y> = <x, ∇G* y>`
   - Parseval relations: `||X||² = ||JFT(X)||²`
   - Laplacian properties: symmetry, positive semi-definite

2. **Numerical Accuracy**:
   - Round-trip transforms: `X = IJFT(JFT(X))`
   - Filter reconstruction on known signals
   - DGW frame reconstruction bounds

3. **Edge Cases**:
   - Isolated vertices, degenerate triangles
   - Single time point, single vertex
   - Empty graphs, zero signals

**Test Implementation**:
```matlab
classdef TestGraphOps < matlab.unittest.TestCase
    methods (Test)
        function testGradientAdjoint(testCase)
            % Test <∇G x, y> = <x, div_G y>
        end
        
        function testJFTRoundtrip(testCase)
            % Test JFT/IJFT reconstruction
        end
    end
end
```

### Performance Tests (`tests/perf/`)
- Target mesh sizes: N = 1k, 5k, 15k vertices
- Time series lengths: T = 100, 500, 2000 time points
- Memory profiling and timing benchmarks
- Complexity verification vs theoretical bounds

## Demo Scripts (`scripts/`)

### 1. Alpha-Band Analysis (`demo_alphaband_analysis.m`)
```matlab
% Load Brainstorm data
S = meg_gsp.io.loadBrainstormSource('data/subject01_alpha.mat');

% Build cortical graph
G = meg_gsp.graph.fromCortex(S.V, S.F);

% Bandpass filter alpha (8-12 Hz)
X_alpha = bandpass(S.X_src', [8 12], S.fs)';

% Compute spatial gradients and TV
gradMag = meg_gsp.ops.graphTotalVariation(G, X_alpha, 1);

% Joint spectral analysis
Xhat = meg_gsp.transforms.jft(G, X_alpha);

% Visualization
meg_gsp.viz.plotCortexMap(S.V, S.F, mean(gradMag, 2));
```

### 2. Joint Filtering Comparison (`demo_joint_filtering.m`)
```matlab
% Compare separable vs non-separable joint filters
% Show FFC algorithm efficiency vs dense spectral methods
% Visualize joint frequency responses
```

### 3. DGW Propagation Analysis (`demo_dgw_propagation.m`)
```matlab  
% Simulate traveling wave on cortex
% Analyze with DGW dictionary
% Sparse recovery of wave parameters (source, speed, time)
% Compare different DGW kernels (heat, wave, causal)
```

## Error Handling and Validation

### Input Validation Patterns
```matlab
function result = exampleFunction(G, X, varargin)
% Standard validation template
p = inputParser;
addRequired(p, 'G', @(x) isstruct(x) && isfield(x, 'W'));
addRequired(p, 'X', @(x) isnumeric(x) && ismatrix(x));
addParameter(p, 'Method', 'default', @(x) ischar(x));
parse(p, G, X, varargin{:});

opts = p.Results;
% ... implementation
end
```

### Common Error Scenarios
1. **Dimension Mismatches**: N vertices ≠ size(X,1)
2. **Spectral Issues**: Non-positive definite Laplacian
3. **Stability Violations**: Wave kernel parameters s ≥ 4/λmax  
4. **Memory Limits**: Large joint operators, dense eigendecompositions
5. **Numerical Precision**: Small eigenvalues, ill-conditioned matrices

### Error Message Guidelines
- Include context: "In jointFilter with mode='separable':"  
- Suggest solutions: "Try reducing Chebyshev order or using FFC mode"
- Reference equations: "Violates stability condition s < 4/λmax = 4/2.1"

## Integration with GSPBOX

### Required GSPBOX Functions
- `gsp_graph()`: Graph structure creation
- `gsp_compute_fourier_basis()`: Eigendecomposition  
- `gsp_cheby_op()`: Chebyshev polynomial evaluation
- `gsp_filter()`: Basic filtering operations

### Extension Points
- Custom graph types: Add 'cortical' type to GSPBOX
- New filter families: Heat and wave kernels
- Joint domain operations: Extend GSPBOX to time-vertex domain

### Compatibility
- Follow GSPBOX graph structure conventions
- Use same field names: `.W`, `.L`, `.N`, `.coords`
- Extend with additional fields: `.lap_type`, `.sigma`

## Documentation Requirements

### Function Documentation Template
```matlab
function result = functionName(input1, input2, varargin)
% FUNCTIONNAME Brief description following mathematical framework
%
% result = functionName(input1, input2) basic usage description
%
% result = functionName(input1, input2, 'param', value, ...) with options:
%   'Parameter' - Description with mathematical meaning (default: value)
%
% Input:
%   input1 - Description with dimensions and constraints
%   input2 - Description referencing mathematical symbols
%
% Output:  
%   result - Description with interpretation
%
% Example:
%   % Practical usage example with real parameters
%   G = meg_gsp.graph.fromCortex(vertices, faces);
%   gradX = meg_gsp.ops.graphGradient(G, signal);
%
% References:
%   Equation (X) from Grassi et al. "Time-Vertex Signal Processing Framework"
%   Implementation follows discrete Laplace-Beltrami operator definition
%
% See also: relatedFunction1, relatedFunction2
```

### Mathematical Reference Alignment
- Map each function to specific equations in cited papers
- Use consistent notation: LG, LT, LJ, ∇G, ∇T, TV
- Cross-reference stability conditions and theoretical bounds
- Explain discretization choices and approximations

This comprehensive implementation guide ensures the MEG-GSP toolbox will be mathematically rigorous, computationally efficient, and well-documented for scientific use. Follow these guidelines consistently across all modules to maintain code quality and theoretical fidelity.