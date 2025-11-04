# Surface-Tangent Vector Field and LIC Texture Generation

This pipeline generates Line Integral Convolution (LIC) textures from surface-tangent vector fields for cortical visualization in three.js.

## Overview

The pipeline consists of:
1. **FreeSurfer Surface Export** (MATLAB) - Convert surfaces to OBJ format
2. **Vector Field Generation** (Python) - Create tangent vector fields
3. **UV Parameterization** - Map from sphere to texture coordinates
4. **LIC Texture Generation** - Create flow visualization texture
5. **Three.js Integration** - Apply texture to 3D cortical mesh

## Prerequisites

### MATLAB Requirements
- FreeSurfer I/O functions (already included in `io/in/`)
- MATLAB R2019b or later

### Python Requirements
```bash
# Activate the virtual environment
external\.venv\Scripts\activate

# Install required packages
pip install nilearn numpy scipy matplotlib pillow trimesh
```

## Usage

### Method 1: Direct FreeSurfer Loading (Recommended)

Uses nilearn to directly load FreeSurfer surfaces:

```bash
# Activate Python environment and run
external\.venv\Scripts\activate
python generate_lic_texture.py
```

Or simply double-click: `run_lic_generation.bat`

### Method 2: Via OBJ Export

First export surfaces to OBJ format, then process:

```matlab
% In MATLAB - run this first
run('export_surfaces_for_lic.m')
```

```bash
# Then run Python processing
external\.venv\Scripts\activate
python generate_lic_texture_trimesh.py
```

### Method 3: GLB Format (Recommended for three.js)

For direct three.js integration with embedded textures:

```matlab
% In MATLAB - export to GLB format
run('export_surfaces_for_lic_glb.m')
```

```bash
# Generate and embed LIC textures
run_lic_glb_pipeline.bat
```

**GLB Pipeline Advantages**:
- Single file format with embedded UV coordinates and textures
- Direct loading in three.js with `GLTFLoader`
- No need for separate coordinate files
- Binary format for efficient loading

## Pipeline Details

### 1. Surface Loading
- **Cortical surface**: `lh.pial` (geometry for rendering)
- **Spherical surface**: `lh.sphere` (UV parameterization)
- Ensures 1:1 vertex correspondence between surfaces

### 2. UV Coordinate Generation

FreeSurfer provides spherical registration files (e.g., `lh.sphere.reg` or `lh.sphere`) that have the same vertex indexing as the cortical surfaces (`lh.pial`, `lh.inflated`). The UV coordinates are computed from the spherical coordinates:

```python
# FreeSurfer spherical to UV mapping
u = (arctan2(y, x) / (2π)) mod 1
v = asin(z)/π + 0.5
```

**Key principle**: The geometry you render is from `lh.pial` (or `lh.inflated`), but the UV mapping comes from `lh.sphere.reg`. Each cortical vertex knows where to read from the 2D texture via the sphere's parameterization.

### 3. Vector Field Creation
Two options implemented:

**Rotational Field** (default):
- Rotates around Z-axis: `v = ẑ × n̂`
- Projects to surface tangent plane

**Gradient Field**:
- Gradient of synthetic scalar field (sum of Gaussians)
- Projects to tangent plane

### 4. UV Rasterization
- Maps 3D tangent vectors to 2D UV texture space (4096×2048)
- Projects vectors using spherical parameterization tangent basis
- Fills holes using diffusion

### 5. LIC Generation
- Convolves white noise along vector field streamlines
- Forward/backward integration along flow lines
- Creates coherent texture showing flow patterns

## Output Files

The pipeline generates:

### For Three.js (OBJ Pipeline)
- `lh_lic_texture.png` - Main LIC texture (4096×2048)
- `lh_uv_coords.npz` - UV coordinates for vertices

### For Three.js (GLB Pipeline)
- `lh_pial_with_lic.glb` - Complete GLB with embedded LIC texture
- `lh_lic_texture.png` - Standalone LIC texture (4096×2048)
- `bilateral_pial_with_lic.glb` - Combined hemispheres with LIC texture

### For Analysis
- `lh_vector_field_uv.npz` - 2D vector field in UV space
- `lh_visualization.png` - Analysis plots
- `vertex_normals_lh.mat` - Surface normals (MATLAB)

## Three.js Integration

### Using GLB Files (Recommended)

