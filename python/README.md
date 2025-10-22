# Bioctree Python - Graph Signal Processing for Neuroscience

A Python implementation of graph signal processing tools for analyzing brain signals on cortical surfaces and other graph structures. This package provides Python equivalents to the MATLAB Bioctree toolbox, leveraging PyGSP and modern Python scientific computing libraries.

## Features

- **Graph Signal Processing**: Complete GSP pipeline including gradient, divergence, total variation, and Fourier transforms
- **Interactive Visualizations**: Modern plotting with matplotlib and plotly for exploring GSP concepts
- **Stanford Bunny Demos**: Python equivalents of MATLAB demonstration scripts
- **MEG/EEG Support**: Data loading and preprocessing for neuroimaging data
- **Cortical Surface Analysis**: Tools for analyzing signals on brain surface meshes

## Installation

### Prerequisites

Python 3.8+ and the following core dependencies:
- numpy >= 1.20.0
- scipy >= 1.7.0
- matplotlib >= 3.3.0
- networkx >= 2.5
- scikit-learn >= 1.0.0

### Install from source

1. Clone the repository:
```bash
git clone https://github.com/DiellorBasha/bioctree.git
cd bioctree/python
```

2. Install in development mode:
```bash
pip install -e .
```

3. Install with full dependencies (including PyGSP and Plotly):
```bash
pip install -e .[full]
```

4. For Jupyter notebook support:
```bash
pip install -e .[full,jupyter]
```

## Quick Start

### Basic Graph Signal Processing

```python
import numpy as np
from bioctree_py.gsp import graphs, ops
from bioctree_py.visualization import plot_graph

# Create a graph
W, coords = graphs.stanford_bunny(n_vertices=300)

# Create a signal
signal = np.random.randn(300)

# Compute graph operations
grad = ops.graph_gradient(W, signal)
tv = ops.graph_total_variation(W, signal)
L = ops.graph_laplacian(W)

# Visualize
plot_graph(W, coords, signal=signal, title="Signal on Stanford Bunny")
```

### Run Complete Demo

```python
from bioctree_py.demos import demo_bunny_pipeline

# Run the complete pipeline demo
results = demo_bunny_pipeline.run_demo()
```

Or from command line:
```bash
bioctree-demo --vertices 300 --save-plots
```

### Load MEG Data

```python
from bioctree_py.io import load_meg_test_data, downsample_signal

# Load MEG data
meg_data, info = load_meg_test_data('path/to/data.mat')

# Downsample for analysis
downsampled, indices = downsample_signal(meg_data, info['sampling_freq'], 64.0)
```

## Module Structure

```
bioctree_py/
├── __init__.py           # Main package interface
├── gsp/                  # Graph signal processing core
│   ├── ops.py           # Operations (gradient, TV, GFT)
│   └── graphs.py        # Graph construction utilities
├── demos/                # Demonstration scripts
│   └── demo_bunny_pipeline.py
├── visualization/        # Interactive plotting tools
│   └── __init__.py
└── io/                   # Data I/O utilities
    └── __init__.py
```

## Examples

### Graph Construction

```python
from bioctree_py.gsp import graphs

# Stanford bunny graph
W, coords = graphs.stanford_bunny(n_vertices=300)

# Random geometric graph
W, coords = graphs.random_geometric_graph(n_vertices=100, radius=0.3)

# Grid graph
W, coords = graphs.grid_graph(height=10, width=10)

# From cortical surface
W = graphs.cortical_surface_graph(vertices, faces)
```

### Signal Analysis

```python
from bioctree_py.gsp import ops

# Graph gradient
gradient = ops.graph_gradient(W, signal)

# Total variation (smoothness measure)
tv = ops.graph_total_variation(W, signal, p=1)

# Graph Fourier Transform
L = ops.graph_laplacian(W, normalized=True)
gft_coeffs, eigenvalues = ops.graph_fourier_transform(L, signal)
```

### Visualization

```python
from bioctree_py.visualization import (
    plot_graph, 
    plot_signal_spectrum, 
    plot_total_variation_evolution
)

# Interactive graph plot
plot_graph(W, coords, signal=signal, interactive=True)

# Signal spectrum
plot_signal_spectrum(eigenvalues, gft_coeffs)

# Time evolution
plot_total_variation_evolution(tv_time_series)
```

## Comparison with MATLAB Version

| Feature | MATLAB | Python |
|---------|--------|--------|
| Graph construction | GSPBOX | PyGSP + custom |
| Visualizations | Static plots | Interactive (Plotly) |
| Data formats | .mat files | .mat, .npz, HDF5 |
| Dependencies | MATLAB + toolboxes | Pure Python ecosystem |
| Performance | Compiled MATLAB | NumPy/SciPy optimized |

## Dependencies

### Core (required)
- **numpy**: Numerical computing foundation
- **scipy**: Scientific computing and sparse matrices
- **matplotlib**: Basic plotting capabilities
- **networkx**: Graph analysis and algorithms
- **scikit-learn**: Machine learning utilities

### Extended (optional)
- **pygsp**: Graph Signal Processing library
- **plotly**: Interactive visualizations
- **h5py**: HDF5 file format support
- **seaborn**: Statistical plotting
- **jupyter**: Notebook interface

## Development

### Running Tests
```bash
pip install -e .[dev]
pytest
```

### Code Formatting
```bash
black bioctree_py/
flake8 bioctree_py/
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`pytest`)
6. Format code (`black` and `flake8`)
7. Commit changes (`git commit -m 'Add amazing feature'`)
8. Push to branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Citation

If you use this software in your research, please cite:

```bibtex
@software{bioctree_python,
  title = {Bioctree Python: Graph Signal Processing for Neuroscience},
  author = {Bioctree Development Team},
  url = {https://github.com/DiellorBasha/bioctree},
  year = {2025}
}
```

## Related Projects

- [PyGSP](https://github.com/epfl-lts2/pygsp): Core graph signal processing library
- [GSPBOX](https://github.com/epfl-lts2/gspbox): Original MATLAB implementation
- [Brainstorm](https://neuroimage.usc.edu/brainstorm/): MEG/EEG analysis software

## Support

- **Documentation**: See individual module docstrings and examples
- **Issues**: Report bugs and feature requests on GitHub
- **Discussions**: Use GitHub Discussions for questions and community support