# MEG-GSP Toolbox for MATLAB

A production-ready MATLAB toolbox that applies Graph Signal Processing (GSP) and Time-Vertex Signal Processing (TVSP) to Brainstorm source-mapped MEG data.

## Overview

This toolbox provides comprehensive tools for analyzing MEG data using graph signal processing techniques on cortical surfaces. It implements joint time-vertex analysis, dynamic graph wavelets, and various filtering approaches based on the mathematical framework from Grassi et al.

## Features

- **Brainstorm Integration**: Import cortical surfaces, source time series, and imaging kernels
- **Graph Construction**: Build cortical graphs with geodesic and cotangent weighting
- **Differential Operators**: Graph gradient, divergence, and total variation operators
- **Joint Transforms**: GFT, JFT, STVFT, and STVWT following TVSP framework
- **Advanced Filtering**: Separable and non-separable joint filters with FFC algorithm
- **Dynamic Graph Wavelets**: Heat, wave, and causal damped kernels for propagation analysis
- **Visualization**: High-quality 3D mesh plotting and time-series animation

## Installation

1. Clone this repository:
   ```bash
   git clone --recursive <repository-url>
   cd meg-gsp-toolbox
   ```

2. Initialize GSPBOX submodule:
   ```bash
   git submodule update --init --recursive
   ```

3. Run the setup script in MATLAB:
   ```matlab
   cd('meg-gsp-toolbox')
   run scripts/setup.m
   ```

## Quick Start

Run the demo scripts to see the toolbox in action:

```matlab
% Alpha-band source analysis
run scripts/demo_alphaband_analysis.m

% Joint filtering comparison
run scripts/demo_joint_filtering.m

% Dynamic graph wavelet propagation analysis
run scripts/demo_dgw_propagation.m
```

## API Documentation

### Core Modules

- **`+meg_gsp/io`**: Brainstorm import/export functions
- **`+meg_gsp/graph`**: Graph construction and Laplacian computation
- **`+meg_gsp/ops`**: Differential operators (gradient, divergence, TV)
- **`+meg_gsp/transforms`**: Spectral transforms (GFT, JFT, STVFT, STVWT)
- **`+meg_gsp/filters`**: Joint filtering with separable/non-separable modes
- **`+meg_gsp/dgw`**: Dynamic graph wavelets and sparse coding
- **`+meg_gsp/viz`**: Visualization utilities for cortical data

### Mathematical Framework

The toolbox implements the joint time-vertex framework with:
- Joint Laplacian: `LJ = LT ⊗ I + I ⊗ LG`
- Joint Fourier Transform: `X̂ = U_G^T X U_T`
- Fast Fourier-Chebyshev (FFC) filtering for efficiency
- Stability conditions for wave kernels: `s < 4/λmax`

## Dependencies

- MATLAB R2022b+ (Signal Processing Toolbox recommended)
- GSPBOX (included as submodule)
- Optional: UNLocBoX for sparse solvers

## Citation

If you use this toolbox in your research, please cite:

```
@misc{meg_gsp_toolbox,
  title={MEG-GSP Toolbox: Graph Signal Processing for MEG Source Analysis},
  author={Your Name},
  year={2025},
  url={https://github.com/yourusername/meg-gsp-toolbox}
}
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.

## References

- Grassi, F., et al. "A Time-Vertex Signal Processing Framework"
- Perraudin, N., et al. "GSPBOX: A toolbox for signal processing on graphs"
- Brainstorm documentation: https://neuroimage.usc.edu/brainstorm/