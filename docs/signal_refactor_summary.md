# Signal Class Refactor: Domain-Agnostic Design

## Summary

The `bct.Signal` class has been successfully refactored from a Manifold-specific design to a domain-agnostic design that works with any `bct.Domain` subclass, including the new `bct.Joint` composite domains.

## Key Changes

### 1. Properties Refactor

**OLD Design:**
```matlab
properties
    Manifold     % bct.Manifold object
    Data         % Signal data array
    Label        % Description string
    Time         % Optional bct.Time object
end
```

**NEW Design:**
```matlab
properties
    Domain       % Any bct.Domain object (Manifold, Lambda, Time, Omega, Joint)
    Data         % Signal data array
    Label        % Description string
end

properties (Dependent)
    IsVector     % True if signal is vector-valued (3-component)
    
    % Backward compatibility (deprecated):
    Manifold     % Extracts Manifold from Domain if applicable
    Time         % Extracts Time from Domain if applicable
    N            % Domain-specific spatial dimension
    T            % Domain-specific temporal dimension
    IsStatic     % True if no time component
    IsDynamic    % True if has time component
end
```

### 2. Constructor Signature

**OLD:**
```matlab
sig = bct.Signal(manifold, data, label, time_obj)
```

**NEW:**
```matlab
sig = bct.Signal(domain_obj, data, label)
```

Where `domain_obj` can be:
- `bct.Manifold` - Spatial domain
- `bct.Lambda` - Spectral domain (Manifold dual)
- `bct.Time` - Temporal domain
- `bct.Omega` - Frequency domain (Time dual)
- `bct.Joint` - Composite domain (e.g., Manifold×Time)

### 3. Data Validation

The `validateAndSetData()` method now uses domain-type checking to validate dimensions:

**Joint Domain:** `[M×N]` or `[M×N×3]`
```matlab
if isa(obj.Domain, 'bct.Joint')
    joint_sz = obj.Domain.size();  % Returns [M, N]
    % Validate data matches [M×N] or [M×N×3]
end
```

**Manifold/Lambda:** `[N×1]` or `[N×3]`
```matlab
if isa(obj.Domain, 'bct.Manifold') || isa(obj.Domain, 'bct.Lambda')
    N = obj.Domain.N;
    % Validate data is [N×1] scalar or [N×3] vector
end
```

**Time/Omega:** `[T×1]`
```matlab
if isa(obj.Domain, 'bct.Time') || isa(obj.Domain, 'bct.Omega')
    T = obj.Domain.N;
    % Validate data is [T×1] column vector
end
```

### 4. createDelta() Static Method

**OLD:**
```matlab
% Spatial delta
delta = bct.Signal.createDelta(manifold, v0);

% Spatiotemporal delta
delta = bct.Signal.createDelta(manifold, v0, time_obj, t0);
```

**NEW:**
```matlab
% Domain-agnostic delta creation
delta_manifold = bct.Signal.createDelta(B.Manifold, 50);
delta_time = bct.Signal.createDelta(B.Time, 25);
delta_joint = bct.Signal.createDelta(B.Joint, [50, 25]);  % [m, n] indices
```

### 5. Backward Compatibility

Dependent property getters provide backward compatibility with legacy code:

**Manifold property:**
```matlab
function m = get.Manifold(obj)
    if isa(obj.Domain, 'bct.Manifold')
        m = obj.Domain;
    elseif isa(obj.Domain, 'bct.Joint') && isa(obj.Domain.A, 'bct.Manifold')
        m = obj.Domain.A;  % Extract from Joint
    else
        m = [];
    end
end
```

**Time property:**
```matlab
function t = get.Time(obj)
    if isa(obj.Domain, 'bct.Time')
        t = obj.Domain;
    elseif isa(obj.Domain, 'bct.Joint') && isa(obj.Domain.B, 'bct.Time')
        t = obj.Domain.B;  % Extract from Joint
    else
        t = [];
    end
end
```

**N and T properties:**
```matlab
% N returns spatial dimension or total elements for Joint
% T returns temporal dimension or 0 for static signals
```

## Usage Examples

### Example 1: Spatial Signal on Manifold
```matlab
B = bct;
B.Manifold = bct.Manifold(icosphere(3));

% Create scalar spatial signal [N×1]
data = randn(B.Manifold.N, 1);
sig = bct.Signal(B.Manifold, data, 'Spatial Signal');
```

### Example 2: Temporal Signal on Time Domain
```matlab
B.Time = bct.Time(100, 200);  % 100 samples at 200 Hz

% Create temporal signal [T×1]
data = sin(2*pi*10 * B.Time.axis);
sig = bct.Signal(B.Time, data, 'Temporal Signal');
```

