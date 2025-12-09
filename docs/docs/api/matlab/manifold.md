# Manifold Class Reference

The `bct.Manifold` class represents geometric meshes or graphs.

## Constructor

### From Vertices and Faces
```matlab
M = bct.Manifold(V, F);
```

**Parameters**:
- `V`: [N × 3] vertex coordinates in ℝ³
- `F`: [M × 3] face indices (1-based)

### From Graph
```matlab
M = bct.Manifold.fromGraph(W);
```

**Parameters**:
- `W`: [N × N] sparse adjacency/weight matrix

## Properties

### V
Vertex positions.
```matlab
V = M.V;  % [N × 3] double
```

### F
Face connectivity.
```matlab
F = M.F;  % [M × 3] int32
```

### N
Number of vertices (dependent property).
```matlab
num_vertices = M.N;
```

### Type
Manifold type (dependent property).
```matlab
type = M.Type;  % 'mesh' or 'graph'
```

### Edges
Edge list (computed from faces or adjacency).
```matlab
E = M.Edges;  % [E × 2] int32
```

### Time
Optional temporal dimension.
```matlab
M.Time = bct.Time(200, 250);  % 200 samples at 250 Hz
```

## Methods

### cotLaplacian
Compute cotangent Laplacian matrix.

```matlab
L = M.cotLaplacian();  % [N × N] sparse
```

**Returns**: Symmetric sparse Laplace-Beltrami matrix

### massMatrix
Compute mass matrix (vertex areas).

```matlab
Mass = M.massMatrix();  % [N × N] sparse diagonal
```

### plot
Visualize mesh.

```matlab
M.plot();
M.plot(Name, Value);
```

**Name-Value Pairs**:
- `'FaceColor'`: Color specification
- `'EdgeColor'`: Edge color
- `'FaceAlpha'`: Transparency (0-1)

### transform
Transform signal to another domain.

```matlab
signal_transformed = M.transform(signal_data, target_domain);
```

### geodesicDistance
Compute geodesic distances.

```matlab
distances = M.geodesicDistance(source_vertex);
```

**Parameters**:
- `source_vertex`: Index of source vertex

**Returns**: [N × 1] distances from source to all vertices

### computeGradient
Compute spatial gradient of scalar field.

```matlab
grad = M.computeGradient(scalar_field);  % [N × 3]
```

## Examples

### Basic Usage
```matlab
% Create from mesh
M = bct.Manifold(V, F);

% Check properties
fprintf('Vertices: %d\n', M.N);
fprintf('Type: %s\n', M.Type);

% Compute operators
L = M.cotLaplacian();
Mass = M.massMatrix();

% Visualize
M.plot('FaceColor', [0.8, 0.8, 0.8], 'EdgeColor', 'none');
```

## See Also

- [Lambda Class](overview.md#bctlambda)
- [BCT Class](bct.md)
- [Manifolds Concept](../../concepts/manifolds.md)
