# BCT Filter Architecture - Quick Reference

## Architecture Overview

```
+kernels/          → Pure mathematical functions (domain-agnostic)
├── gaussian.m     → exp(-(x-c)^2/(2*σ^2))
├── bandpass.m     → Rectangular window
├── heat.m         → exp(-τ*x)
├── mexican_hat.m  → Ricker wavelet
├── gabor.m        → 2D Gaussian
└── separable.m    → Product of two 1D kernels

Filter.m           → Kernel + Domain + Parameters
FilterDesigner.m   → Factory for easy creation
FilterBank.m       → Collection management
```

**Key Principle**: Kernels are domain-agnostic mathematical functions. They become "spatial" or "temporal" only when bound to a Domain object in the Filter class.

## Basic Usage

### 1. Create Filters

```matlab
% Setup BCT
B = bct();
B.Time = bct.Time(0:0.001:1, 1000);
B.Omega = B.Time.dual;

% Method 1: Direct creation
filt = bct.filters.Filter(B.Omega, 'gaussian', ...
    'center', 10, 'sigma', 2, 'label', 'alpha');

% Method 2: Using FilterDesigner (Recommended)
designer = bct.filters.FilterDesigner(B);
filt = designer.temporal('gaussian', 'center', 10, 'sigma', 2);
```

### 2. Update Parameters (GUI-Friendly!)

```matlab
% Direct property access
filt.center = 12;  % ← Perfect for GUI sliders!
filt.sigma = 3;

% Programmatic updates
filt.setParameter('center', 12);
filt.setParameters('center', 12, 'sigma', 3);  % Batch update
```

### 3. Evaluate Filters

```matlab
% Evaluate on domain axis
H = filt.evaluate();

% Evaluate on custom points
custom_points = linspace(0, 50, 1000);
H = filt.evaluate(custom_points);

% Get cached response (auto-computed when needed)
H = filt.Response;
```

### 4. Event Listeners (for GUI plot updates)

```matlab
% Add listener
addlistener(filt, 'ParametersChanged', @updatePlot);

function updatePlot(src, evt)
    H = src.evaluate();
    plot(src.Domain.axis, abs(H));
    title(sprintf('Center=%.1f, Sigma=%.1f', src.center, src.sigma));
end
```

## Available Kernels

All kernels are domain-agnostic mathematical functions. Domain specificity is determined by the Domain object they're bound to in the Filter class, not by the kernel itself.

### 1D Kernels (for Time, Omega, Lambda, or any 1D domain)

- **gaussian** - `@(x, center, sigma)`
  - Mathematical form: `exp(-(x - center)^2 / (2*sigma^2))`
  - Common use: Band-pass filter on frequency domains
  ```matlab
  filt = designer.temporal('gaussian', 'center', 10, 'sigma', 2);  % Frequency filter
  filt = designer.spatial('gaussian', 'center', 5, 'sigma', 1);    % Spectral filter (same kernel!)
  ```

- **bandpass** - `@(x, low, high)`
  - Mathematical form: Rectangular window [low, high]
  - Common use: Ideal band-pass filtering
  ```matlab
  filt = designer.temporal('bandpass', 'low', 8, 'high', 12);  % Alpha band
  ```

- **heat** - `@(x, tau)`
  - Mathematical form: `exp(-tau * x)`
  - Common use: Low-pass diffusion on Lambda (eigenvalues)
  ```matlab
  filt = designer.spatial('heat', 'tau', 0.1);  % Low-pass spatial
  ```

- **mexican_hat** - `@(x, scale)`
  - Mathematical form: Ricker wavelet
  - Common use: Band-pass feature detection
  ```matlab
  filt = designer.spatial('mexican_hat', 'scale', 10);
  ```

### 2D Kernels (for Joint domains)

- **gabor** - `@(X, Y, center_x, center_y, sigma_x, sigma_y)`
  - Mathematical form: 2D Gaussian
  - Common use: Localized spatiotemporal filtering
  ```matlab
  filt = designer.joint('gabor', ...
      'center_x', 5, 'center_y', 10, ...
      'sigma_x', 1, 'sigma_y', 2);
  ```

- **separable** - Product of two 1D kernels
  - Mathematical form: `H(X,Y) = kernel_x(X) * kernel_y(Y)`
  - Common use: Efficient 2D filtering
  ```matlab
  filt = designer.joint('separable', ...
      'kernel_x', heat_kernel, 'kernel_y', gauss_kernel, ...
      'params_x', {0.1}, 'params_y', {10, 2});
  ```

## FilterBank for Multi-Band Analysis