### Example 3: Spatiotemporal Signal on Joint Domain
```matlab
% Joint Manifold×Time is automatically created when Time is set
% B.Joint is now available

% Create spatiotemporal signal [N×T]
data = randn(B.Manifold.N, B.Time.N);
sig = bct.Signal(B.Joint, data, 'Spatiotemporal Signal');

% Access domain components
fprintf('Spatial domain: %s\n', class(sig.Domain.A));  % bct.Manifold
fprintf('Temporal domain: %s\n', class(sig.Domain.B));  % bct.Time
```

### Example 4: Vector Signal on Joint Domain
```matlab
% Create 3-component vector signal [N×T×3]
data = randn(B.Manifold.N, B.Time.N, 3);
sig = bct.Signal(B.Joint, data, 'Vector Spatiotemporal Signal');

fprintf('IsVector: %d\n', sig.IsVector);  % true
```

### Example 5: Delta Signals
```matlab
% Spatial delta at vertex 50
delta_v = bct.Signal.createDelta(B.Manifold, 50);

% Temporal delta at time index 25
delta_t = bct.Signal.createDelta(B.Time, 25);

% Spatiotemporal delta at [vertex=50, time=25]
delta_joint = bct.Signal.createDelta(B.Joint, [50, 25]);
```

## Testing

A comprehensive test script has been created at:
```
examples/test_signal_joint_domain.m
```

This script tests:
1. Signal creation on Manifold domain [N×1]
2. Vector signal on Manifold domain [N×3]
3. Signal creation on Time domain [T×1]
4. Signal creation on Joint domain [N×T]
5. Vector signal on Joint domain [N×T×3]
6. Delta signal creation on all domain types
7. Backward compatibility with legacy properties (Manifold, Time, N, T)
8. Signal summary display

## Files Modified

1. **toolbox/+bct/@Signal/Signal.m**
   - Updated class header documentation
   - Replaced Manifold/Time properties with Domain property
   - Added dependent properties for backward compatibility
   - Refactored constructor to accept any Domain object
   - Completely rewrote validateAndSetData() for domain-type checking
   - Updated all dependent property getters
   - Refactored createDelta() static method for all domain types

2. **examples/test_signal_joint_domain.m** (NEW)
   - Comprehensive test suite for refactored Signal class
   - Tests all domain types and data formats
   - Validates backward compatibility

## Migration Guide

### For Existing Code Using Old Constructor

**OLD CODE:**
```matlab
% Static spatial signal
sig = bct.Signal(B.Manifold, data, 'My Signal');

% Dynamic spatiotemporal signal
sig = bct.Signal(B.Manifold, data, 'My Signal', B.Time);
```

**NEW CODE (Option 1 - Use Joint):**
```matlab
% Static spatial signal (no change needed)
sig = bct.Signal(B.Manifold, data, 'My Signal');

% Dynamic spatiotemporal signal - use Joint domain
sig = bct.Signal(B.Joint, data, 'My Signal');
```

**NEW CODE (Option 2 - Backward compatible):**
```matlab
% The dependent properties Manifold and Time still work!
% So existing code reading sig.Manifold or sig.Time will still function
```

### For Delta Signal Creation

**OLD CODE:**
```matlab
delta = bct.Signal.createDelta(B.Manifold, 50);
delta_st = bct.Signal.createDelta(B.Manifold, 50, B.Time, 25);
```

**NEW CODE:**
```matlab
delta = bct.Signal.createDelta(B.Manifold, 50);
delta_st = bct.Signal.createDelta(B.Joint, [50, 25]);
```

## Benefits

1. **Unified Design:** All signals follow the same pattern regardless of domain type
2. **Joint Domain Support:** Signals can now be naturally defined on composite domains
3. **Extensibility:** Easy to add support for new domain types in the future
4. **Backward Compatibility:** Legacy code using Manifold/Time properties continues to work
5. **Type Safety:** Domain-specific validation prevents dimensional mismatches
6. **Cleaner API:** Single Domain property instead of separate Manifold/Time properties

## Future Enhancements

The following methods may need updates for full Joint domain support:

1. **applyFilter()** - Handle Joint→Joint.dual transforms when 2D transforms are implemented
2. **get_spatial_snapshot()** - Already works via dependent properties
3. **get_temporal_trace()** - Already works via dependent properties

## Conclusion

The Signal class has been successfully refactored to work with any BCT domain type, including the new Joint composite domains. The refactor maintains backward compatibility while providing a cleaner, more extensible architecture for future development.
