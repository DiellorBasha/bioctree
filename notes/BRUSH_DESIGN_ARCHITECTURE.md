# Brush Design System - Complete Architecture

## Overview

The brush design system provides a comprehensive framework for creating spatiotemporal signals on manifolds with:

1. **Direct generation** via `bct.brush.design.brush()` - for known parameters
2. **Interactive design** via `BrushDesigner` class - for parameter exploration
3. **Signal creation** via `Signal.fromBrush()` - for convenience

## Architecture

### Three-Level API

```
Level 1: Direct Generation (Fast path)
  bct.brush.design.brush(category, type, manifold, params, [time])
  → Returns weights [N×1] or [N×T] immediately

Level 2: Interactive Design (Parameter tuning)
  designer = bct.brush.design.create(category, type, manifold, params, [time])
  → Returns BrushDesigner object for manipulation
  → designer.evaluateKernel() - preview spectral response
  → designer.setParameter() - adjust parameters
  → designer.plotKernelResponse() - visualize
  → designer.finalize() - generate weights

Level 3: Signal Wrapper (Convenience)
  sig = Signal.fromBrush(type, bct_obj, Name-Value params...)
  → Returns Signal object with automatic domain handling
```

### Component Hierarchy

```
bct.brush
├── registry.m              # Lookup table: 'patch_spectral' → function handle
├── +patch                  # Spatial brushes [N×1]
│   ├── spectral.m         # MFT → kernel → IMFT
│   └── ...
├── +trajectory             # Path-based brushes [N×1]
│   ├── spectral.m         # Shortest path → spectral filter
│   └── ...
├── +time                   # Spatiotemporal brushes [N×T]
│   ├── spectral.m         # patch.spectral per time step
│   ├── heat.m             # Progressive heat diffusion
│   └── ...
└── +design                 # Design subsystem
    ├── brush.m            # Direct generation
    ├── create.m           # Create designer
    └── BrushDesigner.m    # Interactive designer class
```

## BrushDesigner Class

### Purpose
Enables **parameter manipulation and kernel evaluation** before finalizing brush weights.

### Key Feature
Access to **kernel handle** `g(λ)` for spectral brushes, allowing:
- Evaluation on Lambda axis
- Coverage analysis (number of modes above threshold)
- Parameter optimization
- Visualization

### Properties

```matlab
designer.Category        % 'patch', 'trajectory', 'time'
designer.BrushType       % 'spectral', 'heat', etc.
designer.Manifold        % bct.Manifold
designer.Time            % bct.Time (optional)
designer.Parameters      % Current parameter struct
designer.KernelHandle    % Function g(λ) (spectral brushes)
designer.Lambda          % Lambda domain (manifold.dual)
```

### Methods

```matlab
% Parameter manipulation
designer.setParameter(name, value)
designer.setParameters(struct)

% Kernel evaluation (spectral only)
H = designer.evaluateKernel()           % On Lambda.lambda
H = designer.evaluateKernel(lambda_vec)  % Custom points

% Visualization
designer.plotKernelResponse()           % H(λ) plot
designer.preview()                      % Spatial pattern
designer.preview('TimeIndex', t)        % Time slice

% Finalization
w = designer.finalize()                 % Generate weights
```

## Workflow Examples

### Example 1: Heat Kernel Coverage Analysis

**Goal:** Evaluate spectral heat kernel on Lambda axis to see eigenspace coverage.

```matlab
% Create designer with initial tau
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'heat', 'tau', 0.1));

% Evaluate on Lambda axis
H = designer.evaluateKernel();
fprintf('Modes > 1%%: %d\n', sum(H > 0.01));

% Visualize spectral response
designer.plotKernelResponse();

% Adjust tau for more diffusion
designer.setParameter('tau', 0.3);
H_new = designer.evaluateKernel();
fprintf('Modes > 1%%: %d\n', sum(H_new > 0.01));

% Plot comparison
lambda = designer.Lambda.lambda;
figure;
plot(lambda, H, 'b-', 'DisplayName', '\tau=0.1');
hold on;
plot(lambda, H_new, 'r-', 'DisplayName', '\tau=0.3');
legend; grid on;
set(gca, 'YScale', 'log');

% Preview spatial pattern
designer.preview();

% Finalize
w = designer.finalize();
```

### Example 2: Finding Optimal Parameters

**Goal:** Find tau that gives ~50 modes with >1% response.

