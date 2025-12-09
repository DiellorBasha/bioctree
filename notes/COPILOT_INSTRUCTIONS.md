# Bioctree Implementation Instructions

You are GitHub Copilot helping to implement Bioctree, a comprehensive MATLAB toolbox for spatiotemporal signal processing and compression of electrophysiological signals on networks (graphs). This project combines graph signal processing, compression algorithms, and time-vertex analysis for efficient storage and analysis of neural data.

## CRITICAL: BCT File Extension Requirements

**BCT files MUST always use the .h5 extension, never .bct extension.**

- BCT files are HDF5 files with standardized Bioctree structure
- They are called "BCT files" because of their internal organization, not file extension
- All BCT functions (outbct, inbct, db_create_test_bct, etc.) must use .h5 extensions
- Examples: `data.h5`, `test_bioctree_standard.h5`, `results.h5`
- Never use: `data.bct`, `test.bct`, or any .bct extensions

## NEW: BCT Object-Oriented Class System

**MAJOR ARCHITECTURAL CHANGE: The bioctree codebase is transitioning from functional I/O (outbct/inbct) to an object-oriented BCT class system for all HDF5 file operations.**

### BCT Class Architecture (`toolbox/+bct/`)

The new BCT class provides a comprehensive object-oriented interface for BCT file handling with full CRUD operations, schema validation, and multi-layer support.

#### Core Class (`toolbox/+bct/@bct/bct.m`)
```matlab
% Factory methods for file lifecycle
obj = bct.create('dataset_name');     % Create new BCT file
obj = bct.open('existing_file.h5');   % Open existing BCT file

% CRUD Operations
obj.write_raw(signal_matrix, fs);     % Write raw signals
obj.write_graph(graph_struct);        % Write graph structure
data = obj.read_raw([1,100], [1,50]); % Read time/node slices
obj.validate();                       % Schema validation
```

#### Internal Utilities (`toolbox/+bct/+internal/`)
- **`Schema.m`**: JSON schema management and validation
- **`Validator.m`**: Comprehensive data integrity checking
- **`Paths.m`**: Intelligent path resolution (bioctree root detection)
- **`Util.m`**: HDF5 utilities and UUID generation
- **`Attr.m`**: Type-safe attribute writing
- **`DimScale.m`**: HDF5 dimension scale management

#### Schema Definition (`toolbox/+bct/schema/bct-core-1.0.0.json`)
Enforces standardized BCT file structure with required groups, attributes, and dimensional constraints.

### BCT Class Usage Patterns

#### 1. CREATE Operations
```matlab
% Create new BCT file with automatic schema skeleton
obj = bct.create('my_analysis_results');  % Creates in data/bioctree_files/raw/

% Write core data
obj.write_raw(signal_data, sampling_rate);
obj.write_graph(graph_structure);

% Multi-layer support
obj.write_raw_layers(signal_3D, fs, layer_ids);  % (L×T×N) format
```

#### 2. READ Operations
```matlab
% Open existing file with automatic validation
obj = bct.open('analysis_results.h5');

% Efficient partial loading (hyperslabs)
time_slice = obj.read_raw([100, 200], ':');           % Time range, all nodes
node_slice = obj.read_raw(':', [1, 50]);              % All time, node range
layer_data = obj.read_raw_layers([1,3], [1,100], ':'); % Specific layers

% Frequency band reconstruction
alpha_band = obj.read_tf_band([8, 12], [1, 1000], ':', 1);
```

#### 3. UPDATE Operations
```matlab
% Append new layers dynamically
obj.append_raw_layer(new_layer_data, layer_id);

% Time-frequency coefficient storage
obj.write_tf_coeffs(coeffs_4D, freq_hz, transform_attrs);

% Layer management
obj.set_default_layer(layer_index);
default_id = obj.get_default_layer();
```

#### 4. VALIDATION Operations
```matlab
% Comprehensive validation reporting
report = obj.validate();
if ~report.ok
    fprintf('Validation errors:\n%s\n', strjoin(report.messages, '\n'));
end
```

### Multi-Layer Signal Architecture

The new BCT class natively supports multi-layer signals for complex experimental designs:

#### Layer Organization
```matlab
% 3D Signal Stack: (L × T × N)
% L = Layers (conditions/trials/frequencies)  
% T = Time points
% N = Graph nodes/vertices

% Example: Multi-condition experiment
layer_1 = condition_A_data;  % (T×N)
layer_2 = condition_B_data;  % (T×N)
layer_3 = condition_C_data;  % (T×N)
signal_3D = cat(1, reshape(layer_1,[1,T,N]), ...
                   reshape(layer_2,[1,T,N]), ...
                   reshape(layer_3,[1,T,N])); % (3×T×N)

obj.write_raw_layers(signal_3D, fs, [0, 1, 2]);
```

