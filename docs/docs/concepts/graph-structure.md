# Graph Structure

## Overview

Graphs generalize signal processing from regular grids to irregular network structures. In Bioctree, graphs are treated as abstract manifolds where connectivity matters more than geometric embedding.

## Graph Fundamentals

### Definition

A graph $\mathcal{G} = (V, E, W)$ consists of:
- **Vertices** $V = \{1, 2, \ldots, N\}$
- **Edges** $E \subseteq V \times V$
- **Weights** $W: E \rightarrow \mathbb{R}^+$ (optional)

### Representations

#### Adjacency Matrix
$$
W_{ij} = \begin{cases}
w_{ij} & \text{if } (i,j) \in E \\
0 & \text{otherwise}
\end{cases}
$$

#### Edge List
```matlab
edges = [
    1, 2, 0.5;   % vertex 1 connected to 2, weight 0.5
    1, 3, 0.3;
    2, 3, 0.8;
    ...
];
```

## Graph Laplacian

### Unnormalized Laplacian

$$
L = D - W
$$

where $D$ is the degree matrix: $D_{ii} = \sum_j W_{ij}$

**Properties**:
- Symmetric, positive semi-definite
- $L \mathbf{1} = 0$ (constant is in kernel)
- Smallest eigenvalue is 0

### Normalized Laplacian

$$
\mathcal{L} = D^{-1/2} L D^{-1/2} = I - D^{-1/2} W D^{-1/2}
$$

**Advantage**: Eigenvalues in $[0, 2]$, better for heterogeneous graphs

### Bioctree Usage

```matlab
% Create from adjacency matrix
W = sparse(adjacency_matrix);
G = bct.Graph(W);

% Access Laplacian
L = G.laplacian();            % Unnormalized
L_norm = G.laplacian('normalized');
```

## Graph Fourier Transform

### Definition

For signal $f$ on graph vertices:

**Forward**:
$$\hat{f} = U^T f$$

**Inverse**:
$$f = U \hat{f}$$

where $U$ contains eigenvectors of $L$: $LU = U\Lambda$

### Interpretation

- **Eigenvectors** $u_i$: Graph Fourier bases
- **Eigenvalues** $\lambda_i$: Graph frequencies
- **Coefficients** $\hat{f}_i$: Frequency content

```matlab
% Compute graph eigenbasis
B = bct.bct.fromGraph(W);
B.computeEigenbasis(50);

% Transform signal
f_hat = B.Lambda.forward(f);  % To frequency domain
f_reconstructed = B.Lambda.inverse(f_hat);
```

## Graph vs. Mesh

| Aspect | Graph | Mesh |
|--------|-------|------|
| Geometry | Abstract | Embedded in ℝ³ |
| Edges | Arbitrary | From triangulation |
| Weights | Custom | Cotangent formula |
| Curvature | N/A | Defined |
| Visualization | Network layout | 3D surface |

### When to Use Each

**Use Graph**:
- Social networks
- Sensor networks
- Abstract connectivity (e.g., functional brain networks)
- Custom edge weights (correlations, distances, etc.)

**Use Mesh**:
- Cortical surfaces
- 3D shapes
- Geometric data with spatial embedding
- When curvature and geometry matter

## Graph Signal Processing in Bioctree

### Creating Graphs

```matlab
% From adjacency matrix
W = sparse(N, N);
W(i, j) = weight;  % Add edges
B = bct.bct.fromGraph(W);

% From edge list
edges = [source, target, weight];
B = bct.bct.fromEdgeList(edges);

% From mesh (convert to graph)
M = bct.Manifold(V, F);
G = M.toGraph();
```

### Graph Filtering

```matlab
% Low-pass filter (smooth on graph)
filt = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 10);
f_smooth = filt.apply(f);

% High-pass (detect irregular patterns)
filt_hp = bct.Filter(B.Lambda, 'highpass', 'cutoff', 20);
f_edges = filt_hp.apply(f);
```

### Spectral Clustering

```matlab
% Use eigenvectors for clustering
k = 5;  % Number of clusters
features = B.Lambda.eigenvectors(:, 2:k+1);  % Skip DC
clusters = kmeans(features, k);

% Visualize clusters
scatter3(features(:,1), features(:,2), features(:,3), 20, clusters, 'filled');
```

## Advanced Graph Operations

### Graph Wavelets

```matlab
% Create wavelet filter bank
scales = [1, 2, 4, 8, 16];
wavelets = bct.filters.graphWavelets(B.Lambda, scales);

% Apply wavelets
coeffs = cell(length(scales), 1);
for i = 1:length(scales)
    coeffs{i} = wavelets{i}.apply(signal);
end
```

### Diffusion

```matlab
% Heat diffusion on graph
t = 1.0;  % Time
f_diffused = B.Lambda.diffuse(f_initial, t);
```

### Random Walks

```matlab
% Transition matrix
P = G.transitionMatrix();

% k-step random walk
k = 10;
distribution = P^k * initial_distribution;
```

## Further Reading

- [Manifolds](manifolds.md)
- [Laplace-Beltrami Operator](laplace-beltrami.md)
- [API: bct.Graph](../api/matlab/overview.md)
