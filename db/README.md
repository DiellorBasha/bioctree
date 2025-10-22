# Database Module (/db)

This module contains all database and metadata handling functions for the Bioctree system. These functions manage HDF5 dataset interactions, data conversion operations, and system information retrieval.

## Functions

### Core Data Management
- **`db_data_info.m`** - Get comprehensive information about Bioctree data files and storage
- **`db_convert_data.m`** - Batch convert legacy .bct files to HDF5 format

### HDF5 Structure Management  
- **`db_create_hdf5_structure.m`** - Create HDF5 file structure from JSON configuration
- **`db_load_hdf5_config.m`** - Load HDF5 structure configuration from JSON files

## Usage Examples

### System Information
```matlab
% Get complete data system information
info = db_data_info();

% Get summary only  
summary = db_data_info('summary');

% Cleanup temporary files
db_data_info('cleanup');
```

### Data Conversion
```matlab  
% Convert all .bct files in data system
result = db_convert_data();

% Dry run to see what would be converted
result = db_convert_data('DryRun', true);
```

### HDF5 Structure Operations
```matlab
% Load default HDF5 structure configuration
config = db_load_hdf5_config();

% Create HDF5 file structure from configuration  
success = db_create_hdf5_structure('data.h5', config);
```

## Design Principles

All functions in this module follow the `db_` prefix convention and focus on:
- **Metadata Management**: Tracking data system state and statistics
- **HDF5 Operations**: Creating, configuring, and validating HDF5 structures  
- **Data Conversion**: Migrating between data formats
- **System Monitoring**: Providing status information and cleanup utilities

## Dependencies

- MATLAB HDF5 support
- JSON configuration files in `/config` directory
- Bioctree data directory structure