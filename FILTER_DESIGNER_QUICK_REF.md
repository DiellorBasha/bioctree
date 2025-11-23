# BctFilterDesigner Quick Reference

## Slider → Filter Parameter Mapping

### Joint Filter (Lambda × Omega) with Gabor Kernel

| UI Slider | Filter Parameter | Physical Meaning | Units | Default |
|-----------|------------------|------------------|-------|---------|
| `k0Slider` | `center_x` | Center wavenumber (spatial frequency) | rad/mm | Midpoint of Lambda.axis |
| `sigma_kSlider` | `sigma_x` | Wavenumber bandwidth (spatial spread) | rad/mm | 10% of Lambda range |
| `omegaSlider` | `center_y` | Center frequency (temporal frequency) | rad/s | 0 (DC) |
| `sigma_oSlider` | `sigma_y` | Frequency bandwidth (temporal spread) | rad/s | 5% of Omega range |

## Gabor Kernel Formula

**2D Separable Gaussian:**
```
H(k, ω) = exp(-0.5 * ((k - k0)/σ_k)²) × exp(-0.5 * ((ω - ω0)/σ_ω)²)
```

**Parameter mapping:**
- k0 = `center_x` (k0Slider)
- σ_k = `sigma_x` (sigma_kSlider)
- ω0 = `center_y` (omegaSlider)
- σ_ω = `sigma_y` (sigma_oSlider)

## Code Access Pattern

### From Sliders to Filter
```matlab
% When slider moves (e.g., k0Slider):
app.CurrentFilter.setParameter('center_x', app.k0Slider.Value);
updateKernelPreview(app);
```

### From Filter to Display
```matlab
% Preview (fast, 200×200 grid):
F_preview = gabor_kernel(K_grid, W_grid, k0, ω0, σ_k, σ_ω);

% Full synthesis (actual domain grid):
F_full = app.CurrentFilter.evaluate();  % Uses Joint.A_grid, Joint.B_grid
```

## App Workflow

```
1. SCAN      → Find BCT objects in workspace
2. LOAD      → app.FilterDesigner = FilterDesigner(BCT)
             → app.CurrentFilter = designer.joint('gabor', ...)
             → updateKernelSliders() sets ranges
3. SLIDERS   → Filter.setParameter(name, value)
             → updateKernelPreview() shows result
4. SYNTHESIZE → Filter.evaluate() on full Joint grid
             → Visualize in UIAxesResponse
```

## Domain Axes

| Domain | Axis Property | Units | Physical Meaning |
|--------|---------------|-------|------------------|
| **Lambda** | `Lambda.axis` | rad/mm | Wavenumber k = √λ (spatial frequency) |
| **Omega** | `Omega.axis` | rad/s | Angular frequency ω = 2πf (temporal frequency) |
| **Joint** | `Joint.A_grid`, `Joint.B_grid` | Mixed | Meshgrids of Lambda × Omega |

## Conversion Table

| Quantity | Formula | Example |
|----------|---------|---------|
| Wavenumber → Wavelength | λ = 2π/k | k=0.2 rad/mm → λ=31.4 mm |
| Angular freq → Frequency | f = ω/(2π) | ω=125.7 rad/s → f=20 Hz |
| Frequency → Angular freq | ω = 2πf | f=10 Hz → ω=62.8 rad/s |
| Eigenvalue → Wavenumber | k = √λ | λ=0.04 → k=0.2 rad/mm |

## Parameter Effects

### Spatial Domain (k0, σ_k)
- **Increase k0** → Filter selects finer spatial details (smaller wavelengths)
- **Decrease k0** → Filter selects coarser features (larger wavelengths)
- **Increase σ_k** → Broader spatial bandwidth (less selective)
- **Decrease σ_k** → Narrower bandwidth (more selective, sharp peak)

### Temporal Domain (ω0, σ_ω)
- **Increase ω0** → Filter selects higher frequencies (faster oscillations)
- **Decrease ω0** → Filter selects lower frequencies (slower changes)
- **ω0 = 0** → DC component (mean/trend)
- **Increase σ_ω** → Broader frequency bandwidth
- **Decrease σ_ω** → Narrower bandwidth (sharp frequency selection)

## Typical Use Cases

