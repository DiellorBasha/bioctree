#!/usr/bin/env python3
"""
Generate surface-tangent vector field and LIC texture for cortical visualization.

This script:
1. Loads FreeSurfer surfaces directly using nilearn
2. Generates UV coordinates from spherical parameterization
3. Creates synthetic tangent vector fields
4. Rasterizes vector field to UV texture space
5. Generates Line Integral Convolution (LIC) texture
6. Exports results for three.js rendering

Requirements:
- nilearn (for FreeSurfer surface loading)
- numpy, scipy, matplotlib, PIL
- trimesh (optional, for validation)

Usage:
    python generate_lic_texture.py
"""

import numpy as np
import os
from pathlib import Path
import matplotlib.pyplot as plt
from PIL import Image
import scipy.ndimage as ndimage
from nilearn.surface import load_surf_mesh, load_surf_data
from nilearn import plotting

# Try to import numba for JIT compilation
try:
    from numba import njit, prange
    NUMBA_AVAILABLE = True
    print("Numba available - using JIT-compiled LIC kernel for speed")
except ImportError:
    NUMBA_AVAILABLE = False
    print("Numba not available - using pure Python LIC (slower)")

# Configuration
FREESURFER_DIR = Path(r"C:\CodingProjects\bioctree\test-data\freesurfer\fsaverage")
OUTPUT_DIR = Path(r"C:\CodingProjects\bioctree\output\lic_textures")
HEMISPHERE = 'lh'  # 'lh' or 'rh'

# Texture resolution options
# High quality: 4096x2048 (original)
# Medium quality: 2048x1024 (4x faster)  
# Fast: 1024x512 (16x faster)
QUALITY_SETTINGS = {
    'high': (4096, 2048),
    'medium': (2048, 1024), 
    'fast': (1024, 512)
}

QUALITY = 'medium'  # Change to 'high' or 'fast' as needed
TEXTURE_WIDTH, TEXTURE_HEIGHT = QUALITY_SETTINGS[QUALITY]

print(f"Using {QUALITY} quality: {TEXTURE_WIDTH}x{TEXTURE_HEIGHT}")

def load_freesurfer_surfaces():
    """Load FreeSurfer surfaces using nilearn."""
    print("Loading FreeSurfer surfaces...")
    
    # Load cortical surface (for geometry)
    pial_file = FREESURFER_DIR / "surf" / f"{HEMISPHERE}.pial"
    coords_pial, faces_pial = load_surf_mesh(str(pial_file))
    print(f"Loaded {HEMISPHERE}.pial: {coords_pial.shape[0]} vertices, {faces_pial.shape[0]} faces")
    
    # Load spherical surface (for UV parameterization)
    sphere_file = FREESURFER_DIR / "surf" / f"{HEMISPHERE}.sphere"
    coords_sphere, faces_sphere = load_surf_mesh(str(sphere_file))
    print(f"Loaded {HEMISPHERE}.sphere: {coords_sphere.shape[0]} vertices, {faces_sphere.shape[0]} faces")
    
    # Verify vertex counts match
    assert coords_pial.shape[0] == coords_sphere.shape[0], "Vertex counts don't match!"
    assert np.array_equal(faces_pial, faces_sphere), "Face connectivity doesn't match!"
    
    return coords_pial, coords_sphere, faces_pial

