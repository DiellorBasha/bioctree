#!/usr/bin/env python3
"""
Generate LIC textures for GLB-format cortical surfaces.

This script:
1. Loads GLB files with embedded UV coordinates
2. Generates surface-tangent vector fields
3. Creates LIC textures
4. Embeds LIC textures back into GLB files
5. Exports final GLB files ready for three.js

Requirements:
- pygltflib (pip install pygltflib)
- numpy, scipy, matplotlib, PIL
- trimesh (optional)

Usage:
    python generate_lic_texture_glb.py
"""

import numpy as np
import os
from pathlib import Path
import matplotlib.pyplot as plt
from PIL import Image
import scipy.ndimage as ndimage
import json
import base64
from pygltflib import GLTF2, BufferView, Buffer, Image as GLTFImage, Texture, Sampler, Material

# Configuration
OUTPUT_DIR = Path(r"C:\CodingProjects\bioctree\output\lic_textures")
TEXTURE_WIDTH = 4096
TEXTURE_HEIGHT = 2048

def load_glb_surface(glb_path):
    """Load surface data from GLB file."""
    print(f"Loading GLB file: {glb_path}")
    
    try:
        gltf = GLTF2.load(str(glb_path))
    except Exception as e:
        print(f"Error loading GLB: {e}")
        return None, None, None, None
    
    # Get the first mesh
    if not gltf.meshes or not gltf.meshes[0].primitives:
        print("No mesh data found in GLB file")
        return None, None, None, None
    
    primitive = gltf.meshes[0].primitives[0]
    
    # Extract vertices
    position_accessor = gltf.accessors[primitive.attributes.POSITION]
    vertices = get_accessor_data(gltf, position_accessor).reshape(-1, 3)
    
    # Extract faces
    indices_accessor = gltf.accessors[primitive.indices]
    faces = get_accessor_data(gltf, indices_accessor).reshape(-1, 3)
    
    # Extract UV coordinates
    uv_coords = None
    if hasattr(primitive.attributes, 'TEXCOORD_0') and primitive.attributes.TEXCOORD_0 is not None:
        uv_accessor = gltf.accessors[primitive.attributes.TEXCOORD_0]
        uv_coords = get_accessor_data(gltf, uv_accessor).reshape(-1, 2)
    
    # Extract normals
    normals = None
    if hasattr(primitive.attributes, 'NORMAL') and primitive.attributes.NORMAL is not None:
        normal_accessor = gltf.accessors[primitive.attributes.NORMAL]
        normals = get_accessor_data(gltf, normal_accessor).reshape(-1, 3)
    
    print(f"Loaded: {len(vertices)} vertices, {len(faces)} faces")
    if uv_coords is not None:
        print(f"UV coordinates: {len(uv_coords)} points")
    if normals is not None:
        print(f"Normals: {len(normals)} vectors")
    
    return vertices, faces, uv_coords, normals

def get_accessor_data(gltf, accessor):
    """Extract data from a glTF accessor."""
    buffer_view = gltf.bufferViews[accessor.bufferView]
    buffer = gltf.buffers[buffer_view.buffer]
    
    # Get buffer data
    if hasattr(buffer, 'data'):
        buffer_data = buffer.data
    elif hasattr(buffer, 'uri'):
        # Handle data URI
        if buffer.uri.startswith('data:'):
            header, data = buffer.uri.split(',')
            buffer_data = base64.b64decode(data)
        else:
            # External file (not typical for GLB)
            with open(buffer.uri, 'rb') as f:
                buffer_data = f.read()
    else:
        raise ValueError("Cannot find buffer data")
    
    # Extract the relevant portion
    start = buffer_view.byteOffset + (accessor.byteOffset or 0)
    
    # Determine data type
    component_type_map = {
        5120: np.int8,      # BYTE
        5121: np.uint8,     # UNSIGNED_BYTE
        5122: np.int16,     # SHORT
        5123: np.uint16,    # UNSIGNED_SHORT
        5125: np.uint32,    # UNSIGNED_INT
        5126: np.float32,   # FLOAT
    }
    
    dtype = component_type_map[accessor.componentType]
    
    # Determine number of components
    type_component_count = {
        'SCALAR': 1,
        'VEC2': 2,
        'VEC3': 3,
        'VEC4': 4,
        'MAT2': 4,
        'MAT3': 9,
        'MAT4': 16,
    }
    
    components = type_component_count[accessor.type]
    total_elements = accessor.count * components
    
    # Extract and convert data
    data = np.frombuffer(buffer_data[start:start + total_elements * dtype().itemsize], 
                        dtype=dtype)
    
    return data

