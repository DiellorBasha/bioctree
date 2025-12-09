# Joint Domain Dual Architecture - Implementation Summary

**Date:** November 23, 2025  
**Feature:** Added dual relationship architecture to Joint domains

## Overview

Joint domains now follow the same dual relationship pattern as individual domains (Manifold↔Lambda, Time↔Omega). When a Joint domain is created from two domains that have duals, the Joint domain automatically gets its own dual constructed from the constituent duals.

## Changes Made

### 1. Updated `bct.Joint` Class

**File:** `toolbox/+bct/@Joint/Joint.m`

**New Properties:**
```matlab
dual        % Dual Joint domain (e.g., Manifold_Time ↔ Lambda_Omega)
transform   % Transform to/from dual (placeholder for future 2D transforms)
```

**New Methods:**
```matlab
createDual()  % Explicitly create dual Joint domain from constituent duals
```

**Updated Methods:**
- `Joint()` constructor: Initializes `dual` and `transform` properties
- `disp()`: Shows dual domain and transform status

**Key Implementation Details:**
- Constructor initializes `dual = []` and `transform = []`
- `createDual()` constructs dual from `A.dual` and `B.dual`
- Establishes bidirectional dual relationship
- Validates that constituent domains have duals before creating dual Joint

### 2. Updated `bct.bct.createJoint()` Method

**File:** `toolbox/+bct/@bct/bct.m`

**New Behavior:**
- Automatically creates dual Joint domain when constituent domains have duals
- Sets bidirectional dual relationship
- Provides informative console output showing dual relationship

**Console Output Example:**
```
[bct] Joint domain created: Lambda_Omega ↔ Manifold_Time (dual)
      Grid size: [100×50] = 5000 points
      Units: 1/mm × Hz
```

**Logic:**
```matlab
% Create joint domain
obj.Joint = bct.Joint(domainA, domainB);

% Automatically create dual if constituent domains have duals
if ~isempty(domainA.dual) && ~isempty(domainB.dual)
    dualJoint = bct.Joint(domainA.dual, domainB.dual);
    obj.Joint.dual = dualJoint;
    dualJoint.dual = obj.Joint;
end
```

### 3. Documentation

**New Files:**
- `docs/JOINT_DOMAIN_DUAL_ARCHITECTURE.md` - Complete reference guide
- `examples/test_joint_dual_domains.m` - Comprehensive test script

**Updated Files:**
- `examples/example_signal_synthesis_kronecker_delta.m` - Shows dual creation

## Dual Relationships

### Individual Domains
```
Manifold ↔ Lambda  (spatial ↔ spectral via MFT/IMFT)
Time ↔ Omega       (temporal ↔ frequency via FFT/IFFT)
```

### Joint Domains
```
Lambda_Omega ↔ Manifold_Time       (spectral-frequency ↔ spatiotemporal)
Lambda_Time ↔ Manifold_Omega       (spectral-temporal ↔ spatial-frequency)
Manifold_Omega ↔ Lambda_Time       (spatial-frequency ↔ spectral-temporal)
```

## Usage Examples

### Automatic Dual Creation

```matlab
// Setup BCT with domains
B = bct.io.import.mesh(path);
B = B.computeEigenbasis(100);            // Creates Lambda as Manifold.dual
B.Time = bct.Time(linspace(0,1,50)', 50);  % Auto-creates Omega as Time.dual

% Create Joint domain - dual is automatic
B = B.createJoint('Lambda', 'Omega');

% Access dual
fprintf('Joint: %s\n', B.Joint.Domain);           % Lambda_Omega
fprintf('Dual:  %s\n', B.Joint.dual.Domain);      % Manifold_Time
```

### Accessing Constituent Duals

```matlab
% Lambda_Omega joint domain
fprintf('Joint domain: %s\n', B.Joint.Domain);
fprintf('  A: %s → dual: %s\n', B.Joint.A.name, B.Joint.A.dual.name);  % Lambda → Manifold
fprintf('  B: %s → dual: %s\n', B.Joint.B.name, B.Joint.B.dual.name);  % Omega → Time

% Manifold_Time dual domain
fprintf('Dual domain: %s\n', B.Joint.dual.Domain);
fprintf('  A: %s → dual: %s\n', B.Joint.dual.A.name, B.Joint.dual.A.dual.name);  % Manifold → Lambda
fprintf('  B: %s → dual: %s\n', B.Joint.dual.B.name, B.Joint.dual.B.dual.name);  // Time → Omega
```

### Explicit Dual Creation