def compute_uv_coordinates(coords_sphere):
    """Compute UV coordinates from spherical surface using FreeSurfer convention.
    
    FreeSurfer spherical parameterization:
    u = (atan2(y, x) / 2π) mod 1
    v = asin(z)/π + 0.5
    
    This maps the sphere to a texture where:
    - u=0 corresponds to negative x-axis (longitude -π)
    - u=0.5 corresponds to positive x-axis (longitude 0)
    - v=0 corresponds to south pole (latitude -π/2)
    - v=1 corresponds to north pole (latitude +π/2)
    """
    print("Computing UV coordinates from sphere using FreeSurfer convention...")
    
    x, y, z = coords_sphere[:, 0], coords_sphere[:, 1], coords_sphere[:, 2]
    
    # Normalize to unit sphere (FreeSurfer spheres should be normalized but ensure it)
    norms = np.sqrt(x**2 + y**2 + z**2)
    x = x / (norms + 1e-12)
    y = y / (norms + 1e-12)
    z = z / (norms + 1e-12)
    
    # Clamp z to valid range for arcsin to avoid NaN
    z = np.clip(z, -1.0, 1.0)
    
    # FreeSurfer spherical to UV mapping
    u = (np.arctan2(y, x) / (2 * np.pi)) % 1.0  # [0, 1]
    v = (np.arcsin(z) / np.pi) + 0.5             # [0, 1]
    
    # Clamp to valid range (handle numerical precision at poles)
    u = np.clip(u, 0, 1)
    v = np.clip(v, 0, 1)
    
    uv_coords = np.column_stack([u, v])
    print(f"UV coordinates computed: range u=[{u.min():.3f}, {u.max():.3f}], v=[{v.min():.3f}, {v.max():.3f}]")
    
    return uv_coords

def compute_vertex_normals(coords, faces):
    """Compute vertex normals from surface mesh."""
    print("Computing vertex normals...")
    
    n_vertices = coords.shape[0]
    vertex_normals = np.zeros_like(coords)
    
    # Compute face normals and accumulate to vertices
    for face in faces:
        v0, v1, v2 = coords[face]
        face_normal = np.cross(v1 - v0, v2 - v0)
        
        # Add to each vertex of the face
        vertex_normals[face] += face_normal
    
    # Normalize
    norms = np.linalg.norm(vertex_normals, axis=1, keepdims=True)
    vertex_normals = vertex_normals / (norms + 1e-12)
    
    return vertex_normals

def create_rotational_vector_field(coords, normals):
    """Create a synthetic rotational tangent vector field."""
    print("Creating rotational vector field...")
    
    # Rotational field around Z-axis: v = z_hat × n
    z_hat = np.array([0, 0, 1])
    vectors_3d = np.cross(z_hat, normals)
    
    # Normalize to unit vectors
    norms = np.linalg.norm(vectors_3d, axis=1, keepdims=True)
    vectors_3d = vectors_3d / (norms + 1e-12)
    
    return vectors_3d

def create_gradient_vector_field(coords, normals):
    """Create vector field from gradient of synthetic scalar field."""
    print("Creating gradient-based vector field...")
    
    # Create synthetic scalar field (sum of Gaussians)
    centers = [
        [30, 0, 40],    # Frontal
        [-20, -30, 20], # Temporal
        [0, -50, 30],   # Occipital
    ]
    
    scalar_field = np.zeros(coords.shape[0])
    for center in centers:
        center = np.array(center)
        distances = np.linalg.norm(coords - center, axis=1)
        scalar_field += np.exp(-distances**2 / (20**2))
    
    # Compute gradient (simplified: use neighboring vertices)
    gradient = np.zeros_like(coords)
    # This is a simplified gradient computation
    # In practice, you'd use the mesh connectivity for better accuracy
    for i in range(len(coords)):
        # Use a small perturbation to estimate gradient
        eps = 1.0
        grad_x = scalar_field[min(i+1, len(coords)-1)] - scalar_field[max(i-1, 0)]
        gradient[i, 0] = grad_x / (2 * eps)
    
    # Project to tangent plane
    dot_products = np.sum(gradient * normals, axis=1, keepdims=True)
    tangent_vectors = gradient - dot_products * normals
    
    # Normalize
    norms = np.linalg.norm(tangent_vectors, axis=1, keepdims=True)
    tangent_vectors = tangent_vectors / (norms + 1e-12)
    
    return tangent_vectors

