"""
Input/Output Utilities

Data loading and conversion utilities for the Bioctree Python package.
Handles various data formats including MATLAB .mat files, MEG/EEG data,
and cortical surface meshes.
"""

import numpy as np
import scipy.sparse as sp
from typing import Tuple, Optional, Dict, Any
import warnings

# Optional dependencies
try:
    import scipy.io as sio
    SCIPY_IO_AVAILABLE = True
except ImportError:
    SCIPY_IO_AVAILABLE = False

try:
    import h5py
    H5PY_AVAILABLE = True
except ImportError:
    H5PY_AVAILABLE = False

def load_meg_test_data(file_path: str) -> Tuple[np.ndarray, Dict[str, Any]]:
    """
    Load MEG test data from MATLAB .mat file.
    
    Parameters:
    -----------
    file_path : str
        Path to the .mat file
    
    Returns:
    --------
    meg_data : ndarray
        MEG data array (channels x time)
    info : dict
        Metadata dictionary
    """
    if not SCIPY_IO_AVAILABLE:
        raise ImportError("scipy.io required for loading MATLAB files")
    
    try:
        # Load MATLAB file
        mat_data = sio.loadmat(file_path)
        
        # Extract MEG data (typically stored in 'F' field)
        if 'F' in mat_data:
            meg_data = mat_data['F']
        elif 'data' in mat_data:
            meg_data = mat_data['data']
        else:
            # Find the largest array
            arrays = {k: v for k, v in mat_data.items() 
                     if isinstance(v, np.ndarray) and v.ndim == 2}
            if arrays:
                key = max(arrays.keys(), key=lambda k: arrays[k].size)
                meg_data = arrays[key]
                print(f"Using array '{key}' as MEG data")
            else:
                raise ValueError("No suitable data array found in file")
        
        # Create info dictionary
        info = {
            'n_channels': meg_data.shape[0],
            'n_samples': meg_data.shape[1],
            'sampling_freq': 300.0,  # Default, may be overridden
            'file_path': file_path
        }
        
        # Extract additional metadata if available
        for key in ['fs', 'sfreq', 'sampling_freq']:
            if key in mat_data:
                info['sampling_freq'] = float(mat_data[key])
                break
        
        print(f"Loaded MEG data: {meg_data.shape[0]} channels × {meg_data.shape[1]} samples")
        print(f"Sampling frequency: {info['sampling_freq']} Hz")
        
        return meg_data, info
        
    except Exception as e:
        raise IOError(f"Failed to load MEG data from {file_path}: {str(e)}")

def save_meg_data(meg_data: np.ndarray, 
                  file_path: str, 
                  info: Optional[Dict[str, Any]] = None,
                  format: str = 'mat') -> None:
    """
    Save MEG data to file.
    
    Parameters:
    -----------
    meg_data : ndarray
        MEG data array (channels x time)
    file_path : str
        Output file path
    info : dict, optional
        Metadata dictionary
    format : str, optional
        Output format: 'mat', 'npz', 'hdf5'
    """
    if format == 'mat':
        if not SCIPY_IO_AVAILABLE:
            raise ImportError("scipy.io required for saving MATLAB files")
        
        save_dict = {'F': meg_data}
        if info:
            save_dict.update(info)
        
        sio.savemat(file_path, save_dict)
        
    elif format == 'npz':
        save_dict = {'meg_data': meg_data}
        if info:
            save_dict.update(info)
        
        np.savez(file_path, **save_dict)
        
    elif format == 'hdf5':
        if not H5PY_AVAILABLE:
            raise ImportError("h5py required for saving HDF5 files")
        
        with h5py.File(file_path, 'w') as f:
            f.create_dataset('meg_data', data=meg_data)
            if info:
                for key, value in info.items():
                    f.attrs[key] = value
    
    else:
        raise ValueError(f"Unsupported format: {format}")

