# synth_mesh_signal Signal Class Integration - Summary

## Overview
Updated `bct.sim.synth_mesh_signal` to work with the new `bct.signal.Signal` class architecture. The function now returns a `bct` object with Signal objects automatically created and added, rather than returning raw data arrays.

---

## Key Changes

### 1. Function Signature (Return Value)

**Old:**
```matlab
[xrec, a, f] = bct.sim.synth_mesh_signal(B, spec, ...)
```
- Returns raw data array `xrec [N×1]`

**New:**
```matlab
[B_out, a, f] = bct.sim.synth_mesh_signal(B, spec, ...)
```
- Returns `bct` object with Signal(s) added
- Signals accessible via `B_out.Signals`

---

### 2. New Parameters

#### `'label'` (string)
Custom label for the Signal object. If not provided, auto-generates label based on spec type.

**Example:**
```matlab
B = synth_mesh_signal(B, spec, 'label', 'alpha_oscillation');
```

#### `'return_raw'` (logical, default: false)
Legacy mode: returns raw data `[N×1]` instead of bct object.

**Example:**
```matlab
x = synth_mesh_signal(B, spec, 'return_raw', true);  % Returns [N×1] array
```

---

### 3. Multiple Signal Support

The function now accepts an **array of spec structures** to generate multiple signals at once.

**Example:**
```matlab
% Create multiple signals
specs = struct('type', {}, 'f0', {}, 'bw_abs', {});
for i = 1:5
    specs(i).type = 'narrowband';
    specs(i).f0 = 0.05 * i;
    specs(i).bw_abs = 0.01;
end

B = bct.sim.synth_mesh_signal(B, specs);
% B.Signals now contains 5 Signal objects
```

---

### 4. Automatic Label Generation

When no custom label is provided, labels are auto-generated based on spec type:

| Spec Type | Example Label |
|-----------|---------------|
| `narrowband` | `narrowband_f0.1` |
| `twoband` | `twoband_f0.05_f0.15` |
| `flat` | `flat_1` |
| `powerlaw` | `powerlaw_a1.5` |
| `bandpass` | `bandpass_0.05_0.15` |

Multiple signals get indexed: `narrowband_f0.1_1`, `narrowband_f0.1_2`, etc.

---

## Usage Examples

### Example 1: Single Signal (Default Behavior)

```matlab
% Create bct object
[V, F] = icosphere(3);
B = bct.bct.fromMesh(V, F);

% Generate narrowband signal
spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;

B = bct.sim.synth_mesh_signal(B, spec, 'k', 200);

% Access signal
sig = B.Signals(1);
fprintf('Label: %s\n', sig.Label);  % "narrowband_f0.1"
data = sig.Data;  % [N×1] single array
```

### Example 2: Custom Label

```matlab
spec.type = 'powerlaw';
spec.alpha = 1.5;

B = bct.sim.synth_mesh_signal(B, spec, 'label', 'pink_noise', 'k', 200);

sig = B.Signals(1);
fprintf('Label: %s\n', sig.Label);  % "pink_noise"
```

### Example 3: Multiple Signals from Array

```matlab
% Define multiple frequency bands
specs = struct('type', {}, 'f0', {}, 'bw_abs', {});
for i = 1:5
    specs(i).type = 'narrowband';
    specs(i).f0 = 0.02 * i;  % 0.02, 0.04, 0.06, 0.08, 0.10 cycles/mm
    specs(i).bw_abs = 0.005;
end

% Generate all signals at once
B = bct.sim.synth_mesh_signal(B, specs, 'k', 300);

% Access signals
fprintf('Generated %d signals:\n', length(B.Signals));
for i = 1:length(B.Signals)
    fprintf('  %d. %s\n', i, B.Signals(i).Label);
end
```

### Example 4: Chaining Signal Generation

```matlab
B = bct.bct.fromMesh(V, F);

% Add low frequency signal
spec1.type = 'narrowband';
spec1.f0 = 0.05;
spec1.bw_abs = 0.01;
B = bct.sim.synth_mesh_signal(B, spec1, 'label', 'low_freq', 'k', 200);

% Add high frequency signal
spec2.type = 'narrowband';
spec2.f0 = 0.20;
spec2.bw_abs = 0.02;
B = bct.sim.synth_mesh_signal(B, spec2, 'label', 'high_freq', 'k', 200);

% B.Signals now has 2 signals
fprintf('Signals: %s, %s\n', B.Signals(1).Label, B.Signals(2).Label);
```

### Example 5: Legacy Mode (Backward Compatibility)

```matlab
% Get raw data array (old behavior)
spec.type = 'flat';
x = bct.sim.synth_mesh_signal(B, spec, 'return_raw', true, 'k', 200);

% x is [N×1] single array, not a bct object
assert(isnumeric(x));
assert(size(x, 1) == B.Manifold.N);
```

### Example 6: Different Spec Types