### Low-pass Spatial Filter
```matlab
k0 = min(Lambda.axis)      % Low wavenumber (large wavelength)
σ_k = (k_max - k_min) / 5  % Moderate bandwidth
```

### High-pass Spatial Filter
```matlab
k0 = max(Lambda.axis)      % High wavenumber (small wavelength)
σ_k = (k_max - k_min) / 10 % Narrow bandwidth
```

### Alpha Band (8-12 Hz) Filter
```matlab
ω0 = 10 * 2*pi             % 10 Hz center
σ_ω = 2 * 2*pi             % ±2 Hz bandwidth
```

### Beta Band (13-30 Hz) Filter
```matlab
ω0 = 20 * 2*pi             % 20 Hz center
σ_ω = 8 * 2*pi             % ±8 Hz bandwidth
```

### Traveling Wave (spatial + temporal)
```matlab
k0 = 0.3                   % Specific wavelength
σ_k = 0.05                 % Narrow spatial band
ω0 = 15 * 2*pi             % Specific frequency (15 Hz)
σ_ω = 3 * 2*pi             % Narrow temporal band
% Result: Selects traveling waves with ~20mm wavelength at 15 Hz
```

## Quick Debugging

### Problem: Sliders don't update preview
**Check:**
```matlab
~isempty(app.CurrentBCT)        % BCT loaded?
~isempty(app.FilterDesigner)    % Designer initialized?
~isempty(app.CurrentFilter)     % Filter created?
```

### Problem: Filter response is flat
**Check:**
```matlab
% Sigma too large relative to domain?
sigma_k < (max(Lambda.axis) - min(Lambda.axis))
sigma_o < (max(Omega.axis) - min(Omega.axis))

% Center outside domain?
k0 >= min(Lambda.axis) && k0 <= max(Lambda.axis)
ω0 >= min(Omega.axis) && ω0 <= max(Omega.axis)
```

### Problem: "No Joint domain"
**Fix:**
```matlab
B = B.createJoint('Lambda', 'Omega');
```

### Problem: "Eigenbasis not computed"
**Fix:**
```matlab
B = B.computeEigenbasis(50);  % Or click "Eigenbasis" button in app
```

## Code Snippets

### Create Custom Filter in App
```matlab
% After loading BCT in app:
app.CurrentFilter = app.FilterDesigner.joint('gabor', ...
    'center_x', 0.25, ...      % k0 = 0.25 rad/mm
    'sigma_x', 0.03, ...       % σ_k = 0.03 rad/mm
    'center_y', 40*2*pi, ...   % f0 = 40 Hz
    'sigma_y', 5*2*pi, ...     % Δf = 5 Hz
    'label', 'Gamma Band Filter');

% Sync sliders to filter
app.k0Slider.Value = 0.25;
app.sigma_kSlider.Value = 0.03;
app.omegaSlider.Value = 40*2*pi;
app.sigma_oSlider.Value = 5*2*pi;

updateKernelPreview(app);
```

### Export Filter to Workspace
```matlab
% From app:
filter_to_export = app.CurrentFilter;
assignin('base', 'my_filter', filter_to_export);

% In base workspace:
H = my_filter.evaluate();  % Get filter response
params = my_filter.Parameters;  % Get all parameters
```

### Batch Create Filters (Frequency Banks)
```matlab
designer = bct.filters.FilterDesigner(B);
frequencies = [8 10 15 20 30];  % Hz

filters = cell(1, length(frequencies));
for i = 1:length(frequencies)
    filters{i} = designer.joint('gabor', ...
        'center_x', 0.2, 'sigma_x', 0.05, ...
        'center_y', frequencies(i)*2*pi, ...
        'sigma_y', 2*2*pi, ...
        'label', sprintf('%d Hz Filter', frequencies(i)));
end
```

## Files Reference

- **App Code**: `toolbox/BctFilterDesignerCode.m`
- **Filter Class**: `toolbox/+bct/+filters/Filter.m`
- **Designer Class**: `toolbox/+bct/+filters/FilterDesigner.m`
- **Gabor Kernel**: `toolbox/+bct/+filters/+kernels/gabor.m`
- **Joint Class**: `toolbox/+bct/@Joint/Joint.m`
- **Test Script**: `test_filter_designer_system.m`
- **Full Guide**: `BctFilterDesigner_Usage.md`
