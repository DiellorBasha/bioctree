# BCT File Specification

The BCT (Bioctree) file format is an HDF5-based standard for storing neuroimaging data with mesh geometry, signals, and metadata.

## File Structure

```
dataset_name.h5
├── /raw/                      % Raw signals
│   ├── X                      % Signal data [N × T] or [L × T × N]
│   ├── fs                     % Sampling frequency (Hz)
│   └── layer_ids              % Layer identifiers (if multi-layer)
├── /graph/                    % Mesh/graph structure
│   ├── V                      % Vertices [N × 3]
│   ├── F                      % Faces [M × 3]
│   └── edges                  % Edge list [E × 2]
├── /tf/                       % Time-frequency coefficients (optional)
│   ├── coeffs_real            % Real part [L × F × T × N]
│   ├── coeffs_imag            % Imaginary part [L × F × T × N]
│   ├── freqs                  % Frequency vector [F × 1]
│   └── params/                % Transform parameters
└── /metadata/                 % Metadata
    ├── schema_version         % BCT schema version
    ├── created                % Timestamp
    └── description            % Text description
```

## Creating BCT Files

```matlab
% Create new file
bct_obj = bct.create('my_dataset');

% Write signal data
bct_obj.write_raw(signal_matrix, sampling_rate);

% Write mesh
graph_struct = struct('V', vertices, 'F', faces);
bct_obj.write_graph(graph_struct);

% Validate
report = bct_obj.validate();
```

## Reading BCT Files

```matlab
% Open existing file
bct_obj = bct.open('my_dataset.h5');

% Read full data
data = bct_obj.read_raw();

% Read partial (time range 100-500, vertices 1-1000)
subset = bct_obj.read_raw([100, 500], [1, 1000]);

% Read graph
graph = bct_obj.read_graph();
```

## Multi-Layer Support

```matlab
% Stack multiple conditions/trials as layers
layer_1 = condition_A_data;  % [N × T]
layer_2 = condition_B_data;  % [N × T]

% Combine into 3D array [L × T × N]
multi_layer = cat(1, ...
    reshape(layer_1, [1, size(layer_1)]), ...
    reshape(layer_2, [1, size(layer_2)]));

% Write
bct_obj.write_raw_layers(multi_layer, fs, [0, 1]);

% Read specific layer
layer_1_read = bct_obj.read_raw_layers(1, ':', ':');
```

## Schema Validation

```matlab
% Validate against schema
report = bct_obj.validate();

if report.ok
    fprintf('✓ File is valid\n');
else
    fprintf('Validation errors:\n');
    fprintf('%s\n', report.messages{:});
end
```

## Further Reading

- [BCT I/O Operations](io.md)
- [API Overview](../matlab/overview.md)