def load_cortical_surface(vertices_file: str, 
                         faces_file: str) -> Tuple[np.ndarray, np.ndarray]:
    """
    Load cortical surface mesh from files.
    
    Parameters:
    -----------
    vertices_file : str
        Path to vertices file (.txt, .npz, or .mat)
    faces_file : str
        Path to faces file (.txt, .npz, or .mat)
    
    Returns:
    --------
    vertices : ndarray
        Vertex coordinates (N, 3)
    faces : ndarray
        Face connectivity (F, 3)
    """
    # Load vertices
    if vertices_file.endswith('.txt'):
        vertices = np.loadtxt(vertices_file)
    elif vertices_file.endswith('.npz'):
        data = np.load(vertices_file)
        vertices = data['vertices'] if 'vertices' in data else data[data.files[0]]
    elif vertices_file.endswith('.mat'):
        if not SCIPY_IO_AVAILABLE:
            raise ImportError("scipy.io required for loading MATLAB files")
        data = sio.loadmat(vertices_file)
        vertices = data['vertices'] if 'vertices' in data else list(data.values())[0]
    else:
        raise ValueError(f"Unsupported file format: {vertices_file}")
    
    # Load faces
    if faces_file.endswith('.txt'):
        faces = np.loadtxt(faces_file, dtype=int)
    elif faces_file.endswith('.npz'):
        data = np.load(faces_file)
        faces = data['faces'] if 'faces' in data else data[data.files[0]]
    elif faces_file.endswith('.mat'):
        if not SCIPY_IO_AVAILABLE:
            raise ImportError("scipy.io required for loading MATLAB files")
        data = sio.loadmat(faces_file)
        faces = data['faces'] if 'faces' in data else list(data.values())[0]
    else:
        raise ValueError(f"Unsupported file format: {faces_file}")
    
    # Ensure correct data types
    vertices = vertices.astype(np.float64)
    faces = faces.astype(np.int32)
    
    # Convert 1-based indexing to 0-based if needed
    if np.min(faces) == 1:
        faces -= 1
    
    print(f"Loaded cortical surface: {vertices.shape[0]} vertices, {faces.shape[0]} faces")
    
    return vertices, faces

def downsample_signal(signal: np.ndarray, 
                     original_fs: float, 
                     target_fs: float,
                     axis: int = -1) -> Tuple[np.ndarray, np.ndarray]:
    """
    Downsample signal to target sampling frequency.
    
    Parameters:
    -----------
    signal : ndarray
        Input signal
    original_fs : float
        Original sampling frequency
    target_fs : float
        Target sampling frequency
    axis : int, optional
        Time axis (default: -1)
    
    Returns:
    --------
    downsampled_signal : ndarray
        Downsampled signal
    time_indices : ndarray
        Indices of selected time points
    """
    if target_fs >= original_fs:
        print("Target frequency >= original frequency, returning original signal")
        return signal, np.arange(signal.shape[axis])
    
    # Calculate downsampling factor
    downsample_factor = int(np.round(original_fs / target_fs))
    
    # Create time indices
    time_indices = np.arange(0, signal.shape[axis], downsample_factor)
    
    # Downsample signal
    downsampled_signal = np.take(signal, time_indices, axis=axis)
    
    actual_fs = original_fs / downsample_factor
    print(f"Downsampled from {original_fs} Hz to {actual_fs} Hz (factor: {downsample_factor})")
    
    return downsampled_signal, time_indices

def convert_matlab_to_python_graph(mat_file_path: str, 
                                  output_path: str) -> None:
    """
    Convert MATLAB graph structure to Python-compatible format.
    
    Parameters:
    -----------
    mat_file_path : str
        Path to MATLAB .mat file containing graph
    output_path : str
        Output path for Python graph (.npz format)
    """
    if not SCIPY_IO_AVAILABLE:
        raise ImportError("scipy.io required for loading MATLAB files")
    
    # Load MATLAB graph
    mat_data = sio.loadmat(mat_file_path)
    
    # Extract graph components
    graph_data = {}
    
    # Look for common graph field names
    for field in ['W', 'A', 'adjacency', 'weight_matrix']:
        if field in mat_data:
            W = mat_data[field]
            if sp.issparse(W):
                graph_data['adjacency_matrix'] = W
            else:
                graph_data['adjacency_matrix'] = sp.csr_matrix(W)
            break
    
    # Look for coordinates
    for field in ['coords', 'coordinates', 'positions']:
        if field in mat_data:
            graph_data['coordinates'] = mat_data[field]
            break
    
    # Look for other graph properties
    for field in ['N', 'n_vertices', 'lmax', 'eigenvalues', 'eigenvectors']:
        if field in mat_data:
            graph_data[field] = mat_data[field]
    
    # Save to Python format
    if 'adjacency_matrix' in graph_data:
        # Handle sparse matrix separately
        W = graph_data.pop('adjacency_matrix')
        graph_data['adjacency_data'] = W.data
        graph_data['adjacency_indices'] = W.indices
        graph_data['adjacency_indptr'] = W.indptr
        graph_data['adjacency_shape'] = W.shape
    
    np.savez(output_path, **graph_data)
    print(f"Converted MATLAB graph to Python format: {output_path}")