def spherical_tangent_basis(u, v, eps=1e-3):
    """Compute tangent basis vectors at UV point on sphere using FreeSurfer convention.
    
    FreeSurfer UV parameterization:
    u = (atan2(y, x) / 2π) mod 1
    v = asin(z)/π + 0.5
    
    This function inverts the UV mapping to get sphere coordinates, then
    computes the tangent basis vectors for the parameterization.
    """
    # Convert UV back to spherical coordinates (FreeSurfer convention)
    theta = (u * 2 * np.pi) - np.pi  # [-π, π] longitude
    phi = (v - 0.5) * np.pi          # [-π/2, π/2] latitude
    
    # Clamp phi to valid range for numerical stability
    phi = np.clip(phi, -np.pi/2 + 1e-6, np.pi/2 - 1e-6)
    
    # Sphere point in Cartesian coordinates
    x = np.cos(phi) * np.cos(theta)
    y = np.cos(phi) * np.sin(theta)
    z = np.sin(phi)
    p = np.array([x, y, z])
    
    # Compute tangent vectors by finite differences
    # du direction (longitude tangent)
    theta_u = ((u + eps) * 2 * np.pi) - np.pi
    phi_u = phi  # latitude unchanged for u direction
    x_u = np.cos(phi_u) * np.cos(theta_u)
    y_u = np.cos(phi_u) * np.sin(theta_u)
    z_u = np.sin(phi_u)
    p_u = np.array([x_u, y_u, z_u]) - p
    
    # dv direction (latitude tangent)
    theta_v = theta  # longitude unchanged for v direction
    phi_v = np.clip(((v + eps) - 0.5) * np.pi, -np.pi/2 + 1e-6, np.pi/2 - 1e-6)
    x_v = np.cos(phi_v) * np.cos(theta_v)
    y_v = np.cos(phi_v) * np.sin(theta_v)
    z_v = np.sin(phi_v)
    p_v = np.array([x_v, y_v, z_v]) - p
    
    # Normalize tangent vectors
    tu = p_u / (np.linalg.norm(p_u) + 1e-12)
    
    # Gram-Schmidt orthogonalization
    p_v = p_v - np.dot(p_v, tu) * tu
    tv = p_v / (np.linalg.norm(p_v) + 1e-12)
    
    # Normal vector (should point outward from sphere)
    normal = p / (np.linalg.norm(p) + 1e-12)
    
    return normal, tu, tv

def rasterize_vector_field_to_uv(coords, uv_coords, vectors_3d, coords_sphere):
    """Rasterize 3D vector field to UV texture space."""
    print("Rasterizing vector field to UV texture...")
    
    # Initialize UV texture arrays
    vector_field_uv = np.zeros((TEXTURE_HEIGHT, TEXTURE_WIDTH, 2), dtype=np.float32)
    count_texture = np.zeros((TEXTURE_HEIGHT, TEXTURE_WIDTH), dtype=np.float32)
    
    # Convert UV coordinates to pixel coordinates
    u_pixels = (uv_coords[:, 0] * (TEXTURE_WIDTH - 1)).astype(int)
    v_pixels = (uv_coords[:, 1] * (TEXTURE_HEIGHT - 1)).astype(int)
    
    # Sample subset of vertices for efficiency
    sample_indices = np.arange(0, len(coords), max(1, len(coords) // 50000))
    
    for i in sample_indices:
        u, v = uv_coords[i]
        x_pix, y_pix = u_pixels[i], v_pixels[i]
        
        # Ensure pixel coordinates are in bounds
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
        # Simple diffusion to fill gaps
        kernel = np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]]) / 4.0
        for channel in range(2):
            smoothed = ndimage.convolve(vector_field_uv[:, :, channel], kernel, mode='wrap')
            vector_field_uv[~mask, channel] = smoothed[~mask]
        
        # Update mask
        magnitude = np.linalg.norm(vector_field_uv, axis=2)
        mask = magnitude > 0
    
    return vector_field_uv

