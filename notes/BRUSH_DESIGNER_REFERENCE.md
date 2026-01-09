# Brush Designer Quick Reference

## Overview

`BrushDesigner` provides an interactive workflow for designing brushes with parameter manipulation and kernel evaluation **before** finalizing the brush weights.

## Key Workflow

```matlab
% 1. Create designer
designer = bct.brush.design.create(category, type, manifold, params, [time]);

% 2. Evaluate kernel on Lambda axis
H = designer.evaluateKernel();           % Use Lambda.lambda
H = designer.evaluateKernel(lambda_vec);  % Custom points

% 3. Visualize spectral response
designer.plotKernelResponse();

% 4. Adjust parameters
designer.setParameter('tau', 0.3);
designer.setParameters(struct('tau', 0.3, 'source', 200));

% 5. Preview spatial pattern
designer.preview();
designer.preview('TimeIndex', 50);  % For time brushes

% 6. Finalize
w = designer.finalize();
```

## Basic Examples

### Heat Kernel Coverage Analysis

```matlab
% Create designer
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'heat', 'tau', 0.1));

% Evaluate on Lambda
H = designer.evaluateKernel();
fprintf('Modes > 1%%: %d\n', sum(H > 0.01));

% Increase diffusion
designer.setParameter('tau', 0.3);
H_new = designer.evaluateKernel();
fprintf('Modes > 1%%: %d\n', sum(H_new > 0.01));

% Visualize
designer.plotKernelResponse();

% Finalize
w = designer.finalize();
```

### Gaussian Bandpass

```matlab
% Design bandpass filter
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 500, 'kernel', 'gaussian', 'center', 100, 'bandwidth', 20));

% Check coverage
H = designer.evaluateKernel();
designer.plotKernelResponse();

% Adjust bandwidth
designer.setParameter('bandwidth', 50);
designer.plotKernelResponse();

w = designer.finalize();
```

### Time-Varying Brush

```matlab
% Create with time domain
designer = bct.brush.design.create('time', 'spectral', B.Manifold, ...
    struct('source', 200, 'kernel', 'heat', 'tau', 0.15), B.Time);

% Evaluate kernel at first time point
H = designer.evaluateKernel();

% Preview at different times
designer.preview('TimeIndex', 1);
designer.preview('TimeIndex', 50);
designer.preview('TimeIndex', 100);

% Finalize [N×T]
w = designer.finalize();
```

## BrushDesigner Properties

| Property | Description |
|----------|-------------|
| `Category` | 'patch', 'trajectory', 'time' |
| `BrushType` | Brush type name ('spectral', etc.) |
| `Manifold` | bct.Manifold object |
| `Time` | bct.Time object (optional) |
| `Parameters` | struct of current parameters |
| `KernelHandle` | Function handle g(lambda) (spectral only) |
| `Lambda` | Lambda domain from manifold.dual |

## Methods

### setParameter(name, value)
Update single parameter.

```matlab
designer.setParameter('tau', 0.25);
designer.setParameter('bandwidth', 50);
```

### setParameters(struct)
Update multiple parameters at once.

```matlab
designer.setParameters(struct('tau', 0.3, 'source', 200));
```

### evaluateKernel() → H
Evaluate kernel on Lambda.lambda axis.

```matlab
H = designer.evaluateKernel();
```

### evaluateKernel(lambda_values) → H
Evaluate kernel at custom points.

```matlab
lambda_custom = linspace(0, max(lambda), 200);
H = designer.evaluateKernel(lambda_custom);
```

### plotKernelResponse()
Visualize kernel H(λ) on Lambda axis with linear and log scales.

```matlab
designer.plotKernelResponse();
```

### preview()
Generate and visualize brush weights.

```matlab
designer.preview();                  % Static brush
designer.preview('TimeIndex', 50);   % Time brush at t=50
```

### finalize() → w
Generate final brush weights.

```matlab
w = designer.finalize();  % [N×1] or [N×T]
```

## Coverage Metrics

