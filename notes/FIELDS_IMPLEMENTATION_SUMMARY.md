# bct.field Package Implementation Summary

## Overview
Successfully implemented complete **bct.field** package for structured Field artifact system. The package provides support-type safety, time-aware signal representation, and seamless integration with `bct.Manifold`.

## Package Structure

```
toolbox/+bct/+fields/
├── README.md                    # Package documentation
├── schema.m                     # Schema definition
├── make.m                       # Primary constructor
├── infer.m                      # Type-inferring constructor
├── validate.m                   # Comprehensive validation
├── sizeOfSupport.m              # Support cardinality computation
├── isTimeVarying.m              # Time-varying check
├── selectTime.m                 # Temporal subset extraction
├── withTime.m                   # Time metadata update
├── withMeta.m                   # Metadata merging
├── cast.m                       # Numeric type conversion
├── toStruct.m                   # Serialization helper
├── fromStruct.m                 # Deserialization helper
└── private/
    ├── validateSupport_.m       # Support validation
    ├── validateValue_.m         # Value shape/type validation
    ├── validateTime_.m          # Time struct validation
    └── normalizeTime_.m         # Time struct normalization
```

## Schema v1 (bct.field@1)

### Support Types (6)
- **vertex** - Mesh vertices
- **face** - Triangular faces
- **edge** - Unique edges
- **halfedge** - Directed half-edges (3 per face)
- **dualFace** - Dual cells around vertices
- **dualVertex** - Dual vertices at face centers

### Value Types (5)
- **scalar** - Real scalar values `[S×1]` or `[S×T]`
- **vector3** - 3D vectors `[S×3]` or `[S×3×T]`
- **tangent2** - 2D tangent vectors `[S×2]` or `[S×2×T]` (requires frame)
- **complexScalar** - Complex scalar values
- **complexVector3** - Complex 3D vectors

## Public API Functions

### Construction
```matlab
% Primary constructor with explicit types
F = bct.field.make('support', 'vertex', ...
                    'valueType', 'scalar', ...
                    'value', data);

% Type-inferring constructor
F = bct.field.infer('vertex', data);
```

### Validation
```matlab
% Validate against schema
bct.field.validate(F);

% Validate with Manifold consistency check
bct.field.validate(F, M);

% Get schema definition
schema = bct.field.schema();

% Compute support cardinality
n = bct.field.sizeOfSupport('vertex', M);
```

### Time Operations
```matlab
% Check if time-varying
tf = bct.field.isTimeVarying(F);

% Extract temporal subset
Fsub = bct.field.selectTime(F, 1:10);      % Range
Fsnap = bct.field.selectTime(F, 5);        % Single (becomes static)

% Update time metadata
Fnew = bct.field.withTime(F, struct('t0', 0, 'dt', 0.001, 'unit', 'ms'));
```

### Metadata & Conversion
```matlab
% Merge metadata
F = bct.field.withMeta(F, struct('source', 'simulation'));

% Convert numeric types
Fsingle = bct.field.cast(F, 'single');

% Serialization
S = bct.field.toStruct(F);
F = bct.field.fromStruct(S);
```

## Field Struct Schema

### Required Fields
- **schemaVersion** - Schema identifier: `'bct.field@1'`
- **support** - Support type (one of 6 types)
- **valueType** - Value type (one of 5 types)
- **value** - Numeric array with shape matching valueType

### Optional Fields
- **meshId** - Mesh identifier for validation
- **time** - Time struct `{t0, dt, unit, samples}`
- **frame** - Frame basis `[S×2×3]` or `[S×2×3×T]` (required for tangent2)
- **metadata** - Arbitrary metadata struct

### Time Struct
- **t0** - Time origin (numeric scalar)
- **dt** - Time step (positive numeric scalar)
- **unit** - Time unit (char)
- **samples** - Time samples row vector `[1×T]`

## Value Shape Conventions

### Static Fields
- **scalar**: `[S×1]`
- **vector3**: `[S×3]`
- **tangent2**: `[S×2]` with frame `[S×2×3]`
- **complexScalar**: `[S×1]` (complex)
- **complexVector3**: `[S×3]` (complex)

### Time-Varying Fields
- **scalar**: `[S×T]`
- **vector3**: `[S×3×T]`
- **tangent2**: `[S×2×T]` with frame `[S×2×3×T]`
- **complexScalar**: `[S×T]` (complex)
- **complexVector3**: `[S×3×T]` (complex)

Where:
- **S** = support cardinality (e.g., numVertices for 'vertex')
- **T** = number of time samples

## Error Handling

Descriptive errors with consistent identifiers:
- `bct:Field:MissingField` - Required field missing
- `bct:Field:InvalidSchemaVersion` - Unsupported schema version
- `bct:Field:InvalidSupport` - Invalid support type
- `bct:Field:InvalidValueType` - Invalid valueType
- `bct:Field:InvalidValueShape` - Value shape inconsistent
- `bct:Field:MissingFrame` - Frame required but missing
- `bct:Field:InvalidFrame` - Frame shape inconsistent
- `bct:Field:MismatchedMeshId` - meshId doesn't match Manifold
- `bct:Field:NotTimeVarying` - Operation requires time-varying field

