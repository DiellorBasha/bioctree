# BCT Signal Integration - Implementation Summary

## Overview
Successfully integrated the `Signal` class into the `bct` class, creating a complete architecture for managing signals defined on manifolds with automatic dimension validation.

## Architecture

### Class Hierarchy
```
bct
├── Manifold (bct.manifold.Manifold)
│   ├── V, F (mesh geometry)
│   ├── Edges (graph topology)
│   ├── N (spatial dimension)
│   ├── Eigenvectors, Eigenvalues (cached spectrum)
│   └── Time (bct.manifold.Time) [optional]
│       ├── T (time points)
│       └── fs (sampling frequency)
└── Signals (bct.signal.Signal array)
    ├── Data ([N×1], [N×T], [N×3], or [N×T×3])
    ├── Manifold (reference to geometry)
    └── Label (identifier)
```

## Implementation Details

### New Property in bct Class
```matlab
properties
    Signals bct.signal.Signal = bct.signal.Signal.empty()
end
```

### Signal Management Methods

#### `addSignal(signal_obj)`
Adds a Signal object to the Signals array with validation.

**Validation:**
- Checks that `signal_obj` is a `bct.signal.Signal` instance
- Calls `validateSignalDimensions()` to ensure compatibility
- Raises error if dimensions don't match

**Example:**
```matlab
sig = bct.signal.Signal(B.Manifold, data, 'my_signal');
B.addSignal(sig);
```

#### `removeSignal(index_or_label)`
Removes a signal by numeric index or string label.

**Examples:**
```matlab
B.removeSignal(2);              % Remove by index
B.removeSignal('my_signal');    % Remove by label
```

#### `getSignalByLabel(label)`
Finds and returns the first Signal with matching label.

**Returns:** Signal object or empty if not found

**Example:**
```matlab
sig = B.getSignalByLabel('activation');
if ~isempty(sig)
    % Use signal
end
```

#### `clearSignalsNew()`
Clears all signals from the Signals array.

**Example:**
```matlab
B.clearSignalsNew();
```

#### `validateSignalDimensions(signal_obj)`
Validates that Signal dimensions match Manifold dimensions.

**Checks:**
1. `Signal.N == Manifold.N` (spatial dimension)
2. For dynamic signals (`Signal.T > 0`):
   - `Manifold.Time` must be set
   - `Signal.T == Manifold.Time.T`

**Errors:**
- `bct:SignalDimensionMismatch` - N or T mismatch
- `bct:NoManifoldTime` - Dynamic signal without Manifold.Time

## Validation Rules

### Spatial Dimension (N)
Every signal must have the same number of spatial points as the manifold:
```
Signal.N == Manifold.N
```

### Temporal Dimension (T)
Dynamic signals require matching time dimensions:
```
Signal.T == Manifold.Time.T  (when Signal.T > 0)
```

Static signals have `T = 0` and don't require `Manifold.Time`.

## Usage Examples

### Complete Workflow
```matlab
% 1. Create BCT with mesh
[V, F] = icosphere(3);
B = bct.bct.fromMesh(V, F);

% 2. Add temporal dimension (optional, for dynamic signals)
B.Manifold.Time = bct.manifold.Time(200, 500);

% 3. Create signals
data_static = randn(B.Manifold.N, 1);
sig1 = bct.signal.Signal(B.Manifold, data_static, 'activation');

data_dynamic = randn(B.Manifold.N, B.Manifold.Time.T);
sig2 = bct.signal.Signal(B.Manifold, data_dynamic, 'timeseries');

% 4. Add signals to BCT
B.addSignal(sig1);
B.addSignal(sig2);

% 5. Query signals
sig = B.getSignalByLabel('timeseries');
trace = sig.get_temporal_trace(100);  % Vertex 100
snapshot = sig.get_spatial_snapshot(50);  % Time 50

% 6. Manage signals
B.removeSignal('activation');
B.clearSignalsNew();
```

### Signal Types Supported
```matlab
% Scalar static [N × 1]
data1 = randn(N, 1);
sig1 = bct.signal.Signal(M, data1, 'scalar_static');

% Scalar dynamic [N × T]
data2 = randn(N, T);
sig2 = bct.signal.Signal(M, data2, 'scalar_dynamic');

% Vector static [N × 3]
data3 = randn(N, 3);
sig3 = bct.signal.Signal(M, data3, 'vector_static');

% Vector dynamic [N × T × 3]
data4 = randn(N, T, 3);
sig4 = bct.signal.Signal(M, data4, 'vector_dynamic');
```