```javascript
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

// Load GLB file with embedded LIC texture
const loader = new GLTFLoader();
loader.load('lh_pial_with_lic.glb', (gltf) => {
    const mesh = gltf.scene.children[0];
    
    // LIC texture is already applied as material
    // Optionally adjust material properties
    if (mesh.material) {
        mesh.material.transparent = true;
        mesh.material.opacity = 0.9;
        mesh.material.side = THREE.DoubleSide;
    }
    
    scene.add(mesh);
});

// For bilateral hemisphere
loader.load('bilateral_pial_with_lic.glb', (gltf) => {
    const bilateralMesh = gltf.scene.children[0];
    scene.add(bilateralMesh);
});
```

### Using OBJ Files + Separate Textures

```javascript
// Load the cortical mesh
const loader = new THREE.OBJLoader();
loader.load('cortical_mesh.obj', (mesh) => {
    
    // Load UV coordinates
    // Apply UV coordinates to mesh geometry
    // (Implementation depends on your UV data format)
    
    // Load LIC texture
    const textureLoader = new THREE.TextureLoader();
    const licTexture = textureLoader.load('lh_lic_texture.png');
    
    // Create material with LIC texture
    const material = new THREE.MeshBasicMaterial({
        map: licTexture,
        transparent: true,
        opacity: 0.8
    });
    
    // Or use as overlay:
    const material = new THREE.MeshLambertMaterial({
        color: 0xffffff,
        map: baseTexture,
        alphaMap: licTexture  // LIC as flow overlay
    });
    
    mesh.material = material;
    scene.add(mesh);
});
```

## Configuration

Edit the Python scripts to customize:

```python
# Texture resolution
TEXTURE_WIDTH = 4096   # Higher = more detail
TEXTURE_HEIGHT = 2048

# LIC parameters
num_steps = 20      # Streamline integration steps
step_size = 1.0     # Step size along streamlines

# Vector field type
vector_field_type = 1  # 1=rotational, 2=gradient

# Hemisphere
HEMISPHERE = 'lh'   # 'lh' or 'rh'
```

## File Structure

```
bioctree/
├── generate_lic_texture.py          # Main pipeline (nilearn)
├── generate_lic_texture_trimesh.py  # Alternative (OBJ-based)
├── generate_lic_texture_glb.py      # GLB pipeline with embedded textures
├── export_surfaces_for_lic.m        # MATLAB surface exporter (OBJ)
├── export_surfaces_for_lic_glb.m    # MATLAB surface exporter (GLB)
├── run_lic_generation.bat           # Windows batch script (OBJ)
├── run_lic_glb_pipeline.bat         # Windows batch script (GLB)
├── io/
│   ├── in/                          # FreeSurfer readers
│   └── out/
│       ├── export_freesurfer_to_obj.m  # OBJ format exporter
│       └── export_freesurfer_to_glb.m  # GLB format exporter
├── output/
│   └── lic_textures/                # Generated outputs
└── test-data/
    └── freesurfer/
        └── fsaverage/               # FreeSurfer subject data
```

## Troubleshooting

### Common Issues

**"Surface not found"**:
- Ensure FreeSurfer subject data is in correct location
- Check `FREESURFER_DIR` path in Python scripts

**"Vertex counts don't match"**:
- Pial and sphere surfaces must have same vertex count
- Use same FreeSurfer subject for both surfaces

**"nilearn import error"**:
- Activate virtual environment: `external\.venv\Scripts\activate`
- Install nilearn: `pip install nilearn`

**Poor LIC quality**:
- Increase texture resolution (`TEXTURE_WIDTH`, `TEXTURE_HEIGHT`)
- Adjust LIC parameters (`num_steps`, `step_size`)
- Try different vector field types

### Performance Notes

- LIC generation is CPU-intensive (can take several minutes)
- Reduce texture resolution for faster testing
- Use subsampling for vector field rasterization

## Extensions

The pipeline can be extended with:

1. **Real neuroimaging data**: Use actual fMRI/MEG gradients
2. **Custom vector fields**: Implement domain-specific flows
3. **Multi-scale LIC**: Generate multiple resolution textures
4. **Animated textures**: Time-varying vector fields
5. **Interactive parameters**: Real-time three.js controls

## References

- Cabral & Leedom (1993) - "Imaging Vector Fields Using Line Integral Convolution"
- FreeSurfer: https://surfer.nmr.mgh.harvard.edu/
- Nilearn: https://nilearn.github.io/
- Three.js: https://threejs.org/