## Test Suite

**File**: `tests/test_bct_fields.m`
**Status**: ✅ All 25 tests passing

### Test Coverage
1. Schema validation
2. Support cardinality for all 6 types
3. Static scalar fields (vertex/face)
4. Time-varying scalar fields
5. Static vector3 fields
6. Time-varying vector3 fields
7. Static tangent2 fields with frames
8. Time-varying tangent2 fields with frames
9. Missing frame error handling
10. Complex scalar fields
11. Complex vector3 fields
12. Time selection (single snapshot)
13. Time selection (range)
14. withTime metadata update
15. withMeta metadata merging
16. Type casting (single/double)
17-21. Type inference (scalar, vector3, time-varying, tangent2, complex)
22. Serialization round-trip
23-25. Error validation (invalid support, valueType, meshId)

## Key Design Decisions

1. **Struct-Based Architecture**: Not a class - ensures portability and simplicity
2. **Private Validation Helpers**: Modular validation logic in `private/` subdirectory
3. **Time Dimension Handling**: Single time sample → static field (time removed)
4. **Frame Requirements**: Required for tangent2, ignored for other types
5. **MATLAB Compatibility**: Uses `isreal()` instead of `iscomplex()` for older versions
6. **Argument Order**: `sizeOfSupport(support, M)` - support first for consistency
7. **Non-Breaking**: Incremental additions only, no breaking changes

## Integration Points

### With bct.Manifold
```matlab
M = bct.Manifold(V, F);

% Validate Field against Manifold
F = bct.field.make('support', 'vertex', ...
                    'value', rand(M.numVertices(), 1), ...
                    'valueType', 'scalar', ...
                    'meshId', M.ID);

bct.field.validate(F, M);  % Checks meshId matches M.ID
```

### Future Integration
- **bct.filter**: Apply filters to Fields
- **bct.spectral**: Spectral decomposition of Fields
- **bct.operators**: Operator application to Fields
- **bct.io**: Load/save Fields to disk

## Example Usage

### Static Scalar Vertex Field
```matlab
M = bct.Manifold(V, F);
data = rand(M.numVertices(), 1);

F = bct.field.make('support', 'vertex', ...
                    'valueType', 'scalar', ...
                    'value', data, ...
                    'meshId', M.ID, ...
                    'metadata', struct('source', 'simulation'));
```

### Time-Varying Vector Face Field
```matlab
nf = M.numFaces();
T = 100;
vectors = randn(nf, 3, T);

F = bct.field.make('support', 'face', ...
                    'valueType', 'vector3', ...
                    'value', vectors, ...
                    'time', struct('t0', 0, 'dt', 0.01, 'unit', 's'), ...
                    'meshId', M.ID);

% Extract subset
Fsub = bct.field.selectTime(F, 1:10);
```

### Tangent Field with Frame
```matlab
nv = M.numVertices();
tangents = randn(nv, 2);
frames = randn(nv, 2, 3);

F = bct.field.make('support', 'vertex', ...
                    'valueType', 'tangent2', ...
                    'value', tangents, ...
                    'frame', frames);
```

### Type Inference
```matlab
% Infer scalar from [S×1]
F = bct.field.infer('vertex', rand(M.numVertices(), 1));

% Infer time-varying vector3 from [S×3×T]
F = bct.field.infer('face', rand(M.numFaces(), 3, 100), ...
                     'time', struct('dt', 0.01, 'unit', 's'));

% Infer tangent2 (requires frame)
F = bct.field.infer('vertex', rand(M.numVertices(), 2), ...
                     'frame', rand(M.numVertices(), 2, 3));
```

## Files Created

### Source Files (18 files)
- 14 public API functions
- 4 private validation helpers
- 1 README documentation

### Test Files (1 file)
- Comprehensive test suite with 25 tests

### Documentation (1 file)
- FIELDCONTRACT.md (506 lines) - Complete specification

## Commit Information

**Branch**: feature/manifold-refactor
**Commit**: 93864d3
**Message**: Add bct.field package for structured Field artifact system
**Files**: 19 files changed, 1732 insertions(+)

## Next Steps

Future enhancements could include:
1. **Field Arithmetic**: Operations between Fields (add, multiply, etc.)
2. **Field Resampling**: Interpolation to different supports
3. **Field Transforms**: Spectral transforms, filtering
4. **Field IO**: HDF5/JSON serialization
5. **Field Visualization**: Integration with bct.show
6. **Field Derivatives**: Spatial/temporal gradients
7. **Field Statistics**: Mean, variance, correlation
8. **Multi-Field Operations**: Dot products, cross products

## Summary

The `bct.field` package provides a robust, type-safe foundation for signal analysis on manifolds. All 25 tests pass, the API is clean and documented, and the implementation follows best practices for MATLAB package development. The package integrates seamlessly with the existing bct.Manifold system and is ready for use in spectral analysis workflows.
