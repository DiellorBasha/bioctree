Below is a comprehensive, document for adding a **Field** artifact to bct. It is written to be implemented incrementally, without breaking existing code, and to support your future `bct.filter` and operator/runtime architecture.

---

# bct.field Design Document (Contract + Implementation Plan)

## 0. Objective

Introduce a first-class **Field** artifact to bct to represent signals defined on discrete supports of a manifold/mesh. The Field will unify:

* scalar and vector signals,
* static and time-varying signals,
* signals on vertices/faces/edges/halfedges and selected dual supports,
* explicit metadata and provenance.

This addition must:

1. prevent support-mismatch bugs (vertex vs face, etc.),
2. be portable (struct-based),
3. be compatible with current `bct.Manifold` and operator registry/runtime,
4. enable future `bct.filter` and spectral workflows (eigenmode projection, kernel filtering, reconstruction),
5. be safe to adopt incrementally (no immediate deprecations required).

**Non-goals (Phase 1):**

* Do not implement joint time-frequency, multiresolution pyramids, or GPU-specific representations.
* Do not refactor FEM/Eigenpairs classes as part of this addition.
* Do not change the file format (bct/hdf5) yet—only define exportable structs and optional save/load hooks.

---

## 1. Package Layout

Create a new package:

```
toolbox/+bct/+fields/
    README.md
    schema.m
    validate.m
    make.m
    infer.m
    sizeOfSupport.m
    isTimeVarying.m
    selectTime.m
    cast.m
    withMeta.m
    withTime.m
    toStruct.m
    fromStruct.m
    private/
        validateSupport_.m
        validateValue_.m
        validateTime_.m
        normalizeTime_.m
        supportCardinality_.m
```

**Design choice:** Field is a **struct**, not a class. The `bct.field` package provides constructors, validators, utilities, and conversions.

---

## 2. Field Schema (Contract)

### 2.1 Canonical Field struct (Phase 1)

A Field is a MATLAB struct with required keys and strongly defined semantics.

#### Required fields

* `schemaVersion` (string)
  Example: `"bct.field@1"`

* `meshId` (string)
  Must match `M.ID` (and later `M.Hash` when introduced).
  Purpose: prevent accidental mixing of fields from different meshes.

* `support` (string)
  Enumerated type. Phase 1 supports:

  * `"vertex"`
  * `"face"`
  * `"edge"`
  * `"halfedge"`
  * `"dualFace"` (optional in Phase 1; can validate cardinality later)
  * `"dualVertex"` (optional)
    You can expand later, but do not allow arbitrary strings.

* `value` (numeric array)
  Represents scalar or vector values on the support, optionally time indexed.

* `valueType` (string)
  Enumerated:

  * `"scalar"`
  * `"vector3"`        (embedding vectors, 3D)
  * `"tangent2"`       (intrinsic 2D tangents in a local frame)
  * `"complexScalar"`  (optional Phase 1)
  * `"complexVector3"` (optional Phase 1)
    This is explicit to avoid ambiguous shapes.

* `time` (struct or empty)
  Either `[]` or a normalized struct described below.

* `meta` (struct)
  Always exists; can be empty `struct()`.

#### Optional fields (Phase 1)

* `frame` (struct) only when needed (e.g., `valueType="tangent2"`)

  * `frame.domain` = `"vertex"` or `"face"` (where tangent basis lives)
  * `frame.e1` = [N×3] or [F×3]
  * `frame.e2` = [N×3] or [F×3]
  * `frame.normal` = [N×3] or [F×3] (optional)
  * `frame.convention` (string) e.g., `"right-handed"`
  * `frame.source` (string) e.g., `"bct.geometry.tangents"`

* `units` (string) optional
  (Often stored in meta, but keeping a top-level option is fine.)

* `provenance` (struct) optional
  For pipelines, file origins, preprocessing notes.

### 2.2 Value shape conventions (must be enforced)

Let `S = supportCardinality(M, support)` (number of elements in that discrete support).

The Field must encode the value using one of the following shapes:

#### Scalar

* static: `[S × 1]` or `[S × T]`
* time-varying: `[S × T]`

#### vector3 (embedding vectors)

* static: `[S × 3]` or `[S × 3 × T]`
* time-varying: `[S × 3 × T]`

#### tangent2 (intrinsic 2D tangents)

* static: `[S × 2]` or `[S × 2 × T]`
* time-varying: `[S × 2 × T]`
* Requires `frame` providing an explicit basis (e1,e2) on compatible domain.

**Crucial rule:** support and value first dimension must match:

* `size(value,1) == S`

### 2.3 Time struct schema (normalized)

`time` is either empty `[]` or a struct:

Required time fields (if time is provided):

* `fs` (double) sample rate in Hz, optional if explicit t-vector is provided
* `t0` (double) start time in seconds (default 0)
* `nSamples` (double) number of samples (T)
* `units` (string) default `"s"`
* `t` (double vector) optional explicit time vector [1×T] or [T×1]

