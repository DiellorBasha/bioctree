# Experimental Code

This directory contains experimental, legacy, and prototype code that is not part of the core `+bct` package.

## Directory Structure

### toolbox_legacy/

Legacy code from the original `toolbox/` directory before the package reorganization. This includes:

- **Apps**: `BctFilterDesigner.mlapp`, `BctFilterDesignerCode.m`
- **Standalone Functions**: `bct_cot_fourier.m`, `bct_cot_fourier_pde_matlab.m`, `surfaceMeshShowInParent.m`
- **Build Scripts**: `makebct.m`, `makebct2.m`
- **Data**: `data/`, `bct_schema_scale.json`
- **Utilities**: Various subdirectories with helper functions and experimental features
  - `detections/` - Detection algorithms
  - `differential/` - Differential operators
  - `filters/` - Legacy filter implementations (separate from `+bct.filters`)
  - `frequency/` - Frequency domain utilities
  - `graphs/` - Graph processing utilities
  - `jtv/` - Joint time-vertex processing
  - `operators/` - Matrix operators
  - `ops/` - Operations
  - `preprocess/` - Preprocessing utilities
  - `reports/` - Reporting tools
  - `simulations/` - Simulation utilities
  - `transforms/` - Transform utilities
  - `utils/` - General utilities

## Purpose

The main `toolbox/` directory now contains **ONLY** the `+bct` package, which is the production-ready, well-maintained core of the bioctree library. All experimental, prototype, and legacy code has been moved here to:

1. **Keep the package clean**: The `+bct` package follows MATLAB conventions and is easier to distribute
2. **Preserve experimental work**: Nothing is deleted, but it's clearly separated from production code
3. **Enable easier navigation**: Developers can focus on `+bct` for the main API
4. **Support research**: Experimental code remains available for reference and prototyping

## Usage

Code in this directory is:
- **Not maintained** as part of the core package
- **May be outdated** or incompatible with current `+bct` API
- **Available for reference** and experimentation
- **Subject to reorganization** or removal

To use experimental code, add the appropriate subdirectories to your MATLAB path manually.

## Future Organization

This directory may be further organized into:
- `prototypes/` - Experimental new features
- `deprecated/` - Removed functionality
- `research/` - Research code and paper reproductions
- `old_tests/` - Legacy test scripts
- `scratch_scripts/` - One-off analysis scripts
