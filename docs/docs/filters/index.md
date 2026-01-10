# Filters

Filter design and application is central to signal processing in Bioctree. This section covers spatial, temporal, and joint-domain filtering approaches.

## Overview

Bioctree provides a comprehensive filtering framework that operates on multiple domains:

- **Spatial domain** (on the manifold)
- **Spectral domain** (in eigenspace λ)
- **Temporal domain** (along time axis)
- **Frequency domain** (ω)
- **Joint domains** (combinations of the above)

## Filter Types

### [Spatial Filters](spatial.md)
Filters operating on the cortical mesh in the spatial or spectral (λ) domain.

**Key concepts:**
- Low-pass, high-pass, and band-pass filters in eigenspace
- Heat kernel and diffusion-based filters
- Spatial localization properties
- Chebyshev polynomial approximations

### [Temporal Filters](temporal.md)
Filters operating along the time axis or in frequency (ω) domain.

**Key concepts:**
- Standard temporal filtering (FIR, IIR)
- Frequency-domain filtering via FFT
- Time-frequency trade-offs
- Window functions and tapering

### [Joint Filters (λ–ω)](joint-filters.md)
Filters operating on tensor product spaces combining spatial and temporal/frequency domains.

**Key concepts:**
- Spatiotemporal filtering
- Time-varying spatial filters
- Separable vs. non-separable kernels
- Computational efficiency

### [Wave Packet Filters](wavepacket-filters.md)
Specialized filters for wave packet analysis with joint time-frequency-space localization.

**Key concepts:**
- Gabor-like filters on manifolds
- Dispersion-aware filtering
- Velocity-tuned kernels
- Wave propagation analysis

---

## Design Workflow

1. **Choose your domain**: Spatial (Manifold/Lambda), Temporal (Time/Omega), or Joint
2. **Define kernel**: Select fundamental kernel type (gaussian, heat, etc.)
3. **Set parameters**: Cutoff frequencies, bandwidths, centers
4. **Apply filter**: Use `Filter.apply()` on your signals
5. **Visualize results**: Use `bct.show` functions to inspect filtered signals

## Next Steps

- **Learn the theory**: Read [Concepts](../concepts/index.md) for mathematical foundations
- **See examples**: Check [Examples](../examples/index.md) for complete workflows
- **Try tutorials**: Follow [Tutorials](../tutorials/index.md) for hands-on practice