def compute_vertex_normals_numpy(vertices, faces):
    """Compute vertex normals from mesh."""
    n_vertices = len(vertices)
    vertex_normals = np.zeros_like(vertices)
    
    # Compute face normals
    v0 = vertices[faces[:, 0]]
    v1 = vertices[faces[:, 1]]
    v2 = vertices[faces[:, 2]]
    
    face_normals = np.cross(v1 - v0, v2 - v0)
    
    # Accumulate to vertices
    for i in range(3):
        np.add.at(vertex_normals, faces[:, i], face_normals)
    
    # Normalize
    norms = np.linalg.norm(vertex_normals, axis=1, keepdims=True)
    vertex_normals = vertex_normals / (norms + 1e-12)
    
    return vertex_normals

def create_rotational_vector_field(vertices, normals):
    """Create rotational vector field around Z-axis."""
    print("Creating rotational vector field...")
    
    z_hat = np.array([0, 0, 1])
    vectors_3d = np.cross(z_hat, normals)
    
    # Normalize
    norms = np.linalg.norm(vectors_3d, axis=1, keepdims=True)
    vectors_3d = vectors_3d / (norms + 1e-12)
    
    return vectors_3d

def create_gradient_vector_field(vertices, normals):
    """Create vector field from gradient of synthetic scalar field."""
    print("Creating gradient-based vector field...")
    
    # Create synthetic scalar field (multiple Gaussians)
    centers = np.array([
        [30, 0, 40],    # Frontal
        [-20, -30, 20], # Temporal  
        [0, -50, 30],   # Occipital
        [15, 25, 25],   # Parietal
    ])
    
    scalar_field = np.zeros(len(vertices))
    for center in centers:
        distances = np.linalg.norm(vertices - center, axis=1)
        scalar_field += np.exp(-distances**2 / (25**2))
    
    # Compute gradient using mesh connectivity (simplified)
    # For a more accurate gradient, you'd use the mesh adjacency
    gradient = np.zeros_like(vertices)
    
    # Simple finite difference approximation
    for i in range(len(vertices)):
        # Find nearby vertices (within radius)
        distances = np.linalg.norm(vertices - vertices[i], axis=1)
        neighbors = np.where((distances > 0) & (distances < 5.0))[0]
        
        if len(neighbors) > 0:
            # Weighted gradient estimation
            weights = np.exp(-distances[neighbors]**2 / 2.0)
            scalar_diffs = scalar_field[neighbors] - scalar_field[i]
            position_diffs = vertices[neighbors] - vertices[i]
            
            # Weight by inverse distance
            for j, neighbor in enumerate(neighbors):
                gradient[i] += weights[j] * scalar_diffs[j] * position_diffs[j] / (distances[neighbor] + 1e-6)
    
    # Project to tangent plane
    dot_products = np.sum(gradient * normals, axis=1, keepdims=True)
    tangent_vectors = gradient - dot_products * normals
    
    # Normalize
    norms = np.linalg.norm(tangent_vectors, axis=1, keepdims=True)
    tangent_vectors = tangent_vectors / (norms + 1e-12)
    
    return tangent_vectors

def spherical_tangent_basis(u, v, eps=1e-3):
    """Compute tangent basis at UV point on sphere using FreeSurfer convention.
    
    FreeSurfer UV parameterization:
    u = (atan2(y, x) / 2π) mod 1
    v = asin(z)/π + 0.5
    
    This means:
    - u maps longitude from [-π, π] to [0, 1]
    - v maps latitude from [-π/2, π/2] to [0, 1]
    """
    # Convert UV back to spherical coordinates (FreeSurfer convention)
    theta = u * 2 * np.pi  # [0, 2π] longitude
    phi = (v - 0.5) * np.pi  # [-π/2, π/2] latitude
    
    # Convert to Cartesian coordinates on unit sphere
    x = np.cos(phi) * np.cos(theta)
    y = np.cos(phi) * np.sin(theta)
    z = np.sin(phi)
    p = np.array([x, y, z])
    
    # Compute tangent vectors via finite differences
    # Tangent in u direction (longitude)
    theta_u = (u + eps) * 2 * np.pi
    p_u = np.array([
        np.cos(phi) * np.cos(theta_u),
        np.cos(phi) * np.sin(theta_u),
        np.sin(phi)
    ]) - p
    
    # Tangent in v direction (latitude)
    phi_v = ((v + eps) - 0.5) * np.pi
    p_v = np.array([
        np.cos(phi_v) * np.cos(theta),
        np.cos(phi_v) * np.sin(theta),
        np.sin(phi_v)
    ]) - p
    
    # Orthonormalize Gram-Schmidt
    tu = p_u / (np.linalg.norm(p_u) + 1e-12)
    p_v = p_v - np.dot(p_v, tu) * tu
    tv = p_v / (np.linalg.norm(p_v) + 1e-12)
    
    # Return normalized surface point and tangent basis
    normal = p / (np.linalg.norm(p) + 1e-12)
    
    return normal, tu, tv

