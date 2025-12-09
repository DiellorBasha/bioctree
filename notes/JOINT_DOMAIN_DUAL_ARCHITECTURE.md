# Joint Domain Dual Architecture

## Overview

Joint domains in BCT now follow the same dual relationship architecture as individual domains. When a Joint domain is created from two constituent domains that have duals, the Joint domain automatically gets its own dual constructed from those constituent duals.

## Dual Relationships

### Individual Domain Duals

| Domain | Dual | Relationship |
|--------|------|--------------|
| **Manifold** | **Lambda** | Spatial ↔ Spectral (via MFT/IMFT) |
| **Time** | **Omega** | Temporal ↔ Frequency (via FFT/IFFT) |

### Joint Domain Duals

| Joint Domain | Dual Joint Domain | Relationship |
|--------------|-------------------|--------------|
| **Lambda_Omega** | **Manifold_Time** | Spectral-Frequency ↔ Spatiotemporal |
| **Lambda_Time** | **Manifold_Omega** | Spectral-Temporal ↔ Spatial-Frequency |
| **Manifold_Omega** | **Lambda_Time** | Spatial-Frequency ↔ Spectral-Temporal |

## Architecture

### Properties Added to Joint Class

```matlab
classdef Joint < bct.Domain
    properties
        % ... existing properties ...
        dual        % Dual Joint domain (e.g., Manifold_Time ↔ Lambda_Omega)
        transform   % Transform to/from dual (placeholder for future)
    end
end
```

### Automatic Dual Creation

When creating a Joint domain via `BCT.createJoint()`, the dual is automatically created:

```matlab
% Create Lambda_Omega joint domain
B = B.createJoint('Lambda', 'Omega');

% Dual is automatically created and linked:
% B.Joint = Lambda_Omega
% B.Joint.dual = Manifold_Time (automatically created)
% B.Joint.dual.dual = Lambda_Omega (bidirectional)
```

**Console output:**
```
[bct] Joint domain created: Lambda_Omega ↔ Manifold_Time (dual)
      Grid size: [100×50] = 5000 points
      Units: 1/mm × Hz
```

## Usage Examples

### Example 1: Default BCT Workflow (Manifold + Time)

```matlab
% Import mesh
B = bct.io.import.mesh('path/to/mesh.pial');
B = B.computeEigenbasis(100);  % Creates Lambda as Manifold.dual

% Add time domain
B.Time = bct.Time(linspace(0, 1, 50)', 50);  % Auto-creates Omega as Time.dual

% Create joint domain (recommendation: start with Manifold_Time)
B = B.createJoint('Manifold', 'Time');

% Result:
% B.Joint = Manifold_Time
% B.Joint.dual = Lambda_Omega (automatically created)
```

**Why Manifold_Time first?**
- Most intuitive for spatiotemporal signals
- Matches signal data format `[N×T]` (vertices × time)
- Dual Lambda_Omega is natural spectral-frequency representation

### Example 2: Spectral-Frequency Analysis

```matlab
% Start with spectral-frequency joint domain
B = B.createJoint('Lambda', 'Omega');

% Result:
% B.Joint = Lambda_Omega
% B.Joint.dual = Manifold_Time (automatically created)

% Access dual for spatiotemporal visualization
J_spatial = B.Joint.dual;  % Manifold_Time
```

### Example 3: Accessing Constituent Duals

```matlab
% Lambda_Omega joint domain
J = B.Joint;

% Constituent domains and their duals
fprintf('Joint: %s\n', J.Domain);
fprintf('  A: %s (dual: %s)\n', J.A.name, J.A.dual.name);  % Lambda → Manifold
fprintf('  B: %s (dual: %s)\n', J.B.name, J.B.dual.name);  % Omega → Time

% Dual joint domain
J_dual = J.dual;

fprintf('Dual Joint: %s\n', J_dual.Domain);
fprintf('  A: %s (dual: %s)\n', J_dual.A.name, J_dual.A.dual.name);  % Manifold → Lambda
fprintf('  B: %s (dual: %s)\n', J_dual.B.name, J_dual.B.dual.name);  % Time → Omega
```

## Methods

### `createDual()`

Explicitly create the dual Joint domain (usually automatic via `createJoint()`):

```matlab
J = bct.Joint(B.Lambda, B.Omega);
J_dual = J.createDual();  % Creates Manifold_Time

% Bidirectional relationship established:
% J.dual == J_dual
% J_dual.dual == J
```

### `isDual(otherJoint)`

Check if two Joint domains are duals of each other:

```matlab
J1 = bct.Joint(B.Lambda, B.Omega);
J2 = bct.Joint(B.Manifold, B.Time);

if J1.isDual(J2)
    fprintf('J1 and J2 are dual domains\n');
end
```

**Logic:**
- Checks if `J1.A.dual` matches `J2.A` or `J2.B`
- Checks if `J1.B.dual` matches `J2.A` or `J2.B`
- Returns `true` if both constituent domains are dual

## Display

The `disp()` method now shows dual domain information:

