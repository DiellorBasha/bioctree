# Bioctree Data Engine

This directory contains the HDF5 data storage system for Bioctree analysis results.

## Directory Structure

```
data/
├── README.md                    # This file
├── bioctree_files/             # Primary Bioctree HDF5 files (.bct)
│   ├── raw/                    # Raw analysis results
│   ├── processed/              # Processed/filtered results
│   └── derivatives/            # Derived analysis products
├── temp/                       # Temporary files during processing
├── cache/                      # Cached computations for performance
└── config/                     # Configuration files
```

## File Naming Convention

Bioctree files use the `.h5` extension (HDF5 format) and follow this naming pattern:
```
{subject_id}_{session}_{analysis_type}_{timestamp}.h5
```

Examples:
- `sub01_ses001_wavelet_20251021_143052.h5`
- `groupAvg_allSessions_connectivity_20251021_150312.h5`
- `patient23_preOp_restingState_20251021_162145.h5`

## Data Organization

### Primary Files (`bioctree_files/`)
- **Raw**: Direct outputs from Bioctree analysis pipelines (`.h5` files)
- **Processed**: Quality-controlled, filtered, or normalized data (`.h5` files)
- **Derivatives**: Higher-level analysis results (connectivity, statistics, etc.) (`.h5` files)

### Temporary Files (`temp/`)
- Intermediate processing files
- Automatically cleaned up after analysis completion
- Not version controlled

### Cache (`cache/`)
- Precomputed eigendecompositions
- Frequent query results
- Performance optimization data

## Usage

Use the Bioctree data management functions:

```matlab
% Configure data paths
bioctree_config('DataPath', '/custom/data/location');

# Save analysis results
outbct('subject01_analysis.h5', analysisData);

# Load with querying
data = inbct('subject01_analysis.h5', 'FreqBands', {'alpha'});

% Get data directory info
info = bioctree_data_info();
```

## File Management

- **Automatic cleanup**: Temporary files older than 24 hours are automatically removed
- **Compression**: All `.h5` files use HDF5 compression for efficient storage
- **Indexing**: Metadata indices are maintained for fast querying
- **Backup**: Consider regular backups of `bioctree_files/` directory

## System Requirements

- **Disk Space**: ~100MB per subject session (typical)
- **I/O Performance**: SSD recommended for optimal query performance
- **Memory**: 8GB+ RAM recommended for large datasets
- **MATLAB**: R2018b+ with HDF5 support

## Notes

- This directory can be relocated anywhere on the filesystem
- Update `bioctree_config.m` if moving to a different location
- For production use, consider network storage or dedicated data server
- All paths are configurable and system-independent