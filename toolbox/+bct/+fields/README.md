# bct.fields Package

Provides a structured, validated Field artifact for representing signals defined on discrete supports of a manifold/mesh.

## Overview

A Field is a **struct** (not a class) that represents:
- Scalar and vector signals
- Static and time-varying signals  
- Signals on vertices, faces, edges, halfedges, and dual supports
- Explicit metadata and provenance

## Key Benefits

1. **Support-type safety**: Prevents vertex/face/edge mismatches
2. **Portability**: Struct-based for easy serialization
3. **Time-aware**: Native support for time-varying signals
4. **Metadata-rich**: Provenance tracking built-in
5. **Compatible**: Works with bct.Manifold and operator system

## Field Schema v1

### Required Fields

- `schemaVersion`: "bct.field@1"
- `meshId`: Manifold identifier (M.ID)
- `support`: "vertex" | "face" | "edge" | "halfedge" | "dualFace" | "dualVertex"
- `value`: Numeric array [S×...] where S = support cardinality
- `valueType`: "scalar" | "vector3" | "tangent2" | "complexScalar" | "complexVector3"
- `time`: Empty [] or time struct
- `meta`: Metadata struct (can be empty)

### Optional Fields

- `frame`: Tangent frame specification (required for tangent2)
- `units`: Physical units
- `provenance`: Origin and processing history

## Value Shape Conventions

- **Scalar static**: [S × 1] or [S × T]
- **Scalar time-varying**: [S × T]
- **Vector3 static**: [S × 3]
- **Vector3 time-varying**: [S × 3 × T]
- **Tangent2 static**: [S × 2]
- **Tangent2 time-varying**: [S × 2 × T]

## Quick Start

```matlab
% Load mesh
M = bct.Manifold(V, F);

% Create scalar vertex field (time series)
x = randn(M.numVertices(), 1000);
time = struct('fs', 2400, 't0', 0, 'nSamples', 1000, 'units', "s");

F = bct.fields.make( ...
    'meshId', M.ID, ...
    'support', "vertex", ...
    'valueType', "scalar", ...
    'value', x, ...
    'time', time, ...
    'meta', struct('band', "alpha"));

% Validate against manifold
bct.fields.validate(F, 'Manifold', M);

% Query
isTV = bct.fields.isTimeVarying(F);  % true
n = bct.fields.sizeOfSupport(M, F.support);  % numVertices

% Time selection
F_slice = bct.fields.selectTime(F, 1:100);
```

## Core Functions

- `make(...)` - Primary constructor with validation
- `validate(F, options)` - Validate Field struct
- `infer(M, value, ...)` - Infer Field from Manifold and data
- `schema()` - Get schema definition
- `sizeOfSupport(M, support)` - Get support cardinality
- `isTimeVarying(F)` - Check if time-varying
- `selectTime(F, idx)` - Slice time dimension
- `withTime(F, timeStruct)` - Update time metadata
- `withMeta(F, metaStruct)` - Merge metadata
- `cast(F, type)` - Convert numeric type
- `toStruct(F)` / `fromStruct(S)` - Serialization

## Examples

See individual function help for detailed examples.

## See Also

bct.Manifold, bct.geometry, bct.operators, bct.eigenpairs
