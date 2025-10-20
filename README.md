# bioctree

Bioctree provides tools for spatiotemporal signal processing and compression of electrophysiological signals defined on networks (graphs). The project focuses on graph-based representations, multiscale subdivision and block-compression methods for efficient storage and analysis of time-varying signals measured on networked sensors or neural meshes.

## Key features
- Graph-aware compression and multiscale subdivision routines (see [`compressX`](compression/compressX.m) and [`subdivideBlock`](compression/subdivideBlock.m)).
- Utilities and IO hooks for dataset handling in [io/](io/).
- Visualization helpers in [plotlib/](plotlib/) and example figures in [figures/](figures/).
- Example data and test inputs in [test-data/](test-data/).
- Workflow automation and reproducible scripts in [workflows/](workflows/).

## Repository layout
- [compression/](compression/) — core compression and subdivision algorithms (e.g. [`compressX`](compression/compressX.m), [`subdivideBlock`](compression/subdivideBlock.m)).
- [gspbox/](gspbox/) — graph signal processing utilities used by the codebase - from https://epfl-lts2.github.io/gspbox-html/
- [io/](io/) — data loading/saving utilities.
- [plotlib/](plotlib/) — plotting and visualization helpers.
- [figures/](figures/) — precomputed figures and animations (e.g. [figures/ripple_animation.mp4](figures/ripple_animation.mp4)).
- [test-data/](test-data/) — small datasets for testing and examples.
- [workflows/](workflows/) — scripts and pipelines for common experiments.

## Quick start (MATLAB)
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
