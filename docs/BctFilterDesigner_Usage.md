# BctFilterDesigner App - Usage Guide

## Overview
The BctFilterDesigner app provides an interactive GUI for designing and visualizing filters on BCT (Brain Connectivity Toolbox) domains. It uses the new Filter and FilterDesigner architecture with proper integration of the Joint domain class.

## Architecture

### Domain System
- **Manifold ↔ Lambda**: Spatial mesh ↔ Spectral (wavenumber k = √λ)
  - Lambda auto-created with estimated axis when Manifold exists
  - `computeEigenbasis()` fills Lambda.lambda and Lambda.U with actual eigendecomposition
  
- **Time ↔ Omega**: Temporal ↔ Frequency
  - Omega auto-created as Time's dual via property listener
  - Omega.axis provides frequency domain representation (rad/s)

- **Joint**: Combines any two domains (e.g., Lambda×Omega)
  - Created via `B.createJoint('Lambda', 'Omega')`
  - Properties: A_grid, B_grid (meshgrids), A, B (domain objects)

### Filter Design System
The app uses two main classes:

1. **`bct.filters.FilterDesigner`** - Factory for creating filters
   - `designer.spatial(kernel_name, ...)` - Filter on Lambda domain
   - `designer.temporal(kernel_name, ...)` - Filter on Omega domain
   - `designer.joint(kernel_name, ...)` - Filter on Joint domain

2. **`bct.filters.Filter`** - Filter object with kernel and parameters
   - Stores Domain, KernelFunction, Parameters
   - Dependent properties for parameter access (center_x, sigma_x, etc.)
   - `evaluate()` method to compute filter response on domain grid

## Default Behavior

### When Loading a BCT Object
1. **FilterDesigner** is created for the BCT object
2. **Joint domain** (Lambda×Omega) is created if not present
3. **Default filter** is created using Gabor kernel (2D Gaussian)
   - Kernel type: `'gabor'`
   - Domain: Joint (Lambda×Omega)
   - Parameters initialized from slider values:
     - `center_x` = k0 (wavenumber center, rad/mm)
     - `sigma_x` = σ_k (wavenumber bandwidth, rad/mm)
     - `center_y` = ω0 (angular frequency center, rad/s)
     - `sigma_y` = σ_ω (frequency bandwidth, rad/s)

### Slider Functionality

#### **k0Slider** - Center Wavenumber (Lambda/Spatial)
- **Controls**: `Filter.Parameters.center_x`
- **Units**: rad/mm (wavenumber)
- **Range**: [min(Lambda.axis), max(Lambda.axis)]
- **Default**: Midpoint of Lambda.axis range
- **Purpose**: Sets the center of the spatial frequency filter

#### **sigma_kSlider** - Wavenumber Bandwidth
- **Controls**: `Filter.Parameters.sigma_x`
- **Units**: rad/mm
- **Range**: [0.001, (k_max - k_min)/2]
- **Default**: 10% of Lambda.axis range
- **Purpose**: Sets the width/spread of the spatial frequency filter

#### **omegaSlider** - Center Frequency (Omega/Temporal)
- **Controls**: `Filter.Parameters.center_y`
- **Units**: rad/s (angular frequency)
- **Range**: [min(Omega.axis), max(Omega.axis)]
- **Default**: 0 (DC component)
- **Purpose**: Sets the center of the temporal frequency filter

#### **sigma_oSlider** - Frequency Bandwidth
- **Controls**: `Filter.Parameters.sigma_y`
- **Units**: rad/s
- **Range**: [0.1, (ω_max - ω_min)/2]
- **Default**: 5% of Omega.axis range
- **Purpose**: Sets the width/spread of the temporal frequency filter

## Workflow

### Basic Usage
1. **Scan Workspace**: Click "Scan" to find BCT objects in MATLAB workspace
2. **Select Object**: Click on BCT object in tree view
3. **Load**: Click "Load" button
   - Initializes FilterDesigner
   - Creates default Joint filter (Lambda×Omega with Gabor kernel)
   - Updates slider ranges based on domain axes
