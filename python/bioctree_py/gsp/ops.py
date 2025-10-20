"""
Graph Signal Processing Operations

Python implementation of core graph signal processing operations,
equivalent to the MATLAB gsp/ops/ module.

This module provides:
- Graph gradient and divergence operators
- Total variation computation
- Spectral analysis tools
- Graph filtering utilities
"""

import numpy as np
import scipy.sparse as sp
from typing import Union, Tuple, Optional
import warnings

def graph_gradient(W: Union[np.ndarray, sp.spmatrix], 
                  x: np.ndarray, 
                  directed: bool = False) -> np.ndarray:
    """
    Compute graph gradient operator ∇G applied to signal x.
    
    The gradient assigns to each edge the weighted difference
    between connected vertices.
    
    Parameters:
    -----------
    W : array_like or sparse matrix
        Adjacency or weight matrix of the graph (N x N)
    x : array_like
        Signal on vertices (N,) or (N, T) for T time points
    directed : bool, optional
        Whether to compute directed gradient (default: False)
    
    Returns:
    --------
    grad : ndarray
        Edge gradient values (E,) or (E, T) for E edges
        For edge (i,j): grad_ij = sqrt(W_ij) * (x_j - x_i)
    
    Example:
    --------
    >>> import numpy as np
    >>> from bioctree_py.gsp.ops import graph_gradient
    >>> W = np.array([[0, 1, 1], [1, 0, 1], [1, 1, 0]])  # Triangle graph
    >>> x = np.array([1, 2, 3])  # Signal on vertices
    >>> grad = graph_gradient(W, x)
    """
    # Convert to sparse matrix if needed
    if not sp.issparse(W):
        W = sp.csr_matrix(W)
    
    # Ensure x is 2D for consistent handling
    x = np.atleast_2d(x)
    if x.shape[0] == 1:
        x = x.T
    
    N, T = x.shape
    
    # Get edge list from adjacency matrix
    if directed:
        rows, cols = W.nonzero()
    else:
        # For undirected graphs, only consider upper triangle
        W_upper = sp.triu(W)
        rows, cols = W_upper.nonzero()
    
    E = len(rows)
    
    # Initialize gradient array
    grad = np.zeros((E, T))
    
    # Compute gradient for each edge
    for e, (i, j) in enumerate(zip(rows, cols)):
        weight = W[i, j]
        diff = x[j, :] - x[i, :]
        grad[e, :] = np.sqrt(weight) * diff
    
    # Return 1D array if input was 1D
    if T == 1:
        grad = grad.flatten()
    
    return grad

def graph_divergence(W: Union[np.ndarray, sp.spmatrix], 
                    edge_values: np.ndarray, 
                    directed: bool = False) -> np.ndarray:
    """
    Compute graph divergence operator div_G applied to edge values.
    
    The divergence is the adjoint of the gradient operator.
    
    Parameters:
    -----------
    W : array_like or sparse matrix
        Adjacency or weight matrix of the graph (N x N)
    edge_values : array_like
        Values on edges (E,) or (E, T) for T time points
    directed : bool, optional
        Whether graph is directed (default: False)
    
    Returns:
    --------
    div : ndarray
        Divergence at vertices (N,) or (N, T)
    
    Example:
    --------
    >>> from bioctree_py.gsp.ops import graph_gradient, graph_divergence
    >>> W = np.array([[0, 1, 1], [1, 0, 1], [1, 1, 0]])
    >>> x = np.array([1, 2, 3])
    >>> grad = graph_gradient(W, x)
    >>> div = graph_divergence(W, grad)
    """
    # Convert to sparse matrix if needed
    if not sp.issparse(W):
        W = sp.csr_matrix(W)
    
    # Ensure edge_values is 2D
    edge_values = np.atleast_2d(edge_values)
    if edge_values.shape[0] == 1:
        edge_values = edge_values.T
    
    E, T = edge_values.shape
    N = W.shape[0]
    
    # Get edge list
    if directed:
        rows, cols = W.nonzero()
    else:
        W_upper = sp.triu(W)
        rows, cols = W_upper.nonzero()
    
    # Initialize divergence array
    div = np.zeros((N, T))
    
    # Compute divergence
    for e, (i, j) in enumerate(zip(rows, cols)):
        weight = W[i, j]
        sqrt_weight = np.sqrt(weight)
        
        # Divergence is negative adjoint of gradient
        div[i, :] -= sqrt_weight * edge_values[e, :]
        div[j, :] += sqrt_weight * edge_values[e, :]
    
    # Return 1D array if input was 1D
    if T == 1:
        div = div.flatten()
    
    return div