```matlab
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'heat', 'tau', 0.1));

% Search parameter space
target_modes = 50;
tau_range = linspace(0.05, 0.8, 100);
mode_counts = zeros(size(tau_range));

for i = 1:length(tau_range)
    designer.setParameter('tau', tau_range(i));
    H = designer.evaluateKernel();
    mode_counts(i) = sum(H > 0.01);
end

% Find optimal
[~, idx] = min(abs(mode_counts - target_modes));
tau_optimal = tau_range(idx);

% Apply and visualize
designer.setParameter('tau', tau_optimal);
designer.plotKernelResponse();
designer.preview();

w = designer.finalize();
```

### Example 3: Gaussian Bandpass Design

**Goal:** Design bandpass filter centered at specific eigenvalue.

```matlab
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 500, 'kernel', 'gaussian', 'center', 100, 'bandwidth', 20));

% Check coverage
H = designer.evaluateKernel();
designer.plotKernelResponse();

% Too narrow? Widen bandwidth
designer.setParameter('bandwidth', 50);
designer.plotKernelResponse();

% Center too low? Shift up
designer.setParameter('center', 150);
designer.plotKernelResponse();

w = designer.finalize();
```

### Example 4: Time-Varying Design

**Goal:** Design spatiotemporal brush with time-varying parameters.

```matlab
designer = bct.brush.design.create('time', 'spectral', B.Manifold, ...
    struct('source', 200, 'kernel', 'heat', 'tau', 0.15), B.Time);

% Evaluate kernel at first time point
H = designer.evaluateKernel();

% Preview at different times
for t = [1, 25, 50, 75, 100]
    designer.preview('TimeIndex', t);
end

% Finalize [N×T]
w = designer.finalize();
```

## Coverage Metrics

### Key Metrics for Spectral Analysis

```matlab
H = designer.evaluateKernel();
lambda = designer.Lambda.lambda;

% Mode counts at thresholds
n_modes_1pct = sum(H > 0.01);
n_modes_10pct = sum(H > 0.10);
n_modes_50pct = sum(H > 0.50);

% Effective bandwidth
effective_bw = sum(H) / max(H);

% Peak location
[peak_val, peak_idx] = max(H);
peak_lambda = lambda(peak_idx);

% Frequency range (at -3dB)
threshold_3dB = max(H) / sqrt(2);
range_3dB = lambda(H > threshold_3dB);
bandwidth_3dB = max(range_3dB) - min(range_3dB);
```

### Interpretation

| Metric | Low τ (sharp) | High τ (smooth) |
|--------|---------------|-----------------|
| Modes > 1% | Many (>100) | Few (<20) |
| Effective BW | Large | Small |
| Peak λ | High | Low |
| Spatial pattern | Localized | Diffuse |

## Integration Points

### With Signal Class

```matlab
% After designing
designer = bct.brush.design.create(...);
designer.setParameter('tau', optimal_tau);
w = designer.finalize();

% Create signal
sig = bct.Signal(B.Manifold, w, 'Name', 'Optimized Brush');
sig.plot();
```

Or directly:

```matlab
sig = bct.Signal.fromBrush('spectral', B, 'kernel', 'heat', 'tau', 0.3);
```

### With Filter System

Brushes and filters are complementary:

- **Filters** operate on existing signals: `S_filtered = F * S`
- **Brushes** generate new signals: `S = brush(manifold, params)`

Both use spectral kernels on Lambda domain.

## Spectral Processing Pipeline

### Common Workflow

```
1. Manifold → Compute eigendecomposition → Lambda domain
2. Design spectral kernel g(λ) in Lambda domain
3. For brushes: Apply kernel to source in spectral domain
4. Inverse transform to get spatial pattern

Mathematically:
  w = U * diag(g(λ)) * U' * δ(source)
  
Where:
  U = eigenvectors (Lambda.U)
  λ = eigenvalues (Lambda.lambda)
  g(λ) = spectral kernel (e.g., heat: exp(-τλ))
  δ(source) = delta function at source vertex
```

### Heat Kernel Example

```matlab
% Heat kernel in Lambda domain
g = @(lambda) exp(-tau * lambda);

% For brushes via designer
designer.setParameter('tau', 0.2);
H = designer.evaluateKernel();  % H = g(Lambda.lambda)

% Visualize spectral response
plot(Lambda.lambda, H);
xlabel('\lambda'); ylabel('g(\lambda)');

% Generate spatial pattern
w = designer.finalize();
```

