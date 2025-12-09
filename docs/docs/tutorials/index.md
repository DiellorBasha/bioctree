# Tutorials

Step-by-step tutorials to help you get started with Bioctree and master common workflows.

## Overview

These hands-on tutorials will guide you through the essential operations in Bioctree, from loading data to advanced signal processing techniques.

## Getting Started Tutorials

### [Load a Mesh](load-mesh.md)
Learn how to load cortical surface meshes from different formats (FreeSurfer, BrainStorm) and initialize the Bioctree system.

**You'll learn:**
- Loading `.mat` files with vertices and faces
- Creating a `bct` object from mesh data
- Inspecting mesh properties
- Basic mesh visualization

### [Compute Eigenbasis](eigenbasis.md)
Calculate the Laplace-Beltrami eigenbasis for spectral analysis.

**You'll learn:**
- Computing eigenvalues and eigenvectors
- Choosing the number of eigenmodes
- Understanding spectral content
- Visualizing eigenmodes

## Signal Processing Tutorials

### [Apply Spatial Filters](spatial-filters.md)
Design and apply filters in the spatial/spectral domain.

**You'll learn:**
- Creating spatial filters
- Low-pass, high-pass, and band-pass filtering
- Understanding filter localization
- Comparing filter kernels

### [Build a Wave Packet](wavepacket.md)
Construct wave packets with spatiotemporal-spectral localization.

**You'll learn:**
- Wave packet fundamentals
- Setting temporal and spatial frequencies
- Controlling localization properties
- Analyzing dispersion

### [Detect Traveling Waves](detect-waves.md)
Identify and characterize traveling waves in spatiotemporal data.

**You'll learn:**
- Loading spatiotemporal signal data
- Running wave packet detection
- Interpreting detection results
- Visualizing wave trajectories

---

## Tutorial Path Recommendations

### **For Beginners**
1. [Load a Mesh](load-mesh.md)
2. [Compute Eigenbasis](eigenbasis.md)
3. [Apply Spatial Filters](spatial-filters.md)

### **For Wave Analysis**
1. [Compute Eigenbasis](eigenbasis.md)
2. [Build a Wave Packet](wavepacket.md)
3. [Detect Traveling Waves](detect-waves.md)

### **For Advanced Users**
- Combine multiple tutorials
- Explore [Examples](../examples/index.md) for complete workflows
- Reference [API Documentation](../api/matlab/overview.md) for details

## Prerequisites

Before starting these tutorials, make sure you have:

- ✅ [Installed Bioctree](../getting-started/installation.md)
- ✅ MATLAB R2020a or later
- ✅ Sample mesh data (included in `data/mesh/`)
- ✅ Basic MATLAB knowledge

## Need Help?

- **Concepts unclear?** Review [Concepts](../concepts/index.md)
- **API questions?** Check [API Reference](../api/matlab/overview.md)
- **Found an issue?** Visit our [GitHub repository](https://github.com/DiellorBasha/bioctree)
