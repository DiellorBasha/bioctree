"""
Python Demo: Stanford Bunny Pipeline

Python equivalent of the MATLAB demo_bunny_pipeline.m script.
Demonstrates complete graph signal processing pipeline using PyGSP
and the Bioctree Python module.

This demo showcases:
1. Graph construction (Stanford bunny or equivalent)
2. Signal loading and preprocessing
3. Graph Fourier Transform analysis
4. Spatial derivative computation
5. Interactive visualization

Example usage:
    python demo_bunny_pipeline.py
    
Or from Python:
    from bioctree_py.demos.demo_bunny_pipeline import run_demo
    run_demo()
"""

import numpy as np
import matplotlib.pyplot as plt
import sys
import os

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from bioctree_py.gsp import ops, graphs
from bioctree_py.visualization import plot_graph, plot_signal_spectrum
from bioctree_py.io import load_meg_test_data, downsample_signal, create_example_data

def run_demo(meg_data_path: str = None, 
             interactive: bool = True,
             save_plots: bool = False,
             n_vertices: int = 300) -> dict:
    """
    Run the Stanford bunny pipeline demonstration.
    
    Parameters:
    -----------
    meg_data_path : str, optional
        Path to MEG test data file
    interactive : bool, optional
        Create interactive plots (default: True)
    save_plots : bool, optional
        Save plots to files (default: False)
    n_vertices : int, optional
        Number of vertices for graph subsampling (default: 300)
    
    Returns:
    --------
    results : dict
        Dictionary containing computed results
    """
    print("=== Bioctree Python Demo: Stanford Bunny Pipeline ===\n")
    
    # 1. Load MEG data
    print("1. Loading MEG data...")
    if meg_data_path and os.path.exists(meg_data_path):
        try:
            meg_data, info = load_meg_test_data(meg_data_path)
            print(f"   Loaded real MEG data: {info['n_channels']} channels × {info['n_samples']} samples")
        except Exception as e:
            print(f"   Failed to load MEG data: {e}")
            print("   Using synthetic data instead...")
            meg_data, info = create_example_data(n_vertices, 6000, 60.0, 'oscillatory')
    else:
        print("   Creating synthetic MEG data...")
        meg_data, info = create_example_data(n_vertices, 6000, 60.0, 'oscillatory')
    
    # 2. Create Stanford bunny graph
    print("\n2. Creating Stanford bunny graph...")
    try:
        W, coords = graphs.stanford_bunny(n_vertices)
        print(f"   Graph: {W.shape[0]} vertices, {W.nnz//2} edges")
    except Exception as e:
        print(f"   Failed to create bunny graph: {e}")
        print("   Using random geometric graph instead...")
        W, coords = graphs.random_geometric_graph(n_vertices, radius=0.2)
        print(f"   Random graph: {W.shape[0]} vertices, {W.nnz//2} edges")
    
    # 3. Prepare signals
    print("\n3. Mapping signals to graph vertices...")
    
    # Ensure we have the right number of channels
    if meg_data.shape[0] > n_vertices:
        # Select subset of channels
        indices = np.linspace(0, meg_data.shape[0]-1, n_vertices, dtype=int)
        signals = meg_data[indices, :]
    elif meg_data.shape[0] < n_vertices:
        # Pad with zeros or interpolate
        signals = np.zeros((n_vertices, meg_data.shape[1]))
        signals[:meg_data.shape[0], :] = meg_data
    else:
        signals = meg_data
    
    # Downsample for computational efficiency
    target_fs = 60.0
    if info['sampling_freq'] > target_fs:
        signals, time_indices = downsample_signal(signals, info['sampling_freq'], target_fs, axis=1)
        fs = target_fs
    else:
        fs = info['sampling_freq']
        time_indices = np.arange(signals.shape[1])
    
    duration = signals.shape[1] / fs
    print(f"   Mapped {signals.shape[0]} signals, {signals.shape[1]} samples ({duration:.1f}s at {fs:.1f} Hz)")
    print(f"   Signal power range: [{np.min(signals):.2e}, {np.max(signals):.2e}]")
    
    # 4. Graph Fourier Transform analysis
    print("\n4. Graph Fourier Transform analysis...")
    
    # Compute graph Laplacian
    L = ops.graph_laplacian(W, normalized=True)
    
    # Compute GFT for a subset of time points (for efficiency)
    n_time_analysis = min(100, signals.shape[1])
    time_analysis_indices = np.linspace(0, signals.shape[1]-1, n_time_analysis, dtype=int)
    signals_analysis = signals[:, time_analysis_indices]
    
    # Compute GFT
    try:
        gft_coeffs, eigenvalues = ops.graph_fourier_transform(L, signals_analysis)
        print(f"   Computed GFT: {gft_coeffs.shape[0]} frequencies × {gft_coeffs.shape[1]} time points")
        
        # Find dominant frequencies
        power_spectrum = np.mean(np.abs(gft_coeffs)**2, axis=1)
        dominant_freqs = np.argsort(power_spectrum)[-10:][::-1]
        print(f"   Top 5 dominant graph frequencies: {dominant_freqs[:5]}")
        
    except Exception as e:
        print(f"   GFT computation failed: {e}")
        eigenvalues = None
        gft_coeffs = None
    
    # 5. Spatial analysis
    print("\n5. Computing spatial derivatives...")
    
    # Graph gradient
    try:
        # Compute gradient for first time point
        grad = ops.graph_gradient(W, signals[:, 0])
        print(f"   Computed graph gradient: {len(grad)} edges")
        
        # Total variation
        tv = ops.graph_total_variation(W, signals)
        mean_tv = np.mean(tv, axis=1)
        std_tv = np.std(tv, axis=1)
        print(f"   Mean total variation: {np.mean(mean_tv):.2e} ± {np.mean(std_tv):.2e}")
        
    except Exception as e:
        print(f"   Spatial analysis failed: {e}")
        grad = None
        tv = None
    
    # 6. Visualization
    print("\n6. Creating visualizations...")
    
    try:
        # Plot graph with mean signal
        mean_signal = np.mean(signals, axis=1)
        plot_graph(W, coords, signal=mean_signal,
                  title="Stanford Bunny Graph with Mean Signal",
                  interactive=interactive,
                  save_path="bunny_graph.html" if save_plots else None)
        
        # Plot signal spectrum if available
        if eigenvalues is not None and gft_coeffs is not None:
            # Plot spectrum for first signal
            plot_signal_spectrum(eigenvalues, gft_coeffs[:, 0],
                                title="Graph Signal Spectrum",
                                save_path="signal_spectrum.png" if save_plots else None)
        
        # Plot total variation evolution if available
        if tv is not None:
            plt.figure(figsize=(10, 6))
            for i in range(min(5, tv.shape[0])):
                plt.plot(tv[i, :], alpha=0.7, label=f'Vertex {i}')
            plt.xlabel('Time')
            plt.ylabel('Total Variation')
            plt.title('Total Variation Evolution')
            plt.legend()
            plt.grid(True, alpha=0.3)
            
            if save_plots:
                plt.savefig("tv_evolution.png", dpi=300, bbox_inches='tight')
            plt.show()
        
    except Exception as e:
        print(f"   Visualization failed: {e}")
    
    # 7. Summary
    print("\n7. Pipeline Summary:")
    print("   ✓ Graph construction and signal mapping")
    print("   ✓ Downsampling and preprocessing")
    if eigenvalues is not None:
        print("   ✓ Graph Fourier Transform analysis")
    if grad is not None:
        print("   ✓ Spatial derivative computation")
    print("   ✓ Visualization")
    
    # Return results
    results = {
        'graph': {'W': W, 'coords': coords},
        'signals': signals,
        'sampling_freq': fs,
        'eigenvalues': eigenvalues,
        'gft_coeffs': gft_coeffs,
        'total_variation': tv,
        'gradient': grad
    }
    
    return results

