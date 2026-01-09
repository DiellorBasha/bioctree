# Eigenspectrum Visualization Reference

## Overview

`bct.show.eigenspectrum` provides comprehensive visualization of the Manifold Fourier Transform (MFT), analogous to classic Fourier power spectrum analysis but for signals on manifolds.

## Quick Start

```matlab
% Load mesh and create signal
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);
sig = bct.Signal.fromBrush(B.Manifold, 'Category', 'patch', ...
    'Type', 'spectral', 'Source', 1000, 'Kernel', 'heat', 'Tau', 0.2);

% Basic power spectrum
bct.show.eigenspectrum(sig);
```

## Plot Types

### 1. Power Spectrum (`'Type', 'power'`)

**Standard view:** Power vs eigenvalue λ

```matlab
bct.show.eigenspectrum(sig, 'Type', 'power');
```

- **X-axis:** Eigenvalue λ (spatial frequency)
- **Y-axis:** Power |x̂(λ)|²
- **Analogue:** Classic Fourier power spectrum
- **Use:** Standard spectral analysis

### 2. Index Spectrum (`'Type', 'index'`)

**Clearer view:** Power vs mode index

```matlab
bct.show.eigenspectrum(sig, 'Type', 'index', 'Scale', 'log');
```

- **X-axis:** Eigenmode index k (1, 2, 3, ...)
- **Y-axis:** Power |x̂_k|²
- **Why:** Eigenvalues are non-uniformly spaced (especially on cortical meshes)
- **Interpretation:**
  - Early modes → large-scale structure
  - Later modes → fine spatial detail

### 3. Log-Log Spectrum (`'Type', 'loglog'`)

**Power law analysis:** Detect scaling laws

```matlab
bct.show.eigenspectrum(sig, 'Type', 'loglog');
```

- **Both axes:** Logarithmic
- **Fits:** P ∝ λ^α (power law)
- **Use cases:**
  - Compare conditions (healthy vs diseased)
  - Detect scale-free structure
  - Relate to fractal geometry
  
**Interpretation:**
- Negative exponent α → high-frequency attenuation (smoothing)
- Positive exponent → low-frequency attenuation (sharpening)

### 4. Normalized Spectrum (`'Type', 'normalized'`)

**Energy fractions:** DEC/Parseval-correct

```matlab
bct.show.eigenspectrum(sig, 'Type', 'normalized', ...
    'ShowThreshold', true, 'ThresholdValue', 90);
```

- **Y-axis:** Fraction of total energy
- **Cumulative curve:** Energy accumulation
- **Parseval identity:** x'*M*x = Σ|x̂_k|²
- **Use:** "X% of signal energy lives below spatial scale Y"

**With threshold:**
- Marks λ where cumulative energy reaches threshold (e.g., 90%)
- Useful for bandwidth characterization

### 5. Band-Aggregated Spectrum (`'Type', 'bands'`)

**Binned frequencies:** Like EEG bands

```matlab
bct.show.eigenspectrum(sig, 'Type', 'bands', 'NumBands', 25);
```

- **Bins:** Logarithmically spaced frequency bands
- **Y-axis:** Total power in each band
- **Analogue:** Delta/theta/alpha/beta/gamma in EEG
- **Use:** Broad trends, avoiding dense eigenvalue clutter

### 6. All Plots (`'Type', 'all'`)

**Comprehensive overview:** All plot types in subplots

```matlab
bct.show.eigenspectrum(sig, 'Type', 'all');
```

## Options

### Scale

```matlab
'Scale', 'linear'  % Linear Y-axis (default)
'Scale', 'log'     % Logarithmic Y-axis (semilogy)
```

### Top Modes Visualization

```matlab
'TopModes', 5  % Show spatial patterns of top 5 modes
```

Links spectrum back to geometry - shows what spatial patterns carry the energy.

### Energy Threshold

```matlab
'ShowThreshold', true     % Enable threshold line
'ThresholdValue', 90      % 90% cumulative energy (default)
```

Marks the eigenvalue where cumulative energy reaches specified percentage.

### Styling

```matlab
'Color', 'k'              % Plot color (default: black)
'Color', [0.2 0.4 0.8]    % Custom RGB
'LineWidth', 2.5          % Line width (default: 1.5)
'MarkerSize', 10          % Marker size (default: 6)
```

### Bands

```matlab
'NumBands', 30  % Number of frequency bands (default: 30)
```

## Examples

### Example 1: Basic Analysis

```matlab
% Create signal
sig = bct.Signal.fromBrush(B.Manifold, 'Category', 'patch', ...
    'Type', 'spectral', 'Source', 100, 'Kernel', 'heat', 'Tau', 0.2);

% Standard power spectrum
bct.show.eigenspectrum(sig);

% Log-scale index view
bct.show.eigenspectrum(sig, 'Type', 'index', 'Scale', 'log');
```

### Example 2: Energy Analysis

```matlab
% Normalized with 90% threshold
bct.show.eigenspectrum(sig, 'Type', 'normalized', ...
    'ShowThreshold', true, 'ThresholdValue', 90);

% Find out: "90% of energy in modes with λ < X"
```

### Example 3: Comparing Signals

