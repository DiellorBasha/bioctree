# Kernel System Architecture

## Overview

The `bct.kernel` package provides a comprehensive system for spectral filtering, basis functions, and kernel operations on manifolds. It distinguishes between **analytic kernels** (closed-form) and **operator-defined generators** (computed bases).

## System Components

### 1. `bct.kernel.dictionary()` - Analytic Kernels

Pure function handles with closed-form mathematical expressions.

**Categories:**
- **Basic Smoothing**: Heat, Gaussian, Laplacian, Cauchy
- **Wavelets**: Ricker, SpectralMexicanHat, Morlet, Gabor
- **Orthogonal Bases**: **Hermite** (quantum harmonic oscillator)
- **Spectral Filters**: **MeyerHat** (frequency-domain)
- **Band-pass**: DoG, Boxcar, Triangle, RaisedCosine
- **Windows**: Hann, Hamming, Tukey
- **Impulses**: Delta, Indicator, Constant
- **Nonlinearities**: ReLU, Sigmoid, Tanh, Softplus
- **Distance**: InverseDistance, GaussianDistance
- **Oscillatory**: Sine, Cosine, ComplexExp
- **Normalization**: ZScore, MinMax, UnitNorm
- **Probability**: NormalPDF, LogNormalPDF, GammaPDF
- **Noise**: WhiteNoise, UniformNoise, PinkNoise

**Usage:**
```matlab
D = bct.kernel.dictionary();
gaussian = D("Gaussian");
y = gaussian(x, mu, sigma);
```

### 2. `bct.kernel.generators()` - Operator-Defined Bases

Factory functions for discrete or operator-defined bases without closed forms.

**Categories:**
- **Discrete Wavelets**: **Daubechies**, Symlet, Coiflet, Biorthogonal
- **Optimal Concentration**: **Slepian** (DPSS - Discrete Prolate Spheroidal Sequences)
- **Time-Domain**: MeyerTime, Haar
- **Multitaper**: Multitaper (for spectral estimation)

**Usage:**
```matlab
G = bct.kernel.generators();

% Daubechies wavelet
dbGen = G("Daubechies");
[phi, psi, x] = dbGen(4);  % db4

% Slepian sequences
slepianGen = G("Slepian");
[v, lambda] = slepianGen(1024, 4);  % N=1024, NW=4
```

### 3. `bct.kernel.get()` - Unified Access

Single entry point for all kernels and generators.

**Usage:**
```matlab
% Auto-lookup (dictionary → generators → registry)
f = bct.kernel.get("Gaussian");

% Explicit type
dbGen = bct.kernel.get("Daubechies", 'Type', 'generator');

% Force registry lookup
heat = bct.kernel.get("Heat", 'Type', 'registry');
```

### 4. `bct.kernel.list()` - Enumeration

List available kernels by type.

**Usage:**
```matlab
% All kernels
all = bct.kernel.list();

% Only analytic
analytic = bct.kernel.list('Type', 'analytic');

% Only generators
generators = bct.kernel.list('Type', 'generator');
```

### 5. `bct.kernel.registry()` - Metadata Store

Declarative kernel definitions with UI metadata, parameter ranges, equations.

## Key Distinctions

### Analytic vs Operator-Defined

| Property | Analytic (dictionary) | Operator-Defined (generators) |
|----------|----------------------|------------------------------|
| **Form** | Closed-form expression | Iterative/eigenvalue solution |
| **Speed** | Direct evaluation | Requires computation |
| **Examples** | Gaussian, Heat, Hermite | Daubechies, Slepian |
| **Use Case** | Real-time filtering | Basis construction |

### New Advanced Kernels

#### Hermite Functions
**Type:** Analytic  
**Definition:** 
$$\psi_n(x) = \frac{1}{\sqrt{2^n n! \sqrt{\pi}}} H_n(x) e^{-x^2/2}$$

**Properties:**
- Quantum harmonic oscillator eigenstates
- True continuous basis
- $n=0$ is Gaussian (ground state)
- Increasing $n$ → more oscillations
- Perfect orthogonality

**Usage:**
```matlab
hermite = bct.kernel.get("Hermite");
psi0 = hermite(x, 0);  % Gaussian
psi1 = hermite(x, 1);  % First excited state
```