def rasterize_vector_field_to_uv(vertices, uv_coords, vectors_3d):
    """Rasterize 3D vector field to UV texture space."""
    print("Rasterizing vector field to UV texture...")
    
    # Initialize texture arrays
    vector_field_uv = np.zeros((TEXTURE_HEIGHT, TEXTURE_WIDTH, 2), dtype=np.float32)
    count_texture = np.zeros((TEXTURE_HEIGHT, TEXTURE_WIDTH), dtype=np.float32)
    
    # Convert UV to pixel coordinates
    u_pixels = (uv_coords[:, 0] * (TEXTURE_WIDTH - 1)).astype(int)
    v_pixels = (uv_coords[:, 1] * (TEXTURE_HEIGHT - 1)).astype(int)
    
    # Sample subset for efficiency
    sample_indices = np.arange(0, len(vertices), max(1, len(vertices) // 50000))
    
    for i in sample_indices:
        u, v = uv_coords[i]
        x_pix, y_pix = u_pixels[i], v_pixels[i]
        
        # Ensure bounds
        if 0 <= x_pix < TEXTURE_WIDTH and 0 <= y_pix < TEXTURE_HEIGHT:
            # Get tangent basis at this UV point
            normal, tu, tv = spherical_tangent_basis(u, v)
            
            # Project 3D vector to UV tangent space
            vec_3d = vectors_3d[i]
            du = np.dot(vec_3d, tu)
            dv = np.dot(vec_3d, tv)
            
            # Accumulate in texture
            vector_field_uv[y_pix, x_pix, 0] += du
            vector_field_uv[y_pix, x_pix, 1] += dv
            count_texture[y_pix, x_pix] += 1.0
    
    # Normalize by counts
    mask = count_texture > 0
    vector_field_uv[mask, 0] /= count_texture[mask]
    vector_field_uv[mask, 1] /= count_texture[mask]
    
    # Fill holes with diffusion
    print("Filling holes in vector field texture...")
    for _ in range(10):
        kernel = np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]]) / 4.0
        for channel in range(2):
            smoothed = ndimage.convolve(vector_field_uv[:, :, channel], kernel, mode='wrap')
            vector_field_uv[~mask, channel] = smoothed[~mask]
        
        # Update mask
        magnitude = np.linalg.norm(vector_field_uv, axis=2)
        mask = magnitude > 0
    
    return vector_field_uv

def generate_lic_texture(vector_field_uv, num_steps=20, step_size=1.0):
    """Generate Line Integral Convolution texture."""
    print("Generating LIC texture...")
    
    height, width = vector_field_uv.shape[:2]
    
    # Generate white noise
    np.random.seed(42)
    noise = np.random.random((height, width)).astype(np.float32)
    
    # Initialize output
    lic_texture = np.zeros((height, width), dtype=np.float32)
    
    print("Computing LIC streamlines...")
    for y in range(height):
        if y % 100 == 0:
            print(f"Processing row {y}/{height}")
            
        for x in range(width):
            # Integrate forward and backward along streamline
            total_value = 0.0
            total_weight = 0.0
            
            for direction in [-1, 1]:
                curr_x, curr_y = float(x), float(y)
                
                for step in range(num_steps):
                    # Get current pixel coordinates
                    px, py = int(curr_x) % width, int(curr_y) % height
                    
                    # Sample noise at current position
                    total_value += noise[py, px]
                    total_weight += 1.0
                    
                    # Get vector field at current position
                    vx, vy = vector_field_uv[py, px]
                    magnitude = np.sqrt(vx*vx + vy*vy) + 1e-6
                    
                    # Normalize and step
                    vx_norm = vx / magnitude
                    vy_norm = vy / magnitude
                    
                    curr_x += direction * vx_norm * step_size
                    curr_y += direction * vy_norm * step_size
            
            # Store normalized result
            lic_texture[y, x] = total_value / max(total_weight, 1.0)
    
    # Normalize to 0-255 range
    lic_texture = (lic_texture - lic_texture.min()) / (lic_texture.max() - lic_texture.min() + 1e-12)
    lic_texture = (lic_texture * 255).astype(np.uint8)
    
    return lic_texture

