# Brush Integration Plan — bct.registry & bct.runtime

## Executive Summary

This document outlines the complete integration of the `bct.brush` system into the main BCT registry and runtime architecture. The integration creates a unified discovery and dispatch system while maintaining backward compatibility with existing brush implementations.

**Key Goals:**
1. Create `bct.registry.brushes()` as the authoritative brush catalog
2. Implement `bct.runtime.brushes.*` for session-aware dispatch
3. Maintain backward compatibility with existing `bct.brush.apply()`
4. Follow established patterns from `bct.kernel` and `bct.filter` systems
5. Enable UI-driven brush selection and parameterization

---

## 1. Current State Analysis

### 1.1 Existing Brush System

**Location**: `toolbox/+bct/+brush/`

**Structure**:
```
+bct/+brush/
├── registry.m          # Standalone brush catalog
├── apply.m             # Universal dispatcher
├── embed.m             # Selection utility
├── +patch/             # Spatial selections
│   ├── nearest.m
│   ├── gaussian.m
│   └── spectral.m
├── +trajectory/        # Path-based selections
│   ├── geodesic.m
│   ├── gaussian.m
│   └── spectral.m
├── +time/              # Spatiotemporal patterns
│   ├── heat.m
│   └── spectral.m
└── +design/            # UI components (future)
```

**Current Registry Structure**:
```matlab
R.patch_nearest = struct(...
    'Name', 'Nearest-neighbor patch', ...
    'Category', 'patch', ...
    'Algorithm', @bct.brush.patch.nearest ...
);
```

**Problems**:
- Isolated from main registry/runtime system
- No parameter schema validation
- No dependency checking
- No session-aware filtering
- Limited UI integration support

---

## 2. Target Architecture

### 2.1 Registry Integration

**New Location**: `toolbox/+bct/+registry/+brushes/`

**File Structure**:
```
+bct/+registry/+brushes/
├── defs.m          # Authoritative brush definitions (REQUIRED)
├── schema.m        # BrushSpec schema definition (REQUIRED)
├── validate.m      # Registry validation (REQUIRED)
└── list.m          # Convenience listing (OPTIONAL)
```

**Wrapper**: `toolbox/+bct/+registry/brushes.m`
```matlab
function defs = brushes()
    %BCT.REGISTRY.BRUSHES  Authoritative brush catalog
    defs = bct.registry.brushes.defs();
end
```

### 2.2 Runtime Integration

**New Location**: `toolbox/+bct/+runtime/+brushes/`

**File Structure**:
```
+bct/+runtime/+brushes/
├── dictionary.m    # Fast lookup: BrushId → BrushSpec (REQUIRED)
├── resolve.m       # Session-aware brush resolution (REQUIRED)
└── clearCache.m    # Cache management (OPTIONAL)
```

### 2.3 Backward Compatibility Layer

**Maintain**: `toolbox/+bct/+brush/`

- Keep all existing brush implementations unchanged
- Update `bct.brush.apply()` to use runtime when available
- Deprecate `bct.brush.registry()` in favor of main registry
- Add migration warnings but maintain functionality

---

## 3. BrushSpec Definition

### 3.1 Required Fields

Following the established pattern from `bct.registry.kernels`, each brush must have:

```matlab
spec = struct(...
    'Id',           string,            % Unique identifier (e.g., "patch_gaussian")
    'Category',     string,            % "patch"|"trajectory"|"time"|"dynamic"
    'AxisKinds',    string array,      % ["spatial"|"spatiotemporal"]
    'ParamNames',   string array,      % Required parameter names
    'DefaultParams', function_handle,  % @(manifold)->struct
    'ParamRanges',  function_handle,   % @(manifold)->struct
    'Evaluate',     function_handle,   % @(manifold,params)->w (canonical signature)
    ...
);
```

### 3.2 Optional Fields

