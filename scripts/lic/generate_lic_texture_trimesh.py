#!/usr/bin/env python3
"""
Alternative LIC texture generator using trimesh for OBJ files.
This version works with the OBJ files exported from MATLAB.

Usage:
    python generate_lic_texture_trimesh.py
"""

import numpy as np
import trimesh
from PIL import Image
import scipy.ndimage as ndimage
from pathlib import Path
import matplotlib.pyplot as plt

# Configuration
OUTPUT_DIR = Path(r"C:\CodingProjects\bioctree\output\lic_textures")
TEXTURE_WIDTH = 4096
TEXTURE_HEIGHT = 2048

def load_obj_meshes():
    """Load OBJ meshes exported from MATLAB."""
    print("Loading OBJ meshes...")
    
    # Load cortical surface (geometry)
    pial_path = OUTPUT_DIR / "lh_pial.obj"
    if not pial_path.exists():
        raise FileNotFoundError(f"Please run export_surfaces_for_lic.m first to create {pial_path}")
    
    pial_mesh = trimesh.load(str(pial_path), process=False)
    print(f"Loaded lh_pial.obj: {len(pial_mesh.vertices)} vertices, {len(pial_mesh.faces)} faces")
    
    # Load spherical surface (UV parameterization)
    sphere_path = OUTPUT_DIR / "lh_sphere.obj"
    sphere_mesh = trimesh.load(str(sphere_path), process=False)
    print(f"Loaded lh_sphere.obj: {len(sphere_mesh.vertices)} vertices, {len(sphere_mesh.faces)} faces")
    
    # Convert to numpy arrays
    V_pial = np.asarray(pial_mesh.vertices)
    F_pial = np.asarray(pial_mesh.faces, dtype=np.int32)
    V_sphere = np.asarray(sphere_mesh.vertices)
    F_sphere = np.asarray(sphere_mesh.faces, dtype=np.int32)
    
    # Verify compatibility
    assert V_pial.shape[0] == V_sphere.shape[0], "Vertex counts don't match!"
    assert np.array_equal(F_pial, F_sphere), "Face connectivity doesn't match!"
    
    return V_pial, V_sphere, F_pial

def compute_uv_from_sphere(V_sphere):
    """Compute UV coordinates from spherical vertices."""
    print("Computing UV coordinates...")
    
    x, y, z = V_sphere[:, 0], V_sphere[:, 1], V_sphere[:, 2]
    
    # Spherical to UV mapping
    u = (np.arctan2(y, x) / (2 * np.pi)) % 1.0
    v = (np.arcsin(z) / np.pi) + 0.5
    
    # Clamp to valid range
    u = np.clip(u, 0, 1)
    v = np.clip(v, 0, 1)
    
    UV = np.column_stack([u, v])
    print(f"UV range: u=[{u.min():.3f}, {u.max():.3f}], v=[{v.min():.3f}, {v.max():.3f}]")
    
    return UV

def compute_vertex_normals_trimesh(V, F):
    """Compute vertex normals using trimesh."""
    mesh = trimesh.Trimesh(vertices=V, faces=F, process=False)
    return mesh.vertex_normals

def create_rotational_field(V, normals):
    """Create rotational vector field around Z-axis."""
    print("Creating rotational vector field...")
    
    z_hat = np.array([0, 0, 1])
    v3 = np.cross(z_hat, normals)
    
    # Normalize
    norm = np.linalg.norm(v3, axis=1, keepdims=True) + 1e-12
    v3 = v3 / norm
    
    return v3

def spherical_tangent_basis(u, v, eps=1e-3):
    """Compute tangent basis at UV point on sphere."""
    # Convert UV to spherical
    theta = (u * 2 * np.pi) - np.pi
    phi = (v - 0.5) * np.pi
    
    # Sphere position
    x = np.cos(phi) * np.cos(theta)
    y = np.cos(phi) * np.sin(theta)
    z = np.sin(phi)
    p = np.array([x, y, z])
    
    # Tangent vectors via finite differences
    theta_u = ((u + eps) * 2 * np.pi) - np.pi
    p_u = np.array([
        np.cos(phi) * np.cos(theta_u),
        np.cos(phi) * np.sin(theta_u),
        np.sin(phi)
    ]) - p
    
    phi_v = ((v + eps) - 0.5) * np.pi
    p_v = np.array([
        np.cos(phi_v) * np.cos(theta),
        np.cos(phi_v) * np.sin(theta),
        np.sin(phi_v)
    ]) - p
    
    # Orthonormalize
    tu = p_u / (np.linalg.norm(p_u) + 1e-12)
    p_v = p_v - np.dot(p_v, tu) * tu
    tv = p_v / (np.linalg.norm(p_v) + 1e-12)
    
    return p / np.linalg.norm(p), tu, tv

