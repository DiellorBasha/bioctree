# Database Module (/db)

This module contains database and system management functions for the Bioctree system. Most BCT data operations are now handled by the modern BCT class system.

## Functions

### ✅ Active Functions
- **`db_data_info.m`** - Get comprehensive information about Bioctree data files and storage

### ⚠️ Deprecated Functions (Use BCT Class Instead)
- **`db_create_bct_structure.m`** - ❌ **DEPRECATED** → Use `bct.create()` 
- **`db_load_bct_config.m`** - ❌ **DEPRECATED** → BCT class handles schema automatically
- **`db_create_test_bct.m`** - ❌ **DEPRECATED** → Use BCT class with `write_*()` methods
- **`db_load_test_bct.m`** - ❌ **DEPRECATED** → Use `bct.open()` with `read_*()` methods

## Usage Examples

### ✅ Current System Information (Recommended)
```matlab
% Get complete data system information
info = db_data_info();

% Get summary only  
summary = db_data_info('summary');

% Cleanup temporary files
db_data_info('cleanup');
```

### 🔄 Modern BCT Class Usage (Recommended)
```matlab
% Create new BCT file with schema validation
obj = bct.create('my_dataset');

% Write data using BCT class methods
obj.write_raw(signal_matrix, sampling_rate);
obj.write_graph(graph_structure);

% Read data using BCT class methods  
obj = bct.open('dataset.h5');
data = obj.read_raw([1, 100], [1, 50]);  % Time and node ranges
```

### ⚠️ Deprecated Functions (Legacy - Avoid Using)
```matlab
% These functions are deprecated and will be removed:
% config = db_load_bct_config();           % Use BCT class schema instead
% success = db_create_bct_structure(...);  % Use bct.create() instead
% success = db_create_test_bct();          % Use BCT class methods instead
% data = db_load_test_bct();               % Use bct.open() instead
```

## Design Principles

The remaining active functions focus on:
- **System Monitoring**: Tracking data system state, statistics, and cleanup
- **Legacy Support**: Maintaining compatibility during BCT class migration

**Note**: Most BCT data operations are now handled by the modern BCT class system which provides:
- Schema validation and enforcement
- Multi-layer signal support  
- Efficient hyperslab reading
- Time-frequency analysis capabilities
- Automatic path management

## Migration to BCT Class System

The database module has been streamlined. Most functions are deprecated in favor of the BCT class:

### Old Pattern (Deprecated)
```matlab
success = db_create_test_bct();
data = db_load_test_bct();
```

### New Pattern (Recommended)  
```matlab
obj = bct.create('test_dataset');
obj.write_raw(signal_data, fs);
obj.write_graph(graph_data);

obj = bct.open('test_dataset.h5'); 
data = obj.read_raw();
```

## Dependencies

### Active Functions
- MATLAB HDF5 support for `db_data_info.m`
- Bioctree configuration system (`bioctree_config`)

### Deprecated Functions  
- Still require MATLAB HDF5 support and legacy I/O functions (outbct/inbct)
- **Migration Path**: Use BCT class system which handles dependencies automatically