def analyze_graph_properties(W, coords):
    """Analyze and display graph properties."""
    print("\n--- Graph Properties ---")
    
    props = graphs.graph_properties(W)
    
    print(f"Vertices: {props['n_vertices']}")
    print(f"Edges: {props['n_edges']}")
    print(f"Density: {props['density']:.4f}")
    print(f"Connected: {props['is_connected']}")
    print(f"Components: {props['n_components']}")
    print(f"Average degree: {props['average_degree']:.2f}")
    print(f"Clustering coefficient: {props['clustering_coefficient']:.4f}")
    print(f"Spectral gap: {props['spectral_gap']:.4f}")

def main():
    """Main function for running as script."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Run Stanford Bunny Pipeline Demo')
    parser.add_argument('--meg-data', type=str, help='Path to MEG data file')
    parser.add_argument('--vertices', type=int, default=300, help='Number of vertices')
    parser.add_argument('--no-interactive', action='store_true', help='Disable interactive plots')
    parser.add_argument('--save-plots', action='store_true', help='Save plots to files')
    
    args = parser.parse_args()
    
    results = run_demo(
        meg_data_path=args.meg_data,
        interactive=not args.no_interactive,
        save_plots=args.save_plots,
        n_vertices=args.vertices
    )
    
    # Analyze graph properties
    analyze_graph_properties(results['graph']['W'], results['graph']['coords'])
    
    print("\n=== Demo completed successfully! ===")

if __name__ == "__main__":
    main()