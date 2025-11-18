# UV Validation Implementation

## Summary

Enhanced the UV parametrization feature to ensure safe handling when UV is not available. The UV property can now be safely empty for any Manifold object, and functions requiring UV will issue appropriate warnings or errors.

## Key Changes

### 1. Added checkUV() Validation Method

**File**: `toolbox/+bct/+manifold/Manifold.m`

New method for validating UV availability:
```matlab
hasUV = manifold.checkUV(throw_error)
```

**Behavior:**
- `checkUV(false)` - Returns true/false, issues warning if UV missing (default)
- `checkUV(true)` - Returns true/false, throws error if UV missing
- No warning/error when UV is present

**Usage:**
```matlab
% Optional UV feature with warning
if B.Manifold.checkUV(false)
    plot_in_uv(B.Manifold.UV, data);
else
    plot_on_mesh(B.Manifold.V, data);
end

% Required UV feature with error
B.Manifold.checkUV(true);  % Throws error if UV missing
process_texture(B.Manifold.UV, texture);
```

### 2. Updated Import Pipeline

**File**: `toolbox/+bct/+io/+import/mesh.m`

Enhanced FreeSurfer import:
- More informative console message when UV loaded
- Clear indication that UV is optional
- Better error handling with context in warnings
- No silent failures - always informs user of UV status

**Import behavior:**
- ✓ sphere.reg found → UV loaded, success message printed
- ✗ sphere.reg not found → UV remains empty, no warning (expected case)
- ⚠ sphere.reg found but failed to load → Warning issued with details

### 3. Updated Examples

**Files**: `examples/example_uv_parametrization.m`, `examples/uv_quick_reference.m`

All examples now demonstrate proper UV validation:
```matlab
% Check before using UV
if ~B.Manifold.checkUV(false)
    fprintf('UV not available - exiting\n');
    return;
end

% Proceed with UV-dependent operations
plot_uv_visualization(B.Manifold.UV);
```

### 4. Comprehensive Testing

**File**: `tests/test_uv_validation.m`

New test suite covering:
- ✓ UV defaults to empty
- ✓ checkUV(false) warns when empty
- ✓ checkUV(true) errors when empty
- ✓ checkUV returns true when UV present
- ✓ No warnings when UV available
- ✓ UV can be set to empty after loading
- ✓ Integration with FreeSurfer import

## Usage Patterns

### Pattern 1: Optional UV Feature
```matlab
% Use UV if available, fallback otherwise
if B.Manifold.checkUV(false)  % Warns if missing
    % UV-based visualization
    scatter(B.Manifold.UV(:,1), B.Manifold.UV(:,2), 30, signal, 'filled');
    xlabel('U'); ylabel('V');
else
    % 3D mesh visualization
    trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), ...
        B.Manifold.V(:,3), signal);
end
```

### Pattern 2: Required UV Feature
```matlab
% UV is mandatory for this operation
try
    B.Manifold.checkUV(true);  % Throws if missing
    texture_data = apply_uv_texture(B.Manifold.UV, texture_image);
catch ME
    if strcmp(ME.identifier, 'bct:Manifold:NoUV')
        fprintf('Error: This operation requires UV parametrization\n');
        fprintf('Please import a FreeSurfer surface with .sphere.reg file\n');
    else
        rethrow(ME);
    end
end
```

### Pattern 3: Silent Check
```matlab
% Check without warning (for logic flow)
if ~isempty(B.Manifold.UV)
    % Use UV without triggering warning
    process_with_uv(B.Manifold.UV);
else
    process_without_uv();
end
```

## Error and Warning IDs

**Warning ID**: `bct:Manifold:NoUV`
- Triggered by: `checkUV(false)` when UV is empty
- Message includes guidance on how to obtain UV

**Error ID**: `bct:Manifold:NoUV`
- Triggered by: `checkUV(true)` when UV is empty
- Same message as warning, but throws error

## Best Practices

### For Function Developers

1. **Always validate UV before use:**
   ```matlab
   function result = my_uv_function(manifold)
       if ~manifold.checkUV(false)
           result = [];
           return;
       end
       % Use manifold.UV safely
   end
   ```

2. **Choose appropriate validation mode:**
   - Use `checkUV(false)` for optional features
   - Use `checkUV(true)` for required features

3. **Provide fallbacks when possible:**
   ```matlab
   if manifold.checkUV(false)
       % UV-based method
   else
       % Alternative method
   end
   ```

### For Users

1. **Check UV availability after import:**
   ```matlab
   B = bct.io.import.mesh('lh.pial');
   if B.Manifold.checkUV(false)
       fprintf('UV available for use\n');
   end
   ```

2. **Don't assume UV is always present:**
   - UV requires FreeSurfer .sphere.reg file
   - Not all surfaces have spherical registration
   - Always check before using UV-dependent features

3. **Use informative error handling:**
   ```matlab
   try
       B.Manifold.checkUV(true);
       uv_operation();
   catch ME
       fprintf('Operation failed: %s\n', ME.message);
       fprintf('Hint: Import FreeSurfer surface with .sphere.reg\n');
   end
   ```

## Testing

Run validation tests:
```bash
matlab -batch "run('tests/test_uv_validation.m')"
```

Expected output:
- All 8 tests pass
- Demonstrates warning/error behavior
- Verifies UV can be empty without issues

## Migration Guide

### Before (Unsafe)
```matlab
% Directly accessing UV without checking
plot(B.Manifold.UV(:,1), B.Manifold.UV(:,2));  % Fails if UV empty!
```

### After (Safe)
```matlab
% Check before accessing
if B.Manifold.checkUV(false)
    plot(B.Manifold.UV(:,1), B.Manifold.UV(:,2));
else
    fprintf('UV not available for plotting\n');
end
```

## Summary of Guarantees

1. ✓ UV property can always be empty (default state)
2. ✓ Empty UV never causes errors during import
3. ✓ checkUV() provides clear feedback on availability
4. ✓ Users are guided on how to obtain UV when missing
5. ✓ Functions can gracefully handle missing UV
6. ✓ No silent failures - explicit validation required