def rasterize_to_uv(V, UV, v3):
    """Rasterize 3D vector field to UV texture."""
    print("Rasterizing vector field to UV texture...")
    
    # Convert UV to pixel coordinates
    uv_pix = np.column_stack([
        (UV[:, 0] * (TEXTURE_WIDTH - 1)).astype(int),
        (UV[:, 1] * (TEXTURE_HEIGHT - 1)).astype(int)
    ])
    
    # Initialize texture arrays
    Vtex = np.zeros((TEXTURE_HEIGHT, TEXTURE_WIDTH, 2), dtype=np.float32)
    Cnt = np.zeros((TEXTURE_HEIGHT, TEXTURE_WIDTH, 1), dtype=np.float32)
    
    # Sample subset for efficiency
    indices = np.arange(V.shape[0])[::5]
    
    for i in indices:
        ui, vi = UV[i]
        x, y = uv_pix[i]
        
        # Ensure bounds
        if 0 <= x < TEXTURE_WIDTH and 0 <= y < TEXTURE_HEIGHT:
            n_hat, tu, tv = spherical_tangent_basis(ui, vi)
            
            # Project 3D vector to UV tangent space
            du = np.dot(v3[i], tu)
            dv = np.dot(v3[i], tv)
            
            Vtex[y, x, 0] += du
            Vtex[y, x, 1] += dv
            Cnt[y, x, 0] += 1.0
    
    # Normalize by counts
    mask = Cnt[:, :, 0] > 0
    Vtex[mask] /= Cnt[mask]
    
    # Diffusion fill for holes
    print("Filling holes...")
    for _ in range(8):
        Vpad = np.pad(Vtex, ((1, 1), (1, 1), (0, 0)), mode='edge')
        nbrs = (Vpad[:-2, 1:-1] + Vpad[2:, 1:-1] + 
                Vpad[1:-1, :-2] + Vpad[1:-1, 2:]) * 0.25
        Vtex[~mask] = nbrs[~mask]
        mask |= ~mask & (np.linalg.norm(nbrs, axis=2) > 0)
    
    return Vtex

def generate_lic(noise, vec, L=20, step=1.0):
    """Generate Line Integral Convolution."""
    print("Generating LIC texture...")
    
    H, W = noise.shape
    out = np.zeros((H, W), dtype=np.float32)
    
    for y in range(H):
        if y % 100 == 0:
            print(f"Processing row {y}/{H}")
            
        for x in range(W):
            s = 0.0
            w = 0.0
            
            # Integrate forward and backward
            for d in (-1, +1):
                xf, yf = float(x), float(y)
                for _ in range(L):
                    vx, vy = vec[int(yf) % H, int(xf) % W]
                    mag = (vx*vx + vy*vy)**0.5 + 1e-6
                    xf += d * (vx / mag) * step
                    yf += d * (vy / mag) * step
                    s += noise[int(yf) % H, int(xf) % W]
                    w += 1.0
            
            out[y, x] = s / max(w, 1.0)
    
    # Normalize to 0-255
    out -= out.min()
    out /= (out.max() + 1e-12)
    return (out * 255).astype(np.uint8)

def create_visualization(Vtex, lic_img):
    """Create visualization plots."""
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    
    # Vector magnitude
    magnitude = np.linalg.norm(Vtex, axis=2)
    im1 = axes[0, 0].imshow(magnitude, cmap='viridis')
    axes[0, 0].set_title('Vector Field Magnitude')
    plt.colorbar(im1, ax=axes[0, 0])
    
    # Vector direction
    angle = np.arctan2(Vtex[:, :, 1], Vtex[:, :, 0])
    im2 = axes[0, 1].imshow(angle, cmap='hsv')
    axes[0, 1].set_title('Vector Field Direction')
    plt.colorbar(im2, ax=axes[0, 1])
    
    # LIC result
    axes[1, 0].imshow(lic_img, cmap='gray')
    axes[1, 0].set_title('LIC Texture')
    
    # Vector field quiver (subsampled)
    skip = 100
    y_coords, x_coords = np.mgrid[0:TEXTURE_HEIGHT:skip, 0:TEXTURE_WIDTH:skip]
    u = Vtex[::skip, ::skip, 0]
    v = Vtex[::skip, ::skip, 1]
    axes[1, 1].quiver(x_coords, y_coords, u, v, magnitude[::skip, ::skip])
    axes[1, 1].set_title('Vector Field (subsampled)')
    axes[1, 1].invert_yaxis()
    
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "lh_lic_visualization.png", dpi=150)
    plt.close()

def main():
    """Main execution."""
    print("=== LIC Texture Generation (Trimesh Version) ===")
    
    # Ensure output directory exists
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    try:
        # Load meshes
        V_pial, V_sphere, F = load_obj_meshes()
        
        # Compute UV coordinates
        UV = compute_uv_from_sphere(V_sphere)
        
        # Compute normals
        normals = compute_vertex_normals_trimesh(V_pial, F)
        
        # Create vector field
        v3 = create_rotational_field(V_pial, normals)
        
        # Rasterize to UV
        Vtex = rasterize_to_uv(V_pial, UV, v3)
        
        # Generate LIC
        np.random.seed(0)
        noise = np.random.random((TEXTURE_HEIGHT, TEXTURE_WIDTH)).astype(np.float32)
        lic_img = generate_lic(noise, Vtex, L=16, step=1.0)
        
        # Save results
        Image.fromarray(lic_img).save(OUTPUT_DIR / "lh_lic_cortex.png")
        np.savez(OUTPUT_DIR / "lh_uvs.npz", uv=UV)
        np.savez(OUTPUT_DIR / "lh_vector_field.npz", vectors=Vtex)
        
        # Create visualization
        create_visualization(Vtex, lic_img)
        
        print(f"\n=== Results saved to {OUTPUT_DIR} ===")
        print("Files created:")
        print("- lh_lic_cortex.png (LIC texture for three.js)")
        print("- lh_uvs.npz (UV coordinates)")
        print("- lh_vector_field.npz (vector field data)")
        print("- lh_lic_visualization.png (analysis plots)")
        
    except FileNotFoundError as e:
        print(f"\nError: {e}")
        print("\nPlease run the MATLAB script 'export_surfaces_for_lic.m' first")
        print("to export the required OBJ files.")

if __name__ == "__main__":
    main()