def load_python_graph(file_path: str) -> Tuple[sp.spmatrix, Optional[np.ndarray]]:
    """
    Load graph from Python .npz format.
    
    Parameters:
    -----------
    file_path : str
        Path to .npz file
    
    Returns:
    --------
    W : sparse matrix
        Adjacency matrix
    coords : ndarray or None
        Vertex coordinates if available
    """
    data = np.load(file_path, allow_pickle=True)
    
    # Reconstruct sparse matrix
    if 'adjacency_data' in data:
        W = sp.csr_matrix((data['adjacency_data'], 
                          data['adjacency_indices'], 
                          data['adjacency_indptr']),
                         shape=tuple(data['adjacency_shape']))
    else:
        raise ValueError("No adjacency matrix found in file")
    
    # Get coordinates if available
    coords = data.get('coordinates', None)
    
    return W, coords

def export_graph_for_matlab(W: sp.spmatrix, 
                           coords: Optional[np.ndarray],
                           output_path: str,
                           additional_data: Optional[Dict[str, Any]] = None) -> None:
    """
    Export Python graph to MATLAB-compatible format.
    
    Parameters:
    -----------
    W : sparse matrix
        Adjacency matrix
    coords : ndarray or None
        Vertex coordinates
    output_path : str
        Output .mat file path
    additional_data : dict, optional
        Additional data to save
    """
    if not SCIPY_IO_AVAILABLE:
        raise ImportError("scipy.io required for saving MATLAB files")
    
    save_dict = {
        'W': W,
        'N': W.shape[0]
    }
    
    if coords is not None:
        save_dict['coords'] = coords
    
    if additional_data:
        save_dict.update(additional_data)
    
    sio.savemat(output_path, save_dict)
    print(f"Exported graph to MATLAB format: {output_path}")

def create_example_data(n_vertices: int = 100, 
                       n_time_points: int = 1000,
                       sampling_freq: float = 64.0,
                       signal_type: str = 'random') -> Tuple[np.ndarray, Dict[str, Any]]:
    """
    Create example MEG-like data for testing.
    
    Parameters:
    -----------
    n_vertices : int, optional
        Number of vertices/channels
    n_time_points : int, optional
        Number of time points
    sampling_freq : float, optional
        Sampling frequency in Hz
    signal_type : str, optional
        Type of signal: 'random', 'oscillatory', 'spike'
    
    Returns:
    --------
    signal : ndarray
        Synthetic signal (n_vertices, n_time_points)
    info : dict
        Metadata
    """
    np.random.seed(42)  # For reproducibility
    
    t = np.arange(n_time_points) / sampling_freq
    
    if signal_type == 'random':
        signal = np.random.randn(n_vertices, n_time_points)
        
    elif signal_type == 'oscillatory':
        # Create oscillatory signals with different frequencies
        freqs = np.random.uniform(8, 12, n_vertices)  # Alpha band
        signal = np.array([np.sin(2 * np.pi * f * t) + 
                          0.5 * np.random.randn(n_time_points) 
                          for f in freqs])
        
    elif signal_type == 'spike':
        # Create sparse spike-like signals
        signal = np.random.randn(n_vertices, n_time_points) * 0.1
        for i in range(n_vertices):
            spike_times = np.random.choice(n_time_points, 
                                         size=np.random.poisson(5), 
                                         replace=False)
            signal[i, spike_times] += np.random.exponential(2, len(spike_times))
    
    else:
        raise ValueError(f"Unknown signal type: {signal_type}")
    
    info = {
        'n_channels': n_vertices,
        'n_samples': n_time_points,
        'sampling_freq': sampling_freq,
        'duration': n_time_points / sampling_freq,
        'signal_type': signal_type
    }
    
    return signal, info