# Numba-optimized LIC kernel for massive speedup
if NUMBA_AVAILABLE:
    @njit(parallel=True, fastmath=True)
    def lic_numba(noise, vec, num_steps=16, step_size=1.6):
        """Fast JIT-compiled LIC kernel with multithreading support."""
        H, W = noise.shape
        out = np.zeros((H, W), dtype=np.float32)
        
        for y in prange(H):  # Parallel over rows
            for x in range(W):
                total_value = 0.0
                total_weight = 0.0
                
                # Integrate forward and backward along streamline
                for direction in (-1.0, 1.0):
                    curr_x = float(x)
                    curr_y = float(y)
                    
                    for _ in range(num_steps):
                        # Handle wrapping/clamping for pixel coordinates
                        px = int(curr_x) % W
                        py = int(curr_y) if curr_y >= 0 else int(curr_y) - 1
                        if py < 0:
                            py += H
                        if py >= H:
                            py -= H
                        
                        # Sample noise at current position
                        total_value += noise[py, px]
                        total_weight += 1.0
                        
                        # Get vector field at current position
                        vx = vec[py, px, 0]
                        vy = vec[py, px, 1]
                        magnitude = (vx*vx + vy*vy)**0.5 + 1e-6
                        
                        # Normalize and step
                        vx_norm = vx / magnitude
                        vy_norm = vy / magnitude
                        
                        curr_x += direction * vx_norm * step_size
                        curr_y += direction * vy_norm * step_size
                
                # Store normalized result
                out[y, x] = total_value / total_weight
        
        # Normalize to 0-255 range
        out_min = out.min()
        out_max = out.max()
        out = (out - out_min) / (out_max - out_min + 1e-12)
        return (out * 255.0).astype(np.uint8)

def generate_lic_texture(vector_field_uv, num_steps=16, step_size=1.6):
    """Generate Line Integral Convolution texture with optimizations."""
    print("Generating LIC texture...")
    
    height, width = vector_field_uv.shape[:2]
    
    # Ensure arrays are float32 and C-contiguous for Numba
    vector_field_uv = np.ascontiguousarray(vector_field_uv.astype(np.float32))
    
    # Generate white noise
    np.random.seed(42)  # For reproducibility
    noise = np.random.random((height, width)).astype(np.float32)
    noise = np.ascontiguousarray(noise)
    
    # Optional: Pre-smooth noise and vectors for better quality with fewer steps
    if QUALITY in ['fast', 'medium']:
        print("Pre-smoothing noise and vector field for better quality...")
        noise = ndimage.gaussian_filter(noise, sigma=0.8)
        for i in range(2):
            vector_field_uv[:, :, i] = ndimage.gaussian_filter(vector_field_uv[:, :, i], sigma=1.0)
    
    # Use optimized kernel if available
    if NUMBA_AVAILABLE:
        print(f"Using Numba JIT kernel (parallel) with {num_steps} steps, step size {step_size}")
        lic_texture = lic_numba(noise, vector_field_uv, num_steps=num_steps, step_size=step_size)
    else:
        print(f"Using pure Python kernel with {num_steps} steps, step size {step_size}")
        lic_texture = generate_lic_texture_python(noise, vector_field_uv, num_steps, step_size)
    
    return lic_texture

def generate_lic_texture_python(noise, vector_field_uv, num_steps=16, step_size=1.6):
    """Fallback pure Python LIC implementation."""
    height, width = vector_field_uv.shape[:2]
    lic_texture = np.zeros((height, width), dtype=np.float32)
    
    print("Computing LIC streamlines (Python fallback)...")
    for y in range(height):
        if y % 100 == 0:
            print(f"Processing row {y}/{height}")
            
        for x in range(width):
            # Integrate forward and backward along streamline
            total_value = 0.0
            total_weight = 0.0
            
            for direction in [-1, 1]:  # Forward and backward
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

