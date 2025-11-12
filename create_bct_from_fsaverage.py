#!/usr/bin/env python3
"""
Create BCT files from existing fsaverage mesh data
Uses existing mesh files in test-data/mesh/fsaverage/ to create PyGSP graphs,
then converts them to BCT format for the JavaScript BCT viewer.
"""

import numpy as np
import json
from pathlib import Path
import sys
import os

# Add project root to path to import utilities
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

def faces_to_unique_edges(faces):
    """Extract unique edges from triangle faces"""
    f = faces.astype(np.int64)
    e01 = np.sort(f[:, [0,1]], axis=1)
    e12 = np.sort(f[:, [1,2]], axis=1)
    e20 = np.sort(f[:, [2,0]], axis=1)
    edges = np.vstack([e01, e12, e20])
    edges = np.unique(edges, axis=0)
    return edges

def build_graph_from_mesh(coords, faces, scheme='geodesic'):
    """Build graph from mesh with various weighting schemes"""
    edges = faces_to_unique_edges(faces)
    vi = coords[edges[:,0]]
    vj = coords[edges[:,1]]
    d = np.linalg.norm(vi - vj, axis=1)
    eps = 1e-12

    if scheme == 'geodesic':
        w = 1.0 / (d + eps)
    elif scheme == 'spherical':
        # For sphere, use great circle distance
        vi_norm = vi / np.linalg.norm(vi, axis=1, keepdims=True)
        vj_norm = vj / np.linalg.norm(vj, axis=1, keepdims=True)
        dot_prod = np.sum(vi_norm * vj_norm, axis=1)
        dot_prod = np.clip(dot_prod, -1, 1)
        spherical_dist = np.arccos(dot_prod)
        w = 1.0 / (spherical_dist + eps)
    elif scheme == 'heat':
        sigma = np.median(d)
        w = np.exp(-(d**2) / (2.0 * sigma**2))
    else:  # unweighted
        w = np.ones_like(d)

    return edges, w

def create_bct_from_mesh(coords, faces, hemisphere, scheme='geodesic'):
    """Create BCT format data from mesh coordinates and faces"""
    
    # Build graph edges and weights
    edges, weights = build_graph_from_mesh(coords, faces, scheme)
    
    # Convert to BCT format
    bct_data = {
        "format": "bct",
        "version": "1.0",
        "metadata": {
            "description": f"fsaverage {hemisphere} hemisphere - {scheme} weighted graph",
            "created": "2024-11-10",
            "hemisphere": hemisphere,
            "weighting_scheme": scheme,
            "vertices": int(coords.shape[0]),
            "faces": int(faces.shape[0]),
            "edges": int(len(edges)),
            "source": "fsaverage_mesh"
        },
        "graph": {
            "nodes": {
                "count": int(coords.shape[0]),
                "coords": coords.tolist()
            },
            "edges": {
                "count": int(len(edges)),
                "coo_i": edges[:, 0].tolist(),
                "coo_j": edges[:, 1].tolist(),
                "coo_w": weights.tolist()
            }
        }
    }
    
    return bct_data

