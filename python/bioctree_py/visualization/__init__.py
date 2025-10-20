"""
Interactive Visualization Tools

Python visualization utilities for graph signal processing,
providing interactive plots and animations for exploring GSP concepts.

This module leverages matplotlib, plotly, and other visualization libraries
to create publication-quality figures and interactive demonstrations.
"""

import numpy as np
import matplotlib.pyplot as plt
import scipy.sparse as sp
from typing import Optional, Union, Tuple, List
import warnings

# Optional dependencies
try:
    import plotly.graph_objects as go
    import plotly.express as px
    from plotly.subplots import make_subplots
    PLOTLY_AVAILABLE = True
except ImportError:
    PLOTLY_AVAILABLE = False

try:
    import networkx as nx
    NETWORKX_AVAILABLE = True
except ImportError:
    NETWORKX_AVAILABLE = False

def plot_graph(W: Union[np.ndarray, sp.spmatrix], 
               coords: Optional[np.ndarray] = None,
               signal: Optional[np.ndarray] = None,
               title: str = "Graph Visualization",
               node_size: float = 50,
               edge_width: float = 1.0,
               colormap: str = 'viridis',
               interactive: bool = True,
               save_path: Optional[str] = None) -> None:
    """
    Visualize graph structure with optional signal overlay.
    
    Parameters:
    -----------
    W : array_like or sparse matrix
        Adjacency matrix (N x N)
    coords : array_like, optional
        Vertex coordinates (N, 2) or (N, 3)
    signal : array_like, optional
        Signal values to color vertices (N,)
    title : str, optional
        Plot title
    node_size : float, optional
        Size of vertices
    edge_width : float, optional
        Width of edges
    colormap : str, optional
        Colormap for signal visualization
    interactive : bool, optional
        Create interactive plot using Plotly (default: True)
    save_path : str, optional
        Path to save the figure
    """
    if not sp.issparse(W):
        W = sp.csr_matrix(W)
    
    N = W.shape[0]
    
    # Generate coordinates if not provided
    if coords is None:
        if NETWORKX_AVAILABLE:
            G = nx.from_scipy_sparse_array(W)
            coords = np.array(list(nx.spring_layout(G, dim=2).values()))
        else:
            # Fallback: random coordinates
            coords = np.random.rand(N, 2)
    
    # Ensure 2D coordinates for 2D plotting
    if coords.shape[1] > 2:
        coords = coords[:, :2]
    
    if interactive and PLOTLY_AVAILABLE:
        _plot_graph_plotly(W, coords, signal, title, node_size, edge_width, 
                          colormap, save_path)
    else:
        _plot_graph_matplotlib(W, coords, signal, title, node_size, edge_width,
                              colormap, save_path)

def _plot_graph_matplotlib(W, coords, signal, title, node_size, edge_width, 
                          colormap, save_path):
    """Matplotlib-based graph plotting."""
    fig, ax = plt.subplots(figsize=(10, 8))
    
    # Plot edges
    rows, cols = W.nonzero()
    for i, j in zip(rows, cols):
        if i < j:  # Avoid duplicate edges in undirected graphs
            x_coords = [coords[i, 0], coords[j, 0]]
            y_coords = [coords[i, 1], coords[j, 1]]
            ax.plot(x_coords, y_coords, 'k-', alpha=0.3, linewidth=edge_width)
    
    # Plot vertices
    if signal is not None:
        scatter = ax.scatter(coords[:, 0], coords[:, 1], 
                           c=signal, s=node_size, cmap=colormap, 
                           alpha=0.8, edgecolors='black', linewidth=0.5)
        plt.colorbar(scatter, ax=ax, label='Signal Value')
    else:
        ax.scatter(coords[:, 0], coords[:, 1], 
                  s=node_size, color='lightblue', 
                  alpha=0.8, edgecolors='black', linewidth=0.5)
    
    ax.set_title(title, fontsize=14, fontweight='bold')
    ax.set_xlabel('X coordinate')
    ax.set_ylabel('Y coordinate')
    ax.grid(True, alpha=0.3)
    ax.set_aspect('equal')
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
    
    plt.show()

