# bct Class Reference

The main orchestrator class for Bioctree operations.

## Constructor

### fromMesh
Create from mesh vertices and faces:
```matlab
B = bct.bct.fromMesh(V, F);
```

**Parameters**:
- `V`: [N × 3] vertex coordinates
- `F`: [M × 3] face indices (1-based)

### fromGraph
Create from graph adjacency:
```matlab
B = bct.bct.fromGraph(W);
```

**Parameters**:
- `W`: [N × N] sparse adjacency/weight matrix

## Properties

### Manifold
Geometric structure (mesh or graph).
```matlab
M = B.Manifold;  % bct.Manifold object
```

### Lambda
Spectral domain (eigenmode space).
```matlab
Lambda = B.Lambda;  % bct.Lambda object (if computed)
```

### Time
Temporal dimension.
```matlab
T = B.Time;  % bct.Time object (if set)
```

### Omega
Frequency domain.
```matlab
Omega = B.Omega;  % bct.Omega object (if Time is set)
```

### Signals
Array of signals.
```matlab
sigs = B.Signals;  % Array of bct.Signal objects
```

## Methods

### computeEigenbasis
Compute eigenmodes of Laplace-Beltrami operator.

**Syntax**:
```matlab
B.computeEigenbasis(K);
B.computeEigenbasis(K, Name, Value);
```

**Parameters**:
- `K`: Number of eigenmodes to compute

**Name-Value Pairs**:
- `'Method'`: `'sparse'` (default) or `'dense'`
- `'Tolerance'`: Eigenvalue tolerance (default: 1e-6)
- `'UseGPU'`: Use GPU acceleration (default: false)

**Example**:
```matlab
B.computeEigenbasis(100);
B.computeEigenbasis(100, 'Method', 'sparse', 'Tolerance', 1e-8);
```

### addSignal
Add signal to collection.

**Syntax**:
```matlab
B.addSignal(signal);
```

**Parameters**:
- `signal`: bct.Signal object

**Example**:
```matlab
sig = bct.Signal(B.Manifold, data, 'my_signal');
B.addSignal(sig);
```

### removeSignal
Remove signal from collection.

**Syntax**:
```matlab
B.removeSignal(index_or_label);
```

**Example**:
```matlab
B.removeSignal(1);            % Remove first signal
B.removeSignal('my_signal');  % Remove by label
```

### getSignalByLabel
Retrieve signal by label.

**Syntax**:
```matlab
sig = B.getSignalByLabel(label);
```

**Returns**: bct.Signal object or empty if not found

### getJointDomain
Create tensor product domain.

**Syntax**:
```matlab
joint = B.getJointDomain(domain1_name, domain2_name);
```

**Example**:
```matlab
lambda_omega = B.getJointDomain('Lambda', 'Omega');
```

### computeDispersion
Estimate dispersion relation from data.

**Syntax**:
```matlab
B.computeDispersion(signal);
B.computeDispersion(signal, Name, Value);
```

**Name-Value Pairs**:
- `'Type'`: `'linear'`, `'sqrt'`, `'polynomial'`
- `'Order'`: Polynomial order (if Type='polynomial')

## Examples

### Complete Workflow
```matlab
% Create from mesh
B = bct.bct.fromMesh(V, F);

% Compute eigenbasis
B.computeEigenbasis(100);

% Add temporal dimension
B.Manifold.Time = bct.Time(200, 250);

% Create signal
data = randn(B.Manifold.N, 200);
sig = bct.Signal(B.Manifold, data, 'test');
B.addSignal(sig);

% Create filter
filt = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 30);

% Apply
filtered = filt.apply(sig);

% Visualize
bct.show.signal(B, filtered);
```

## See Also

- [Manifold Class](manifold.md)
- [Signal Class](overview.md#bctsignal)
- [Filter Class](filters.md)