```matlab
>> B.Joint

  bct.Joint domain: Lambda_Omega

    First domain (A):  Lambda [1/mm]
      A_axis: [100×1] from 0.0143 to 0.1274

    Second domain (B): Omega [Hz]
      B_axis: [50×1] from 0 to 49

    Joint grid size: [100×50] = 5000 points
    Joint units: 1/mm × Hz
    Dual domain: Manifold_Time
    Transform: <not implemented>
```

## Transform Property (Future Work)

The `transform` property is a placeholder for future 2D joint transforms:

```matlab
% Current status
B.Joint.transform  % Empty (not implemented)

% Future implementation:
% B.Joint.transform.forward(data)   % Manifold_Time → Lambda_Omega
% B.Joint.transform.inverse(coeffs) % Lambda_Omega → Manifold_Time
```

**Planned transforms:**
- **2D MFT ⊗ FFT**: Spatiotemporal → Spectral-Frequency
- **2D IMFT ⊗ IFFT**: Spectral-Frequency → Spatiotemporal
- Efficient tensor product implementations
- Support for separable and non-separable operations

## Design Principles

### 1. Consistency with Individual Domains

Joint domains follow the same dual architecture as `Manifold↔Lambda` and `Time↔Omega`:

```matlab
% Individual domains
B.Manifold.dual  % Lambda
B.Lambda.dual    % Manifold

% Joint domains
B.Joint.dual           % Dual Joint (e.g., Manifold_Time if Joint is Lambda_Omega)
B.Joint.dual.dual      % B.Joint (bidirectional)
```

### 2. Automatic Setup

Users don't need to manually create dual relationships:

```matlab
% Old (manual): NOT NEEDED
J1 = bct.Joint(B.Lambda, B.Omega);
J2 = bct.Joint(B.Manifold, B.Time);
J1.dual = J2;
J2.dual = J1;

// New (automatic): HAPPENS AUTOMATICALLY
B = B.createJoint('Lambda', 'Omega');
% B.Joint.dual automatically set to Manifold_Time
```

### 3. Transform Placeholder

The `transform` property is initialized but not yet functional, following the pattern:
- Domain owns transform to its dual
- Transform implements `forward()` and `inverse()` methods
- Enables seamless domain conversion

## Testing

Run the test script to verify dual relationships:

```matlab
test_joint_dual_domains
```

**Tests:**
- ✓ Automatic dual creation via `createJoint()`
- ✓ Bidirectional dual relationships
- ✓ Constituent domain dual consistency
- ✓ `isDual()` method validation
- ✓ Explicit `createDual()` method
- ✓ Transform property existence (placeholder)

## Common Patterns

### Pattern 1: Spatiotemporal Signal Analysis

```matlab
% Setup
B.Time = bct.Time(linspace(0, 1, 50)', 50);
B = B.createJoint('Manifold', 'Time');

% Signal in spatiotemporal domain
signal = bct.Signal(B.Manifold, data, B.Time);  % [N×T]

% Future: Transform to spectral-frequency
% coeffs = B.Joint.dual.transform.forward(signal.Data);  % Manifold_Time → Lambda_Omega
```

### Pattern 2: Filter Design in Dual Domains

```matlab
% Design filter in spectral-frequency domain
designer = bct.filters.FilterDesigner(B);

% Create filter on Lambda_Omega (if Joint is Lambda_Omega)
filt = designer.joint('gabor', ...
    'center_x', 0.2, ...    % Wavenumber
    'center_y', 10*2*pi);   % Frequency

% Evaluate on Joint grid
H = filt.evaluate();  % [M×N] on Lambda×Omega

% Future: Apply to signal via dual transform
% response = signal.applyFilter(filt, B.Joint.dual, B.Joint);
```

### Pattern 3: Dual Domain Access

```matlab
% Start with either domain
J_spectral = bct.Joint(B.Lambda, B.Omega);    % Spectral-frequency
J_spatial = J_spectral.dual;                   % Spatiotemporal

% Both have same grid sizes
sz_spectral = J_spectral.size();   % [M_lambda, N_omega]
sz_spatial = J_spatial.size();     % [N_vertices, T_time]
```

## Next Steps

1. **Implement 2D Joint Transforms**
   - `bct.factory.transforms.JointMFT` (Manifold_Time → Lambda_Omega)
   - `bct.factory.transforms.JointIMFT` (Lambda_Omega → Manifold_Time)
   - Efficient tensor product computation

2. **Enable Joint Filtering**
   - Update `Signal.applyFilter()` to handle Joint domains
   - Support 2D spectral-frequency filtering
   - Automatic domain routing

3. **BctFilterDesigner Integration**
   - Add Joint filter application UI
   - Visualize 2D filter responses
   - Support dual domain selection

## References

- `toolbox/+bct/@Joint/Joint.m` - Joint class implementation
- `toolbox/+bct/@bct/bct.m` - BCT `createJoint()` method
- `examples/test_joint_dual_domains.m` - Test script
- `docs/SIGNAL_SYNTHESIS_ARCHITECTURE.md` - Overall architecture