```matlab
bank = bct.filters.FilterBank();

% Add filters
bank.add(designer.temporal('gaussian', 'center', 8, 'sigma', 1, 'label', 'theta'));
bank.add(designer.temporal('gaussian', 'center', 12, 'sigma', 1, 'label', 'alpha'));
bank.add(designer.temporal('gaussian', 'center', 30, 'sigma', 2, 'label', 'beta'));

% Display
bank.list();

% Get by label or index
alpha_filt = bank.get('alpha');
theta_filt = bank.get(1);

% Evaluate all
responses = bank.evaluateAll();  % Cell array of responses

% Remove
bank.remove('beta');
bank.remove(1);
```

## GUI Integration Pattern

### App Designer Setup

```matlab
classdef FilterGUI < matlab.apps.AppBase
    properties
        Filter bct.filters.Filter
        FilterListener event.listener
    end
    
    methods (Access = private)
        function startupFcn(app)
            % Create filter
            app.Filter = bct.filters.Filter(app.BCT.Omega, 'gaussian', ...
                'center', 10, 'sigma', 2);
            
            % Add listener for automatic plot updates
            app.FilterListener = addlistener(app.Filter, 'ParametersChanged', ...
                @(src,evt) updateFilterPlot(app));
            
            % Initial plot
            updateFilterPlot(app);
        end
        
        function centerSliderValueChanged(app, event)
            % Slider callback - direct property assignment!
            app.Filter.center = app.CenterSlider.Value;
            % Plot updates automatically via listener
        end
        
        function sigmaSliderValueChanged(app, event)
            app.Filter.sigma = app.SigmaSlider.Value;
            % Plot updates automatically via listener
        end
        
        function updateFilterPlot(app)
            % Re-evaluate and plot
            H = app.Filter.evaluate();
            plot(app.UIAxes, app.Filter.Domain.axis, abs(H));
            xlabel(app.UIAxes, 'Frequency (Hz)');
            ylabel(app.UIAxes, '|H(f)|');
            title(app.UIAxes, sprintf('Gaussian Filter: %.1f Hz, σ=%.1f', ...
                app.Filter.center, app.Filter.sigma));
        end
    end
end
```

## Key Properties

### Filter Object
- `Domain` - bct.Domain object (Manifold/Lambda/Time/Omega/Joint)
- `KernelName` - String: 'gaussian', 'heat', 'gabor', etc.
- `Parameters` - Struct of kernel parameters
- `Label` - User-defined label

### Dependent Properties (Direct Access)
- `center` - Center parameter
- `sigma` - Sigma parameter
- `tau` - Tau parameter (heat kernel)
- `low`, `high` - Bandpass bounds
- `Response` - Cached filter response

### Events
- `ParametersChanged` - Fired when any parameter changes

## Common Patterns

### Pattern 1: Single Filter with Slider
```matlab
filt = designer.temporal('gaussian', 'center', 10, 'sigma', 2);
% In slider callback:
filt.center = sliderValue;  % Simple!
```

### Pattern 2: Multiple Filters
```matlab
bank = bct.filters.FilterBank();
bank.add(designer.temporal('gaussian', 'center', 10, 'sigma', 2, 'label', 'alpha'));
bank.add(designer.temporal('gaussian', 'center', 30, 'sigma', 4, 'label', 'beta'));

% Update specific filter
bank.get('alpha').center = 12;
```

### Pattern 3: Joint Filter for Spatiotemporal
```matlab
joint_filt = designer.joint('gabor', ...
    'domains', {'Lambda', 'Omega'}, ...
    'center_x', 5, 'center_y', 10, ...
    'sigma_x', 1, 'sigma_y', 2);

% Update spatial center
joint_filt.Parameters.center_x = 7;

% Re-evaluate
H_joint = joint_filt.evaluate();  % [M×N] matrix
```

## Testing

Run comprehensive tests:
```matlab
test_filter_architecture  % Full test suite
example_filter_usage      % Usage examples
```

## Migration from Old Filter Class

Old:
```matlab
filt = bct.filters.Filter('Manifold');
filt.g = bct.filters.design.manifold.heat(B.Manifold, 'tau', 0.1);
```

New:
```matlab
designer = bct.filters.FilterDesigner(B);
filt = designer.spatial('heat', 'tau', 0.1);
```

## Adding Custom Kernels

1. Create kernel function in the kernels package:
   ```matlab
   % toolbox/+bct/+filters/+kernels/mykernel.m
   function kernel_fh = mykernel()
       % mykernel - Returns custom kernel function handle
       %
       % Description:
       %   Pure mathematical function - domain-agnostic.
       %   Becomes a filter when bound to a Domain.
       
       kernel_fh = @(x, param1, param2) ...;
   end
   ```

2. Add parameter defaults in Filter.parseParameters():
   ```matlab
   case 'mykernel'
       addParameter(p, 'param1', default_val, @isnumeric);
       addParameter(p, 'param2', default_val, @isnumeric);
   ```

3. Use it on any domain:
   ```matlab
   filt = designer.temporal('mykernel', 'param1', val1, 'param2', val2);
   filt = designer.spatial('mykernel', 'param1', val1, 'param2', val2);  % Same kernel!
   ```
