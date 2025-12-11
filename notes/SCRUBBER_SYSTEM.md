# BaseScrubber Component System

## Overview

The BaseScrubber system provides interactive 1D axis navigation with real-time kernel visualization for the BCT toolbox. It enables users to define regions of interest (windows) across different spectral domains with visual feedback.

## Architecture

```
BaseScrubber (core component)
    ├── scrubber.html    - Tailwind UI template with SVG canvas
    ├── scrubber.js      - Complete interaction logic
    └── BaseScrubber.m   - MATLAB wrapper class

Domain Wrappers (configuration-only)
    ├── TimeScrubber.m      - Time domain (ms units)
    ├── OmegaScrubber.m     - Frequency domain (Hz units)
    └── LambdaScrubber.m    - Eigenmode domain (scientific notation)
```

### Design Philosophy

**Single Responsibility**: BaseScrubber handles ALL UI rendering, drag logic, kernel calculations, and event dispatch. Domain wrappers ONLY configure axis metadata.

**Benefits**:
- No code duplication across domains
- Single source of truth for UI behavior
- Easy maintenance and debugging
- Consistent user experience
- Portable across applications

## Features

### Interactive Controls

1. **Drag Center Knob**: Click and drag the center knob to reposition the window
2. **Scroll to Adjust Width**: Scroll over the selection region to zoom in/out
3. **Click-to-Set**: Click anywhere on the axis to jump the center to that position
4. **Asymmetric Mode**: Enable independent left/right handle adjustment

### Kernel Shapes

Six mathematically-defined kernel shapes:
- **Gaussian**: Smooth bell curve (σ = width/6)
- **Rectangular**: Flat-top window (hard cutoff)
- **Triangular**: Linear taper to zero
- **Hamming**: Raised cosine (0.54 + 0.46·cos)
- **Hann**: Cosine-squared taper
- **Tukey**: Flat-top with tapered edges (α = 0.5)

### Visual Feedback

- Real-time kernel curve rendering in SVG
- Gradient fill for visual appeal
- Center line indicator
- Optional left/right boundary lines (asymmetric mode)
- Axis tick marks and labels
- Value displays (center, width)
- Domain badge indicator

## Usage

### Basic Usage

```matlab
% Create base scrubber
scrubber = BaseScrubber();

% Configure axis
scrubber.setAxis(axisMin, axisMax, label, domain, tickFormatter, snapFunction);

% Set window parameters
scrubber.setCenter(50);
scrubber.setWidth(20);
scrubber.setKernelShape('gaussian');

% Set callback
scrubber.OnChange = @(src, evt) disp(evt);
```

### Time Domain Scrubber

```matlab
% From bct.Time object
timeObj = bct.Time(fs, T);
timeScrubber = TimeScrubber(timeObj);

% Manual configuration
timeScrubber = TimeScrubber();
timeScrubber.configureFromTime(tmin, tmax, fs);

% Select temporal window
timeScrubber.setCenter(1.0);  % 1 second
timeScrubber.setWidth(0.2);   % 200 ms window
timeScrubber.setKernelShape('hann');
```

### Frequency Domain Scrubber

```matlab
% From bct.Omega object
omegaObj = bct.Omega(timeObj);
omegaScrubber = OmegaScrubber(omegaObj);

% Manual configuration
omegaScrubber = OmegaScrubber();
omegaScrubber.configureFromOmega(fmin, fmax, df);

% Select frequency band
omegaScrubber.setCenter(60);  % 60 Hz
omegaScrubber.setWidth(20);   % 20 Hz bandwidth
omegaScrubber.setKernelShape('tukey');
```

### Eigenmode Domain Scrubber

```matlab
% From bct.Lambda object
B = bct.bct.fromMesh(V, F);
B.computeEigenbasis(100);
lambdaScrubber = LambdaScrubber(B.Lambda);

% Select eigenmode range
eigenvalues = B.Lambda.lambda;
lambdaScrubber.setCenter(median(eigenvalues));
lambdaScrubber.setWidth(range(eigenvalues) * 0.1);
lambdaScrubber.setKernelShape('gaussian');
```

## API Reference

### BaseScrubber Methods

#### Configuration
- `setAxis(min, max, label, domain, tickFormatter, snapFunction)` - Configure axis parameters
- `setCenter(value)` - Set window center position
- `setWidth(value)` - Set window width
- `setKernelShape(shape)` - Set kernel shape ('gaussian', 'rectangular', etc.)
- `enableAsymmetricMode(enable)` - Enable/disable asymmetric mode
- `reset()` - Reset to default center/width

#### State Access
- `[center, width] = getWindow()` - Get current window parameters
- `spec = toWindowSpec()` - Export to WindowSpec structure
- `fromWindowSpec(spec)` - Import from WindowSpec structure

