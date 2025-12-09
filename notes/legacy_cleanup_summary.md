# Legacy Signal Stack Cleanup - Summary

## Overview
Removed all legacy signal_stack structure and related methods from the `bct` class, completing the migration to the new `bct.signal.Signal` architecture.

## What Was Removed

### 1. Properties Removed

#### `signal_stack` (Private Property)
**Location:** `properties (Access=private, Transient)` block

**Removed:**
```matlab
signal_stack struct = struct('data', {}, 'labels', {}, 'metadata', {});
```

**Reason:** Replaced by the new `Signals` property which stores `bct.signal.Signal` objects

#### `signals` (Dependent Property)
**Location:** `properties (Dependent)` block

**Removed:**
```matlab
signals    % DEPRECATED: Access to legacy signal stack with metadata
```

**Reason:** This was a getter for the deprecated `signal_stack` structure

---

### 2. Methods Removed

#### `get.signals(this)`
**Location:** Methods block (lines ~611-616)

**Removed:**
```matlab
function S = get.signals(this)
  % DEPRECATED: Return legacy signal stack with data, labels, and metadata
  % Use B.Signals property instead for new code
  S = this.signal_stack;
end
```

**Reason:** Getter for deprecated `signals` dependent property

---

#### `addSignal_legacy(this, signal_data, label, metadata)`
**Location:** DEPRECATED methods block (lines ~742-786)

**Functionality:** Added signals to the legacy signal_stack structure

**Removed:**
```matlab
function addSignal_legacy(this, signal_data, label, metadata)
  % DEPRECATED: Add a signal to the legacy signal stack
  % Validation and storage logic for signal_stack
end
```

**Replaced by:** `addSignal(signal_obj)` which accepts `bct.signal.Signal` objects

---

#### `clearSignals(this)`
**Location:** DEPRECATED methods block (lines ~789-794)

**Functionality:** Cleared all signals from the legacy stack

**Removed:**
```matlab
function clearSignals(this)
  % DEPRECATED: Clear all signals from the legacy stack
  this.signal_stack = struct('data', {}, 'labels', {}, 'metadata', {});
end
```

**Replaced by:** `clearSignalsNew()` which clears the `Signals` array

---

#### `getSignal(this, index_or_label)`
**Location:** DEPRECATED methods block (lines ~797-815)

**Functionality:** Retrieved signals from legacy stack by index or label

**Removed:**
```matlab
function signal_data = getSignal(this, index_or_label)
  % DEPRECATED: Get signal by index or label from legacy stack
  % Logic for finding and returning signal data from signal_stack
end
```

**Replaced by:** 
- `B.Signals(idx)` for index access
- `B.getSignalByLabel('label')` for label-based access

---

## Migration Guide

### For Users with Existing Code

If you have code using the deprecated signal_stack methods, here's how to migrate:

#### Adding Signals

**Old API:**
```matlab
B.addSignal_legacy(data, 'my_label', struct('info', 'metadata'));
```

**New API:**
```matlab
sig = bct.signal.Signal(B.Manifold, data, 'my_label');
B.addSignal(sig);
```

#### Accessing Signals

**Old API:**
```matlab
% By index
data = B.getSignal(1);

% By label
data = B.getSignal('my_label');

% All signals
all_sigs = B.signals;
```

**New API:**
```matlab
% By index
sig = B.Signals(1);
data = sig.Data;

% By label
sig = B.getSignalByLabel('my_label');
data = sig.Data;

% All signals
all_sigs = B.Signals;
```

#### Clearing Signals

**Old API:**
```matlab
B.clearSignals();
```

**New API:**
```matlab
B.clearSignalsNew();
```

#### Removing Specific Signals

**Old API:**
```matlab
% Not directly supported - had to manually manipulate signal_stack
```

**New API:**
```matlab
% By index
B.removeSignal(2);

% By label
B.removeSignal('my_label');
```

---

## Benefits of the New Architecture

### ✅ Type Safety
- Signals are now proper `bct.signal.Signal` objects
- Compile-time type checking
- Clear object structure

### ✅ Better Validation
- Automatic dimension checking against Manifold
- Prevents mismatched signals at addition time
- Clear error messages

### ✅ Rich Functionality
Signal objects provide:
- `get_spatial_snapshot(t)` - Get snapshot at time t
- `get_temporal_trace(node)` - Get time series at node
- Properties: `IsVector`, `IsStatic`, `IsDynamic`, `N`, `T`
- Type information and display methods

### ✅ Cleaner API
- Intuitive method names
- Consistent interface
- Better documentation

### ✅ Support for Vector Signals
The new Signal class supports:
- Scalar static [N × 1]
- Scalar dynamic [N × T]
- **Vector static [N × 3]** (NEW!)
- **Vector dynamic [N × T × 3]** (NEW!)

### ✅ Manifold Integration
Signals are tightly integrated with the Manifold:
- Reference to geometry (`Signal.Manifold`)
- Automatic dimension matching
- Support for both mesh and graph types

---

## Code Impact

### Lines Removed
- **Property declarations:** ~2 lines
- **Dependent property block:** ~3 lines  
- **get.signals method:** ~6 lines
- **addSignal_legacy method:** ~45 lines
- **clearSignals method:** ~6 lines
- **getSignal method:** ~20 lines

**Total:** ~82 lines of deprecated code removed

### Files Modified
- `toolbox/+bct/@bct/bct.m` - Main class file

### Tests Status
✅ All existing tests pass
✅ `test_bct_signal_integration.m` - All 10 tests passing
✅ `example_bct_signal_workflow.m` - Complete workflow passing

---

## Current State

The `bct` class now has a clean, unified signal management system:

### Properties
```matlab
properties
    Manifold               % bct.manifold.Manifold object
    Signals                % Array of bct.signal.Signal objects
end
```

### Methods
```matlab
% Signal Management
B.addSignal(signal_obj)              % Add Signal object
B.removeSignal(index_or_label)       % Remove signal
B.getSignalByLabel(label)            % Find by label
B.clearSignalsNew()                  % Clear all
B.validateSignalDimensions(sig)      % Validate compatibility
```

### Access Patterns
```matlab
% Direct array access
sig = B.Signals(1);

% Iteration
for i = 1:length(B.Signals)
    process(B.Signals(i));
end

% Filtering
dynamic_sigs = B.Signals([B.Signals.IsDynamic]);
```

---

## Summary

The legacy `signal_stack` structure has been completely removed from the `bct` class. All signal management now uses the modern `bct.signal.Signal` architecture, providing:

- Type-safe signal storage
- Automatic dimension validation
- Rich signal operations
- Support for vector signals
- Clean, intuitive API
- Better integration with Manifold

The codebase is now cleaner, more maintainable, and ready for future enhancements.