#### Meyer Wavelet
**Type:** Analytic (frequency-domain)  
**Definition:** Smooth transition function in $[\frac{2\pi}{3}, \frac{8\pi}{3}]$

**Properties:**
- Infinitely smooth
- Compact in frequency
- Ideal spectral filter
- Apply on eigenvalue ($\lambda$) axis

**Usage:**
```matlab
meyerHat = bct.kernel.get("MeyerHat");
spectralFilter = meyerHat(eigenvalues);
filtered = spectralFilter .* signal_lambda;
```

#### Daubechies Wavelets
**Type:** Generator  
**Definition:** Filter coefficients (no closed form)

**Properties:**
- Compact support
- Increasing vanishing moments
- Discrete multiresolution
- Standard for wavelet decomposition

**Usage:**
```matlab
% Generate wavelet functions
dbGen = bct.kernel.get("Daubechies");
[phi, psi, x] = dbGen(4);  % db4

% Use in decomposition
[C,L] = wavedec(signal, level, 'db4');
```

#### Slepian Functions (DPSS)
**Type:** Generator  
**Definition:** Solutions to:
$$\int_{-W}^{W} \text{sinc}(W(x-y)) \psi(y) dy = \lambda \psi(x)$$

**Properties:**
- Optimal time-frequency concentration
- Ordered by concentration eigenvalues
- Gold standard for bounded domains
- Manifold analogue: band-limited Laplacian eigenfunctions

**Usage:**
```matlab
slepianGen = bct.kernel.get("Slepian");
[v, lambda] = slepianGen(1024, 4);  % N=1024, NW=4

% Multitaper spectrum
spectrum = v' * signal;  % Project onto Slepian basis
```

## Conceptual Framework

### The Balance Principle

> **"The most balanced functions are eigenfunctions of symmetry-defining operators. Analytic kernels approximate this balance; Slepian and Hermite achieve it optimally."**

| Kernel | Operator | Symmetry |
|--------|----------|----------|
| Hermite | Quantum harmonic oscillator | Phase space |
| Slepian | Band-limited projection | Time-frequency |
| Heat | Diffusion operator | Scale |
| Meyer | Smooth band-pass | Frequency |

### Taxonomy by Mathematical Structure

```
bct.kernel
├── dictionary (Analytic)
│   ├── Closed-form expressions
│   ├── Direct evaluation
│   └── Examples: Gaussian, Heat, Hermite, MeyerHat
│
├── generators (Operator-Defined)
│   ├── Iterative construction
│   ├── Eigenvalue problems
│   └── Examples: Daubechies, Slepian
│
└── registry (Metadata)
    ├── UI parameters
    ├── LaTeX equations
    └── Parameter ranges
```

## Integration with BCT

### For Manifold Filtering

```matlab
% 1. Get eigenspectrum
B = bct.bct.fromMesh(V, F);
[evecs, evals] = B.manifold.spectrum(100);

% 2. Choose kernel
heat = bct.kernel.get("Heat");
spectralFilter = heat(evals, tau);

% 3. Apply in spectral domain
signal_lambda = evecs' * signal;
filtered_lambda = spectralFilter .* signal_lambda;
filtered = evecs * filtered_lambda;
```

### For Basis Construction

```matlab
% Hermite basis on λ-axis
hermite = bct.kernel.get("Hermite");
for n = 0:20
    basis(:,n+1) = hermite(evals, n);
end

% Project signal
coeffs = basis' * signal_lambda;
```

### For Optimal Concentration

```matlab
% Slepian sequences for bounded mesh region
slepian = bct.kernel.get("Slepian");
N = size(evals, 1);
NW = 4;  % Time-bandwidth product
[tapers, concentration] = slepian(N, NW);

% Multitaper projection
multitaper_coeffs = tapers' * signal;
```

## Performance Notes

- **Dictionary lookup**: ~0.001 ms (hash table)
- **Generator execution**: 1-100 ms (depends on parameters)
- **Registry lookup**: ~0.01 ms (struct field)

Use `dictionary` for repeated kernel evaluations in loops.

## See Also

- `examples/example_advanced_kernels.m` - Comprehensive demo
- `examples/example_kernel_dictionary.m` - Dictionary integration
- `docs/spectral_brush_documentation.md` - UI integration
- `toolbox/+bct/@bct/` - Main orchestrator class