4. **Adjust Parameters**: Move sliders to change filter shape
   - Each slider movement updates Filter.Parameters
   - Kernel preview updates automatically
5. **Synthesize**: Click "Synthesize" to evaluate filter on full Joint grid
   - Calls `Filter.evaluate()` on Joint domain
   - Displays filter response as heatmap

### Filter Types (FilterTypeDropDown)
Currently supported:
- **Joint** (default): Gabor kernel on Lambda×Omega
  - Separable 2D Gaussian
  - Independent control of spatial and temporal characteristics

Future options:
- **Spatial**: Filter on Lambda only (wavenumber kernels)
- **Temporal**: Filter on Omega only (frequency kernels)
- **Joint Separable**: Product of 1D kernels
- **Dynamic**: Time-varying filters

## Kernel Preview vs Filter Response

### Kernel Preview (UIAxesKernel)
- Shows the **kernel function only** (mathematical function)
- Evaluated on a smooth 200×200 grid for visualization
- Updates in real-time as sliders move
- Axes: Wavenumber (k, rad/mm) × Frequency (Hz)

### Filter Response (UIAxesResponse)
- Shows the **filter evaluated on actual domain grid**
- Uses Joint.A_grid and Joint.B_grid from BCT object
- Only computed when "Synthesize" button clicked
- Shows response at actual eigenvalues/frequencies

## Mathematical Details

### Gabor Kernel (Default Joint Filter)
```matlab
H(k, ω) = exp(-((k - k0)² / (2σ_k²) + (ω - ω0)² / (2σ_ω²)))
```

Where:
- k = wavenumber (from Lambda.axis, k = √λ)
- ω = angular frequency (from Omega.axis)
- k0 = center_x (k0Slider value)
- σ_k = sigma_x (sigma_kSlider value)
- ω0 = center_y (omegaSlider value)
- σ_ω = sigma_y (sigma_oSlider value)

This is a **separable** 2D Gaussian:
```matlab
H(k, ω) = Gaussian_k(k; k0, σ_k) × Gaussian_ω(ω; ω0, σ_ω)
```

### Physical Interpretation
- **k0**: Selects wavelength λ = 2π/k0 (spatial scale of interest)
- **σ_k**: Bandwidth in wavenumber space (range of wavelengths)
- **ω0**: Selects frequency f = ω0/(2π) (temporal scale of interest)
- **σ_ω**: Bandwidth in frequency space (range of frequencies)

## Code Structure

### Key Functions

#### `createDefaultFilter(app)`
- Creates default Joint filter with Gabor kernel
- Initializes parameters from slider values
- Called when BCT object is loaded

#### `updateKernelPreview(app)`
- Updates Filter.Parameters from slider values
- Evaluates kernel on preview grid (200×200)
- Displays in UIAxesKernel

#### `updateKernelSliders(app)`
- Sets slider ranges based on Lambda.axis and Omega.axis
- Initializes slider values to sensible defaults
- Updates Filter parameters

#### Slider Callbacks
Each slider has a callback that:
1. Updates corresponding Filter.Parameter using `setParameter()`
2. Calls `updateKernelPreview()` to refresh visualization

Example (k0Slider):
```matlab
function k0SliderValueChanged(app, event)
    if ~isempty(app.CurrentFilter)
        app.CurrentFilter.setParameter('center_x', app.k0Slider.Value);
    end
    updateKernelPreview(app);
end
```

#### `SynthesizeButtonPushed(app, event)`
- Validates Lambda.lambda exists (eigenbasis computed)
- Ensures Joint domain exists
- Evaluates `Filter.evaluate()` on full Joint grid
- Visualizes response in UIAxesResponse

## Example BCT Workflow