Normalization rules:

* If `t` exists, infer `nSamples` from it and infer `fs` if evenly sampled.
* If `t` missing, must have `fs` and `nSamples`.
* Always validate that `nSamples == T` (where T derived from `value` shape).

---

## 3. Core API

### 3.1 `bct.field.schema()`

Returns the schema definition (struct describing allowed supports, valueTypes, required fields, and shape rules). Used by validators and by documentation.

### 3.2 `bct.field.make(...)` (Primary constructor)

Creates a Field struct with strong validation.

Signature (recommended):

```matlab
F = bct.field.make( ...
    'meshId', meshId, ...
    'support', support, ...
    'value', value, ...
    'valueType', valueType, ...
    'time', timeStructOrEmpty, ...
    'meta', metaStruct, ...
    'frame', frameStructOptional);
```

Rules:

* Must validate everything; never return invalid Field.
* Must normalize time struct via `private/normalizeTime_.m`.
* Must inject defaults: `schemaVersion`, empty `meta` if omitted.

### 3.3 `bct.field.validate(F, options)`

Validates a Field struct. Returns `ok` and optionally throws.

* `options.Throw` default `true`
* `options.Manifold` optional; if provided, validate cardinality against actual mesh supports.
* `options.Strict` default `true`

Validation checks:

* required keys exist
* `support` ∈ supported supports
* `valueType` ∈ supported types
* `value` shape consistent with `valueType`
* `time` consistent with presence/absence of time dimension T
* `meshId` is a string scalar
* If `frame` exists, validate it is compatible and normalized

### 3.4 `bct.field.infer(...)` (Convenience constructor)

Build Field given a Manifold and a value matrix, infer support and valueType where possible.

Example:

```matlab
F = bct.field.infer(M, value, 'support',"vertex", 'time',tStruct);
```

Rules:

* `infer` may guess based on `size(value,2)==3` etc., but **must be conservative**.
* If ambiguous, throw and require explicit `valueType`.

### 3.5 Support cardinality helpers

* `n = bct.field.sizeOfSupport(M, support)`
  Computes S for support using `M`:

  * `"vertex"` -> size(M.Vertices,1)
  * `"face"` -> size(M.Faces,1)
  * `"edge"` -> size(M.Edges,1)
  * `"halfedge"` -> depends on halfedge builder; if not available, compute as `3*#faces` and document.
  * `"dualFace"` -> Phase 1 can define as `#vertices` (typical dual cells around vertices) if that’s your convention; if uncertain, keep unsupported or allow but skip cardinality check unless you have DEC object.

### 3.6 Time utilities

* `tf = bct.field.isTimeVarying(F)`
* `F2 = bct.field.selectTime(F, idxOrRange)`
* `F2 = bct.field.withTime(F, timeStruct)` (replaces time metadata, validates)

### 3.7 Meta utilities

* `F2 = bct.field.withMeta(F, patchStruct)` merges metadata safely.

### 3.8 Conversions

* `S = bct.field.toStruct(F)` (identity for now, but used for future file export)
* `F = bct.field.fromStruct(S)` validates and normalizes.

---

## 4. Interaction with `bct.Manifold`

### 4.1 Policy: Field references Manifold by meshId, not by handle

A Field should not store `Manifold` itself, only:

* `meshId` (and later `meshHash`)
* optional `supportSize` cached in meta if desired

### 4.2 Validation with a Manifold

`bct.field.validate(F, 'Manifold', M)` must check:

* `F.meshId == M.ID` (or accept override option `AllowMeshIdMismatch` for migration tools)
* `size(value,1) == sizeOfSupport(M, F.support)`

This is the key safety guarantee against mixing.

---

## 5. Integration with `bct.registry` and `bct.runtime` (Phase 1)

### 5.1 Registry addition (later, minimal in Phase 1)

Add a new registry domain concept: `"field"` or `"fields"`.

However, for Phase 1, do **not** require registry changes. Field is a data artifact; operators can accept Field or raw arrays. Introduce registry integration once Field is stable.

### 5.2 Runtime operator binding (future)

Future operator specs can declare:

* `inputType = "Field"`
* `outputType = "Field"`
* `requires = ["field.support=vertex", ...]`

Runtime can bind operators that enforce support compatibility (e.g., gradient requires vertex scalar field, returns face vector field).

---

## 6. Planned compatibility with `bct.filter` and spectral workflows

### 6.1 Proposed future filter signatures (not implemented in Phase 1)

* `Fout = bct.filter.spectral(Fin, M, kernel, k, opts)`
* `C = bct.filter.project(Fin, M, k, opts)` (returns spectral coefficients Field)
* `Fout = bct.filter.reconstruct(C, M, opts)`

### 6.2 Required design implications for Field now

To support these later:

* `Field.support` must explicitly encode the domain (`vertex`, etc.)
* `meta` should be allowed to store spectral provenance:

  * `meta.spectrum.k`
  * `meta.spectrum.operator`
  * `meta.spectrum.massType`