def save_results(uv_coords, vector_field_uv, lic_texture):
    """Save all results to files."""
    print("Saving results...")
    
    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # Save UV coordinates
    np.savez(OUTPUT_DIR / f"{HEMISPHERE}_uv_coords.npz", uv=uv_coords)
    print(f"Saved UV coordinates to {OUTPUT_DIR / f'{HEMISPHERE}_uv_coords.npz'}")
    
    # Save vector field
    np.savez(OUTPUT_DIR / f"{HEMISPHERE}_vector_field_uv.npz", vectors=vector_field_uv)
    print(f"Saved vector field to {OUTPUT_DIR / f'{HEMISPHERE}_vector_field_uv.npz'}")
    
    # Save LIC texture as PNG
    lic_image = Image.fromarray(lic_texture, mode='L')
    lic_path = OUTPUT_DIR / f"{HEMISPHERE}_lic_texture.png"
    lic_image.save(lic_path)
    print(f"Saved LIC texture to {lic_path}")
    
    # Create visualization plots
    create_visualizations(vector_field_uv, lic_texture)

def create_visualizations(vector_field_uv, lic_texture):
    """Create visualization plots."""
    print("Creating visualizations...")
    
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    
    # Vector field magnitude
    magnitude = np.linalg.norm(vector_field_uv, axis=2)
    im1 = axes[0, 0].imshow(magnitude, cmap='viridis', aspect='auto')
    axes[0, 0].set_title('Vector Field Magnitude')
    axes[0, 0].set_xlabel('U (longitude)')
    axes[0, 0].set_ylabel('V (latitude)')
    plt.colorbar(im1, ax=axes[0, 0])
    
    # Vector field direction (as HSV)
    angle = np.arctan2(vector_field_uv[:, :, 1], vector_field_uv[:, :, 0])
    angle_normalized = (angle + np.pi) / (2 * np.pi)  # Normalize to [0, 1]
    hsv_image = np.zeros((TEXTURE_HEIGHT, TEXTURE_WIDTH, 3))
    hsv_image[:, :, 0] = angle_normalized  # Hue = direction
    hsv_image[:, :, 1] = 1.0  # Full saturation
    hsv_image[:, :, 2] = magnitude / (magnitude.max() + 1e-12)  # Value = magnitude
    
    # Convert HSV to RGB for display
    from matplotlib.colors import hsv_to_rgb
    rgb_image = hsv_to_rgb(hsv_image)
    axes[0, 1].imshow(rgb_image, aspect='auto')
    axes[0, 1].set_title('Vector Field Direction (Hue=direction, Brightness=magnitude)')
    axes[0, 1].set_xlabel('U (longitude)')
    axes[0, 1].set_ylabel('V (latitude)')
    
    # LIC texture
    im3 = axes[1, 0].imshow(lic_texture, cmap='gray', aspect='auto')
    axes[1, 0].set_title('LIC Texture')
    axes[1, 0].set_xlabel('U (longitude)')
    axes[1, 0].set_ylabel('V (latitude)')
    plt.colorbar(im3, ax=axes[1, 0])
    
    # Vector field quiver plot (subsampled)
    skip = 100  # Show every 100th vector
    y_coords, x_coords = np.mgrid[0:TEXTURE_HEIGHT:skip, 0:TEXTURE_WIDTH:skip]
    u_vectors = vector_field_uv[::skip, ::skip, 0]
    v_vectors = vector_field_uv[::skip, ::skip, 1]
    
    axes[1, 1].quiver(x_coords, y_coords, u_vectors, v_vectors, 
                     magnitude[::skip, ::skip], cmap='viridis', scale=20)
    axes[1, 1].set_title('Vector Field (subsampled)')
    axes[1, 1].set_xlabel('U (longitude)')
    axes[1, 1].set_ylabel('V (latitude)')
    axes[1, 1].invert_yaxis()  # Flip Y to match image orientation
    
    plt.tight_layout()
    
    # Save visualization
    vis_path = OUTPUT_DIR / f"{HEMISPHERE}_visualization.png"
    plt.savefig(vis_path, dpi=150, bbox_inches='tight')
    print(f"Saved visualization to {vis_path}")
    plt.close()