def _plot_graph_plotly(W, coords, signal, title, node_size, edge_width,
                      colormap, save_path):
    """Plotly-based interactive graph plotting."""
    # Extract edges
    rows, cols = W.nonzero()
    edge_x = []
    edge_y = []
    
    for i, j in zip(rows, cols):
        if i < j:  # Avoid duplicates
            edge_x.extend([coords[i, 0], coords[j, 0], None])
            edge_y.extend([coords[i, 1], coords[j, 1], None])
    
    # Create edge trace
    edge_trace = go.Scatter(x=edge_x, y=edge_y,
                           line=dict(width=edge_width, color='rgba(50,50,50,0.3)'),
                           hoverinfo='none',
                           mode='lines')
    
    # Create node trace
    if signal is not None:
        node_trace = go.Scatter(x=coords[:, 0], y=coords[:, 1],
                               mode='markers',
                               hoverinfo='text',
                               text=[f'Vertex {i}<br>Signal: {signal[i]:.3f}' 
                                    for i in range(len(coords))],
                               marker=dict(size=node_size//3,
                                         color=signal,
                                         colorscale=colormap,
                                         colorbar=dict(title="Signal Value"),
                                         line=dict(width=1, color='black')))
    else:
        node_trace = go.Scatter(x=coords[:, 0], y=coords[:, 1],
                               mode='markers',
                               hoverinfo='text',
                               text=[f'Vertex {i}' for i in range(len(coords))],
                               marker=dict(size=node_size//3,
                                         color='lightblue',
                                         line=dict(width=1, color='black')))
    
    # Create figure
    fig = go.Figure(data=[edge_trace, node_trace],
                   layout=go.Layout(title=title,
                                   titlefont_size=16,
                                   showlegend=False,
                                   hovermode='closest',
                                   margin=dict(b=20,l=5,r=5,t=40),
                                   annotations=[ dict(
                                       text="Interactive graph visualization",
                                       showarrow=False,
                                       xref="paper", yref="paper",
                                       x=0.005, y=-0.002,
                                       xanchor='left', yanchor='bottom',
                                       font=dict(color="gray", size=12)
                                   )],
                                   xaxis=dict(showgrid=False, zeroline=False, 
                                            showticklabels=False),
                                   yaxis=dict(showgrid=False, zeroline=False, 
                                            showticklabels=False)))
    
    if save_path:
        fig.write_html(save_path)
    
    fig.show()

def plot_signal_spectrum(eigenvalues: np.ndarray, 
                        signal_coeffs: np.ndarray,
                        title: str = "Graph Signal Spectrum",
                        save_path: Optional[str] = None) -> None:
    """
    Plot graph signal spectrum (GFT coefficients vs eigenvalues).
    
    Parameters:
    -----------
    eigenvalues : array_like
        Graph Laplacian eigenvalues (frequencies)
    signal_coeffs : array_like
        Graph Fourier Transform coefficients
    title : str, optional
        Plot title
    save_path : str, optional
        Path to save the figure
    """
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))
    
    # Magnitude spectrum
    ax1.stem(eigenvalues, np.abs(signal_coeffs), basefmt=' ')
    ax1.set_xlabel('Graph Frequency (Eigenvalue)')
    ax1.set_ylabel('|GFT Coefficient|')
    ax1.set_title(f'{title} - Magnitude')
    ax1.grid(True, alpha=0.3)
    
    # Phase spectrum (if complex)
    if np.iscomplexobj(signal_coeffs):
        ax2.stem(eigenvalues, np.angle(signal_coeffs), basefmt=' ')
        ax2.set_xlabel('Graph Frequency (Eigenvalue)')
        ax2.set_ylabel('Phase (radians)')
        ax2.set_title(f'{title} - Phase')
    else:
        ax2.stem(eigenvalues, signal_coeffs, basefmt=' ')
        ax2.set_xlabel('Graph Frequency (Eigenvalue)')
        ax2.set_ylabel('GFT Coefficient')
        ax2.set_title(f'{title} - Real Part')
    
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
    
    plt.show()

