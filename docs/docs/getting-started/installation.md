# Installation Guide

## System Requirements

### MATLAB Version
- **MATLAB R2021a or newer** (recommended: R2023a+)
- Required toolboxes:
  - Statistics and Machine Learning Toolbox
  - Image Processing Toolbox (optional, for visualization)

### Operating System
- Windows 10/11
- macOS 10.15+
- Linux (Ubuntu 20.04+, RHEL 8+)

### Hardware
- **RAM**: Minimum 8 GB, recommended 16 GB+
- **Storage**: ~500 MB for bioctree + dependencies
- **GPU**: Optional (for accelerated eigensolver)

## Installation Steps

### 1. Download Bioctree

#### Option A: Clone from GitHub (Recommended)

```bash
git clone https://github.com/DiellorBasha/bioctree.git
cd bioctree
```

#### Option B: Download ZIP

1. Visit [github.com/DiellorBasha/bioctree](https://github.com/DiellorBasha/bioctree)
2. Click "Code" → "Download ZIP"
3. Extract to your desired location

### 2. Run Initialization Script

Open MATLAB and navigate to the bioctree root directory:

```matlab
cd /path/to/bioctree
bioctree_start
```

This script will:
1. ✓ Load configuration
2. ✓ Add paths to MATLAB
3. ✓ Download external dependencies
4. ✓ Validate dependencies
5. ✓ Initialize the +bct package
6. ✓ Run environment checks

You should see output like:

```
╔══════════════════════════════════════════════════════════╗
║          Bioctree Toolbox Initialization                ║
╚══════════════════════════════════════════════════════════╝

[1/6] Loading configuration...
      ✓ Config loaded from: C:\...\bioctree\config
      ✓ Root directory: C:\...\bioctree

[2/6] Adding paths to MATLAB...
      ✓ Toolbox: C:\...\bioctree\toolbox
      ✓ External libraries added

[3/6] Downloading dependencies...
      ✓ gptoolbox
      ✓ gspbox
      ✓ iso2mesh

[4/6] Validating dependencies...
      ✓ All dependencies validated

[5/6] Package initialization...
      ✓ +bct package ready

[6/6] Environment validation...
      ✓ System ready

╔══════════════════════════════════════════════════════════╗
║          Bioctree Ready!                                 ║
╚══════════════════════════════════════════════════════════╝
```

### 3. Verify Installation

Run a quick test:

```matlab
% Load test mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

% Compute first 10 eigenmodes
B.computeEigenbasis(10);

% Display info
disp(B);
```

Expected output:
```
bct object with:
  Manifold: 40962 vertices, 81920 faces
  Lambda: 10 eigenmodes computed
  Signals: 0 signals
```

## Dependencies

Bioctree automatically downloads and manages the following dependencies:

### Core Dependencies

#### 1. gptoolbox
**Purpose**: Geometry processing utilities  
**Source**: [github.com/alecjacobson/gptoolbox](https://github.com/alecjacobson/gptoolbox)  
**Used for**:
- Mesh manipulation
- Cotangent Laplacian computation
- Mass matrix computation

#### 2. gspbox
**Purpose**: Graph signal processing  
**Source**: [epfl-lts2.github.io/gspbox-html](https://epfl-lts2.github.io/gspbox-html/)  
**Used for**:
- Graph operators
- Filter design
- Wavelets

#### 3. iso2mesh
**Purpose**: Mesh generation  
**Source**: [github.com/fangq/iso2mesh](https://github.com/fangq/iso2mesh)  
**Used for**:
- Mesh refinement
- Surface extraction

### Optional Dependencies

#### GIFTI Toolbox
**Purpose**: Reading GIFTI surface files  
**Install**: `bioctree_install_gifti()`

```matlab
% Install GIFTI support
bioctree_install_gifti();

% Load GIFTI file
surf = gifti('lh.pial.gii');
B = bct.bct.fromMesh(surf.vertices, surf.faces);
```

#### FreeSurfer MATLAB Tools
**Purpose**: Reading FreeSurfer surface files  
**Install**: Add FreeSurfer's MATLAB directory to path

## Configuration

### Custom Data Path

By default, bioctree stores data in `<bioctree_root>/data/`. To use a custom location:

```matlab
% Set custom data path (persistent)
bioctree_config('DataPath', '/path/to/my/data');

% Verify
cfg = bioctree_config();
disp(cfg.DataPath);
```

### External Libraries Path

To use externally installed libraries instead of auto-downloaded ones:

```matlab
% Edit config/bioctree_paths.json
{
  "gptoolbox": "/my/custom/gptoolbox",
  "gspbox": "/my/custom/gspbox",
  "iso2mesh": "/my/custom/iso2mesh"
}
```

Then run `bioctree_start` to load the custom paths.

### Persistent Configuration

To automatically run `bioctree_start` every time you start MATLAB:

```matlab
% Add to your startup.m file
edit startup.m

% Add this line:
run('/path/to/bioctree/bioctree_start.m');
```

## Troubleshooting

### Issue: "Cannot find +bct package"

**Solution**: Ensure the toolbox directory is on your path:

```matlab
addpath('/path/to/bioctree/toolbox');
```

### Issue: "Eigendecomposition fails"

**Cause**: Missing or corrupt gptoolbox installation  
**Solution**: Re-download dependencies:

```matlab
% Delete external folder
rmdir('external', 's');

% Re-run initialization
bioctree_start;
```

### Issue: "Out of memory during eigensolver"

**Solution**: Reduce the number of eigenmodes or use sparse methods:

```matlab
% Instead of 500 modes
B.computeEigenbasis(100);  % Use fewer modes

% Or use sparse solver
B.computeEigenbasis(100, 'Method', 'sparse');
```

### Issue: "Dependencies download fails"

**Solution**: Manual download and placement:

1. Download dependencies manually:
   - [gptoolbox](https://github.com/alecjacobson/gptoolbox/archive/refs/heads/master.zip)
   - [gspbox](https://github.com/epfl-lts2/gspbox/archive/refs/heads/master.zip)
   - [iso2mesh](https://github.com/fangq/iso2mesh/archive/refs/heads/master.zip)

2. Extract to `bioctree/external/`:
   ```
   external/
     gptoolbox/
     gspbox/
     iso2mesh/
   ```

3. Run `bioctree_start` again

### Issue: "HDF5 errors when saving BCT files"

**Solution**: Ensure HDF5 support in MATLAB:

```matlab
% Test HDF5
h5create('test.h5', '/data', 10);
h5write('test.h5', '/data', 1:10);
delete('test.h5');  % Cleanup

% If this fails, reinstall MATLAB or update to newer version
```

## Updating Bioctree

### Git Users

```bash
cd /path/to/bioctree
git pull origin main
```

Then restart MATLAB and run `bioctree_start`.

### ZIP Users

1. Download the latest version
2. Extract to the same location (overwrite existing files)
3. Restart MATLAB
4. Run `bioctree_start`

## Uninstallation

To completely remove bioctree:

```matlab
% Remove from MATLAB path
rmpath(genpath('/path/to/bioctree'));

% Save path
savepath;

% Delete directory (outside MATLAB)
% rm -rf /path/to/bioctree
```

## Next Steps

- **[Quickstart Guide](quickstart.md)**: Run your first analysis
- **[Introduction](introduction.md)**: Understand bioctree concepts
- **[Load Mesh Tutorial](../tutorials/load-mesh.md)**: Load and visualize cortical surfaces