#### Layer Access Patterns
```matlab
% Access specific experimental conditions
condition_A = obj.read_raw_layers(1, ':', ':');      % Layer 1 only
conditions_AB = obj.read_raw_layers([1,2], ':', ':'); % Layers 1&2
all_conditions = obj.read_raw_layers(':', [1,100], [1,50]); % Time/node slice
```

### Time-Frequency Analysis Support

#### Complex Coefficient Storage
```matlab
% 4D Coefficient Array: (L × F × T × N)
% Split real/imaginary storage for efficiency
obj.write_tf_coeffs(coeffs_complex_4D, freq_hz, tf_attributes);

% Transform attributes
tf_attrs = struct(...
    'transform', 'continuous_wavelet', ...
    'pr_exact', true, ...                    % Perfect reconstruction
    'padding', 'symmetric', ...
    'params_json', jsonencode(cwt_params));
```

#### Band-Limited Reconstruction
```matlab
% Direct frequency band signal reconstruction
alpha_signal = obj.read_tf_band([8, 12], time_range, node_range, layer_ids);
beta_signal = obj.read_tf_band([13, 30], time_range, node_range, layer_ids);
```

### Path Management and Data Organization

#### Intelligent Path Resolution
```matlab
% The BCT class automatically resolves paths relative to bioctree root
obj = bct.create('experiment_1');  
% → Creates: <bioctree_root>/data/bioctree_files/raw/experiment_1.h5

obj = bct.create('processed/filtered_data');
% → Creates: <bioctree_root>/data/bioctree_files/raw/processed/filtered_data.h5

% Absolute paths are rebased under bioctree data directory for portability
```

#### Data Directory Structure Integration
```matlab
% BCT class respects bioctree configuration
config = bioctree_config();
% All BCT files created under config.DataPath by default
% Supports custom paths via bioctree_config('DataPath', '/custom/location')
```

### Refactoring Guidelines for Legacy Code

#### Phase 1: Replace outbct/inbct Calls
```matlab
% OLD PATTERN (functional)
success = outbct('results.h5', analysis_data, 'Compression', 6);
data = inbct('results.h5', 'TimeRange', [1, 100]);

% NEW PATTERN (object-oriented)
obj = bct.create('results');
obj.write_raw(analysis_data.X, analysis_data.fs);
obj.write_graph(analysis_data.graph);
data_slice = obj.read_raw([1, 100], ':');
```

#### Phase 2: Leverage Advanced Features
```matlab
% Multi-layer experiments
obj.write_raw_layers(multi_condition_data, fs, condition_ids);

% Efficient partial loading
time_window = obj.read_raw([start_idx, end_idx], vertex_indices);

% Frequency domain analysis
obj.write_tf_coeffs(cwt_coeffs, frequencies, transform_params);
band_limited = obj.read_tf_band([freq_min, freq_max], time_range, vertices);
```

#### Phase 3: Add Validation Integration
```matlab
% Add validation checkpoints in analysis pipelines
function results = analysis_pipeline(input_file)
    obj = bct.open(input_file);
    
    % Validate input data integrity
    report = obj.validate();
    assert(report.ok, 'Input validation failed: %s', strjoin(report.messages, '; '));
    
    % Perform analysis...
    
    % Create results file with validation
    results_obj = bct.create('pipeline_results');
    results_obj.write_raw(processed_data, fs);
    
    % Final validation
    final_report = results_obj.validate();
    if ~final_report.ok
        warning('Output validation issues: %s', strjoin(final_report.messages, '; '));
    end
end
```

### Error Handling and Debugging

#### Schema Validation Errors
```matlab
% Common validation issues and solutions:
try
    obj = bct.open('problematic_file.h5');
catch ME
    if contains(ME.identifier, 'bct:SchemaInvalid')
        fprintf('Schema validation failed:\n%s\n', ME.message);
        % Handle schema migration or file repair
    end
end
```

#### Dimensional Consistency Checks
```matlab
% Automatic axis validation prevents common errors:
% - Signal dimensions vs graph node count
% - Time axis length vs signal temporal dimension  
% - Layer count consistency across datasets
```

### Migration Strategy

#### Database Functions (`db/`)
1. **`db_create_test_bct.m`**: Replace outbct call with BCT class
2. **`db_load_test_bct.m`**: Replace inbct call with BCT class  
3. **New functions**: `db_create_bct_class.m`, `db_load_bct_class.m`

#### Demo Scripts (`demo/`)
Update all demo scripts to use BCT class for file I/O operations.

#### Analysis Workflows (`workflows/`)
Integrate BCT class validation and multi-layer support into analysis pipelines.

### Performance Considerations

#### Hyperslab Reading
```matlab
% Efficient partial data access without loading full datasets
subset = obj.read_raw([time_start, time_end], [node_start, node_end]);
% Only loads requested data slice, not entire file
```

#### Layer-Specific Analysis
```matlab
% Process individual layers without loading all data
for layer_id = 1:num_layers
    layer_data = obj.read_raw_layers(layer_id, ':', ':');
    results(layer_id) = analyze_layer(layer_data);
end
```

