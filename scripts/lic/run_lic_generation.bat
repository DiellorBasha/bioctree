@echo off
echo Activating Python environment and running LIC texture generation...

REM Activate the Python virtual environment
call external\.venv\Scripts\activate.bat

REM Check if nilearn is available
python -c "import nilearn; print('nilearn version:', nilearn.__version__)" 2>nul
if errorlevel 1 (
    echo Installing required packages...
    pip install nilearn matplotlib pillow scipy
)

REM Run the LIC texture generation script
echo Running LIC texture generation...
python generate_lic_texture.py

REM Keep window open if run by double-click
if "%1"=="" pause

echo Done!