def main():
    """Main function to create BCT files from fsaverage mesh data"""
    
    # Paths
    mesh_dir = Path("test-data/mesh/fsaverage")
    output_dir = Path("app/test-data")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Check if mesh files exist
    hemispheres = ['lh', 'rh']
    
    for hemi in hemispheres:
        coords_file = mesh_dir / f"{hemi}_coords.npy"
        faces_file = mesh_dir / f"{hemi}_faces.npy"
        
        if not coords_file.exists():
            print(f"❌ Missing {coords_file}")
            continue
            
        if not faces_file.exists():
            print(f"❌ Missing {faces_file}")
            continue
            
        print(f"\n🧠 Processing {hemi.upper()} hemisphere...")
        
        # Load mesh data
        coords = np.load(coords_file).astype(np.float32)
        faces = np.load(faces_file).astype(np.int32)
        
        print(f"   Loaded {coords.shape[0]:,} vertices, {faces.shape[0]:,} faces")
        
        # Create BCT files with different weighting schemes
        schemes = ['geodesic', 'spherical', 'heat']
        
        for scheme in schemes:
            print(f"   📊 Creating {scheme} weighted graph...")
            
            try:
                # Create BCT data
                bct_data = create_bct_from_mesh(coords, faces, hemi, scheme)
                
                # Save BCT file
                bct_filename = f"fsaverage_{hemi}_{scheme}.bct"
                bct_path = output_dir / bct_filename
                
                with open(bct_path, 'w') as f:
                    json.dump(bct_data, f, indent=2)
                
                edge_count = bct_data['graph']['edges']['count']
                print(f"      ✅ Saved {bct_filename} ({edge_count:,} edges)")
                
            except Exception as e:
                print(f"      ❌ Error creating {scheme} graph: {e}")
    
    # Create a combined bilateral BCT file
    print(f"\n🔗 Creating bilateral BCT file...")
    
    try:
        # Load both hemispheres with geodesic weighting
        lh_coords = np.load(mesh_dir / "lh_coords.npy").astype(np.float32)
        lh_faces = np.load(mesh_dir / "lh_faces.npy").astype(np.int32)
        rh_coords = np.load(mesh_dir / "rh_coords.npy").astype(np.float32)
        rh_faces = np.load(mesh_dir / "rh_faces.npy").astype(np.int32)
        
        # Build graphs for both hemispheres
        lh_edges, lh_weights = build_graph_from_mesh(lh_coords, lh_faces, 'geodesic')
        rh_edges, rh_weights = build_graph_from_mesh(rh_coords, rh_faces, 'geodesic')
        
        # Offset right hemisphere indices
        rh_offset = len(lh_coords)
        rh_edges_offset = rh_edges + rh_offset
        
        # Combine coordinates and edges
        all_coords = np.vstack([lh_coords, rh_coords])
        all_edges_i = np.concatenate([lh_edges[:, 0], rh_edges_offset[:, 0]])
        all_edges_j = np.concatenate([lh_edges[:, 1], rh_edges_offset[:, 1]])
        all_weights = np.concatenate([lh_weights, rh_weights])
        
        # Create bilateral BCT data
        bilateral_bct = {
            "format": "bct",
            "version": "1.0",
            "metadata": {
                "description": "fsaverage bilateral brain - geodesic weighted graph",
                "created": "2024-11-10",
                "hemisphere": "bilateral",
                "weighting_scheme": "geodesic",
                "vertices_lh": int(len(lh_coords)),
                "vertices_rh": int(len(rh_coords)),
                "vertices_total": int(len(all_coords)),
                "edges_lh": int(len(lh_edges)),
                "edges_rh": int(len(rh_edges)),
                "edges_total": int(len(all_edges_i)),
                "source": "fsaverage_mesh"
            },
            "graph": {
                "nodes": {
                    "count": int(len(all_coords)),
                    "coords": all_coords.tolist()
                },
                "edges": {
                    "count": int(len(all_edges_i)),
                    "coo_i": all_edges_i.tolist(),
                    "coo_j": all_edges_j.tolist(),
                    "coo_w": all_weights.tolist()
                }
            }
        }
        
        # Save bilateral BCT file
        bilateral_path = output_dir / "fsaverage_bilateral_geodesic.bct"
        with open(bilateral_path, 'w') as f:
            json.dump(bilateral_bct, f, indent=2)
        
        print(f"   ✅ Saved fsaverage_bilateral_geodesic.bct ({len(all_edges_i):,} edges)")
        
    except Exception as e:
        print(f"   ❌ Error creating bilateral BCT: {e}")
    
    print(f"\n🎉 BCT file creation complete!")
    print(f"📁 Files saved to: {output_dir}")
    print(f"📊 You can now test these BCT files in the JavaScript viewer")

if __name__ == "__main__":
    main()