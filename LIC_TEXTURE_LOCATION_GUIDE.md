# LIC Texture Location and Usage Guide

## 📍 **Where to Find Your LIC Textures**

After running the LIC generation pipeline, your textures will be located in:

### **Primary Location**: `output/lic_textures/`
```
C:\CodingProjects\bioctree\output\lic_textures\
├── lh_lic_texture.png          # Left hemisphere LIC texture (4096×2048)
├── rh_lic_texture.png          # Right hemisphere LIC texture (4096×2048)  
├── lh_pial_with_uv_lic.png     # LH texture from GLB pipeline
├── rh_pial_with_uv_lic.png     # RH texture from GLB pipeline
├── bilateral_pial_with_uv_lic.png # Combined hemispheres texture
├── lh_pial_with_lic.glb        # GLB with embedded LIC texture
├── rh_pial_with_lic.glb        # RH GLB with embedded LIC texture
└── bilateral_pial_with_lic.glb # Bilateral GLB with embedded LIC texture
```

### **Copy to**: `test-data/mesh/` (for easier access)

## 🚀 **How to Generate and Copy LIC Textures**

### **Option 1: Complete Pipeline (Recommended)**
```bash
# Runs LIC generation + automatic copying
run_complete_lic_pipeline.bat
```

### **Option 2: Manual Steps**
```bash
# 1. Generate LIC textures
python generate_lic_texture.py

# 2. Copy to test-data/mesh
python copy_lic_textures.py
```

### **Option 3: MATLAB + Python**
```matlab
% 1. Export surfaces first
export_surfaces_for_lic_sphere

% 2. Copy textures after Python generation
copy_lic_textures
```

## 🎯 **Main LIC Texture Files You Need**

For three.js visualization, you primarily need:

1. **`lh_lic_texture.png`** - Left hemisphere LIC texture
2. **`rh_lic_texture.png`** - Right hemisphere LIC texture

These are high-resolution (4096×2048) PNG files showing the flow patterns on the cortical surface.

## 📦 **GLB Files (Alternative)**

For easier three.js integration:
- **`lh_pial_with_lic.glb`** - Complete left hemisphere with embedded LIC texture
- **`rh_pial_with_lic.glb`** - Complete right hemisphere with embedded LIC texture

## 🔧 **Usage in three.js**

### Using PNG Textures
```javascript
const textureLoader = new THREE.TextureLoader();
const lhTexture = textureLoader.load('test-data/mesh/lh_lic_texture.png');
const rhTexture = textureLoader.load('test-data/mesh/rh_lic_texture.png');

// Apply to your cortical mesh materials
const lhMaterial = new THREE.MeshBasicMaterial({ map: lhTexture });
const rhMaterial = new THREE.MeshBasicMaterial({ map: rhTexture });
```

### Using GLB Files
```javascript
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

const loader = new GLTFLoader();
loader.load('test-data/mesh/lh_pial_with_lic.glb', (gltf) => {
    scene.add(gltf.scene); // Texture already applied!
});
```

## 📋 **File Checklist**

After running the pipeline, you should have in `test-data/mesh/`:
- [ ] `lh_lic_texture.png` (Left hemisphere texture)
- [ ] `rh_lic_texture.png` (Right hemisphere texture)  
- [ ] `lh_pial_with_lic.glb` (LH GLB with embedded texture)
- [ ] `rh_pial_with_lic.glb` (RH GLB with embedded texture)
- [ ] `README_LIC_TEXTURES.md` (Documentation)

## 🔄 **Auto-Copy Feature**

The LIC generation scripts now automatically attempt to copy textures to `test-data/mesh/` after generation. If this fails, you can manually run:

```bash
python copy_lic_textures.py
```

Or in MATLAB:
```matlab
copy_lic_textures
```