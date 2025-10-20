@echo off
REM Install Bioctree Python Module - Windows version
echo === Installing Bioctree Python Module ===

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is required but not installed.
    echo Please install Python 3.8 or later from python.org
    pause
    exit /b 1
)

REM Show Python version
python -c "import sys; print(f'Python version: {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')"

REM Install core dependencies
echo Installing core dependencies...
pip install numpy scipy matplotlib networkx scikit-learn

REM Install optional dependencies
echo Installing optional dependencies...
pip install pygsp plotly h5py seaborn 2>nul || echo Some optional packages failed to install (this is OK)

REM Install Jupyter support (optional)
echo Installing Jupyter support...
pip install jupyter ipywidgets 2>nul || echo Jupyter installation failed (this is OK)

REM Install the package in development mode
echo Installing Bioctree Python in development mode...
cd /d "%~dp0"
pip install -e .

REM Test installation
echo Testing installation...
python -c "import bioctree_py; bioctree_py.version_info()"

REM Run a simple test
echo Running basic functionality test...
python -c "from bioctree_py.gsp import graphs, ops; import numpy as np; W, coords = graphs.random_geometric_graph(30); x = np.random.randn(30); tv = ops.graph_total_variation(W, x); print(f'✓ Basic test passed: Graph with {W.shape[0]} vertices, TV = {np.mean(tv):.3f}')"

echo.
echo === Installation Complete! ===
echo.
echo You can now:
echo 1. Import the module: python -c "import bioctree_py"
echo 2. Run demos: python -c "from bioctree_py.demos import demo_bunny_pipeline; demo_bunny_pipeline.run_demo()"
echo 3. Use command line: bioctree-demo --help
echo.
echo For interactive visualizations, install plotly:
echo   pip install plotly
echo.
echo For PyGSP Stanford bunny support:
echo   pip install pygsp
echo.
pause