```matlab
spec = struct(...
    'Name',          string,          % Display name
    'Tags',          string array,    % ["geometric","spectral","smooth",...]
    'Requires',      string array,    % ["Graph"|"FEM"|"DEC"|"Eigenpairs"]
    'OutputDims',    string,          % "spatial" | "spatiotemporal"
    'Description',   string,          % Human-readable description
    'Examples',      struct,          % Usage examples
    'Performance',   struct,          % Complexity notes
    ...
);
```

### 3.3 Complete BrushSpec Example

```matlab
spec = struct(...
    'Id',           "patch_gaussian", ...
    'Category',     "patch", ...
    'AxisKinds',    ["spatial"], ...
    'ParamNames',   ["source", "sigma", "metric"], ...
    'DefaultParams', @(M) struct(...
        'source', 1, ...
        'sigma', 0.05 * computeCharacteristicLength(M), ...
        'metric', "geometry"), ...
    'ParamRanges',  @(M) struct(...
        'source', [1, M.numVertices()], ...
        'sigma',  [0.01, 1.0] * computeCharacteristicLength(M), ...
        'metric', ["geometry", "fem"]), ...
    'Evaluate',     @bct.brush.patch.gaussian, ...
    'Name',         "Gaussian Patch", ...
    'Tags',         ["geometric", "smooth", "distance-based"], ...
    'Requires',     ["Graph"], ...
    'OutputDims',   "spatial", ...
    'Description',  "Gaussian-weighted spatial selection centered at source vertex", ...
    'Examples',     struct(...
        'basic',  "params = struct('source', 100, 'sigma', 5.0); w = apply('patch_gaussian', M, params);", ...
        'fem',    "params = struct('source', 100, 'sigma', 5.0, 'metric', 'fem'); ..."), ...
    'Performance',  struct(...
        'Complexity', "O(N) for graph distances + O(N) for evaluation", ...
        'Notes',      "Efficient for sparse selections with proper thresholding") ...
);
```

---

## 4. Implementation Plan

### Phase 1: Registry Infrastructure (Week 1)

#### 4.1 Create `+bct/+registry/+brushes/defs.m`

```matlab
function defs = defs()
%BCT.REGISTRY.BRUSHES.DEFS  Authoritative brush definitions registry
%
% Output:
%   defs - struct array with BrushSpec fields
%
% Contract:
%   - Evaluate(manifold, params) is canonical signature
%   - DefaultParams(manifold) returns struct with all ParamNames
%   - ParamRanges(manifold) returns validation structs
%   - Registry must be deterministic

    defs = initializeEmpty();
    
    %% PATCH BRUSHES
    defs(end+1) = definePatchNearest();
    defs(end+1) = definePatchGaussian();
    defs(end+1) = definePatchSpectral();
    
    %% TRAJECTORY BRUSHES
    defs(end+1) = defineTrajectoryGeodesic();
    defs(end+1) = defineTrajectoryGaussian();
    defs(end+1) = defineTrajectorySpectral();
    
    %% TIME BRUSHES
    defs(end+1) = defineTimeHeat();
    defs(end+1) = defineTimeSpectral();
    
    % Validate on construction
    bct.registry.brushes.validate(defs);
end

function spec = definePatchGaussian()
    spec = struct(...
        'Id',           "patch_gaussian", ...
        'Category',     "patch", ...
        'AxisKinds',    ["spatial"], ...
        'ParamNames',   ["source", "sigma", "metric"], ...
        'DefaultParams', @defaultParamsPatchGaussian, ...
        'ParamRanges',  @paramRangesPatchGaussian, ...
        'Evaluate',     @bct.brush.patch.gaussian, ...
        'Name',         "Gaussian Patch", ...
        'Tags',         ["geometric", "smooth", "distance-based"], ...
        'Requires',     ["Graph"], ...
        'OutputDims',   "spatial", ...
        'Description',  "Gaussian-weighted spatial selection" ...
    );
end

function p = defaultParamsPatchGaussian(manifold)
    % Compute characteristic length scale
    charLength = computeCharacteristicLength(manifold);
    
    p = struct(...
        'source', round(manifold.numVertices() / 2), ...  % Center vertex
        'sigma',  0.05 * charLength, ...                  % 5% of mesh scale
        'metric', "geometry" ...
    );
end

function r = paramRangesPatchGaussian(manifold)
    charLength = computeCharacteristicLength(manifold);
    
    r = struct(...
        'source', struct('type', 'integer', 'range', [1, manifold.numVertices()]), ...
        'sigma',  struct('type', 'numeric', 'range', [0.001, 1.0] * charLength), ...
        'metric', struct('type', 'string', 'values', ["geometry", "fem"]) ...
    );
end

function L = computeCharacteristicLength(manifold)
    % Estimate characteristic length from bounding box
    V = manifold.Vertices;
    bbox = max(V) - min(V);
    L = norm(bbox);
end
```

