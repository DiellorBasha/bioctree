## BioctreePlotter Class - Signal Visualization

The BioctreePlotter class now supports comprehensive graph signal visualization in addition to wireframe plotting.

### Key Features

#### Signal Plotting Methods
- `plotSignal()` - Plot graph signals with color-coded vertices
- `getAvailableSignals()` - List all available signal datasets 
- `loadSignalData()` - Load signal data from HDF5 files or structures

#### Visualization Options
- **Multiple colormaps**: jet, parula, hot, cool, etc.
- **Edge transparency control**: Show/hide graph structure with adjustable alpha
- **Customizable markers**: Variable vertex sizes and colors
- **Flexible viewing**: Multiple view angles and perspectives
- **Signal statistics**: Display range, nonzero count, and coverage percentage

### Usage Examples

#### Basic Signal Plotting
```matlab
% From HDF5 file
plotter = BioctreePlotter('icosphere_demo.h5');
plotter.plotSignal('SignalName', 'signal_patch_05_pct');
```

#### Advanced Signal Visualization
```matlab
% Custom styling
plotter.plotSignal('SignalName', 'signal_patch_10_pct', ...
                  'Colormap', 'parula', ...
                  'MarkerSize', 60, ...
                  'EdgeAlpha', 0.2, ...
                  'ViewAngle', [45, 30], ...
                  'Title', 'Custom Signal Plot');
```

#### Signal Discovery and Analysis
```matlab
% List available signals
signals = plotter.getAvailableSignals();
fprintf('Available signals: %s\n', strjoin(signals, ', '));

% Display graph information
plotter.displayInfo();
```

### Signal Data Format Support

#### HDF5 Structure
- Supports `/data/raw/signal_name` format
- Handles multi-layer signal storage
- Compatible with Bioctree HDF5 export format
- Automatic temporal dimension handling (uses first timepoint if multiple)

#### Data Structures
- Direct graph structures with `X` field
- Multi-layer structures with `X_layers` field
- Compatible with GSPBox graph formats

### Technical Implementation

#### Automatic Features
- **Edge detection**: Creates edges from coordinates when adjacency unavailable
- **Signal validation**: Checks signal dimensions match graph vertices
- **Error handling**: Comprehensive error messages for debugging
- **Performance optimization**: Efficient plotting for large graphs (tested with 642 vertices, 10K+ edges)

#### Supported Input Formats
- Signal dimensions: [N x 1] for static signals, [N x T] for temporal
- Time indexing: Selectable time points for temporal signals
- Multiple signal datasets per HDF5 file
- Named signal layers (e.g., 'signal_patch_05_pct', 'signal_patch_10_pct')

### Example Workflow

```matlab
% Complete signal analysis workflow
config = bioctree_config();
hdf5_file = fullfile(config.DataPath, 'bioctree_files', 'demo.h5');

% Initialize plotter
plotter = BioctreePlotter(hdf5_file);

% Explore available data
plotter.displayInfo();
signals = plotter.getAvailableSignals();

% Create comparison plots
figure('Position', [100, 100, 1200, 800]);

subplot(2, 2, 1);
plotter.plotSignal('SignalName', 'signal_patch_05_pct', 'Title', '5% Coverage');

subplot(2, 2, 2);
plotter.plotSignal('SignalName', 'signal_patch_10_pct', 'Title', '10% Coverage');

subplot(2, 2, 3);
plotter.plotSignal('SignalName', 'signal_patch_15_pct', 'Title', '15% Coverage');

subplot(2, 2, 4);
plotter.plotSignal('SignalName', 'signal_patch_20_pct', 'Title', '20% Coverage');
```

### Performance Notes
- Tested with icosphere graphs (642 vertices, 10,250 edges)
- Supports 11+ simultaneous signal layers
- Efficient edge rendering with transparency options
- Automatic coordinate-based edge generation when needed

### Integration with Bioctree Workflow
- Seamless integration with `workflow_sphere.m` output
- Compatible with `outbct.m` HDF5 export format
- Works with multi-scale patch signal generation
- Supports the complete Bioctree analysis pipeline