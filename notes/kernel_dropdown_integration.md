# Kernel Dropdown Integration

## Overview

This document describes the integration of the KernelDropDown and VelocitySpinner controls in the BctFrontend app, enabling dynamic filter creation and velocity control for the velocity_gabor kernel.

## Implementation

### Frontend Callbacks (BctFrontend.m)

#### 1. KernelDropDownValueChanged

**Location:** Lines 287-304

**Purpose:** Recreate filter when user changes kernel type

**Behavior:**
- Calls `BctBackend.createFilterFromKernelType(app, value)` to create new filter
- Updates kernel preview via `BctBackend.updateKernelPreview(app)`
- Shows/hides VelocitySpinner based on kernel type:
  - Visible for 'Velocity Gabor'
  - Hidden for all other kernels

**Registration:** Line 496
```matlab
app.KernelDropDown.ValueChangedFcn = createCallbackFcn(app, @KernelDropDownValueChanged, true);
```

#### 2. VelocitySpinnerValueChanged

**Location:** Lines 307-315

**Purpose:** Update velocity parameter when spinner value changes

**Behavior:**
- Calls `BctBackend.updateVelocityParameter(app, value)` to update filter.v
- Updates kernel preview via `BctBackend.updateKernelPreview(app)`

**Registration:** Line 561
```matlab
app.VelocitySpinner.ValueChangedFcn = createCallbackFcn(app, @VelocitySpinnerValueChanged, true);
```

#### 3. Initial Visibility

VelocitySpinner and VelocitySpinnerLabel are initially hidden (lines 553, 562):
```matlab
app.VelocitySpinnerLabel.Visible = 'off';
app.VelocitySpinner.Visible = 'off';
```

They become visible only when 'Velocity Gabor' is selected.

### Backend Methods (BctBackend.m)

#### 1. createFilterFromKernelType(app, kernelType)

**Location:** Lines 520-636

**Purpose:** Create Joint filter based on kernel type selection

**Inputs:**
- `kernelType`: String from KernelDropDown ('Gaussian', 'Heat', 'Mexican Hat', 'Gabor', 'Velocity Gabor')

**Behavior:**
1. Ensures Joint domain exists (creates if needed)
2. Gets spectral Joint domain (Lambda × Omega)
3. Normalizes kernel type string (lowercase, replace spaces with underscores)
4. Reads current slider values:
   - `k0` = WavenumberSlider.Value
   - `sigma_k` = kbandwidthSlider.Value
   - `omega0` = FrequencySlider.Value
   - `sigma_o` = BandwidthSlider.Value
   - `v` = VelocitySpinner.Value
5. Creates appropriate Filter object based on kernel type:

**Kernel Type Mappings:**

| Kernel Type | Filter Kernel | Parameters |
|------------|---------------|------------|
| velocity_gabor | velocity_gabor | v, lambda0 (k0), sigma_l (sigma_k), sigma_w (sigma_o) |
| gabor | gabor | center_x (k0), sigma_x (sigma_k), center_y (omega0), sigma_y (sigma_o) |
| gaussian | gabor | center_x (k0), sigma_x (sigma_k), center_y (omega0), sigma_y (sigma_o) |
| heat | gabor | center_x (0), sigma_x (1/tau), center_y (omega0), sigma_y (sigma_o) |
| mexican_hat | gabor | center_x (k0), sigma_x (scale), center_y (omega0), sigma_y (sigma_o) |

**Notes:**
- gaussian, heat, and mexican_hat currently use 'gabor' kernel (placeholder until dedicated kernels implemented)
- velocity_gabor uses VelocitySpinner.Value directly for v parameter (not computed from omega)

#### 2. updateVelocityParameter(app, velocity)

**Location:** Lines 638-650

**Purpose:** Update velocity parameter in current filter

**Behavior:**
- Returns early if no CurrentFilter
- Checks if CurrentFilter.KernelName is 'velocity_gabor'
- If yes, updates 'v' parameter via `setParameter('v', velocity)`
- Prints confirmation message

#### 3. createDefaultFilter(app)

**Location:** Lines 641-650

**Purpose:** Create default filter on app startup or BCT load

**Behavior:**
- Gets kernel type from KernelDropDown.Value (defaults to 'Gaussian')
- Delegates to `createFilterFromKernelType(app, kernelType)`

#### 4. updateKernelPreview(app)

**Location:** Lines 652-829

**Purpose:** Update kernel preview visualization

**Behavior:**
- Returns early if no CurrentFilter
- Updates filter parameters based on kernel type:
  - **velocity_gabor**: Updates lambda0, sigma_l, sigma_w, v
  - **Other kernels**: Updates center_x, sigma_x, center_y, sigma_y
- Evaluates kernel on fine grid and displays

## Usage Workflow

### 1. Selecting a Kernel Type

1. User opens BctFrontend app
2. Default kernel is 'Gaussian'
3. User changes KernelDropDown to any of:
   - Gaussian
   - Heat
   - Mexican Hat
   - Gabor
   - Velocity Gabor
4. `KernelDropDownValueChanged` callback fires
5. New filter created with current slider values
6. Kernel preview updates
7. VelocitySpinner shows/hides appropriately

### 2. Adjusting Velocity (for Velocity Gabor)