```matlab
J = bct.Joint(B.Lambda, B.Omega);
J_dual = J.createDual();  % Explicitly creates Manifold_Time

% Bidirectional relationship
assert(J.dual == J_dual);
assert(J_dual.dual == J);
```

### Checking Dual Relationships

```matlab
J1 = bct.Joint(B.Lambda, B.Omega);
J2 = bct.Joint(B.Manifold, B.Time);

if J1.isDual(J2)
    fprintf('J1 and J2 are dual domains\n');
end
```

## Testing

Run the comprehensive test script:

```matlab
test_joint_dual_domains
```

**Tests Covered:**
1. ✓ Automatic dual creation via `createJoint()`
2. ✓ Bidirectional dual relationships
3. ✓ Constituent domain dual consistency
4. ✓ `isDual()` method validation
5. ✓ Explicit `createDual()` method
6. ✓ Transform property existence (placeholder)
7. ✓ Display method shows dual information

## Design Principles

### 1. Consistency
Joint domains follow the same dual pattern as individual domains:
```matlab
B.Manifold.dual      % Lambda
B.Lambda.dual        % Manifold
B.Joint.dual         % Dual Joint (e.g., Manifold_Time)
B.Joint.dual.dual    % B.Joint (bidirectional)
```

### 2. Automatic Setup
Users don't manually create dual relationships - it happens automatically via `createJoint()`.

### 3. Transform Placeholder
The `transform` property is initialized but not yet functional, ready for future 2D transform implementation:
```matlab
B.Joint.transform  % Empty (planned: 2D MFT ⊗ FFT)
```

## Future Work

### 1. Implement 2D Joint Transforms
```matlab
% Create transform classes
bct.factory.transforms.JointMFT    % Manifold_Time → Lambda_Omega
bct.factory.transforms.JointIMFT   % Lambda_Omega → Manifold_Time

% Set in Joint constructor
if both constituent domains have transforms
    obj.transform = createJointTransform(A.transform, B.transform);
end
```

**Implementation approach:**
- Tensor product of constituent transforms (MFT ⊗ FFT)
- Efficient separable computation
- Support for forward and inverse operations

### 2. Enable Joint Domain Filtering

Update `Signal.applyFilter()` to handle Joint domains:
```matlab
% Future usage
signal = bct.Signal.createDelta(B.Manifold, v0, B.Time, t0);
filt = designer.joint('gabor', ...);
response = signal.applyFilter(filt, B.Joint.dual, B.Joint);
% Workflow: Manifold_Time → (2D transform) → Lambda_Omega → (filter) → Lambda_Omega → (2D inverse) → Manifold_Time
```

### 3. BctFilterDesigner Integration
- Add Joint filter application UI
- Visualize 2D filter responses in dual domains
- Support automatic domain selection

## Migration Notes

**No breaking changes** - this is a pure enhancement:
- Existing Joint domain code continues to work
- `dual` and `transform` properties are new, optional features
- Automatic dual creation is a convenience, not a requirement

**Recommendation:**
When creating Joint domains, prefer starting with the most intuitive pairing:
```matlab
% Recommended (spatiotemporal → spectral-frequency)
B = B.createJoint('Manifold', 'Time');
% B.Joint = Manifold_Time
// B.Joint.dual = Lambda_Omega (automatic)

% Alternative (spectral-frequency → spatiotemporal)
B = B.createJoint('Lambda', 'Omega');
% B.Joint = Lambda_Omega
% B.Joint.dual = Manifold_Time (automatic)
```

## References

**Modified Files:**
- `toolbox/+bct/@Joint/Joint.m` - Joint class with dual properties
- `toolbox/+bct/@bct/bct.m` - BCT createJoint() method

**New Files:**
- `docs/JOINT_DOMAIN_DUAL_ARCHITECTURE.md` - Full reference
- `examples/test_joint_dual_domains.m` - Test script

**Related Documentation:**
- `docs/SIGNAL_SYNTHESIS_ARCHITECTURE.md` - Overall BCT architecture
- `docs/FILTER_DESIGNER_QUICK_REF.md` - Filter design system

## Summary

Joint domains now seamlessly integrate with BCT's dual domain architecture:
- ✓ Automatic dual creation from constituent duals
- ✓ Bidirectional dual relationships
- ✓ Placeholder for future 2D transforms
- ✓ Consistent with individual domain dual pattern
- ✓ No breaking changes to existing code
- ✓ Comprehensive testing and documentation

**Result:** Joint domains are now first-class citizens in the BCT dual domain ecosystem, ready for future 2D transform implementation and full spatiotemporal filtering capabilities.