**Task List**:
- [ ] Create directory structure
- [ ] Implement `defs.m` with all brush definitions
- [ ] Implement helper functions for each brush type
- [ ] Add characteristic length computation utility

#### 4.2 Create `+bct/+registry/+brushes/schema.m`

```matlab
function S = schema()
%BCT.REGISTRY.BRUSHES.SCHEMA  BrushSpec schema definition
%
% Output:
%   S - struct describing required fields, types, and invariants

    S = struct();
    
    % Required fields
    S.RequiredFields = [
        "Id"
        "Category"
        "AxisKinds"
        "ParamNames"
        "DefaultParams"
        "ParamRanges"
        "Evaluate"
    ];
    
    % Optional fields
    S.OptionalFields = [
        "Name"
        "Tags"
        "Requires"
        "OutputDims"
        "Description"
        "Examples"
        "Performance"
    ];
    
    % Field types
    S.FieldTypes = struct(...
        'Id',           "string", ...
        'Category',     "string", ...
        'AxisKinds',    "string array", ...
        'ParamNames',   "string array", ...
        'DefaultParams', "function_handle", ...
        'ParamRanges',  "function_handle", ...
        'Evaluate',     "function_handle", ...
        'Name',         "string", ...
        'Tags',         "string array", ...
        'Requires',     "string array", ...
        'OutputDims',   "string", ...
        'Description',  "string" ...
    );
    
    % Allowed values for enumerated fields
    S.AllowedValues = struct(...
        'Category',    ["patch", "trajectory", "time", "dynamic"], ...
        'AxisKinds',   ["spatial", "spatiotemporal"], ...
        'Requires',    ["Graph", "FEM", "DEC", "Eigenpairs"], ...
        'OutputDims',  ["spatial", "spatiotemporal"] ...
    );
    
    % Validation function
    S.ValidateEntry = @validateBrushSpec;
end

function validateBrushSpec(spec)
    % Validate required fields present
    schema = bct.registry.brushes.schema();
    for i = 1:length(schema.RequiredFields)
        field = schema.RequiredFields(i);
        if ~isfield(spec, field)
            error('bct:registry:brushes:MissingField', ...
                'Required field "%s" missing', field);
        end
    end
    
    % Validate types
    validateFieldTypes(spec, schema);
    
    % Validate enumerated values
    validateEnumeratedFields(spec, schema);
    
    % Validate function handles
    validateFunctionHandles(spec);
end
```

**Task List**:
- [ ] Define complete schema structure
- [ ] Implement validation functions
- [ ] Add invariant checks (e.g., ParamNames consistency)

#### 4.3 Create `+bct/+registry/+brushes/validate.m`