* Field must support “coefficients” as another support in future:

  * e.g., `support="eigenmode"` with size `k`
  * This can be Phase 2.

For Phase 1: do not implement eigenmode support; keep Field on mesh supports only.

---

## 7. Implementation tasks (coding agent checklist)

### 7.1 Create package + scaffolding

1. Create folder `toolbox/+bct/+fields/` and `private/`.
2. Add `README.md` describing purpose, schema, examples.

### 7.2 Implement schema + enums

* `schema.m` defines:

  * supported supports
  * supported valueTypes
  * value shape rules
  * time schema rules

### 7.3 Implement validator (must be strict)

* `validate.m` calls:

  * `private/validateSupport_.m`
  * `private/validateValue_.m`
  * `private/validateTime_.m`
* Should throw descriptive errors with identifiers:

  * `bct:Field:MissingField`
  * `bct:Field:InvalidSupport`
  * `bct:Field:InvalidValueShape`
  * `bct:Field:TimeMismatch`
  * `bct:Field:MeshMismatch`

### 7.4 Implement constructor

* `make.m`:

  * normalize inputs
  * fill defaults
  * validate
  * return struct

### 7.5 Implement support cardinality

* `sizeOfSupport.m`:

  * requires Manifold input
  * implement vertex/face/edge robustly
  * implement halfedge as `3*numFaces` unless halfedge structure exists
  * document dual supports as “reserved” unless DEC provides sizes

### 7.6 Implement time normalization

* `private/normalizeTime_.m`:

  * ensure `time` is either `[]` or struct
  * enforce `nSamples` consistency with `value` time dimension
  * if `t` present: compute `nSamples`, attempt infer fs from diff(t), validate uniform sampling if strict
  * ensure units default `"s"`

### 7.7 Implement utilities

* `isTimeVarying.m`
* `selectTime.m` (slice time dimension properly for all valueTypes)
* `cast.m` (allow convert double->single etc. without changing semantics)
* `withMeta.m`
* `withTime.m`
* `toStruct/fromStruct`

### 7.8 Add unit tests (strongly recommended)

Create `toolbox/+bct/+test/test_fields.m` (or your test harness) with:

* scalar vertex static, scalar vertex time series
* face vector3 time series
* tangent2 requires frame
* support size mismatch throws
* time mismatch throws
* meshId mismatch throws when Manifold provided

Tests should use a small synthetic mesh to run quickly.

---

## 8. Error message policy (important for debugging)

All errors should include:

* the expected support cardinality and received `size(value,1)`
* expected value shape for `valueType`
* expected vs actual time sample count

Keep error identifiers consistent.

---

## 9. Examples (include in README)

### Example A: scalar vertex field, time series

```matlab
M = bct.Manifold(V, F);
x = randn(M.numVertices(), 1000);

time = struct('fs', 2400, 't0', 0, 'nSamples', 1000, 'units', "s");

Fv = bct.field.make( ...
  'meshId', M.ID, ...
  'support', "vertex", ...
  'valueType', "scalar", ...
  'value', x, ...
  'time', time, ...
  'meta', struct('band',"alpha"));
```

### Example B: face vector field (embedding vectors)

```matlab
vf = randn(M.numFaces(), 3, 1000);

Ff = bct.field.make( ...
  'meshId', M.ID, ...
  'support', "face", ...
  'valueType', "vector3", ...
  'value', vf, ...
  'time', time, ...
  'meta', struct('desc',"face vector field"));
```

### Example C: tangent2 field + frame requirement

```matlab
[N,e1,e2] = bct.geometry.tangents(M,'Domain',"vertex");
u2 = randn(M.numVertices(),2,1000);

frame = struct('domain',"vertex",'e1',e1,'e2',e2,'convention',"right-handed");

Ft = bct.field.make( ...
  'meshId', M.ID, ...
  'support', "vertex", ...
  'valueType', "tangent2", ...
  'value', u2, ...
  'time', time, ...
  'frame', frame, ...
  'meta', struct());
```

---

## 10. Future extensions (explicitly planned, not implemented now)

### 10.1 Spectral coefficient fields

Add support `"eigenmode"` with cardinality `k`, value `[k×T]`. This integrates naturally with `bct.spectrum` and `bct.filter`.

### 10.2 Dual supports

Once DEC is a stable dependency in your runtime context, define:

* `"dualFace"` cardinality = number of vertices (dual cells)
* `"dualEdge"` cardinality = number of edges
  and validate via DEC object when available.

### 10.3 Field bundles

A “FieldSet” for multi-band or multi-modal collections, optionally.

---

# Implementation Guardrails (to avoid breaking bct)

1. **No changes to existing geometry/topology/spectrum code paths** in Phase 1.
2. Field introduction is additive only.
3. Avoid introducing circular dependencies:

   * `bct.field` may accept Manifold for validation, but must not depend on UI or runtime.
4. Do not embed Manifold handle into Field.
5. Do not silently coerce shapes; always validate and throw.

---
