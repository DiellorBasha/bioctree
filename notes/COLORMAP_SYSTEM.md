# BCT Colormap System Reference

## Overview

The `bct.color` package provides a comprehensive, semantically-organized colormap system for the Bioctree toolbox. Colormaps are registered with metadata indicating their appropriate use cases (scalar, diverging, cyclic, etc.).

## Architecture

```
+bct/+color/
├── ColormapRegistry.m       % Singleton registry
├── ColormapDefinition.m     % Colormap metadata + generator
├── colormapTable.m          % Central colormap registration
├── scalar.m                 % Generate scalar colormaps
├── diverging.m              % Generate diverging colormaps
├── cyclic.m                 % Generate cyclic colormaps
├── +enum/
│   └── ColormapCategory.m   % Category enumeration
└── +internal/
    ├── pickColor.m          % Categorical color selection
    └── pickDivergingPair.m  % Diverging color pair selection
```

## Usage

### Quick Start

```matlab
% Generate a scalar colormap (256 colors)
C = bct.color.scalar(1, 256);

% Generate a diverging colormap
C = bct.color.diverging(1, 256);

% Generate a cyclic colormap for phase data
C = bct.color.cyclic(360);

% Access the registry
reg = bct.color.ColormapRegistry.instance();
names = reg.list();  % All registered colormaps
def = reg.get('viridis');  % Get definition
C = def.sample(128);  % Generate 128-color map
```

### Registry API

```matlab
reg = bct.color.ColormapRegistry.instance();

% List all colormaps
allNames = reg.list();

% List by category
scalarNames = reg.list(bct.color.enum.ColormapCategory.Scalar);
divNames = reg.list(bct.color.enum.ColormapCategory.Diverging);

% Get organized by category
byCategory = reg.listByCategory();
% Returns: struct with fields Scalar, Diverging, Cyclic, Binary, Categorical

% Check existence
if reg.has('viridis')
    def = reg.get('viridis');
end

% Get colormap and sample
def = reg.get('magma');
C = def.sample(256);  % Generate Nx3 RGB matrix
```

### ColormapDefinition Properties

```matlab
def = reg.get('viridis');

def.Name           % "viridis"
def.Category       % bct.color.enum.ColormapCategory.Scalar
def.Domain         % [0 1] - data range
def.Generator      % @(N) viridis(N) - function handle
def.IsDiscrete     % false - continuous colormap
def.IsDiverging    % false - not zero-centered
```

## Registered Colormaps

### Scalar (8 colormaps)
Continuous scalar fields (non-negative or arbitrary range)

- **viridis** - Perceptually uniform, excellent for heatmaps
- **parula** - MATLAB default, good general-purpose
- **magma** - Perceptually uniform, dark background
- **inferno** - Perceptually uniform, warm tones
- **plasma** - Perceptually uniform, vibrant
- **turbo** - High dynamic range, rainbow-like
- **hot** - Black-red-yellow-white progression
- **gray** - Simple grayscale

### Diverging (2 colormaps)
Signed scalar fields (zero-centered)

- **redblue** - Classic blue-white-red
- **coolwarm** - Perceptually balanced blue-white-red

### Cyclic (2 colormaps)
Phase/angular data (periodic)

- **phaseCyclic** - HSV hue cycle
- **twilight** - Perceptually uniform cyclic

### Binary (1 colormap)
Logical masks/thresholds

- **binaryMask** - Black/white discrete

### Categorical (2 colormaps)
Labels/parcels/regions

- **lines** - 12 distinct colors (MATLAB default)
- **tab10** - Tableau 10 palette

## Colormap Categories

```matlab
% Enumeration: bct.color.enum.ColormapCategory

Binary        % Logical masks, thresholds
Scalar        % Continuous scalar fields (≥0 or arbitrary)
Diverging     % Signed scalar fields (e.g., eigenmodes)
Cyclic        % Phase/angular data
VectorRGB     % Pre-colored RGB data
Categorical   % Labels/parcels/regions
```

## Adding Custom Colormaps

Edit [colormapTable.m](../toolbox/+bct/+color/colormapTable.m):

```matlab
struct( ...
    'Name', "myColormap", ...
    'Category', bct.color.enum.ColormapCategory.Scalar, ...
    'Domain', [0 1], ...
    'Generator', @(N) myColormapGenerator(N), ...
    'IsDiscrete', false, ...
    'IsDiverging', false ...
)
```

Generator function signature:
```matlab
function C = myColormapGenerator(N)
    % Generate Nx3 RGB matrix in [0,1]
    C = ...; % Your logic here
end
```

## Design Principles

1. **Semantic correctness**: Colormaps are categorized by data type
2. **Immutability**: `ColormapDefinition` objects are immutable
3. **Lazy evaluation**: Colormaps generated on-demand via `sample(N)`
4. **Extensibility**: Easy to add new colormaps to `colormapTable.m`
5. **Type safety**: Category enum prevents misuse

## Best Practices

### Choosing Colormaps

- **Scalar non-negative data** (e.g., power, magnitude): Use `Scalar` category
  - Recommended: `viridis`, `magma`, `inferno`
  
- **Signed data** (e.g., eigenmodes, correlations): Use `Diverging` category
  - Recommended: `coolwarm`, `redblue`
  
- **Phase/angle data**: Use `Cyclic` category
  - Recommended: `twilight`, `phaseCyclic`
  
- **Binary masks**: Use `Binary` category
  - Use: `binaryMask`
  
- **Categorical labels**: Use `Categorical` category
  - Recommended: `tab10`, `lines`

### Perceptual Uniformity

For quantitative visualization, prefer perceptually uniform colormaps:
- **Scalar**: `viridis`, `magma`, `inferno`, `plasma`
- **Diverging**: `coolwarm`
- **Cyclic**: `twilight`

Avoid `jet`, `hsv`, and `hot` for quantitative data (non-uniform perception).

## Testing

Run comprehensive tests:
```matlab
cd tests
test_colormap_system
```

## References

- Matplotlib colormaps: https://matplotlib.org/stable/users/explain/colors/colormaps.html
- Colormap theory: Moreland, "Diverging Color Maps for Scientific Visualization"
- Perceptual uniformity: viridis paper (Smith & van der Walt, 2015)
