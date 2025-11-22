# BCT Filter Architecture - Quick Reference

## Architecture Overview

```
+kernels/          → Pure mathematical functions (domain-agnostic)
├── +spatial/      → heat, mexican_hat (for Lambda domain)
├── +temporal/     → gaussian, bandpass (for Time/Omega domain)
└── +joint/        → gabor, separable (for Joint domain)

Filter.m           → Kernel + Domain + Parameters
FilterDesigner.m   → Factory for easy creation
FilterBank.m       → Collection management
```

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

### Temporal (Time/Omega domain)
- **gaussian** - `@(x, center, sigma)`
  ```matlab
  filt = designer.temporal('gaussian', 'center', 10, 'sigma', 2);
  ```
- **bandpass** - `@(x, low, high)`
  ```matlab
  filt = designer.temporal('bandpass', 'low', 8, 'high', 12);
  ```

### Spatial (Lambda domain)
- **heat** - `@(lambda, tau)` - Diffusion kernel
  ```matlab
  filt = designer.spatial('heat', 'tau', 0.1);
  ```
- **mexican_hat** - `@(lambda, scale)` - Band-pass wavelet
  ```matlab
  filt = designer.spatial('mexican_hat', 'scale', 10);
  ```

### Joint (Joint domain)
- **gabor** - `@(X, Y, center_x, center_y, sigma_x, sigma_y)`
  ```matlab
  filt = designer.joint('gabor', ...
      'center_x', 5, 'center_y', 10, ...
      'sigma_x', 1, 'sigma_y', 2);
  ```
- **separable** - Combines two 1D kernels
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

1. Create kernel function in appropriate package:
   ```matlab
   % toolbox/+bct/+filters/+kernels/+temporal/mykernel.m
   function kernel_fh = mykernel()
       kernel_fh = @(x, param1, param2) ... ;
   end
   ```

2. Add parameter defaults in Filter.parseParameters():
   ```matlab
   case 'mykernel'
       addParameter(p, 'param1', default_val, @isnumeric);
       addParameter(p, 'param2', default_val, @isnumeric);
   ```

3. Use it:
   ```matlab
   filt = designer.temporal('mykernel', 'param1', val1, 'param2', val2);
   ```