def graph_total_variation(W: Union[np.ndarray, sp.spmatrix], 
                         x: np.ndarray, 
                         p: float = 1.0) -> np.ndarray:
    """
    Compute total variation of graph signals.
    
    TV measures spatial roughness/smoothness of signals on the graph.
    
    Parameters:
    -----------
    W : array_like or sparse matrix
        Adjacency or weight matrix of the graph (N x N)
    x : array_like
        Signal matrix (N,) or (N, T) where N=vertices, T=time points
    p : float, optional
        Norm parameter (default: 1 for L1 TV)
    
    Returns:
    --------
    tv : ndarray
        Total variation per vertex (N,) or (N, T)
        For p=1: TV(x)[i] = Σ_{j∈N(i)} w_{ij} |x[i] - x[j]|
        For p=2: TV(x)[i] = (Σ_{j∈N(i)} w_{ij} (x[i] - x[j])²)^(1/2)
    
    Example:
    --------
    >>> from bioctree_py.gsp.ops import graph_total_variation
    >>> import numpy as np
    >>> W = np.array([[0, 1, 1], [1, 0, 1], [1, 1, 0]])
    >>> x = np.array([1, 5, 2])  # Smooth signal has lower TV
    >>> tv = graph_total_variation(W, x)
    """
    # Convert to sparse matrix if needed
    if not sp.issparse(W):
        W = sp.csr_matrix(W)
    
    # Ensure x is 2D
    x = np.atleast_2d(x)
    if x.shape[0] == 1:
        x = x.T
    
    N, T = x.shape
    
    # Initialize output
    tv = np.zeros((N, T))
    
    # Compute total variation for each vertex
    for i in range(N):
        # Find neighbors of vertex i
        neighbors = W[i, :].nonzero()[1]
        
        if len(neighbors) == 0:
            # Isolated vertex has zero TV
            continue
        
        # Get edge weights to neighbors
        weights = W[i, neighbors].toarray().flatten()
        
        # Compute differences to all neighbors
        for t in range(T):
            x_i = x[i, t]
            x_neighbors = x[neighbors, t]
            
            # Compute weighted differences
            diffs = np.abs(x_i - x_neighbors)
            
            if p == 1:
                # L1 total variation (standard)
                tv[i, t] = np.sum(weights * diffs)
            elif p == 2:
                # L2 total variation
                tv[i, t] = np.sqrt(np.sum(weights * (diffs**2)))
            elif np.isinf(p):
                # L∞ total variation (max norm)
                tv[i, t] = np.max(weights * diffs)
            else:
                # General Lp norm
                tv[i, t] = (np.sum(weights * (diffs**p)))**(1/p)
    
    # Return 1D array if input was 1D
    if T == 1:
        tv = tv.flatten()
    
    return tv

def graph_laplacian(W: Union[np.ndarray, sp.spmatrix], 
                   normalized: bool = True, 
                   type: str = 'combinatorial') -> sp.spmatrix:
    """
    Compute graph Laplacian matrix.
    
    Parameters:
    -----------
    W : array_like or sparse matrix
        Adjacency or weight matrix
    normalized : bool, optional
        Whether to return normalized Laplacian (default: True)
    type : str, optional
        Type of Laplacian: 'combinatorial', 'normalized', 'random_walk'
    
    Returns:
    --------
    L : sparse matrix
        Graph Laplacian matrix
    """
    # Convert to sparse matrix
    if not sp.issparse(W):
        W = sp.csr_matrix(W)
    
    # Compute degree matrix
    degrees = np.array(W.sum(axis=1)).flatten()
    D = sp.diags(degrees, format='csr')
    
    if type == 'combinatorial':
        L = D - W
    elif type == 'normalized':
        # L = I - D^(-1/2) W D^(-1/2)
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            D_inv_sqrt = sp.diags(1.0 / np.sqrt(degrees), format='csr')
            D_inv_sqrt.data[~np.isfinite(D_inv_sqrt.data)] = 0
        L = sp.eye(W.shape[0], format='csr') - D_inv_sqrt @ W @ D_inv_sqrt
    elif type == 'random_walk':
        # L = I - D^(-1) W
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            D_inv = sp.diags(1.0 / degrees, format='csr')
            D_inv.data[~np.isfinite(D_inv.data)] = 0
        L = sp.eye(W.shape[0], format='csr') - D_inv @ W
    else:
        raise ValueError(f"Unknown Laplacian type: {type}")
    
    return L

def graph_fourier_transform(L: sp.spmatrix, x: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """
    Compute Graph Fourier Transform of signal x.
    
    Parameters:
    -----------
    L : sparse matrix
        Graph Laplacian matrix
    x : array_like
        Signal on vertices (N,) or (N, T)
    
    Returns:
    --------
    x_hat : ndarray
        Graph Fourier coefficients
    eigenvalues : ndarray
        Laplacian eigenvalues (graph frequencies)
    """
    # Compute eigendecomposition of Laplacian
    eigenvalues, eigenvectors = sp.linalg.eigsh(L, k=min(L.shape[0]-1, 100), 
                                               which='SM', return_eigenvectors=True)
    
    # Ensure x is 2D
    x = np.atleast_2d(x)
    if x.shape[0] == 1:
        x = x.T
    
    # Compute GFT coefficients
    x_hat = eigenvectors.T @ x
    
    return x_hat, eigenvalues