```matlab
% Create BCT object
B = bct();

% Load mesh
B.Manifold = bct.Manifold('path/to/mesh.gii');

% Compute eigenbasis (fills Lambda.lambda and Lambda.U)
B.computeEigenbasis(100);  % 100 eigenmodes

% Create Time domain
B.Time = bct.Time(0:0.01:1, 100);  % 0-1s, 100Hz sampling

% Omega is automatically created as Time.dual

% Launch app
app = BctFilterDesigner;

% In app:
% 1. Scan workspace
% 2. Load BCT object 'B'
% 3. App automatically creates Joint(Lambda, Omega) and default Gabor filter
% 4. Adjust sliders to tune filter
% 5. Click Synthesize to see full response
```

## Advanced Usage

### Custom Filter Creation (Outside App)
```matlab
% Using FilterDesigner
designer = bct.filters.FilterDesigner(B);

% Create custom joint filter
filt = designer.joint('gabor', ...
    'center_x', 0.2, 'sigma_x', 0.05, ...   % Wavenumber params
    'center_y', 40*2*pi, 'sigma_y', 10*2*pi, ... % Frequency params (rad/s)
    'label', 'Alpha Band Spatial Filter');

% Evaluate filter
H = filt.evaluate();  % Returns [M×N] on Joint grid

% Update parameters interactively
filt.center_x = 0.3;  % Change center wavenumber
filt.sigma_y = 5*2*pi;  % Change frequency bandwidth
H_new = filt.evaluate();
```

### Loading Custom Filter into App
```matlab
% Create filter manually
app.CurrentFilter = designer.joint('gabor', ...
    'center_x', 0.15, 'sigma_x', 0.03, ...
    'center_y', 20*2*pi, 'sigma_y', 5*2*pi);

% Update sliders to match filter parameters
app.k0Slider.Value = app.CurrentFilter.Parameters.center_x;
app.sigma_kSlider.Value = app.CurrentFilter.Parameters.sigma_x;
app.omegaSlider.Value = app.CurrentFilter.Parameters.center_y;
app.sigma_oSlider.Value = app.CurrentFilter.Parameters.sigma_y;

% Refresh preview
updateKernelPreview(app);
```

## Troubleshooting

### "Eigenbasis Not Computed" Error
**Solution**: Click "Eigenbasis" button in app to compute `B.computeEigenbasis(k)`
- This fills Lambda.lambda with actual eigenvalues
- Lambda is always created as Manifold's dual, but starts with estimated axis

### "No Omega Domain" Error
**Solution**: Assign Time domain to BCT object
```matlab
B.Time = bct.Time(timepoints, fs);
% Omega is automatically created as Time.dual
```

### Sliders Don't Update Filter
**Check**:
1. BCT object loaded? (`app.CurrentBCT` not empty)
2. FilterDesigner initialized? (`app.FilterDesigner` not empty)
3. Filter created? (`app.CurrentFilter` not empty)

### Filter Response is Flat/Constant
**Check**:
1. Sigma values too large (filter spread wider than domain)
2. Center values outside domain range
3. Joint grid dimensions correct (`B.Joint.size()`)

## Future Enhancements

### Planned Features
1. **Multiple filter types** via FilterTypeDropDown
   - Spatial only (Lambda kernels: heat_wavenumber, mexican_hat_wavenumber)
   - Temporal only (Omega kernels: gaussian, bandpass)
   - Joint separable (independent 1D kernels combined)
   
2. **Kernel selection dropdown**
   - Gaussian, Heat, Mexican Hat, Bandpass, etc.
   - Different parameter sets per kernel type
   
3. **Filter bank creation**
   - Multiple filters at different scales
   - Use `bct.filters.FilterBank` class
   
4. **Signal filtering**
   - Apply filter to actual data on BCT object
   - Show before/after comparison

5. **Export functionality**
   - Save filter parameters
   - Export filter response to workspace

## References

- Filter class: `toolbox/+bct/+filters/Filter.m`
- FilterDesigner class: `toolbox/+bct/+filters/FilterDesigner.m`
- Gabor kernel: `toolbox/+bct/+filters/+kernels/gabor.m`
- Joint class: `toolbox/+bct/@Joint/Joint.m`
- Example workflow: `example_bct_filter_workflow.m`