When evaluating kernels on Lambda, useful metrics:

```matlab
H = designer.evaluateKernel();
lambda = designer.Lambda.lambda;

% Count modes above thresholds
n_1pct = sum(H > 0.01);
n_10pct = sum(H > 0.10);
n_50pct = sum(H > 0.50);

% Effective bandwidth
eff_bw = sum(H) / max(H);

% Peak location
[~, idx] = max(H);
peak_lambda = lambda(idx);

fprintf('Modes > 1%%: %d\n', n_1pct);
fprintf('Effective BW: %.1f\n', eff_bw);
fprintf('Peak at λ=%.2f\n', peak_lambda);
```

## Parameter Tuning Workflow

### Find Optimal Tau for Target Coverage

```matlab
target_modes = 50;
tau_range = linspace(0.05, 0.8, 50);
mode_counts = zeros(size(tau_range));

for i = 1:length(tau_range)
    designer.setParameter('tau', tau_range(i));
    H = designer.evaluateKernel();
    mode_counts(i) = sum(H > 0.01);
end

% Find best tau
[~, idx] = min(abs(mode_counts - target_modes));
tau_optimal = tau_range(idx);

designer.setParameter('tau', tau_optimal);
designer.plotKernelResponse();
```

### Compare Multiple Configurations

```matlab
configs = [
    struct('tau', 0.1, 'label', 'Sharp');
    struct('tau', 0.3, 'label', 'Medium');
    struct('tau', 0.6, 'label', 'Smooth')
];

figure;
for i = 1:length(configs)
    designer.setParameter('tau', configs(i).tau);
    H = designer.evaluateKernel();
    
    plot(lambda, H, 'LineWidth', 2, 'DisplayName', configs(i).label);
    hold on;
end
grid on;
xlabel('\lambda');
ylabel('H(\lambda)');
legend('Location', 'best');
set(gca, 'YScale', 'log');
```

## Use Cases

### 1. **Heat Diffusion Control**
Adjust `tau` to control spatial smoothness and spectral coverage.

- Low tau (0.05-0.15): Sharp, many modes, localized
- Medium tau (0.2-0.4): Balanced coverage
- High tau (0.5-1.0): Smooth, few modes, diffuse

### 2. **Bandpass Filtering**
Design Gaussian bandpass to isolate specific spatial frequencies.

```matlab
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'gaussian', 'center', 100, 'bandwidth', 30));
```

### 3. **Coverage Analysis**
Evaluate how many eigenmodes contribute to the pattern.

```matlab
H = designer.evaluateKernel();
coverage = sum(H > 0.01);  % Modes with >1% response
```

### 4. **Parameter Optimization**
Systematically search parameter space for desired characteristics.

## Demos

- `examples/demo_brush_designer_quickstart.m` - Basic workflow
- `examples/demo_brush_designer.m` - Comprehensive examples
- `examples/demo_spectral_coverage.m` - Coverage analysis

## Integration with Signal Generation

After finalizing design, create signal:

```matlab
% Design interactively
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, params);
designer.plotKernelResponse();
designer.setParameter('tau', 0.3);
w = designer.finalize();

% Create signal
sig = bct.Signal(B.Manifold, w, 'Name', 'Tuned Heat Brush');
sig.plot();
```

Or use directly:

```matlab
% After finding optimal parameters via designer
sig = bct.Signal.fromBrush('spectral', B, 'kernel', 'heat', 'tau', 0.3, 'source', 100);
```

## Key Advantages

✓ **Preview kernel response** on Lambda axis before generating brush  
✓ **Interactive parameter adjustment** with immediate feedback  
✓ **Coverage metrics** to ensure desired spectral characteristics  
✓ **Spatial preview** to verify pattern before finalizing  
✓ **Systematic optimization** of parameters for target behavior  

## See Also

- `bct.brush.design.brush` - Direct brush generation
- `bct.Signal.fromBrush` - Signal from brush
- `bct.filter.design.kernel` - Filter kernel design
- `FilterDesigner` - Filter designer class