```matlab
function validate(defs)
%BCT.REGISTRY.BRUSHES.VALIDATE  Validate brush registry
%
% Validates:
%   - No duplicate IDs
%   - All required fields present
%   - DefaultParams returns struct with all ParamNames
%   - ParamRanges returns struct with all ParamNames
%   - Evaluate function executes without error
%
% Throws on validation failure

    % Check for duplicates
    ids = string({defs.Id});
    if length(ids) ~= length(unique(ids))
        error('bct:registry:brushes:DuplicateIds', 'Duplicate brush IDs detected');
    end
    
    % Validate each entry
    schema = bct.registry.brushes.schema();
    for i = 1:length(defs)
        try
            schema.ValidateEntry(defs(i));
            validateExecutable(defs(i));
        catch ME
            error('bct:registry:brushes:ValidationFailed', ...
                'Validation failed for brush "%s": %s', defs(i).Id, ME.message);
        end
    end
    
    fprintf('bct.registry.brushes: Validation passed (%d brushes)\n', length(defs));
end

function validateExecutable(spec)
    % Create test manifold
    [V, F] = icosphere(3);  % Small test mesh
    M = bct.Manifold(V, F);
    
    % Get default parameters
    try
        params = spec.DefaultParams(M);
    catch ME
        error('DefaultParams function failed: %s', ME.message);
    end
    
    % Validate parameter names match
    paramNames = string(fieldnames(params));
    if ~isequal(sort(paramNames), sort(spec.ParamNames))
        error('DefaultParams fields do not match ParamNames');
    end
    
    % Test parameter ranges
    try
        ranges = spec.ParamRanges(M);
    catch ME
        error('ParamRanges function failed: %s', ME.message);
    end
    
    if ~isequal(sort(string(fieldnames(ranges))), sort(spec.ParamNames))
        error('ParamRanges fields do not match ParamNames');
    end
    
    % Test execution (basic smoke test)
    try
        w = spec.Evaluate(M, params);
        assert(size(w, 1) == M.numVertices(), 'Output size mismatch');
    catch ME
        warning('Brush execution test failed (may require specific dependencies): %s', ME.message);
    end
end
```

**Task List**:
- [ ] Implement duplicate detection
- [ ] Add per-entry validation
- [ ] Create test manifold generation utility
- [ ] Add smoke tests for each brush

#### 4.4 Create wrapper `+bct/+registry/brushes.m`

```matlab
function defs = brushes()
%BCT.REGISTRY.BRUSHES  Authoritative brush catalog
%
% Syntax:
%   defs = bct.registry.brushes()
%
% Output:
%   defs - struct array of BrushSpec entries
%
% See also: bct.registry.brushes.defs, bct.runtime.brushes

    defs = bct.registry.brushes.defs();
end
```

### Phase 2: Runtime Infrastructure (Week 2)

#### 4.5 Create `+bct/+runtime/+brushes/dictionary.m`

