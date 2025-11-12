#!/usr/bin/env python3
"""
Convert BCT JSON files to GLB format for Three.js visualization
Creates 3D mesh files from BCT graph data with nodes and edges
"""

import numpy as np
import json
import trimesh
from pathlib import Path
import sys

def load_bct_file(bct_path):
    """Load BCT JSON file"""
    with open(bct_path, 'r') as f:
        return json.load(f)

def create_mesh_from_bct(bct_data, node_size=0.5, edge_thickness=0.1, max_edges=1000):
    """Create a 3D mesh from BCT graph data"""
    
    coords = np.array(bct_data['graph']['nodes']['coords'])
    edges_i = bct_data['graph']['edges']['coo_i']
    edges_j = bct_data['graph']['edges']['coo_j']
    
    print(f"  Creating mesh with {len(coords)} nodes and {len(edges_i)} edges...")
    
    # Limit edges for performance
    num_edges = min(len(edges_i), max_edges)
    edges_i = edges_i[:num_edges]
    edges_j = edges_j[:num_edges]
    
    meshes = []
    
    # Create nodes as small spheres
    if len(coords) < 10000:  # Only for smaller datasets
        node_sphere = trimesh.creation.icosphere(subdivisions=1, radius=node_size)
        for i, coord in enumerate(coords):
            if i % 5000 == 0:  # Sample nodes for very large datasets
                node_mesh = node_sphere.copy()
                node_mesh.apply_translation(coord)
                meshes.append(node_mesh)
    
    # Create edges as cylinders
    for i in range(min(num_edges, 500)):  # Limit to 500 edges for GLB size
        start_coord = coords[edges_i[i]]
        end_coord = coords[edges_j[i]]
        
        # Create cylinder between points
        direction = end_coord - start_coord
        length = np.linalg.norm(direction)
        
        if length > 0:
            # Create cylinder
            cylinder = trimesh.creation.cylinder(
                radius=edge_thickness,
                height=length
            )
            
            # Orient cylinder
            cylinder.apply_translation([0, 0, length/2])
            
            # Rotation to align with edge direction
            z_axis = np.array([0, 0, 1])
            direction_norm = direction / length
            
            if not np.allclose(direction_norm, z_axis):
                if np.allclose(direction_norm, -z_axis):
                    # 180 degree rotation
                    cylinder.apply_transform(trimesh.transformations.rotation_matrix(np.pi, [1, 0, 0]))
                else:
                    # General rotation
                    rotation_axis = np.cross(z_axis, direction_norm)
                    rotation_axis = rotation_axis / np.linalg.norm(rotation_axis)
                    rotation_angle = np.arccos(np.dot(z_axis, direction_norm))
                    cylinder.apply_transform(trimesh.transformations.rotation_matrix(rotation_angle, rotation_axis))
            
            # Translate to start position
            cylinder.apply_translation(start_coord)
            meshes.append(cylinder)
    
    # Combine all meshes
    if meshes:
        combined_mesh = trimesh.util.concatenate(meshes)
        combined_mesh.rezero()
        return combined_mesh
    else:
        # Fallback: create point cloud
        return create_point_cloud_mesh(coords, node_size)

def create_point_cloud_mesh(coords, point_size=0.8):
    """Create a simple point cloud mesh for large datasets"""
    print(f"  Creating point cloud with {len(coords)} points...")
    
    # Sample points for very large datasets
    if len(coords) > 5000:
        indices = np.random.choice(len(coords), 5000, replace=False)
        coords = coords[indices]
    
    # Create spheres for each point
    sphere = trimesh.creation.icosphere(subdivisions=1, radius=point_size)
    meshes = []
    
    for coord in coords:
        point_mesh = sphere.copy()
        point_mesh.apply_translation(coord)
        meshes.append(point_mesh)
    
    combined_mesh = trimesh.util.concatenate(meshes)
    combined_mesh.rezero()
    return combined_mesh

def convert_bct_to_glb(bct_path, output_path):
    """Convert a single BCT file to GLB format"""
    print(f"Converting {bct_path.name}...")
    
    try:
        # Load BCT data
        bct_data = load_bct_file(bct_path)
        
        # Determine mesh creation strategy based on size
        node_count = bct_data['graph']['nodes']['count']
        edge_count = bct_data['graph']['edges']['count']
        
        print(f"  BCT data: {node_count:,} nodes, {edge_count:,} edges")
        
        if node_count > 50000:
            # Large dataset - point cloud only
            coords = np.array(bct_data['graph']['nodes']['coords'])
            mesh = create_point_cloud_mesh(coords, point_size=1.0)
        else:
            # Smaller dataset - full mesh with edges
            mesh = create_mesh_from_bct(bct_data, node_size=0.8, edge_thickness=0.2)
        
        # Add vertex colors based on position (optional)
        if hasattr(mesh, 'vertices') and len(mesh.vertices) > 0:
            # Color based on Z coordinate (height)
            z_coords = mesh.vertices[:, 2]
            z_norm = (z_coords - z_coords.min()) / (z_coords.max() - z_coords.min() + 1e-8)
            
            # Create color gradient (blue to red)
            colors = np.zeros((len(mesh.vertices), 4))
            colors[:, 0] = z_norm  # Red channel
            colors[:, 2] = 1 - z_norm  # Blue channel
            colors[:, 3] = 1.0  # Alpha
            
            mesh.visual.vertex_colors = colors
        
        # Export to GLB
        mesh.export(str(output_path))
        file_size = output_path.stat().st_size / (1024 * 1024)
        
        print(f"  ✅ Exported: {output_path.name} ({file_size:.1f} MB)")
        return True
        
    except Exception as e:
        print(f"  ❌ Error converting {bct_path.name}: {e}")
        return False

def main():
    """Convert all BCT files to GLB format"""
    
    # Paths
    bct_dir = Path("app/test-data")
    output_dir = Path("app/data")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print("🔄 Converting BCT files to GLB format for Three.js...")
    print(f"📁 Input: {bct_dir}")
    print(f"📁 Output: {output_dir}")
    
    # Find all BCT files
    bct_files = list(bct_dir.glob("*.bct"))
    
    if not bct_files:
        print("❌ No BCT files found in app/test-data/")
        return
    
    print(f"📊 Found {len(bct_files)} BCT files to convert")
    
    # Convert each BCT file
    successful_conversions = 0
    
    for bct_file in bct_files:
        # Skip the simple example file
        if "example.bct" in bct_file.name:
            continue
            
        # Create output filename
        glb_filename = bct_file.name.replace(".bct", ".glb")
        glb_path = output_dir / glb_filename
        
        # Convert
        if convert_bct_to_glb(bct_file, glb_path):
            successful_conversions += 1
    
    print(f"\n🎉 Conversion complete!")
    print(f"✅ Successfully converted {successful_conversions} files")
    print(f"📁 GLB files saved to: {output_dir}")
    
    # List created files
    glb_files = list(output_dir.glob("*.glb"))
    if glb_files:
        print(f"\n📄 Created GLB files:")
        for glb_file in glb_files:
            size_mb = glb_file.stat().st_size / (1024 * 1024)
            print(f"  - {glb_file.name} ({size_mb:.1f} MB)")
    
    print(f"\n🎯 You can now load these GLB files in your Three.js BCT viewer!")

if __name__ == "__main__":
    main()