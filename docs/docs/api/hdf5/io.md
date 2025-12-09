# BCT I/O Operations

Complete guide to reading and writing BCT files.

## Creating Files

### Basic Creation
```matlab
% Create in default location
bct_obj = bct.create('experiment_1');

% Creates: <bioctree_root>/data/bioctree_files/raw/experiment_1.h5
```

### Custom Location
```matlab
% Specify full path
bct_obj = bct.create('/path/to/my_file');
```

## Writing Data

### Raw Signals
```matlab
% Single-layer signal [N × T]
signal_data = randn(num_vertices, num_timepoints);
fs = 250;  % Hz

bct_obj.write_raw(signal_data, fs);
```

### Multi-Layer Signals
```matlab
% Multi-layer [L × T × N]
bct_obj.write_raw_layers(multi_layer_data, fs, layer_ids);
```

### Graph Structure
```matlab
graph_struct = struct('V', vertices, 'F', faces);
bct_obj.write_graph(graph_struct);
```

### Time-Frequency Coefficients
```matlab
% Complex coefficients [L × F × T × N]
bct_obj.write_tf_coeffs(cwt_coeffs, frequencies, transform_params);
```

## Reading Data

### Full Data
```matlab
% Read all signal data
data = bct_obj.read_raw();  % [N × T] or [L × T × N]
```

### Partial Data (Hyperslabs)
```matlab
% Time range [100, 500], all vertices
subset = bct_obj.read_raw([100, 500], ':');

% All time, vertices [1, 1000]
subset = bct_obj.read_raw(':', [1, 1000]);

% Specific time and vertices
subset = bct_obj.read_raw([100, 500], [1, 1000]);
```

### Layer Selection
```matlab
% Read specific layer
layer_data = bct_obj.read_raw_layers(layer_id, time_range, vertex_range);

% Multiple layers
layers = bct_obj.read_raw_layers([1, 2, 3], ':', ':');
```

### Frequency Band Reconstruction
```matlab
% Reconstruct alpha band (8-12 Hz)
alpha_signal = bct_obj.read_tf_band([8, 12], time_range, vertex_range, layer_ids);
```

## File Management

### Validation
```matlab
report = bct_obj.validate();
```

### Metadata
```matlab
% Add description
bct_obj.set_metadata('description', 'MEG experiment alpha waves');

% Read metadata
meta = bct_obj.get_metadata();
```

### Close File
```matlab
% Files auto-close, but can explicitly close
bct_obj.close();
```

## Best Practices

1. **Always validate** after writing
2. **Use partial loading** for large files
3. **Store metadata** for reproducibility
4. **Use .h5 extension** (not .bct)

## Further Reading

- [BCT Specification](specification.md)
- [API Overview](../matlab/overview.md)