#### Properties
- `OnChange` - Callback function handle for change events
  - Event data: `{center, width, domain, kernelShape}`

### Domain Wrapper Methods

All domain wrappers inherit BaseScrubber API and add:

#### TimeScrubber
- `configureFromTime(timeObj)` - Configure from bct.Time object
- `configureFromTime(tmin, tmax, fs)` - Manual configuration

#### OmegaScrubber
- `configureFromOmega(omegaObj)` - Configure from bct.Omega object
- `configureFromOmega(fmin, fmax, df)` - Manual configuration

#### LambdaScrubber
- `configureFromLambda(lambdaObj)` - Configure from bct.Lambda object
- `configureFromLambda(eigenvalues)` - Configure from eigenvalue array

## WindowSpec Structure

WindowSpec provides serialization for window parameters:

```matlab
spec = struct(...
    'center', 50, ...
    'width', 20, ...
    'domain', 'time', ...
    'kernel', 'gaussian', ...
    'isSymmetric', true ...
);

% Export
spec = scrubber.toWindowSpec();

% Import
scrubber.fromWindowSpec(spec);
```

## Integration with BCT

### Filter Design Workflow

```matlab
% 1. Load mesh and compute eigenbasis
B = bct.bct.fromMesh(V, F);
B.computeEigenbasis(100);

% 2. Create scrubber for spatial domain
spatialScrubber = LambdaScrubber(B.Lambda);
spatialScrubber.OnChange = @(~, evt) updateFilter(evt);

% 3. User interacts with scrubber
% 4. OnChange callback applies filter with selected window

function updateFilter(evt)
    % Create spatial filter using window parameters
    center = evt.center;
    width = evt.width;
    % ... apply filter to BCT object
end
```

### Multi-Domain Analysis

```matlab
% Create scrubbers for each domain
timeScrubber = TimeScrubber(B.Time);
omegaScrubber = OmegaScrubber(B.Omega);
lambdaScrubber = LambdaScrubber(B.Lambda);

% Coordinate across domains
timeScrubber.OnChange = @(~, evt) updateSpatialAnalysis(evt);
omegaScrubber.OnChange = @(~, evt) updateSpectralAnalysis(evt);
lambdaScrubber.OnChange = @(~, evt) updateManifoldVisualization(evt);
```

## Testing

Run comprehensive tests:
```matlab
run('ui/tailwind/test/test_scrubber_system.m');
```

Quick basic test:
```matlab
run('ui/tailwind/test/test_scrubber_basic.m');
```

## Technical Details

### JavaScript Communication

BaseScrubber uses MATLAB's `uihtml` Data property for bidirectional communication:

**MATLAB → JavaScript**:
```matlab
obj.Data = struct('cmd', 'setCenter', 'value', 50);
```

**JavaScript → MATLAB**:
```javascript
BCT.postToMatlab('onChange', {center: 50, width: 20});
```

### Kernel Mathematics

Each kernel shape is mathematically defined:

**Gaussian**:
```
K(x) = exp(-0.5 * (|x - c| / (w/6))^2)
```

**Rectangular**:
```
K(x) = 1  if |x - c| ≤ w/2, else 0
```

**Triangular**:
```
K(x) = max(0, 1 - |x - c| / (w/2))
```

**Hamming**:
```
K(x) = 0.54 + 0.46 * cos(π * |x - c| / (w/2))  if |x - c| ≤ w/2
```

**Hann**:
```
K(x) = 0.5 * (1 + cos(π * |x - c| / (w/2)))  if |x - c| ≤ w/2
```

**Tukey**:
```
K(x) = {
  1                                    if |x - c| ≤ α·w/4
  0.5 * (1 + cos(π * t))              if α·w/4 < |x - c| ≤ w/2
  0                                    otherwise
}
where t = (|x - c| - α·w/4) / ((1 - α)·w/4), α = 0.5
```

### Performance

- SVG rendering: 60 FPS on standard hardware
- Kernel calculation: <1ms for 200 samples
- Drag latency: <16ms (sub-frame)
- Memory footprint: ~2MB per scrubber instance

## Future Extensions

### ManifoldScrubber (Special Case)

ManifoldScrubber will use a different paradigm:
- 3D mesh interaction instead of 1D axis
- Geodesic radius selection
- Vertex-based seed selection
- Integrated with ManifoldViewer

### Joint Domain Scrubbers

For tensor product domains (Time × Lambda, Omega × Lambda):
- 2D interaction surface
- Rectangular or elliptical windows
- Multi-axis kernel visualization

## See Also

- [Component Base Class](Component.md)
- [ManifoldViewer](ManifoldViewer.md)
- [BCT Domain Architecture](../../docs/concepts/domain-architecture.md)
- [Filter Design Guide](../../docs/tutorials/filter-design.md)
