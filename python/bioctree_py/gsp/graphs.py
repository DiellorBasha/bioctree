"""
Graph Construction and Utilities

Python implementation of graph construction utilities,
equivalent to the MATLAB gsp/graph/ module.

This module provides:
- Standard graph generators (bunny, grid, etc.)
- Graph construction from data
- Graph manipulation utilities
"""

import numpy as np
import scipy.sparse as sp
from typing import Tuple, Optional, Union
import networkx as nx

def stanford_bunny(N: int = 300) -> Tuple[sp.spmatrix, np.ndarray]:
    """
    Create Stanford bunny graph using PyGSP.
    
    Parameters:
    -----------
    N : int, optional
        Number of vertices to select (default: 300)
    
    Returns:
    --------
    W : sparse matrix
        Adjacency matrix
    coords : ndarray
        3D coordinates of vertices (N, 3)
    """
    try:
        from pygsp import graphs
        
        # Create full bunny graph
        G = graphs.Bunny()
        
        # Subsample if needed
        if N < G.N:
            # Select vertices with highest degrees for better connectivity
            degrees = np.array(G.W.sum(axis=1)).flatten()
            indices = np.argsort(degrees)[-N:]
            
            # Extract subgraph
            W = G.W[np.ix_(indices, indices)]
            coords = G.coords[indices] if hasattr(G, 'coords') else None
        else:
            W = G.W
            coords = G.coords if hasattr(G, 'coords') else None
            
        return W, coords
        
    except ImportError:
        # Fallback: create a random geometric graph
        print("PyGSP not available, creating random geometric graph")
        return random_geometric_graph(N)

def random_geometric_graph(N: int, 
                          radius: float = 0.3, 
                          dim: int = 3) -> Tuple[sp.spmatrix, np.ndarray]:
    """
    Create random geometric graph.
    
    Parameters:
    -----------
    N : int
        Number of vertices
    radius : float, optional
        Connection radius (default: 0.3)
    dim : int, optional
        Dimensionality (default: 3)
    
    Returns:
    --------
    W : sparse matrix
        Adjacency matrix
    coords : ndarray
        Vertex coordinates (N, dim)
    """
    # Generate random coordinates
    coords = np.random.rand(N, dim)
    
    # Compute pairwise distances
    from scipy.spatial.distance import pdist, squareform
    distances = squareform(pdist(coords))
    
    # Create adjacency matrix
    W = sp.csr_matrix(distances < radius)
    
    # Remove self-loops
    W.setdiag(0)
    
    return W, coords

def grid_graph(height: int, width: int, 
               diagonal: bool = False) -> Tuple[sp.spmatrix, np.ndarray]:
    """
    Create 2D grid graph.
    
    Parameters:
    -----------
    height : int
        Grid height
    width : int
        Grid width
    diagonal : bool, optional
        Include diagonal connections (default: False)
    
    Returns:
    --------
    W : sparse matrix
        Adjacency matrix
    coords : ndarray
        2D coordinates of vertices (N, 2)
    """
    if diagonal:
        G = nx.grid_2d_graph(height, width, create_using=nx.Graph())
        # Add diagonal edges
        for i in range(height-1):
            for j in range(width-1):
                G.add_edge((i, j), (i+1, j+1))
                G.add_edge((i, j+1), (i+1, j))
    else:
        G = nx.grid_2d_graph(height, width)
    
    # Convert to adjacency matrix
    W = nx.adjacency_matrix(G)
    
    # Create coordinates
    coords = np.array(list(G.nodes()))
    
    return W, coords

def sensor_graph(coordinates: np.ndarray, 
                 k: int = 8, 
                 distance_threshold: Optional[float] = None) -> sp.spmatrix:
    """
    Create graph from sensor coordinates (e.g., MEG/EEG).
    
    Parameters:
    -----------
    coordinates : array_like
        Sensor coordinates (N, 3)
    k : int, optional
        Number of nearest neighbors (default: 8)
    distance_threshold : float, optional
        Maximum distance for connections
    
    Returns:
    --------
    W : sparse matrix
        Adjacency matrix
    """
    from sklearn.neighbors import NearestNeighbors
    
    N = coordinates.shape[0]
    
    # Find k nearest neighbors
    nbrs = NearestNeighbors(n_neighbors=k+1, algorithm='auto').fit(coordinates)
    distances, indices = nbrs.kneighbors(coordinates)
    
    # Create adjacency matrix
    row_ind = []
    col_ind = []
    data = []
    
    for i in range(N):
        for j in range(1, k+1):  # Skip self (index 0)
            neighbor = indices[i, j]
            dist = distances[i, j]
            
            # Apply distance threshold if specified
            if distance_threshold is None or dist <= distance_threshold:
                # Use Gaussian weights
                weight = np.exp(-dist**2 / (2 * np.std(distances)**2))
                
                row_ind.extend([i, neighbor])
                col_ind.extend([neighbor, i])
                data.extend([weight, weight])
    
    W = sp.csr_matrix((data, (row_ind, col_ind)), shape=(N, N))
    
    # Remove duplicate entries and self-loops
    W.eliminate_zeros()
    W.setdiag(0)
    
    return W

def cortical_surface_graph(vertices: np.ndarray, 
                          faces: np.ndarray, 
                          distance_weights: bool = True) -> sp.spmatrix:
    """
    Create graph from cortical surface mesh.
    
    Parameters:
    -----------
    vertices : array_like
        Vertex coordinates (N, 3)
    faces : array_like
        Face connectivity (F, 3)
    distance_weights : bool, optional
        Use Euclidean distances as weights (default: True)
    
    Returns:
    --------
    W : sparse matrix
        Adjacency matrix
    """
    N = vertices.shape[0]
    
    # Initialize adjacency matrix
    W = sp.lil_matrix((N, N))
    
    # Add edges from faces
    for face in faces:
        v0, v1, v2 = face
        
        # Add edges for each triangle
        edges = [(v0, v1), (v1, v2), (v2, v0)]
        
        for i, j in edges:
            if distance_weights:
                # Euclidean distance weight
                dist = np.linalg.norm(vertices[i] - vertices[j])
                weight = 1.0 / (1.0 + dist)  # Inverse distance
            else:
                weight = 1.0
            
            W[i, j] = weight
            W[j, i] = weight
    
    return W.tocsr()

def graph_properties(W: sp.spmatrix) -> dict:
    """
    Compute basic graph properties.
    
    Parameters:
    -----------
    W : sparse matrix
        Adjacency matrix
    
    Returns:
    --------
    props : dict
        Dictionary with graph properties
    """
    N = W.shape[0]
    
    # Convert to NetworkX graph for analysis
    G = nx.from_scipy_sparse_array(W)
    
    # Compute properties
    props = {
        'n_vertices': N,
        'n_edges': G.number_of_edges(),
        'density': nx.density(G),
        'is_connected': nx.is_connected(G),
        'n_components': nx.number_connected_components(G),
        'average_degree': np.mean([d for n, d in G.degree()]),
        'clustering_coefficient': nx.average_clustering(G),
    }
    
    # Add spectral properties
    from .ops import graph_laplacian
    L = graph_laplacian(W, normalized=True)
    eigenvals = sp.linalg.eigsh(L, k=min(10, N-2), which='SM', return_eigenvectors=False)
    
    props.update({
        'spectral_gap': eigenvals[1] if len(eigenvals) > 1 else 0,
        'max_eigenvalue': np.max(eigenvals),
    })
    
    return props