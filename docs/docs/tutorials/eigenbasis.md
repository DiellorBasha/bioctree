# Computing the Eigenbasis

Step-by-step guide to computing eigenmodes of the Laplace-Beltrami operator.

## Basic Usage

```matlab
% Load mesh
B = bct.bct.fromMesh(V, F);

% Compute first 100 eigenmodes
B.computeEigenbasis(100);

% Access results
eigenvalues = B.Lambda.eigenvalues;      % [100 × 1]
eigenvectors = B.Lambda.eigenvectors;    % [N × 100]
```

## Choosing Number of Modes

**Rule of thumb**:
```matlab
N = B.Manifold.N;  % Number of vertices

% Quick exploration
K = round(N / 100);

% Production analysis
K = round(N / 20);

% High fidelity
K = round(N / 5);

B.computeEigenbasis(K);
```

## Visualization

```matlab
% Visualize first few modes
bct.show.eigenmodes(B, [1, 2, 3, 4, 5]);

% High frequency modes
bct.show.eigenmodes(B, [95, 96, 97, 98, 99, 100]);

% Specific mode
bct.show.eigenmodes(B, 42);
```

## Advanced Options

```matlab
% Use sparse solver (faster for K << N)
B.computeEigenbasis(100, 'Method', 'sparse');

% Higher tolerance
B.computeEigenbasis(100, 'Tolerance', 1e-10);

% Use GPU (if available)
B.computeEigenbasis(100, 'UseGPU', true);
```

## Verify Orthogonality

```matlab
% Check orthogonality
M = B.Manifold.massMatrix();
phi = B.Lambda.eigenvectors;

% Should be identity matrix
orthogonality = phi' * M * phi;

% Check diagonal is 1, off-diagonal is 0
diag_values = diag(orthogonality);
off_diag = orthogonality - diag(diag_values);

fprintf('Max diagonal deviation: %.2e\n', max(abs(diag_values - 1)));
fprintf('Max off-diagonal: %.2e\n', max(abs(off_diag(:))));
```

## Next Steps

- [Apply Spatial Filters](spatial-filters.md)
- [Wave Packet Analysis](wavepacket.md)
