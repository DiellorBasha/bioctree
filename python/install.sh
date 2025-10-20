#!/bin/bash
# Install Bioctree Python Module
# Run this script to set up the Python environment for Bioctree

echo "=== Installing Bioctree Python Module ==="

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed."
    echo "Please install Python 3.8 or later."
    exit 1
fi

# Check Python version
python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Python version: $python_version"

# Install core dependencies
echo "Installing core dependencies..."
pip install numpy scipy matplotlib networkx scikit-learn

# Install optional dependencies
echo "Installing optional dependencies..."
pip install -q pygsp plotly h5py seaborn 2>/dev/null || echo "Some optional packages failed to install (this is OK)"

# Install Jupyter support (optional)
echo "Installing Jupyter support..."
pip install -q jupyter ipywidgets 2>/dev/null || echo "Jupyter installation failed (this is OK)"

# Install the package in development mode
echo "Installing Bioctree Python in development mode..."
cd "$(dirname "$0")"
pip install -e .

# Test installation
echo "Testing installation..."
python3 -c "import bioctree_py; bioctree_py.version_info()"

# Run a simple test
echo "Running basic functionality test..."
python3 -c "
from bioctree_py.gsp import graphs, ops
import numpy as np
W, coords = graphs.random_geometric_graph(30)
x = np.random.randn(30)
tv = ops.graph_total_variation(W, x)
print(f'✓ Basic test passed: Graph with {W.shape[0]} vertices, TV = {np.mean(tv):.3f}')
"

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "You can now:"
echo "1. Import the module: python3 -c 'import bioctree_py'"
echo "2. Run demos: python3 -c 'from bioctree_py.demos import demo_bunny_pipeline; demo_bunny_pipeline.run_demo()'"
echo "3. Use command line: bioctree-demo --help"
echo ""
echo "For interactive visualizations, install plotly:"
echo "  pip install plotly"
echo ""
echo "For PyGSP Stanford bunny support:"
echo "  pip install pygsp"