1. User selects 'Velocity Gabor' from dropdown
2. VelocitySpinner becomes visible
3. User adjusts VelocitySpinner value
4. `VelocitySpinnerValueChanged` callback fires
5. Filter.v parameter updates
6. Kernel preview updates

### 3. Adjusting Other Parameters

1. User adjusts any of the sliders:
   - WavenumberSlider (k0 or lambda0)
   - kbandwidthSlider (sigma_k or sigma_l)
   - FrequencySlider (omega0)
   - BandwidthSlider (sigma_o or sigma_w)
2. Corresponding `ValueChanged` callback fires
3. `updateKernelPreview` updates filter parameters
4. Kernel preview updates

## Parameter Mapping

### Velocity Gabor Kernel

| UI Control | Filter Parameter | Description |
|-----------|-----------------|-------------|
| WavenumberSlider | lambda0 | Center eigenvalue |
| kbandwidthSlider | sigma_l | Spatial bandwidth |
| BandwidthSlider | sigma_w | Temporal bandwidth |
| VelocitySpinner | v | Group velocity (rad/mm/s) |

**Dispersion relation:** ω = v√λ + Dλ

### Standard Kernels (Gabor, Gaussian, etc.)

| UI Control | Filter Parameter | Description |
|-----------|-----------------|-------------|
| WavenumberSlider | center_x | Center wavenumber |
| kbandwidthSlider | sigma_x | Spatial bandwidth |
| FrequencySlider | center_y | Center angular frequency |
| BandwidthSlider | sigma_y | Temporal bandwidth |

## Key Design Decisions

### 1. Direct Velocity Control

**Decision:** VelocitySpinner directly controls filter.v parameter

**Rationale:** Previous implementation computed v from omega via `v = omega0 / sqrt(lambda0)`. This was indirect and unintuitive. Direct control allows users to specify exact group velocity.

### 2. Callback Delegation Pattern

**Decision:** Frontend callbacks delegate to Backend static methods

**Rationale:** Maintains separation of concerns:
- Frontend: UI components and event handling only
- Backend: Business logic and filter management

### 3. Dynamic Visibility

**Decision:** VelocitySpinner visibility controlled by kernel type

**Rationale:** Velocity parameter only applicable to velocity_gabor kernel. Hiding it for other kernels reduces UI clutter and prevents confusion.

### 4. Kernel Type Normalization

**Decision:** Convert dropdown values to lowercase with underscores

**Rationale:** 
- UI displays: 'Velocity Gabor' (user-friendly)
- Code uses: 'velocity_gabor' (MATLAB naming convention)
- Normalization ensures robust string matching

## Testing

### Basic Functionality Tests

```matlab
% 1. Test kernel dropdown changes
app = BctFrontEnd;
app.KernelDropDown.Value = 'Gaussian';
assert(strcmp(app.CurrentFilter.KernelName, 'gabor'), 'Gaussian should create gabor filter');

app.KernelDropDown.Value = 'Velocity Gabor';
assert(strcmp(app.CurrentFilter.KernelName, 'velocity_gabor'), 'Should create velocity_gabor filter');
assert(strcmp(app.VelocitySpinner.Visible, 'on'), 'Velocity spinner should be visible');

% 2. Test velocity parameter update
app.VelocitySpinner.Value = 1.5;
pause(0.1);  % Allow callback to fire
assert(abs(app.CurrentFilter.Parameters.v - 1.5) < 1e-6, 'Velocity should update');

% 3. Test slider updates
app.WavenumberSlider.Value = 0.2;
pause(0.1);
assert(abs(app.CurrentFilter.Parameters.lambda0 - 0.2) < 1e-6, 'lambda0 should update');
```

### Integration Tests

```matlab
% Test complete workflow
app = BctFrontEnd;

% Load BCT
BctBackend.loadDefaultBCT(app);

% Change kernel type
app.KernelDropDown.Value = 'Velocity Gabor';

% Adjust parameters
app.VelocitySpinner.Value = 0.8;
app.WavenumberSlider.Value = 0.15;
app.kbandwidthSlider.Value = 0.05;
app.BandwidthSlider.Value = 10 * 2*pi;

% Verify filter created correctly
F = app.CurrentFilter;
assert(strcmp(F.KernelName, 'velocity_gabor'));
assert(abs(F.Parameters.v - 0.8) < 1e-6);
assert(abs(F.Parameters.lambda0 - 0.15) < 1e-6);
assert(abs(F.Parameters.sigma_l - 0.05) < 1e-6);
```

## Future Enhancements

1. **Dedicated Heat/Mexican Hat Kernels**: Currently use 'gabor' as placeholder
2. **Dispersion Coefficient Control**: Add slider for D parameter in velocity_gabor
3. **Real-time Preview**: Stream kernel updates as sliders move (not just on release)
4. **Parameter Presets**: Save/load common filter configurations
5. **Kernel Comparison View**: Side-by-side comparison of different kernel types

## Related Files

- **Frontend**: `apps/app_code/BctFrontend.m`
- **Backend**: `apps/app_code/BctBackend.m`
- **Kernel Implementation**: `toolbox/+bct/+filters/+kernels/velocity_gabor.m`
- **Filter Class**: `toolbox/+bct/+filters/@Filter/Filter.m`

## References

- **Signal Mask System**: `docs/signal_mask_migration.md`
- **Fundamental Kernels**: `docs/fundamental_kernels.md`
- **Velocity Gabor Kernel**: Original implementation in velocity_gabor.m
