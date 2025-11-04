#!/usr/bin/env python3
"""
Copy LIC textures to test-data/mesh directory.

This script automatically copies generated LIC textures and related files
from the output directory to test-data/mesh/ for easier access.
"""

import shutil
from pathlib import Path
import os
from datetime import datetime

# Configuration
SOURCE_DIR = Path(r"C:\CodingProjects\bioctree\output\lic_textures")
TARGET_DIR = Path(r"C:\CodingProjects\bioctree\test-data\mesh")

def main():
    """Copy LIC textures to test-data/mesh directory."""
    print("=== Copying LIC Textures to test-data/mesh ===\n")
    
    # Ensure target directory exists
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    
    # Define files to copy
    lic_files = [
        'lh_lic_texture.png',           # Left hemisphere LIC texture
        'rh_lic_texture.png',           # Right hemisphere LIC texture
        'lh_pial_with_uv_lic.png',      # GLB pipeline LH texture
        'rh_pial_with_uv_lic.png',      # GLB pipeline RH texture
        'bilateral_pial_with_uv_lic.png' # Bilateral texture
    ]
    
    support_files = [
        'lh_uv_coords.npz',             # UV coordinates
        'rh_uv_coords.npz',             # RH UV coordinates
        'lh_uv_coords.mat',             # MATLAB format UV coords
        'lh_visualization.png',         # Analysis visualization
        'rh_visualization.png',         # RH visualization
        'lh_vector_field_uv.npz',       # Vector field data
        'rh_vector_field_uv.npz'        # RH vector field data
    ]
    
    glb_files = [
        'lh_pial_with_lic.glb',         # LH GLB with embedded LIC
        'rh_pial_with_lic.glb',         # RH GLB with embedded LIC
        'bilateral_pial_with_lic.glb'   # Bilateral GLB with embedded LIC
    ]
    
    # Copy files
    copied_lic = copy_files(lic_files, "LIC texture files")
    copied_support = copy_files(support_files, "supporting files")
    copied_glb = copy_files(glb_files, "GLB files with embedded textures")
    
    # Create README
    create_readme()
    
    # Summary
    print("\n=== Copy Summary ===")
    print(f"LIC textures copied: {copied_lic}/{len(lic_files)}")
    print(f"Support files copied: {copied_support}/{len(support_files)}")
    print(f"GLB files copied: {copied_glb}/{len(glb_files)}")
    print(f"Target directory: {TARGET_DIR}")
    
    if copied_lic == 0:
        print("\n⚠️  No LIC textures found!")
        print("Make sure to run the LIC generation pipeline first:")
        print("  1. MATLAB: export_surfaces_for_lic_glb")
        print("  2. Python: python generate_lic_texture.py")
        print("  3. Or: run_lic_generation.bat")
    else:
        print("\n✅ LIC textures successfully copied to test-data/mesh/")
        print("The textures are ready for use in three.js visualization!")
        
        # Open directory on Windows
        if os.name == 'nt' and (copied_lic > 0 or copied_glb > 0):
            try:
                os.startfile(str(TARGET_DIR))
            except:
                pass

def copy_files(file_list, category_name):
    """Copy a list of files from source to target directory."""
    print(f"Copying {category_name}...")
    copied_count = 0
    
    for filename in file_list:
        source_file = SOURCE_DIR / filename
        target_file = TARGET_DIR / filename
        
        if source_file.exists():
            try:
                shutil.copy2(source_file, target_file)
                print(f"  ✓ Copied: {filename}")
                copied_count += 1
            except Exception as e:
                print(f"  ✗ Failed to copy {filename}: {e}")
        else:
            print(f"  - Not found: {filename}")
    
    return copied_count

def create_readme():
    """Create README file for the copied LIC textures."""
    readme_content = f"""# LIC Textures for Cortical Visualization

This directory contains Line Integral Convolution (LIC) textures generated
from FreeSurfer cortical surfaces for three.js visualization.

## LIC Texture Files

### Main LIC Textures (4096×2048 PNG)
- `lh_lic_texture.png` - Left hemisphere LIC texture
- `rh_lic_texture.png` - Right hemisphere LIC texture

### GLB Pipeline Textures
- `lh_pial_with_uv_lic.png` - LH texture from GLB pipeline
- `rh_pial_with_uv_lic.png` - RH texture from GLB pipeline
- `bilateral_pial_with_uv_lic.png` - Combined hemispheres texture

## GLB Files with Embedded Textures
- `lh_pial_with_lic.glb` - LH mesh with embedded LIC texture
- `rh_pial_with_lic.glb` - RH mesh with embedded LIC texture
- `bilateral_pial_with_lic.glb` - Combined mesh with embedded LIC texture

## Supporting Files
- `lh_uv_coords.npz` - UV coordinates for texture mapping
- `lh_visualization.png` - Analysis and visualization plots
- `lh_vector_field_uv.npz` - Vector field data

## Usage in three.js

### Using PNG Textures
```javascript
const textureLoader = new THREE.TextureLoader();
const licTexture = textureLoader.load("lh_lic_texture.png");
const material = new THREE.MeshBasicMaterial({{ map: licTexture }});
```

### Using GLB Files
```javascript
import {{ GLTFLoader }} from 'three/examples/jsm/loaders/GLTFLoader.js';

const loader = new GLTFLoader();
loader.load("lh_pial_with_lic.glb", (gltf) => {{
    scene.add(gltf.scene);
}});
```

## Generation Pipeline

These textures were generated using:
1. FreeSurfer cortical surfaces (lh.pial, rh.pial)
2. Spherical parameterization (lh.sphere.reg, rh.sphere.reg)
3. Surface-tangent vector field generation
4. Line Integral Convolution (LIC) algorithm

For more details, see the main README_LIC_Pipeline.md file.

Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""
    
    readme_file = TARGET_DIR / 'README_LIC_TEXTURES.md'
    try:
        readme_file.write_text(readme_content, encoding='utf-8')
        print(f"\n  ✓ Created README: {readme_file.name}")
    except Exception as e:
        print(f"\n  ✗ Failed to create README: {e}")

if __name__ == "__main__":
    main()