def plot_total_variation_evolution(tv_history: np.ndarray,
                                  title: str = "Total Variation Evolution",
                                  save_path: Optional[str] = None) -> None:
    """
    Plot evolution of total variation over time/iterations.
    
    Parameters:
    -----------
    tv_history : array_like
        Total variation values over time (T,) or (N, T)
    title : str, optional
        Plot title
    save_path : str, optional
        Path to save the figure
    """
    tv_history = np.atleast_2d(tv_history)
    
    if tv_history.shape[0] == 1:
        # Single signal
        plt.figure(figsize=(10, 6))
        plt.plot(tv_history.flatten(), linewidth=2)
        plt.xlabel('Time/Iteration')
        plt.ylabel('Total Variation')
        plt.title(title)
        plt.grid(True, alpha=0.3)
    else:
        # Multiple signals
        plt.figure(figsize=(12, 8))
        
        # Plot mean and std
        mean_tv = np.mean(tv_history, axis=0)
        std_tv = np.std(tv_history, axis=0)
        
        plt.plot(mean_tv, linewidth=2, label='Mean TV')
        plt.fill_between(range(len(mean_tv)), 
                        mean_tv - std_tv, mean_tv + std_tv,
                        alpha=0.3, label='±1 Std')
        
        plt.xlabel('Time/Iteration')
        plt.ylabel('Total Variation')
        plt.title(title)
        plt.legend()
        plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
    
    plt.show()

def plot_graph_comparison(graphs: List[Tuple[sp.spmatrix, np.ndarray, str]],
                         signals: Optional[List[np.ndarray]] = None,
                         save_path: Optional[str] = None) -> None:
    """
    Compare multiple graphs side by side.
    
    Parameters:
    -----------
    graphs : list of tuples
        List of (W, coords, title) for each graph
    signals : list of arrays, optional
        Signals for each graph
    save_path : str, optional
        Path to save the figure
    """
    n_graphs = len(graphs)
    fig, axes = plt.subplots(1, n_graphs, figsize=(5*n_graphs, 5))
    
    if n_graphs == 1:
        axes = [axes]
    
    for i, (W, coords, graph_title) in enumerate(graphs):
        ax = axes[i]
        
        # Plot edges
        rows, cols = W.nonzero()
        for u, v in zip(rows, cols):
            if u < v:
                x_coords = [coords[u, 0], coords[v, 0]]
                y_coords = [coords[u, 1], coords[v, 1]]
                ax.plot(x_coords, y_coords, 'k-', alpha=0.3, linewidth=0.5)
        
        # Plot vertices
        if signals and i < len(signals):
            scatter = ax.scatter(coords[:, 0], coords[:, 1], 
                               c=signals[i], s=30, cmap='viridis',
                               alpha=0.8, edgecolors='black', linewidth=0.5)
        else:
            ax.scatter(coords[:, 0], coords[:, 1], 
                      s=30, color='lightblue',
                      alpha=0.8, edgecolors='black', linewidth=0.5)
        
        ax.set_title(graph_title, fontsize=12, fontweight='bold')
        ax.set_aspect('equal')
        ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
    
    plt.show()

def create_animation_frames(W: sp.spmatrix,
                          coords: np.ndarray,
                          signals: np.ndarray,
                          title: str = "Graph Signal Animation") -> List:
    """
    Create animation frames for time-varying graph signals.
    
    Parameters:
    -----------
    W : sparse matrix
        Adjacency matrix
    coords : array_like
        Vertex coordinates (N, 2) or (N, 3)
    signals : array_like
        Time-varying signals (N, T)
    title : str, optional
        Animation title
    
    Returns:
    --------
    frames : list
        List of plotly frames for animation
    """
    if not PLOTLY_AVAILABLE:
        print("Plotly not available for animations")
        return []
    
    signals = np.atleast_2d(signals)
    N, T = signals.shape
    
    frames = []
    
    for t in range(T):
        # Extract edges for this frame
        rows, cols = W.nonzero()
        edge_x = []
        edge_y = []
        
        for i, j in zip(rows, cols):
            if i < j:
                edge_x.extend([coords[i, 0], coords[j, 0], None])
                edge_y.extend([coords[i, 1], coords[j, 1], None])
        
        # Create frame
        frame = go.Frame(
            data=[
                go.Scatter(x=edge_x, y=edge_y,
                          line=dict(width=1, color='rgba(50,50,50,0.3)'),
                          mode='lines', hoverinfo='none'),
                go.Scatter(x=coords[:, 0], y=coords[:, 1],
                          mode='markers',
                          marker=dict(size=8,
                                    color=signals[:, t],
                                    colorscale='viridis',
                                    cmin=np.min(signals),
                                    cmax=np.max(signals),
                                    colorbar=dict(title="Signal")),
                          hovertemplate='Vertex: %{pointNumber}<br>Value: %{marker.color:.3f}')
            ],
            name=f'frame_{t}'
        )
        frames.append(frame)
    
    return frames