# Loading Mesh Data

Learn how to load cortical surface meshes from various sources into Bioctree.

## Quick Start

```matlab
% Load fsaverage mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

% Display info
disp(B);
```

## Mesh File Formats

### 1. MATLAB .mat Files

```matlab
% Load .mat containing V (vertices) and F (faces)
data = load('cortex.mat');
B = bct.bct.fromMesh(data.V, data.F);
```

**Expected variables**:
- `V`: [N × 3] double (vertex coordinates)
- `F`: [M × 3] integer (face indices, 1-based)

### 2. FreeSurfer Surfaces

```matlab
% Requires FreeSurfer MATLAB tools
addpath('/Applications/freesurfer/matlab');

% Load surface
[V, F] = read_surf('lh.pial');
B = bct.bct.fromMesh(V, F);
```

### 3. GIFTI Files

```matlab
% Requires GIFTI toolbox
g = gifti('surface.gii');
B = bct.bct.fromMesh(g.vertices, g.faces);
```

### 4. Custom ASCII/Binary

```matlab
% Read custom format
V = dlmread('vertices.txt');  % [N × 3]
F = dlmread('faces.txt');     % [M × 3]
B = bct.bct.fromMesh(V, F);
```

## Validate Mesh

```matlab
% Check mesh topology
B.Manifold.validateTopology();

% Check for issues
is_closed = B.Manifold.isClosed();
is_manifold = B.Manifold.isManifold();

fprintf('Closed: %d, Manifold: %d\n', is_closed, is_manifold);
```

## Visualize Mesh

```matlab
% Basic plot
figure;
B.Manifold.plot();

% With options
B.Manifold.plot('FaceColor', [0.8, 0.8, 0.8], ...
                'EdgeColor', 'none', ...
                'FaceAlpha', 0.8);
lighting gouraud;
camlight;
```

## Next Steps

- [Compute Eigenbasis](eigenbasis.md)
- [Apply Spatial Filters](spatial-filters.md)