def main():
    """Main pipeline execution."""
    print("=== Surface-Tangent Vector Field and LIC Texture Generation ===")
    print(f"Processing hemisphere: {HEMISPHERE}")
    print(f"Texture resolution: {TEXTURE_WIDTH} x {TEXTURE_HEIGHT} ({QUALITY} quality)")
    print(f"Numba acceleration: {'✓ Available' if NUMBA_AVAILABLE else '✗ Not available'}")
    print(f"FreeSurfer directory: {FREESURFER_DIR}")
    print(f"Output directory: {OUTPUT_DIR}")
    
    # Performance estimates
    total_pixels = TEXTURE_WIDTH * TEXTURE_HEIGHT
    if NUMBA_AVAILABLE:
        est_time = total_pixels / 2_000_000  # Rough estimate: 2M pixels/second with Numba
        print(f"Estimated LIC generation time: ~{est_time:.1f} seconds")
    else:
        est_time = total_pixels / 50_000  # Much slower without Numba
        print(f"Estimated LIC generation time: ~{est_time:.1f} seconds (consider installing numba)")
    
    # Load surfaces
    coords_pial, coords_sphere, faces = load_freesurfer_surfaces()
    
    # Compute UV coordinates
    uv_coords = compute_uv_coordinates(coords_sphere)
    
    # Compute vertex normals
    normals = compute_vertex_normals(coords_pial, faces)
    
    # Create vector field (choose one)
    print("\nChoose vector field type:")
    print("1. Rotational field (around Z-axis)")
    print("2. Gradient field (from synthetic scalar)")
    
    # For this example, use rotational field
    vector_field_type = 1
    
    if vector_field_type == 1:
        vectors_3d = create_rotational_vector_field(coords_pial, normals)
    else:
        vectors_3d = create_gradient_vector_field(coords_pial, normals)
    
    # Rasterize to UV space
    vector_field_uv = rasterize_vector_field_to_uv(coords_pial, uv_coords, vectors_3d, coords_sphere)
    
    # Generate LIC texture with optimized parameters
    import time
    start_time = time.time()
    
    # Adjust parameters based on quality setting
    if QUALITY == 'fast':
        num_steps, step_size = 12, 1.8  # Fewer steps, longer strides
    elif QUALITY == 'medium':
        num_steps, step_size = 16, 1.6  # Balanced
    else:  # high quality
        num_steps, step_size = 24, 1.2  # More steps, shorter strides
    
    lic_texture = generate_lic_texture(vector_field_uv, num_steps=num_steps, step_size=step_size)
    
    elapsed_time = time.time() - start_time
    print(f"LIC generation completed in {elapsed_time:.2f} seconds")
    
    # Save results
    save_results(uv_coords, vector_field_uv, lic_texture)
    
    print("\n=== Pipeline Complete ===")
    print(f"All files saved to: {OUTPUT_DIR}")
    print(f"LIC generation time: {elapsed_time:.2f} seconds")
    
    if not NUMBA_AVAILABLE:
        print("\n💡 Performance Tip:")
        print("Install numba for 10-50x faster LIC generation:")
        print("  pip install numba")
        print("Then re-run this script for much faster processing!")
    
    print("\nNext steps for three.js:")
    print(f"1. Load the cortical surface mesh")
    print(f"2. Apply UV coordinates from {HEMISPHERE}_uv_coords.npz")
    print(f"3. Use {HEMISPHERE}_lic_texture.png as a texture map")
    
    if QUALITY != 'high':
        print(f"\n📐 Quality Setting: {QUALITY} ({TEXTURE_WIDTH}x{TEXTURE_HEIGHT})")
        print("For higher quality, change QUALITY = 'high' in the script")
        print("Or use texture upscaling/mipmapping in three.js")
    
    # Automatically copy textures to test-data/mesh
    try:
        from pathlib import Path
        script_dir = Path(__file__).parent
        copy_script = script_dir / "copy_lic_textures.py"
        if copy_script.exists():
            print(f"\nCopying textures to test-data/mesh...")
            exec(open(copy_script).read())
        else:
            print(f"\nTo copy textures to test-data/mesh, run:")
            print(f"python copy_lic_textures.py")
    except Exception as e:
        print(f"\nTo copy textures to test-data/mesh, run:")
        print(f"python copy_lic_textures.py")

if __name__ == "__main__":
    main()