def embed_lic_in_glb(input_glb_path, output_glb_path, lic_texture):
    """Embed LIC texture in GLB file."""
    print(f"Embedding LIC texture in GLB: {input_glb_path} -> {output_glb_path}")
    
    # Load existing GLB
    gltf = GLTF2.load(str(input_glb_path))
    
    # Convert LIC texture to PNG bytes
    lic_image = Image.fromarray(lic_texture, mode='L')
    png_buffer = io.BytesIO()
    lic_image.save(png_buffer, format='PNG')
    png_data = png_buffer.getvalue()
    
    # Add buffer for image
    buffer_index = len(gltf.buffers)
    image_buffer = Buffer(byteLength=len(png_data))
    image_buffer.data = png_data
    gltf.buffers.append(image_buffer)
    
    # Add buffer view for image
    buffer_view_index = len(gltf.bufferViews)
    image_buffer_view = BufferView(
        buffer=buffer_index,
        byteOffset=0,
        byteLength=len(png_data)
    )
    gltf.bufferViews.append(image_buffer_view)
    
    # Add image
    image_index = len(gltf.images) if gltf.images else 0
    gltf_image = GLTFImage(
        bufferView=buffer_view_index,
        mimeType='image/png'
    )
    if not gltf.images:
        gltf.images = []
    gltf.images.append(gltf_image)
    
    # Add sampler
    sampler_index = len(gltf.samplers) if gltf.samplers else 0
    sampler = Sampler(
        magFilter=9729,  # LINEAR
        minFilter=9987,  # LINEAR_MIPMAP_LINEAR
        wrapS=10497,     # REPEAT
        wrapT=10497      # REPEAT
    )
    if not gltf.samplers:
        gltf.samplers = []
    gltf.samplers.append(sampler)
    
    # Add texture
    texture_index = len(gltf.textures) if gltf.textures else 0
    texture = Texture(
        source=image_index,
        sampler=sampler_index
    )
    if not gltf.textures:
        gltf.textures = []
    gltf.textures.append(texture)
    
    # Add/update material
    if not gltf.materials:
        gltf.materials = []
        material = Material()
        gltf.materials.append(material)
    else:
        material = gltf.materials[0]
    
    # Set LIC texture as base color texture
    if not hasattr(material, 'pbrMetallicRoughness') or material.pbrMetallicRoughness is None:
        material.pbrMetallicRoughness = {}
    
    material.pbrMetallicRoughness['baseColorTexture'] = {'index': texture_index}
    material.pbrMetallicRoughness['metallicFactor'] = 0.0
    material.pbrMetallicRoughness['roughnessFactor'] = 1.0
    
    # Update mesh to use material
    if gltf.meshes and gltf.meshes[0].primitives:
        gltf.meshes[0].primitives[0].material = 0
    
    # Save GLB with embedded texture
    gltf.save(str(output_glb_path))
    print(f"Saved GLB with embedded LIC texture: {output_glb_path}")