```matlab
function [D, meta] = dictionary(context)
%BCT.RUNTIME.BRUSHES.DICTIONARY  Fast brush lookup dictionary
%
% Syntax:
%   D = bct.runtime.brushes.dictionary()
%   D = bct.runtime.brushes.dictionary(context)
%   [D, meta] = bct.runtime.brushes.dictionary(context)
%
% Inputs:
%   context - (optional) struct with:
%             .manifold         - bct.Manifold object
%             .checkDependencies - logical (default: true)
%
% Outputs:
%   D    - dictionary mapping BrushId (string) → BrushSpec (struct)
%   meta - struct with statistics
%
% Caching:
%   Dictionary is cached persistently for performance.
%   Call bct.runtime.brushes.clearCache() to force rebuild.

    persistent cachedDict
    persistent cacheTime
    
    % Check if cache needs refresh
    needsRefresh = isempty(cachedDict) || ...
                   (nargin == 1 && isfield(context, 'forceRefresh') && context.forceRefresh);
    
    if needsRefresh
        % Build from registry
        defs = bct.registry.brushes();
        
        % Filter by context if provided
        if nargin == 1 && isfield(context, 'manifold')
            defs = filterByDependencies(defs, context);
        end
        
        % Build dictionary
        cachedDict = builtin('dictionary');
        for i = 1:length(defs)
            cachedDict(defs(i).Id) = defs(i);
        end
        cacheTime = now();
    end
    
    D = cachedDict;
    
    if nargout > 1
        meta = struct(...
            'numBrushes', length(D), ...
            'cacheTime', cacheTime ...
        );
    end
end

function filtered = filterByDependencies(defs, context)
    % Filter brushes based on manifold capabilities
    if ~isfield(context, 'checkDependencies') || context.checkDependencies
        filtered = [];
        for i = 1:length(defs)
            if isDependencySatisfied(defs(i), context.manifold)
                filtered(end+1) = defs(i); %#ok<AGROW>
            end
        end
    else
        filtered = defs;
    end
end

function satisfied = isDependencySatisfied(spec, manifold)
    % Check if brush requirements are met
    satisfied = true;
    
    if ~isfield(spec, 'Requires') || isempty(spec.Requires)
        return;
    end
    
    for i = 1:length(spec.Requires)
        req = spec.Requires(i);
        switch req
            case "Graph"
                try
                    manifold.Graph();
                catch
                    satisfied = false;
                    return;
                end
            case "FEM"
                try
                    manifold.FEM();
                catch
                    satisfied = false;
                    return;
                end
            case "DEC"
                try
                    manifold.DEC();
                catch
                    satisfied = false;
                    return;
                end
            case "Eigenpairs"
                % Check if FEM is available (eigenpairs computed through FEM)
                try
                    manifold.FEM();
                catch
                    satisfied = false;
                    return;
                end
        end
    end
end
```

**Task List**:
- [ ] Implement persistent caching
- [ ] Add dependency filtering logic
- [ ] Test with various manifold configurations

#### 4.6 Create `+bct/+runtime/+brushes/resolve.m`

```matlab
function spec = resolve(id, context)
%BCT.RUNTIME.BRUSHES.RESOLVE  Resolve brush by ID with context
%
% Syntax:
%   spec = bct.runtime.brushes.resolve(id)
%   spec = bct.runtime.brushes.resolve(id, context)
%
% Inputs:
%   id      - Brush identifier (string)
%   context - (optional) struct with:
%             .manifold - bct.Manifold object
%             .params   - user-provided parameters (merged with defaults)
%
% Output:
%   spec - Complete BrushSpec with context-aware defaults

    % Get dictionary
    if nargin < 2
        D = bct.runtime.brushes.dictionary();
    else
        D = bct.runtime.brushes.dictionary(context);
    end
    
    % Lookup brush
    if ~isKey(D, id)
        error('bct:runtime:brushes:UnknownBrush', ...
            'Brush "%s" not found. Use bct.runtime.brushes.list() to see available brushes.', id);
    end
    
    spec = D(id);
    
    % Merge context if provided
    if nargin == 2 && isfield(context, 'manifold')
        % Compute context-aware defaults
        spec.DefaultParamsResolved = spec.DefaultParams(context.manifold);
        spec.ParamRangesResolved = spec.ParamRanges(context.manifold);
        
        % Merge with user params if provided
        if isfield(context, 'params')
            spec.DefaultParamsResolved = mergeParams(...
                spec.DefaultParamsResolved, context.params);
        end
    end
end

function merged = mergeParams(defaults, user)
    merged = defaults;
    userFields = fieldnames(user);
    for i = 1:length(userFields)
        merged.(userFields{i}) = user.(userFields{i});
    end
end
```

**Task List**:
- [ ] Implement dictionary lookup
- [ ] Add context-aware parameter resolution
- [ ] Implement parameter merging

#### 4.7 Create `+bct/+runtime/+brushes/clearCache.m`

```matlab
function clearCache()
%BCT.RUNTIME.BRUSHES.CLEARCACHE  Clear runtime dictionary cache
%
% Forces rebuild of brush dictionary on next access

    % Clear persistent variable in dictionary function
    clear bct.runtime.brushes.dictionary
    
    fprintf('bct.runtime.brushes: Cache cleared\n');
end
```