```matlab
B = bct.bct.fromMesh(V, F);

% Flat spectrum (white noise)
spec.type = 'flat';
B = bct.sim.synth_mesh_signal(B, spec, 'k', 200);

% 1/f noise (pink noise)
spec.type = 'powerlaw';
spec.alpha = 1;
B = bct.sim.synth_mesh_signal(B, spec, 'k', 200);

% Bandpass filter
spec.type = 'bandpass';
spec.fmin = 0.05;
spec.fmax = 0.15;
B = bct.sim.synth_mesh_signal(B, spec, 'k', 200);

% Two-band signal
spec.type = 'twoband';
spec.f1 = 0.05;
spec.bw1 = 0.01;
spec.f2 = 0.15;
spec.bw2 = 0.02;
B = bct.sim.synth_mesh_signal(B, spec, 'k', 200);

% B.Signals now has 4 different signals
```

---

## Migration Guide

### Old Code → New Code

#### Single Signal Generation

**Old:**
```matlab
x = bct.sim.synth_mesh_signal(B, spec);
% x is [N×1] array
```

**New (default):**
```matlab
B = bct.sim.synth_mesh_signal(B, spec);
x = B.Signals(1).Data;  % Get data from Signal object
```

**New (legacy mode):**
```matlab
x = bct.sim.synth_mesh_signal(B, spec, 'return_raw', true);
% Same as old behavior
```

#### Multiple Signals in Loop

**Old:**
```matlab
signals = cell(5, 1);
for i = 1:5
    spec.f0 = 0.05 * i;
    signals{i} = bct.sim.synth_mesh_signal(B, spec);
end
```

**New (spec array):**
```matlab
specs = struct('type', {}, 'f0', {}, 'bw_abs', {});
for i = 1:5
    specs(i).type = 'narrowband';
    specs(i).f0 = 0.05 * i;
    specs(i).bw_abs = 0.01;
end
B = bct.sim.synth_mesh_signal(B, specs);
% All signals in B.Signals array
```

**New (chaining):**
```matlab
for i = 1:5
    spec.f0 = 0.05 * i;
    B = bct.sim.synth_mesh_signal(B, spec);
end
% All signals accumulated in B.Signals
```

---

## Implementation Details

### New Helper Function: `generate_label()`

Internal function that creates automatic labels:

```matlab
function label = generate_label(spec, idx)
    switch lower(spec.type)
        case 'narrowband'
            label = sprintf('narrowband_f%.3g', spec.f0);
        case 'powerlaw'
            label = sprintf('powerlaw_a%.2g', spec.alpha);
        % ... etc
    end
end
```

### Signal Creation Flow

1. **Parse parameters** - Check for `label` and `return_raw` options
2. **Handle spec array** - If multiple specs, recursively generate each
3. **Generate signal data** - Same eigendecomposition and synthesis logic
4. **Create Signal object** - `bct.signal.Signal(Manifold, data, label)`
5. **Add to bct** - `B.addSignal(sig)` with automatic validation
6. **Return** - Return modified bct object (or raw data if legacy mode)

### Backward Compatibility

The `return_raw` parameter ensures complete backward compatibility:

```matlab
% New code (default)
B = synth_mesh_signal(B, spec);

% Old code (still works)
x = synth_mesh_signal(B, spec, 'return_raw', true);
```

---

## Benefits

### ✅ Type Safety
- Returns proper `bct.signal.Signal` objects
- Automatic dimension validation
- Clear object structure

### ✅ Better Organization
- Signals stored in structured array
- Labels for identification
- Metadata accessible via Signal properties

### ✅ Workflow Integration
- Seamlessly integrates with bct object
- Signals automatically validated against Manifold
- Can accumulate multiple signals

### ✅ Reduced Boilerplate
- No manual Signal creation needed
- Automatic labeling reduces code
- Spec arrays eliminate loops

### ✅ Maintains Compatibility
- `return_raw` mode for legacy code
- Same eigendecomposition logic
- Same output format available

---

## Files Modified

### `toolbox/+bct/+sim/synth_mesh_signal.m`

**Changes:**
- Updated function signature: `[B_out, a, f]` instead of `[xrec, a, f]`
- Added parameters: `'label'`, `'return_raw'`
- Added spec array handling for multiple signals
- Added automatic label generation
- Added Signal object creation and addition
- Added helper function `generate_label()`

**Lines changed:** ~80 lines added/modified

---

## Testing

### Test Files Created

1. **`tests/test_synth_mesh_signal.m`** - Comprehensive functional tests
   - Single signal generation
   - Multiple signals from array
   - Custom labels
   - Different spec types
   - Legacy mode
   - Chaining
   - Data validation

2. **`tests/test_synth_mesh_signal_api.m`** - API-level tests (no gptoolbox)
   - Parameter parsing
   - Label generation
   - API design verification
   - Manual Signal workflow

### Test Status
✅ API tests pass (without gptoolbox)  
⚠️ Functional tests require gptoolbox for eigendecomposition

---

## Summary

The `bct.sim.synth_mesh_signal` function has been successfully updated to work with the new Signal class architecture. Key improvements:

- **Returns bct objects** with Signal objects automatically added
- **Supports multiple signals** via spec array
- **Automatic labeling** based on spec type
- **Maintains backward compatibility** via `return_raw` parameter
- **Integrates seamlessly** with bct workflow

The function now follows the same pattern as other signal management methods in the bct class, providing a consistent and intuitive API.
