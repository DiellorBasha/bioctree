# Database Module (/db)

This module contains all database and metadata handling functions for the Bioctree system. These functions manage BCT dataset interactions, data conversion operations, and system information retrieval.

## Functions

### Core Data Management
- **`db_data_info.m`** - Get comprehensive information about Bioctree data files and storage
- **`db_convert_data.m`** - Batch convert legacy .bct files to HDF5 format

### BCT Structure Management  
- **`db_create_bct_structure.m`** - Create BCT file structure from JSON configuration
- **`db_load_bct_config.m`** - Load BCT structure configuration from JSON files
- **`db_create_test_bct.m`** - Generate standard test BCT file for bioctree development
- **`db_load_test_bct.m`** - Load standard test BCT file with automatic creation if missing

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

### BCT Structure Operations
```matlab
% Load default BCT structure configuration
config = db_load_bct_config();

% Create BCT file structure from configuration  
success = db_create_bct_structure('data.bct', config);

% Generate standard test BCT file
success = db_create_test_bct();  % Creates test_bioctree_standard.bct

% Load standard test data (creates if missing)
data = db_load_test_bct();  % Returns structure with graph, signal, etc.
```

## Design Principles

All functions in this module follow the `db_` prefix convention and focus on:
- **Metadata Management**: Tracking data system state and statistics
- **BCT Operations**: Creating, configuring, and validating BCT structures  
- **Data Conversion**: Migrating between data formats
- **System Monitoring**: Providing status information and cleanup utilities

## Standard Test Dataset

The `db_create_test_bct()` function generates the canonical test BCT file used throughout bioctree:

- **File**: `test_bioctree_standard.bct` (in data directory)
- **Graph**: Icosphere (level 3, ~642 vertices) 
- **Signals**: 10 patch layers with sizes from 5% to 85%
- **Temporal**: 100 time steps per layer (1000 total)
- **Purpose**: Standard dataset for testing, demos, and development

This file should be referenced in all bioctree functions that need test data.

## Dependencies

- MATLAB HDF5 support
- JSON configuration files in `/config` directory
- Bioctree data directory structure