def create_visualization(vector_field_uv, lic_texture, output_path):
    """Create visualization plots."""
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    
    # Vector magnitude
    magnitude = np.linalg.norm(vector_field_uv, axis=2)
    im1 = axes[0, 0].imshow(magnitude, cmap='viridis', aspect='auto')
    axes[0, 0].set_title('Vector Field Magnitude')
    axes[0, 0].set_xlabel('U (longitude)')
    axes[0, 0].set_ylabel('V (latitude)')
    plt.colorbar(im1, ax=axes[0, 0])
    
    # Vector direction
    angle = np.arctan2(vector_field_uv[:, :, 1], vector_field_uv[:, :, 0])
    im2 = axes[0, 1].imshow(angle, cmap='hsv', aspect='auto')
    axes[0, 1].set_title('Vector Field Direction')
    axes[0, 1].set_xlabel('U (longitude)')
    axes[0, 1].set_ylabel('V (latitude)')
    plt.colorbar(im2, ax=axes[0, 1])
    
    # LIC texture
    axes[1, 0].imshow(lic_texture, cmap='gray', aspect='auto')
    axes[1, 0].set_title('LIC Texture')
    axes[1, 0].set_xlabel('U (longitude)')
    axes[1, 0].set_ylabel('V (latitude)')
    
    # Vector field quiver (subsampled)
    skip = 100
    y_coords, x_coords = np.mgrid[0:TEXTURE_HEIGHT:skip, 0:TEXTURE_WIDTH:skip]
    u = vector_field_uv[::skip, ::skip, 0]
    v = vector_field_uv[::skip, ::skip, 1]
    axes[1, 1].quiver(x_coords, y_coords, u, v, magnitude[::skip, ::skip], cmap='viridis')
    axes[1, 1].set_title('Vector Field (subsampled)')
    axes[1, 1].set_xlabel('U (longitude)')
    axes[1, 1].set_ylabel('V (latitude)')
    axes[1, 1].invert_yaxis()
    
    plt.tight_layout()
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    plt.close()

def main():
    """Main pipeline execution."""
    print("=== GLB-based LIC Texture Generation ===")
    
    import io  # Import here to avoid conflicts
    
    # Ensure output directory exists
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # Input GLB files (generated by MATLAB script)
    input_glb_files = [
        'lh_pial_with_uv.glb',
        'rh_pial_with_uv.glb',
        'bilateral_pial_with_uv.glb'
    ]
    
    for glb_file in input_glb_files:
        glb_path = OUTPUT_DIR / glb_file
        
        if not glb_path.exists():
            print(f"Skipping {glb_file} - file not found")
            print(f"Run export_surfaces_for_lic_glb.m first to generate GLB files")
            continue
        
        print(f"\n=== Processing {glb_file} ===")
        
        # Load surface data from GLB
        vertices, faces, uv_coords, normals = load_glb_surface(glb_path)
        
        if vertices is None:
            print(f"Failed to load {glb_file}")
            continue
        
        # Compute normals if not available
        if normals is None:
            normals = compute_vertex_normals_numpy(vertices, faces)
        
        # Check UV coordinates
        if uv_coords is None:
            print(f"No UV coordinates found in {glb_file}")
            continue
        
        # Create vector field (rotational by default)
        vectors_3d = create_rotational_vector_field(vertices, normals)
        
        # Rasterize to UV space
        vector_field_uv = rasterize_vector_field_to_uv(vertices, uv_coords, vectors_3d)
        
        # Generate LIC texture
        lic_texture = generate_lic_texture(vector_field_uv, num_steps=16, step_size=1.0)
        
        # Save results
        base_name = glb_file.replace('.glb', '')
        
        # Save LIC texture as PNG
        lic_png_path = OUTPUT_DIR / f"{base_name}_lic.png"
        Image.fromarray(lic_texture, mode='L').save(lic_png_path)
        print(f"Saved LIC texture: {lic_png_path}")
        
        # Save vector field data
        vector_data_path = OUTPUT_DIR / f"{base_name}_vectors.npz"
        np.savez(vector_data_path, vectors=vector_field_uv)
        
        # Create visualization
        vis_path = OUTPUT_DIR / f"{base_name}_visualization.png"
        create_visualization(vector_field_uv, lic_texture, vis_path)
        print(f"Saved visualization: {vis_path}")
        
        # Create GLB with embedded LIC texture
        output_glb_path = OUTPUT_DIR / f"{base_name}_with_lic.glb"
        try:
            embed_lic_in_glb(glb_path, output_glb_path, lic_texture)
        except Exception as e:
            print(f"Warning: Could not embed texture in GLB: {e}")
            print(f"LIC texture saved separately as {lic_png_path}")
    
    print("\n=== GLB LIC Pipeline Complete ===")
    print(f"All files saved to: {OUTPUT_DIR}")
    print("\nGenerated files:")
    print("- *_with_lic.glb: GLB files with embedded LIC textures")
    print("- *_lic.png: Standalone LIC textures")
    print("- *_vectors.npz: Vector field data")
    print("- *_visualization.png: Analysis plots")
    print("\nThree.js usage:")
    print("- Load GLB files directly with embedded textures")
    print("- Or load geometry + apply separate PNG textures")

if __name__ == "__main__":
    main()