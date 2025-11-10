#!/usr/bin/env python3
"""
Import high-resolution lh.sphere and rh.sphere from MNE fsaverage
and save to test-data/mesh/ directory for bioctree usage.

Based on fsaverage_web_and_gsp notebook approach.
"""

import os
import numpy as np
import nibabel as nib
import mne
from pathlib import Path
import scipy.io as sio

def main():
    print("=== MNE fsaverage Sphere Importer ===")
    
    # Output directory
    output_dir = Path("test-data/mesh/fsaverage")
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"Output directory: {output_dir}")
    
    # Fetch high-resolution fsaverage from MNE
    print("\nFetching high-resolution fsaverage from MNE...")
    fs_path = mne.datasets.fetch_fsaverage(verbose=True)
    subjects_dir = os.path.dirname(fs_path)
    subject = 'fsaverage'
    surf_dir = os.path.join(subjects_dir, subject, 'surf')
    
    print(f"MNE subjects_dir: {subjects_dir}")
    print(f"Surface directory: {surf_dir}")
    
    # Process both hemispheres
    hemispheres = ['lh', 'rh']
    surface_type = 'sphere'
    
    all_data = {}
    
    for hemi in hemispheres:
        print(f"\n--- Processing {hemi.upper()} hemisphere ---")
        
        # Define file paths
        sphere_path = os.path.join(surf_dir, f'{hemi}.{surface_type}')
        thick_path = os.path.join(surf_dir, f'{hemi}.thickness')
        curv_path = os.path.join(surf_dir, f'{hemi}.curv')
        sulc_path = os.path.join(surf_dir, f'{hemi}.sulc')
        
        print(f"Loading sphere: {sphere_path}")
        
        # Check if sphere file exists
        if not os.path.exists(sphere_path):
            print(f"❌ Sphere file not found: {sphere_path}")
            continue
            
        try:
            # Load geometry using nibabel
            coords, faces = nib.freesurfer.read_geometry(sphere_path)
            coords = coords.astype('float32')
            faces = faces.astype('int64')
            
            print(f"✓ Loaded geometry: {coords.shape[0]:,} vertices, {faces.shape[0]:,} faces")
            
            # Load morphometric data
            morphometrics = {}
            
            # Thickness
            if os.path.exists(thick_path):
                thickness = nib.freesurfer.read_morph_data(thick_path).astype('float32')
                morphometrics['thickness'] = thickness
                print(f"✓ Loaded thickness: min={thickness.min():.3f}, max={thickness.max():.3f}")
            
            # Curvature  
            if os.path.exists(curv_path):
                curvature = nib.freesurfer.read_morph_data(curv_path).astype('float32')
                morphometrics['curvature'] = curvature
                print(f"✓ Loaded curvature: min={curvature.min():.3f}, max={curvature.max():.3f}")
            
            # Sulcal depth
            if os.path.exists(sulc_path):
                sulc = nib.freesurfer.read_morph_data(sulc_path).astype('float32')
                morphometrics['sulc'] = sulc
                print(f"✓ Loaded sulc: min={sulc.min():.3f}, max={sulc.max():.3f}")
            
            # Analyze sphere properties
            sphere_radii = np.linalg.norm(coords, axis=1)
            sphere_center = np.mean(coords, axis=0)
            mean_radius = np.mean(sphere_radii)
            radius_std = np.std(sphere_radii)
            
            print(f"Sphere analysis:")
            print(f"  Center: [{sphere_center[0]:.6f}, {sphere_center[1]:.6f}, {sphere_center[2]:.6f}]")
            print(f"  Mean radius: {mean_radius:.2f}")
            print(f"  Radius std: {radius_std:.6f} ({radius_std/mean_radius*100:.4f}%)")
            print(f"  Radius range: {sphere_radii.min():.2f} - {sphere_radii.max():.2f}")
            
            # Store hemisphere data
            hemi_data = {
                'vertices': coords,
                'faces': faces,
                'sphere_properties': {
                    'center': sphere_center,
                    'mean_radius': mean_radius,
                    'radius_std': radius_std,
                    'radius_range': [sphere_radii.min(), sphere_radii.max()]
                },
                'morphometrics': morphometrics
            }
            
            all_data[hemi] = hemi_data
            
            # Save individual hemisphere files
            
            # 1. MATLAB format (.mat)
            mat_file = output_dir / f'{hemi}_sphere_fsaverage.mat'
            sio.savemat(str(mat_file), {
                'vertices': coords,
                'faces': faces + 1,  # Convert to 1-based indexing for MATLAB
                'morphometrics': morphometrics,
                'sphere_properties': hemi_data['sphere_properties'],
                'source': 'MNE fsaverage high-resolution',
                'hemisphere': hemi,
                'surface_type': surface_type
            })
            print(f"✓ Saved MATLAB file: {mat_file}")
            
            # 2. NumPy format (.npz)
            npz_file = output_dir / f'{hemi}_sphere_fsaverage.npz'
            np.savez_compressed(str(npz_file),
                vertices=coords,
                faces=faces,
                **morphometrics,
                **{f'sphere_{k}': v for k, v in hemi_data['sphere_properties'].items()},
                hemisphere=hemi,
                surface_type=surface_type
            )
            print(f"✓ Saved NumPy file: {npz_file}")
            
            # 3. Individual arrays for easy loading
            coords_file = output_dir / f'{hemi}_sphere_vertices.npy'
            faces_file = output_dir / f'{hemi}_sphere_faces.npy'
            
            np.save(str(coords_file), coords)
            np.save(str(faces_file), faces)
            
            print(f"✓ Saved vertices: {coords_file}")
            print(f"✓ Saved faces: {faces_file}")
            
            # 4. Save morphometric data separately
            for morph_name, morph_data in morphometrics.items():
                morph_file = output_dir / f'{hemi}_{morph_name}.npy'
                np.save(str(morph_file), morph_data)
                print(f"✓ Saved {morph_name}: {morph_file}")
            
        except Exception as e:
            print(f"❌ Error processing {hemi} hemisphere: {e}")
            import traceback
            traceback.print_exc()
            continue
    
    # Save combined data
    if all_data:
        print(f"\n--- Saving combined data ---")
        
        # Combined MATLAB file
        combined_mat = output_dir / 'bilateral_spheres_fsaverage.mat'
        combined_data = {
            'source': 'MNE fsaverage high-resolution',
            'surface_type': surface_type,
            'hemispheres': list(all_data.keys())
        }
        
        for hemi, hemi_data in all_data.items():
            combined_data[f'{hemi}_vertices'] = hemi_data['vertices']
            combined_data[f'{hemi}_faces'] = hemi_data['faces'] + 1  # MATLAB 1-based
            combined_data[f'{hemi}_sphere_properties'] = hemi_data['sphere_properties']
            
            for morph_name, morph_data in hemi_data['morphometrics'].items():
                combined_data[f'{hemi}_{morph_name}'] = morph_data
        
        sio.savemat(str(combined_mat), combined_data)
        print(f"✓ Saved combined MATLAB file: {combined_mat}")
        
        # Summary file
        summary_file = output_dir / 'fsaverage_summary.txt'
        with open(summary_file, 'w') as f:
            f.write("=== MNE fsaverage High-Resolution Sphere Data ===\n")
            f.write(f"Source: {subjects_dir}\n")
            f.write(f"Surface type: {surface_type}\n")
            f.write(f"Processing date: {np.datetime_as_string(np.datetime64('now'), unit='s')}\n\n")
            
            for hemi, hemi_data in all_data.items():
                f.write(f"{hemi.upper()} Hemisphere:\n")
                f.write(f"  Vertices: {hemi_data['vertices'].shape[0]:,}\n")
                f.write(f"  Faces: {hemi_data['faces'].shape[0]:,}\n")
                props = hemi_data['sphere_properties']
                f.write(f"  Mean radius: {props['mean_radius']:.2f}\n")
                f.write(f"  Radius std: {props['radius_std']:.6f}\n")
                f.write(f"  Center: [{props['center'][0]:.6f}, {props['center'][1]:.6f}, {props['center'][2]:.6f}]\n")
                f.write(f"  Morphometrics: {list(hemi_data['morphometrics'].keys())}\n\n")
        
        print(f"✓ Saved summary: {summary_file}")
    
    # Final summary
    print(f"\n=== Import Complete ===")
    print(f"✅ High-resolution fsaverage sphere data imported from MNE")
    print(f"📁 Output directory: {output_dir}")
    print(f"🧠 Hemispheres processed: {len(all_data)}")
    
    if all_data:
        total_vertices = sum(data['vertices'].shape[0] for data in all_data.values())
        total_faces = sum(data['faces'].shape[0] for data in all_data.values())
        print(f"📊 Total vertices: {total_vertices:,}")
        print(f"📊 Total faces: {total_faces:,}")
        
        print(f"\n📋 Files created:")
        for file in sorted(output_dir.glob('*')):
            size_mb = file.stat().st_size / (1024 * 1024)
            print(f"  - {file.name} ({size_mb:.2f} MB)")
    
    print(f"\n🎯 Usage in MATLAB/bioctree:")
    print(f"   load('test-data/mesh/fsaverage/lh_sphere_fsaverage.mat')")
    print(f"   load('test-data/mesh/fsaverage/bilateral_spheres_fsaverage.mat')")
    
    print(f"\n🎯 Usage in Python:")
    print(f"   data = np.load('test-data/mesh/fsaverage/lh_sphere_fsaverage.npz')")
    print(f"   vertices = data['vertices']")
    print(f"   faces = data['faces']")

if __name__ == "__main__":
    # Check required packages
    try:
        import numpy as np
        import nibabel as nib
        import mne
        import scipy.io
        print("✓ All required packages available")
    except ImportError as e:
        print(f"❌ Missing required package: {e}")
        print("Install with: pip install numpy nibabel mne scipy")
        exit(1)
    
    main()