## File Organization

```
toolbox/+bct/+brush/
├── registry.m                          # Brush lookup
├── +patch/
│   └── spectral.m                     # [N×1] spectral
├── +trajectory/
│   └── spectral.m                     # [N×1] path + spectral
├── +time/
│   ├── spectral.m                     # [N×T] spectral per time
│   └── heat.m                         # [N×T] progressive heat
└── +design/
    ├── brush.m                         # Direct generation
    ├── create.m                        # Create designer
    └── BrushDesigner.m                 # Designer class

toolbox/+bct/@Signal/
└── fromBrush.m                         # Static method

examples/
├── demo_brush_designer_quickstart.m    # 5-min intro
├── demo_brush_designer.m               # Comprehensive examples
└── demo_spectral_coverage.m            # Coverage analysis

docs/
└── BRUSH_DESIGNER_REFERENCE.md         # Quick reference
```

## Design Patterns

### Pattern 1: Direct Generation (Known Parameters)

```matlab
w = bct.brush.design.brush('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'heat', 'tau', 0.2));
```

**Use when:** Parameters are known, no tuning needed.

### Pattern 2: Interactive Design (Parameter Exploration)

```matlab
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'heat', 'tau', 0.1));
designer.evaluateKernel();
designer.plotKernelResponse();
designer.setParameter('tau', 0.3);
w = designer.finalize();
```

**Use when:** Need to explore parameter space, visualize spectral response.

### Pattern 3: Signal Wrapper (Convenience)

```matlab
sig = bct.Signal.fromBrush('spectral', B, ...
    'source', 100, 'kernel', 'heat', 'tau', 0.2);
```

**Use when:** Want Signal object directly, parameters known.

## Advanced Use Cases

### 1. Multi-Configuration Comparison

```matlab
configs = {...
    struct('tau', 0.1, 'name', 'Sharp'), ...
    struct('tau', 0.3, 'name', 'Medium'), ...
    struct('tau', 0.6, 'name', 'Smooth')
};

designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'heat', 'tau', 0.1));

figure;
for i = 1:length(configs)
    designer.setParameter('tau', configs{i}.tau);
    H = designer.evaluateKernel();
    plot(lambda, H, 'LineWidth', 2, 'DisplayName', configs{i}.name);
    hold on;
end
legend; grid on;
```

### 2. Parameter Sweep

```matlab
tau_values = logspace(-2, 0, 20);  % 0.01 to 1.0
results = zeros(length(tau_values), length(lambda));

for i = 1:length(tau_values)
    designer.setParameter('tau', tau_values(i));
    results(i, :) = designer.evaluateKernel();
end

% Heatmap of tau vs lambda
imagesc(lambda, tau_values, log10(results));
colorbar; xlabel('\lambda'); ylabel('\tau');
title('Heat Kernel: \tau vs \lambda');
```

### 3. Adaptive Parameter Selection

```matlab
% Goal: Maximum coverage below eigenvalue threshold
lambda_max = 200;
tau_range = linspace(0.1, 1.0, 50);
coverage = zeros(size(tau_range));

for i = 1:length(tau_range)
    designer.setParameter('tau', tau_range(i));
    H = designer.evaluateKernel();
    
    % Coverage in desired range
    lambda = designer.Lambda.lambda;
    in_range = lambda <= lambda_max;
    coverage(i) = sum(H(in_range) > 0.01);
end

[max_cov, idx] = max(coverage);
tau_best = tau_range(idx);
```

## Summary

The brush design system provides:

✓ **Three-level API** for different use cases  
✓ **Interactive parameter manipulation** via BrushDesigner  
✓ **Kernel evaluation on Lambda** for spectral coverage analysis  
✓ **Visualization tools** for both spectral and spatial domains  
✓ **Coverage metrics** for parameter optimization  
✓ **Integration** with Signal class and filter system  

### Key Innovation

**Access to kernel handle `g(λ)` during design stage**, enabling:
- Evaluation on Lambda axis before spatial generation
- Parameter tuning based on spectral characteristics
- Coverage analysis (number of modes)
- Systematic parameter optimization

This addresses the core need: "take a spectral heat kernel and evaluate it on the Lambda axis to see how it covers the eigenspace" **before** committing to the final brush weights.
