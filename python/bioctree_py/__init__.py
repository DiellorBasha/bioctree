"""
Bioctree Python Module - Graph Signal Processing for Neuroscience

A Python implementation of graph signal processing tools for analyzing
brain signals on cortical surfaces and other graph structures.

This module provides Python equivalents to the MATLAB Bioctree toolbox,
leveraging PyGSP for core graph signal processing functionality.

Modules:
    gsp: Core graph signal processing operations
    demos: Demonstration scripts and tutorials
    visualization: Interactive plotting and analysis tools
    io: Data input/output and format conversion utilities

Example:
    >>> import bioctree_py as bct
    >>> from bioctree_py.demos import demo_bunny_pipeline
    >>> demo_bunny_pipeline.run()

Dependencies:
    - pygsp: Graph signal processing library
    - numpy: Numerical computing
    - scipy: Scientific computing
    - matplotlib: Plotting and visualization
    - plotly: Interactive visualizations
    - networkx: Graph analysis
    - scikit-learn: Machine learning utilities
"""

__version__ = "1.0.0"
__author__ = "Bioctree Development Team"
__license__ = "MIT"

# Core imports
from . import gsp
from . import demos
from . import visualization
from . import io

# Convenience imports
from .gsp import ops
from .gsp import graphs
# from .gsp import filters
# from .gsp import transforms

# Version info
def version_info():
    """Print version and dependency information."""
    print(f"Bioctree Python v{__version__}")
    print("Dependencies:")
    
    try:
        import pygsp
        version = getattr(pygsp, '__version__', 'unknown')
        print(f"  - PyGSP: {version}")
    except ImportError:
        print("  - PyGSP: Not installed")
    
    try:
        import numpy as np
        print(f"  - NumPy: {np.__version__}")
    except ImportError:
        print("  - NumPy: Not installed")
    
    try:
        import scipy
        print(f"  - SciPy: {scipy.__version__}")
    except ImportError:
        print("  - SciPy: Not installed")
    
    try:
        import matplotlib
        print(f"  - Matplotlib: {matplotlib.__version__}")
    except ImportError:
        print("  - Matplotlib: Not installed")
    
    try:
        import plotly
        print(f"  - Plotly: {plotly.__version__}")
    except ImportError:
        print("  - Plotly: Not installed")

def setup():
    """Initialize the Bioctree Python environment."""
    print("=== Initializing Bioctree Python ===")
    version_info()
    print("Ready for graph signal processing!")
    return True

# Auto-setup when imported (but not when testing)
# if __name__ != "__main__":
#     setup()