## Backward Compatibility

### Deprecated Properties
The following properties are marked as `Hidden` but still accessible:
- `T` → Use `B.Manifold.Time.T`
- `N` → Use `B.Manifold.N`
- `fs` → Use `B.Manifold.Time.fs`
- `L`, `F` → Use `B.Manifold.F`
- `signal_stack` → Use `B.Signals`

### Deprecated Methods
Legacy methods renamed with `_legacy` suffix:
- `addSignal()` → `addSignal_legacy()`
- `clearSignals()` (uses warning)
- `getSignal()` (uses warning)

All deprecated methods display warnings guiding users to new API.

## Testing

### Test Files
1. **`test_signal_class.m`** - Signal class comprehensive tests
   - All 4 signal types
   - Dimension validation
   - Spatial/temporal access methods
   
2. **`test_bct_signal_integration.m`** - BCT + Signal integration
   - Add/remove signals
   - Dimension validation
   - Array operations
   - Label queries
   
3. **`test_bct_deprecated_properties.m`** - Backward compatibility
   - Deprecated property access
   - Legacy method warnings
   - Migration path verification

### Test Results
✅ All tests pass
✅ Dimension validation working correctly
✅ Backward compatibility maintained
✅ Array operations functional

## Files Modified

### Core Implementation
- `toolbox/+bct/@bct/bct.m` (lines 54-63, 620-750)
  - Added `Signals` property
  - Implemented management methods
  - Deprecated legacy methods

### Tests
- `tests/test_bct_signal_integration.m` (220 lines)
- `tests/test_signal_class.m` (existing)
- `tests/test_bct_deprecated_properties.m` (existing)

### Examples
- `examples/example_bct_signal_workflow.m` (150 lines)
  - Complete workflow demonstration
  - All signal types
  - Error handling examples

## Key Features

### ✅ Type Safety
- Signals property only accepts `bct.signal.Signal` objects
- Automatic type checking in `addSignal()`

### ✅ Dimension Validation
- Enforced at signal addition time
- Clear error messages for mismatches
- Prevents invalid configurations

### ✅ Flexible Management
- Add/remove by index or label
- Query by label
- Array-based access
- Clear all signals

### ✅ Multiple Signals
- Supports array of Signal objects
- Signals can share labels (getSignalByLabel returns first match)
- Independent management

### ✅ Clean API
- Intuitive method names
- Consistent with MATLAB conventions
- Clear deprecation path

## Migration Guide

### From Old API to New API

**Creating BCT objects:**
```matlab
% Old (still works)
B = bct.bct.open('data.h5');

% New (preferred)
[V, F] = icosphere(2);
B = bct.bct.fromMesh(V, F);
B.Manifold.Time = bct.manifold.Time(100, 250);
```

**Accessing dimensions:**
```matlab
% Old
N = B.N;
T = B.T;
fs = B.fs;

% New
N = B.Manifold.N;
T = B.Manifold.Time.T;
fs = B.Manifold.Time.fs;
```

**Managing signals:**
```matlab
% Old
B.signal_stack = data;

% New
sig = bct.signal.Signal(B.Manifold, data, 'label');
B.addSignal(sig);
data = B.getSignalByLabel('label').Data;
```

## Future Enhancements

### Potential Additions
1. **Batch operations:** `addSignals([sig1, sig2, sig3])`
2. **Indexing shortcuts:** `B.Signals('label')` returns signal by label
3. **HDF5 serialization:** Save/load Signals to/from HDF5 files
4. **Signal algebra:** Operations between signals (add, multiply, etc.)
5. **Filtering:** `B.Signals([B.Signals.IsDynamic])` helper
6. **Metadata:** Additional properties for signal provenance/units

### Integration Points
- Update `bct.open()` to load Signals from HDF5
- Update `bct.save()` to write Signals to HDF5
- Add visualization methods for common signal types
- Create signal processing methods operating on Signals

## Summary

The Signal integration into the bct class provides:
- **Clean separation of concerns** (geometry in Manifold, data in Signal)
- **Type-safe signal storage** with automatic validation
- **Flexible management** with intuitive API
- **Backward compatibility** with deprecated properties still accessible
- **Complete test coverage** with comprehensive examples

The architecture is now ready for advanced signal processing workflows while maintaining compatibility with existing code.
