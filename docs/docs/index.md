# Welcome to Bioctree

**Spatiotemporal–Spectral Signal Processing on Cortical Manifolds**

A comprehensive MATLAB toolbox for analyzing neural signals on brain surface meshes using graph signal processing and spectral geometry.

---

## :material-rocket-launch: Core Features

<div class="grid cards" markdown>

-   :material-waves:{ .lg .middle } **Wave Packet Analysis**

    ---

    Detect and characterize traveling waves on cortical surfaces with precise spatiotemporal-spectral localization.

    [:octicons-arrow-right-24: Learn about wave packets](concepts/wave-packets.md)

-   :material-sine-wave:{ .lg .middle } **Spectral Filtering**

    ---

    Design and apply filters in eigenspace with guaranteed spatial localization properties using Laplace–Beltrami operators.

    [:octicons-arrow-right-24: Explore filters](filters/spatial.md)

-   :material-chart-timeline:{ .lg .middle } **Joint Domain Processing**

    ---

    Unified framework for signals on product spaces: spatial × temporal, spatial × spectral, and beyond.

    [:octicons-arrow-right-24: Joint domains](concepts/joint-spectrum.md)

-   :material-brain:{ .lg .middle } **Manifold-Based Analysis**

    ---

    Finite element methods (FEM) and differential geometry for cortical mesh processing.

    [:octicons-arrow-right-24: Manifold concepts](concepts/manifolds.md)

-   :material-database:{ .lg .middle } **HDF5-Based Storage**

    ---

    Efficient `.bct` file format for storing mesh data, eigenbases, signals, and comprehensive metadata.

    [:octicons-arrow-right-24: File format spec](api/hdf5/specification.md)

-   :material-graph:{ .lg .middle } **Graph Signal Processing**

    ---

    Leverage GSP tools and techniques adapted for cortical surface analysis with spectral graph theory.

    [:octicons-arrow-right-24: Graph structure](concepts/graph-structure.md)

</div>

---

## :material-lightning-bolt: Quick Start

Get up and running in minutes with Bioctree:

```matlab
% Load a cortical mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

% Compute Laplace–Beltrami eigenbasis
B = B.computeEigenbasis(256);

% Create a signal and filter it
signal = B.createSignal(data);
filtered = signal.lowpass(cutoff_freq);
```

[:material-book-open-page-variant: Full Quickstart Guide](getting-started/quickstart.md){ .md-button .md-button--primary }

---

## :material-telescope: What Makes Bioctree Unique?

### :material-chart-scatter-plot: Neural Signal Processing Meets Differential Geometry

Bioctree bridges computational neuroscience and differential geometry by providing:

- **Laplace–Beltrami eigenbasis** computation for arbitrary cortical meshes
- **Wave packet transforms** with joint time-frequency-space localization
- **Dispersion analysis** for characterizing wave propagation dynamics
- **Spatiotemporal filtering** using tensor product operators

---

## :material-code-braces: Example: Detecting Traveling Waves

Identify and characterize neural traveling waves on cortical surfaces:

```matlab
% Detect wave packets in spatiotemporal data
params = struct(...
    'f_min', 8, ...
    'f_max', 12, ...
    'detection_threshold', 2.5 ...
);

[detections, wt_coeffs] = bct.sim.detectWavePackets(signal, params);

% Visualize wave trajectories on the cortical mesh
bct.show.waveTrajectories(detections, B.manifold);
```

[:material-play-circle: More Examples](examples/index.md){ .md-button }

---

## :material-book-education: Learning Paths

<div class="grid cards" markdown>

-   :material-school:{ .lg .middle } **New to Bioctree?**

    ---

    Start with our comprehensive introduction covering core concepts and architecture.

    [:octicons-arrow-right-24: Introduction](getting-started/introduction.md)

-   :material-cog:{ .lg .middle } **Ready to Install?**

    ---

    Get Bioctree set up with MATLAB and required dependencies.

    [:octicons-arrow-right-24: Installation Guide](getting-started/installation.md)

-   :material-flask:{ .lg .middle } **Learn by Example**

    ---

    Follow hands-on tutorials covering common analysis workflows.

    [:octicons-arrow-right-24: Tutorials](tutorials/load-mesh.md)

-   :material-api:{ .lg .middle } **API Reference**

    ---

    Detailed documentation of all classes, methods, and functions.

    [:octicons-arrow-right-24: API Docs](api/matlab/overview.md)

</div>

---

## :material-frequently-asked-questions: Key Concepts

Understanding these foundational concepts will help you make the most of Bioctree:

| Concept | Description |
|---------|-------------|
| **Manifold** | The cortical surface mesh representing spatial domain |
| **Lambda (Λ)** | Spectral domain dual to the manifold via Laplace–Beltrami eigenbasis |
| **Joint Domain** | Tensor product of two domains (e.g., Time × Lambda) |
| **Wave Packet** | Spatiotemporally localized oscillatory pattern |
| **Dispersion** | Relationship between frequency and spatial wavelength |

[:material-library: Full Concept Guide](concepts/overview.md){ .md-button }

---

## :material-github: Open Source

Bioctree is open-source software released under the MIT License.

[:fontawesome-brands-github: View on GitHub](https://github.com/DiellorBasha/bioctree){ .md-button .md-button--primary }
[:material-file-document: Read the Docs](getting-started/introduction.md){ .md-button }
[:material-help-circle: Get Support](about/contributing.md){ .md-button }

---

## :material-bookshelf: Citation

If you use Bioctree in your research, please cite:

```bibtex
@software{bioctree2025,
  author = {Basha, Diellor},
  title = {Bioctree: Spatiotemporal-Spectral Signal Processing for Cortical Manifolds},
  year = {2025},
  url = {https://github.com/DiellorBasha/bioctree}
}
```

---

*Built with :material-heart: for computational neuroscience and graph signal processing*