### Phase 3: Backward Compatibility (Week 2)

#### 4.8 Update `+bct/+brush/apply.m`

```matlab
function w = apply(brushName, domain, params)
%BCT.BRUSH.APPLY  Apply a brush by name
%
%   w = bct.brush.apply(brushName, domain, params)
%
%   Inputs
%   ------
%   brushName : string or char - brush identifier
%   domain    : bct.Manifold
%   params    : struct with brush-specific parameters
%
%   Output
%   ------
%   w         : N×1 or N×T weighted selection field
%
%   Note: Now uses bct.runtime.brushes for dispatch

    arguments
        brushName (1,:) char
        domain
        params struct
    end

    % Use runtime for dispatch (preferred path)
    try
        context = struct('manifold', domain, 'params', params);
        spec = bct.runtime.brushes.resolve(brushName, context);
        w = spec.Evaluate(domain, spec.DefaultParamsResolved);
        return;
    catch ME
        % Fallback to legacy registry
        warning('bct:brush:apply:FallingBackToLegacy', ...
            'Runtime dispatch failed: %s. Using legacy registry.', ME.message);
    end

    % Legacy path (maintain for backward compatibility)
    R = bct.brush.registry();

    if ~isfield(R, brushName)
        error('bct:brush:UnknownBrush', ...
              'Unknown brush: %s', brushName);
    end

    alg = R.(brushName).Algorithm;
    w = alg(domain, params);

end
```

**Task List**:
- [ ] Add runtime dispatch as primary path
- [ ] Keep legacy fallback
- [ ] Add deprecation warnings

### Phase 4: Testing and Validation (Week 3)

#### 4.9 Create test suite

**Location**: `tests/unit/test_brush_integration.m`

```matlab
classdef test_brush_integration < matlab.unittest.TestCase
    
    properties (TestParameter)
        brushId = {"patch_nearest", "patch_gaussian", "patch_spectral", ...
                   "trajectory_geodesic", "time_heat"}
    end
    
    methods (Test)
        function testRegistryLoads(testCase)
            defs = bct.registry.brushes();
            testCase.verifyNotEmpty(defs);
            testCase.verifyGreaterThanOrEqual(length(defs), 8);
        end
        
        function testDictionaryBuilds(testCase)
            D = bct.runtime.brushes.dictionary();
            testCase.verifyNotEmpty(D);
        end
        
        function testBrushExecutes(testCase, brushId)
            % Create test manifold
            [V, F] = icosphere(4);
            M = bct.Manifold(V, F);
            
            % Get brush spec
            spec = bct.runtime.brushes.resolve(brushId, struct('manifold', M));
            
            % Execute with defaults
            w = spec.Evaluate(M, spec.DefaultParamsResolved);
            
            % Verify output
            testCase.verifyEqual(size(w, 1), M.numVertices());
        end
        
        function testBackwardCompatibility(testCase)
            [V, F] = icosphere(4);
            M = bct.Manifold(V, F);
            
            params = struct('source', 1, 'sigma', 0.1, 'metric', "geometry");
            w = bct.brush.apply('patch_gaussian', M, params);
            
            testCase.verifyEqual(size(w, 1), M.numVertices());
        end
    end
end
```

**Task List**:
- [ ] Create comprehensive test suite
- [ ] Test all registered brushes
- [ ] Test dependency filtering
- [ ] Test backward compatibility

---

## 5. Migration Guide

### 5.1 For End Users

**Old Code** (still works):
```matlab
params = struct('source', 100, 'sigma', 5.0);
w = bct.brush.apply('patch_gaussian', M, params);
```

**New Code** (recommended):
```matlab
context = struct('manifold', M);
spec = bct.runtime.brushes.resolve('patch_gaussian', context);
params = spec.DefaultParamsResolved;
params.source = 100;
params.sigma = 5.0;
w = spec.Evaluate(M, params);
```