#### Memory Management
```matlab
% BCT class manages HDF5 file handles efficiently
% Automatic cleanup prevents file handle leaks
% Chunked storage optimizes read/write performance
```

### Integration with Existing Bioctree Functions

The BCT class system is designed to integrate seamlessly with existing bioctree workflows:

#### Graph Processing Functions
```matlab
% BCT class provides graph data in standard bioctree format
obj = bct.open('dataset.h5');
G = obj.graph;  % Standard bioctree graph structure
% Use with existing functions: graphGradient(G, signal), etc.
```

#### Signal Processing Workflows  
```matlab
% BCT class signals compatible with all bioctree processing
raw_signals = obj.read_raw(':', ':');
processed = apply_bioctree_filter(raw_signals, filter_params);
obj_out = bct.create('filtered_results');
obj_out.write_raw(processed, fs);
```

This BCT class system represents a major architectural upgrade that will enable more robust, efficient, and maintainable bioctree workflows while maintaining backward compatibility with existing functions.

## Project Overview

Bioctree provides tools for graph-aware compression, multiscale subdivision, and joint time-vertex analysis of signals measured on networked sensors or neural meshes. It integrates Graph Signal Processing (GSP) with compression techniques and builds on EPFL's GSPBOX for core graph operations.

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

### 1. I/O Module (`gsp/io/`)
**Purpose**: Interface with Brainstorm output files and data loading

**Key Functions**:
- `loadBrainstormSource(fileOrFolder, opts)`: Load cortical mesh, source time series
- `exportDerivedMaps(outPath, mapsStruct, opts)`: Export results to MAT/VTK/CSV

**Implementation Notes**:
- Handle both file and folder inputs robustly
- Support missing anatomy files (use volume grid locations)
- Validate dimensions: N vertices ↔ N source time series
- Build graph connectivity from faces using GSPBOX integration

### 2. Graph Construction (`gsp/graph/`)
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

### 3. Differential Operators (`gsp/ops/`)
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

### 6. Dynamic Graph Wavelets (`gsp/dgw/`)
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

### 7. Visualization (`gsp/viz/`)
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

## Bioctree Project Structure

### Repository Layout
```
bioctree/
├── bioctree_start.m      # Main initialization script
├── compression/          # Core compression algorithms
├── external/            
│   ├── gspbox/          # EPFL GSPBOX (cloned from GitHub)
│   └── icosphere.m      # Icosphere generation utility
├── gsp/                 # Graph Signal Processing modules
│   ├── graph/           # Graph construction and Laplacians
│   ├── io/              # Brainstorm interface and data I/O
│   ├── ops/             # Differential operators (gradient, divergence, TV)
│   ├── transforms/      # Spectral transforms (GFT, JFT, STVFT/WT)
│   ├── filters/         # Joint filtering (separable/non-separable, FFC)
│   ├── dgw/             # Dynamic graph wavelets
│   ├── viz/             # Visualization utilities
│   ├── utils/           # Helper functions
│   └── examples/        # Runnable examples
├── io/                  # General data I/O utilities
├── plotlib/             # Plotting and visualization helpers
├── test-data/           # MEG/EEG datasets for testing
├── tests/               # Unit and performance tests
├── toolbox/             # Core signal processing tools
│   ├── frequency/       # FFT and spectral analysis
│   ├── transforms/      # Wavelet and other transforms
│   ├── filters/         # General filtering
│   ├── ops/             # Mathematical operators
│   └── simulations/     # Signal generation
└── workflows/           # Demo scripts and pipelines
```

### Integration Strategy
The bioctree project combines:
1. **Compression algorithms** for efficient storage of neural signals
2. **Graph signal processing** for cortical surface analysis
3. **Time-vertex analysis** for joint spatiotemporal processing
4. **Visualization tools** for scientific plotting and animation

### Key Integration Points
- **GSPBOX Integration**: All graph operations build on EPFL's GSPBOX foundation
- **Shared Transforms**: Leverage existing `toolbox/frequency/` for temporal transforms
- **Unified I/O**: Extend `io/` for Brainstorm compatibility in `gsp/io/`
- **Common Plotting**: Build on `plotlib/` for cortical visualization in `gsp/viz/`

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

## Demo Scripts (`workflows/`)

### 1. Alpha-Band Analysis (`demo_alphaband_analysis.m`)
```matlab
% Load Brainstorm data
S = loadBrainstormSource('test-data/subject01_alpha.mat');

% Build cortical graph
G = fromCortex(S.V, S.F);

% Bandpass filter alpha (8-12 Hz)
X_alpha = bandpass(S.X_src', [8 12], S.fs)';

% Compute spatial gradients and TV
gradMag = graphTotalVariation(G, X_alpha, 1);

% Joint spectral analysis
Xhat = jft(G, X_alpha);

% Visualization
plotCortexMap(S.V, S.F, mean(gradMag, 2));
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
%   G = fromCortex(vertices, faces);
%   gradX = graphGradient(G, signal);
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