```matlab
% Three signals with different scales
sig_sharp = bct.Signal.fromBrush(..., 'Tau', 0.05);
sig_medium = bct.Signal.fromBrush(..., 'Tau', 0.2);
sig_smooth = bct.Signal.fromBrush(..., 'Tau', 0.6);

% Compute spectra
s1 = sig_sharp.mft();
s2 = sig_medium.mft();
s3 = sig_smooth.mft();

lambda = s1.Domain.lambda;
P1 = abs(s1.Data).^2;
P2 = abs(s2.Data).^2;
P3 = abs(s3.Data).^2;

% Plot comparison
figure;
semilogy(lambda, P1, 'b', 'DisplayName', 'Sharp');
hold on;
semilogy(lambda, P2, 'g', 'DisplayName', 'Medium');
semilogy(lambda, P3, 'r', 'DisplayName', 'Smooth');
legend; grid on;
xlabel('\lambda'); ylabel('Power');
title('Spectrum Comparison');
```

**Key insight:**
- Sharp patterns (low τ) → broad spectrum (many modes)
- Smooth patterns (high τ) → narrow spectrum (few modes)

### Example 4: Mode Visualization

```matlab
% Show top 6 spatial modes
bct.show.eigenspectrum(sig, 'TopModes', 6);
```

Answers: "What spatial patterns carry the energy?"

### Example 5: Power Law Analysis

```matlab
% Log-log spectrum with automatic power law fit
bct.show.eigenspectrum(sig, 'Type', 'loglog');
```

Displays: P ∝ λ^α with fitted exponent α

### Example 6: Comprehensive Analysis

```matlab
% All views at once
bct.show.eigenspectrum(sig, 'Type', 'all', ...
    'NumBands', 20);
```

## Interpretation Guide

### Spatial Scales

| Eigenvalue λ | Spatial Scale | Interpretation |
|--------------|---------------|----------------|
| Small (0-10) | Global | Large-scale patterns |
| Medium (10-100) | Regional | Intermediate structure |
| Large (>100) | Local | Fine spatial detail |

### Energy Concentration

```matlab
sig_spectral = sig.mft();
P = abs(sig_spectral.Data).^2;
P_norm = P / sum(P);
cumulative = cumsum(P_norm);

% Find thresholds
idx_50 = find(cumulative >= 0.5, 1);
idx_90 = find(cumulative >= 0.9, 1);

fprintf('50%% energy in first %d modes\n', idx_50);
fprintf('90%% energy in first %d modes\n', idx_90);
```

**Sharp signals:** Energy spread over many modes  
**Smooth signals:** Energy concentrated in few modes

### Power Law Exponent

If log-log plot shows P ∝ λ^α:

- **α < -2:** Very smooth (strong high-frequency attenuation)
- **α ≈ -1:** Typical cortical signals
- **α ≈ 0:** Flat spectrum (white noise on manifold)
- **α > 0:** Unusual (high-frequency emphasis)

## Mathematical Background

### Manifold Fourier Transform

**Forward (spatial → spectral):**
```
x̂ = Φ' * M * x
```

**Inverse (spectral → spatial):**
```
x = Φ * x̂
```

Where:
- Φ = eigenvectors (columns of Lambda.U)
- M = mass matrix (FEM lumped mass)
- λ = eigenvalues (Lambda.lambda)

### Power Spectrum

```matlab
P(λ) = |x̂(λ)|²
```

Direct analogue of Fourier power spectrum.

### Parseval's Identity (DEC version)

```matlab
x' * M * x = sum(|x̂|²)
```

Total energy in spatial domain = total energy in spectral domain

### Normalization

```matlab
P_norm = P / sum(P)
```

Gives fraction of total energy per mode.

## Use Cases

### 1. Signal Characterization

```matlab
bct.show.eigenspectrum(sig, 'Type', 'normalized', 'ShowThreshold', true);
```

Quantify spatial frequency content.

### 2. Filter Design

```matlab
% View spectrum to choose cutoff
bct.show.eigenspectrum(sig, 'Type', 'power', 'Scale', 'log');

% Design lowpass filter to retain 90% energy
```

### 3. Condition Comparison

```matlab
% Compare healthy vs diseased
bct.show.eigenspectrum(sig_healthy, 'Type', 'loglog');
bct.show.eigenspectrum(sig_diseased, 'Type', 'loglog');
```

Look for changes in power law exponent.

### 4. Band Analysis

```matlab
bct.show.eigenspectrum(sig, 'Type', 'bands', 'NumBands', 20);
```

Aggregate power into spatial frequency bands for easier interpretation.

### 5. Mode Inspection

```matlab
bct.show.eigenspectrum(sig, 'TopModes', 8);
```

See which spatial patterns dominate.

## Integration with Brush Designer

```matlab
% Design brush with eigenspectrum feedback
designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
    struct('source', 100, 'kernel', 'heat', 'tau', 0.2));

% Evaluate kernel on Lambda
H = designer.evaluateKernel();
lambda = designer.Lambda.lambda;

% Compare kernel vs actual signal spectrum
figure;
subplot(2,1,1);
plot(lambda, H, 'b', 'DisplayName', 'Kernel');
title('Designed Kernel');

subplot(2,1,2);
sig = bct.Signal(designer.finalize(), B.Manifold);
bct.show.eigenspectrum(sig, 'Type', 'power');
title('Actual Signal Spectrum');
```

## Performance Notes

- MFT computation is cached in Signal object
- For large meshes (>100k vertices), spectrum computation is fast
- Top mode visualization can be slow for many modes (>20)

## See Also

- [Signal.mft](Signal.m#L319) - Manifold Fourier Transform
- [BrushDesigner](BRUSH_DESIGNER_REFERENCE.md) - Interactive brush design with kernel evaluation
- [bct.operator.transform.mft](toolbox/+bct/+operator/+transform/mft.m) - Transform operator
- [demo_eigenspectrum.m](examples/demo_eigenspectrum.m) - Comprehensive demo