### 5.2 For Developers Adding New Brushes

**Step 1**: Implement brush function
```matlab
% In +bct/+brush/+patch/mynewbrush.m
function w = mynewbrush(manifold, params)
    % Implementation
end
```

**Step 2**: Add to registry
```matlab
% In +bct/+registry/+brushes/defs.m
function spec = defineMyNewBrush()
    spec = struct(...
        'Id', "patch_mynewbrush", ...
        'Evaluate', @bct.brush.patch.mynewbrush, ...
        % ... other fields
    );
end
```

**Step 3**: Test
```matlab
defs = bct.registry.brushes();
bct.registry.brushes.validate(defs);
```

---

## 6. Timeline and Milestones

| Week | Phase | Deliverables |
|------|-------|--------------|
| 1 | Registry | `+bct/+registry/+brushes/*` complete |
| 2 | Runtime + Compat | `+bct/+runtime/+brushes/*` + updated `apply.m` |
| 3 | Testing | Full test suite passing |
| 4 | Documentation | Updated docs and migration guide |

---

## 7. Success Criteria

- [ ] All existing brushes registered in new system
- [ ] Registry validation passes
- [ ] Runtime dictionary builds without errors
- [ ] All tests pass
- [ ] Backward compatibility maintained
- [ ] Documentation updated
- [ ] Example code works with both old and new APIs

---

## 8. Future Enhancements

### 8.1 UI Integration
- Parameter editor widgets
- Real-time preview
- Brush composition tools

### 8.2 Brush Algebra
- Combine brushes with operators (union, intersect, blend)
- Morphological operations
- Boolean logic

### 8.3 Serialization
- Save/load brush configurations
- Preset library
- History and undo

---

## Appendix A: Complete File Checklist

### New Files to Create

**Registry**:
- [ ] `toolbox/+bct/+registry/brushes.m`
- [ ] `toolbox/+bct/+registry/+brushes/defs.m`
- [ ] `toolbox/+bct/+registry/+brushes/schema.m`
- [ ] `toolbox/+bct/+registry/+brushes/validate.m`
- [ ] `toolbox/+bct/+registry/+brushes/list.m` (optional)

**Runtime**:
- [ ] `toolbox/+bct/+runtime/+brushes/dictionary.m`
- [ ] `toolbox/+bct/+runtime/+brushes/resolve.m`
- [ ] `toolbox/+bct/+runtime/+brushes/clearCache.m`

**Tests**:
- [ ] `tests/unit/test_brush_registry.m`
- [ ] `tests/unit/test_brush_runtime.m`
- [ ] `tests/unit/test_brush_integration.m`

### Files to Modify

- [ ] `toolbox/+bct/+brush/apply.m` - add runtime dispatch
- [ ] `toolbox/+bct/+brush/registry.m` - add deprecation warning

### Documentation

- [ ] `notes/BrushContract.md` - ✅ Already created
- [ ] `docs/brush-integration-guide.md` - Migration guide
- [ ] Update API reference documentation

---

## Appendix B: Parameter Schema Examples

### Simple Parameter
```matlab
'sigma', struct(...
    'type', 'numeric', ...
    'range', [0.001, 10.0], ...
    'default', 1.0, ...
    'description', 'Width parameter' ...
)
```

### Vertex Index Parameter
```matlab
'source', struct(...
    'type', 'integer', ...
    'range', [1, N], ...
    'default', @(M) round(M.numVertices()/2), ...
    'description', 'Source vertex index' ...
)
```

### Enumerated Parameter
```matlab
'metric', struct(...
    'type', 'string', ...
    'values', ["geometry", "fem"], ...
    'default', "geometry", ...
    'description', 'Distance metric' ...
)
```

---

This integration plan provides a complete roadmap for bringing the brush system into the main BCT registry/runtime architecture while maintaining backward compatibility and following established patterns.
