# bioctree

Bioctree provides tools for spatiotemporal signal processing and compression of electrophysiological signals defined on networks (graphs). The project focuses on graph-based representations, multiscale subdivision and block-compression methods for efficient storage and analysis of time-varying signals measured on networked sensors or neural meshes.

**Now available in both MATLAB and Python!**

## Key features
- **Dual implementation**: Complete functionality in both MATLAB and Python
- **Interactive visualization**: Modern plotting with matplotlib and plotly (Python)
- Graph-aware compression and multiscale subdivision routines (see [`compressX`](compression/compressX.m) and [`subdivideBlock`](compression/subdivideBlock.m)).
- Utilities and IO hooks for dataset handling in [io/](io/).
- Visualization helpers in [plotlib/](plotlib/) and example figures in [figures/](figures/).
- Example data and test inputs in [test-data/](test-data/).
- Workflow automation and reproducible scripts in [workflows/](workflows/).

## Repository layout
- **[python/](python/)** — **NEW: Complete Python implementation with PyGSP integration**
- [compression/](compression/) — core compression and subdivision algorithms (e.g. [`compressX`](compression/compressX.m), [`subdivideBlock`](compression/subdivideBlock.m)).
- [gsp/](gsp/) — graph signal processing utilities and operations
- [io/](io/) — data loading/saving utilities.
- [plotlib/](plotlib/) — plotting and visualization helpers.
- [test-data/](test-data/) — datasets for testing and examples including MEG data.
- [workflows/](workflows/) — scripts and pipelines for common experiments and demos.

## Quick start

### MATLAB
1. Install GSPBOX (Graph Signal Processing Toolbox):
   ```matlab
   % Download and add to path
   addpath(genpath('path/to/gspbox'))
   ```

2. Run the main entry point:
   ```matlab
   bioctree_start  % Initialize environment
   ```

3. Try the demos:
   ```matlab
   cd workflows/demo
   demo_bunny_baseline     % Basic Stanford bunny graph demo
   demo_bunny_grad_descent % Gradient descent filtering demo  
   demo_bunny_laplacian    % Laplacian-based filtering demo
   ```

### Python
1. Install the package and dependencies:
   ```bash
   # From bioctree root directory
   cd python
   pip install -r requirements.txt
   pip install -e .  # Install bioctree_py in development mode
   ```

2. Quick test:
   ```python
   from bioctree_py.demos import demo_bunny_pipeline
   demo_bunny_pipeline.run_demo()
   ```

3. Interactive graph signal processing:
   ```python
   from bioctree_py.gsp import stanford_bunny, graph_gradient
   import numpy as np
   
   # Create Stanford bunny graph
   G = stanford_bunny()
   
   # Generate test signal
   signal = np.random.randn(G.N)
   
   # Compute spatial derivative
   grad = graph_gradient(G, signal)
   print(f"Graph: {G.N} vertices, Gradient norm: {np.linalg.norm(grad):.3f}")
   ```

## Features by platform

| Feature | MATLAB | Python |
|---------|--------|--------|
| Graph signal processing | ✅ GSPBOX | ✅ NetworkX + PyGSP |
| Stanford bunny demos | ✅ | ✅ |
| Interactive visualization | ⚠️ Limited | ✅ matplotlib + plotly |
| MEG data processing | ✅ | ✅ |
| Compression algorithms | ✅ | 🚧 Coming soon |
| Wave detection | ✅ | 🚧 Coming soon |

For detailed Python features and installation, see [python/PYTHON_INTEGRATION_SUMMARY.md](python/PYTHON_INTEGRATION_SUMMARY.md)
1. Open MATLAB and add the project to your path:
   - `addpath(genpath('c:\CodingProjects\bioctree'))`
2. Run a basic compression call:
   - `result = compressX(data, G, options);`
   - See [`compression/compressX.m`](compression/compressX.m) for input/option details.
3. Visualize results using helpers in [plotlib/](plotlib/) and sample outputs in [figures/](figures/).

## Usage notes
- The codebase assumes signals are defined on graph nodes; graphs and signal matrices should follow the shapes expected by functions in [`gspbox`](gspbox/).
- Compression pipelines often use multiscale subdivision. Inspect [`subdivideBlock`](compression/subdivideBlock.m) to understand block partitioning strategies.

## Reproducible examples
- Example workflows and scripts are in [workflows/](workflows/). Use the corresponding inputs from [test-data/](test-data/) to reproduce experiments and figures from [figures/](figures/).

## Contributing
- To add features or fixes, open a pull request with tests or example scripts under [workflows/](workflows/) and small datasets under [test-data/](test-data/).
- Follow existing coding style in MATLAB files under [compression/](compression/) and helper modules in [io/](io/) and [plotlib/](plotlib/).

## License
See project root for license information.
