# Standard Test BCT File - Developer Instructions

## Overview

The bioctree project uses a standardized test BCT file (`test_bioctree_standard.h5`) for consistent testing, demos, and development. This file is automatically created and managed by the database module.

## Usage in Code

### Loading Test Data

```matlab
% Load complete test dataset
data = db_load_test_bct();

% Access components
coords = data.graph.coords;        % [642 x 3] vertex coordinates
signal = data.signal.signal;       % [642 x 1000] multi-layer patch signals
time_vec = data.temporal.time_vector; % [1 x 1000] time samples

% Load specific components only
graph_only = db_load_test_bct('DataType', 'graph');
signal_only = db_load_test_bct('DataType', 'signal');
```

### File Creation (Advanced)

```matlab
% Create with custom parameters (for specific tests)
success = db_create_test_bct('my_test.h5', ...
    'NumLayers', 5, ...
    'IcosphereLevel', 2, ...
    'TimeSteps', 50);
```

## Standard Test File Specification

- **Graph**: Icosphere subdivision level 3 (642 vertices, 1280 faces)
- **Signal Layers**: 10 patch signals with increasing sizes
  - Layer 1: 5% patch size (~32 nodes)
  - Layer 2: 13.9% patch size (~89 nodes)  
  - Layer 3: 22.8% patch size (~146 nodes)
  - ...
  - Layer 10: 85% patch size (~546 nodes)
- **Temporal**: 100 time steps per layer (1000 total)
- **Sampling Rate**: 100 Hz
- **Random Seed**: 42 (for reproducibility)

## Integration Guidelines

### For Test Functions
```matlab
function test_my_function()
    % Use standard test data
    data = db_load_test_bct('Verbose', false);
    
    % Run your tests
    result = my_function(data.graph.coords, data.signal.signal);
    
    % Assertions using known properties
    assert(size(result, 1) == 642, 'Wrong number of vertices');
end
```

### For Demo Scripts
```matlab
function demo_my_feature()
    fprintf('Loading standard test dataset...\n');
    
    % Load with verbose output for user
    data = db_load_test_bct('Verbose', true);
    
    % Demo your feature
    demo_visualization(data);
end
```

### For Copilot Instructions
When creating new bioctree functions, always reference the standard test file:

```
The standard test dataset is available via db_load_test_bct() and contains:
- 642-vertex icosphere graph in data.graph.coords [642 x 3]
- Multi-layer patch signals in data.signal.signal [642 x 1000] 
- Temporal information in data.temporal
- This should be used for testing and demonstrations
```

## File Locations

- **Development**: `test_bioctree_standard.h5` (current directory)
- **Production**: `{config.DataPath}/test_bioctree_standard.h5`
- **Config**: Uses `bioctree_config()` for path resolution

## Maintenance

The test file is automatically created when first accessed via `db_load_test_bct()`. 

To recreate (if corrupted):
```matlab
delete('test_bioctree_standard.h5');  % or full path
data = db_load_test_bct();  % Will recreate automatically
```

To verify integrity:
```matlab
data = db_load_test_bct('Verbose', true);
fprintf('Vertices: %d, Signal size: [%d x %d]\n', ...
    size(data.graph.coords, 1), size(data.signal.signal));
```

## File Extension Requirements

**CRITICAL: All BCT files must use .h5 extension, never .bct**

- BCT files are HDF5 files with Bioctree-specific internal structure
- The "BCT" name refers to the data organization, not the file extension
- Always use: `data.h5`, `test.h5`, `results.h5`
- Never use: `data.bct`, `test.bct`, `results.bct`

## Best Practices

1. **Always use `db_load_test_bct()`** instead of hardcoded file paths
2. **Handle missing paths gracefully** - the function creates files automatically
3. **Use `'Verbose', false`** in unit tests to reduce output  
4. **Use `'Verbose', true`** in demos to show users what's loading
5. **Reference standard dimensions** (642 vertices, 1000 time samples) in assertions
6. **Leverage reproducibility** - same seed always gives same signals
7. **Use .h5 extension** for all BCT files to maintain HDF5 compatibility

## Examples

See these files for usage examples:
- `demo/demo_bioctree_plotter.m`
- `tests/unit/test_*.m`
- `workflows/workflow_*.m`