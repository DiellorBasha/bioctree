@echo off
REM =======================================================
REM GLB-based LIC Texture Generation Pipeline
REM =======================================================

echo === GLB LIC Texture Pipeline ===
echo.

REM Change to project directory
cd /d "C:\CodingProjects\bioctree"

REM Check if Python is available
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python not found in PATH
    echo Please install Python or activate your virtual environment
    pause
    exit /b 1
)

echo Python found: 
python --version

REM Install required packages if not present
echo.
echo Installing/checking required packages...
echo.

pip install pygltflib numpy scipy matplotlib pillow trimesh >nul 2>&1
if %errorlevel% neq 0 (
    echo Warning: Some packages may have failed to install
    echo Continuing with available packages...
)

REM Check if output directory exists and contains GLB files
if not exist "output\lic_textures\*.glb" (
    echo.
    echo WARNING: No GLB files found in output\lic_textures\
    echo.
    echo Please run the MATLAB script first:
    echo   1. Open MATLAB
    echo   2. Run: export_surfaces_for_lic_glb
    echo   3. This will generate GLB files with UV coordinates
    echo.
    set /p continue="Continue anyway? (y/N): "
    if /i not "%continue%"=="y" (
        echo Pipeline cancelled
        pause
        exit /b 1
    )
)

REM Run the GLB LIC generation
echo.
echo Running GLB-based LIC texture generation...
echo.

python generate_lic_texture_glb.py

if %errorlevel% neq 0 (
    echo.
    echo ERROR: LIC generation failed
    echo Check the error messages above
    pause
    exit /b 1
)

echo.
echo === Pipeline Complete ===
echo.
echo Generated files are in: output\lic_textures\
echo.
echo Files generated:
echo - *_with_lic.glb: GLB files with embedded LIC textures
echo - *_lic.png: Standalone LIC texture images  
echo - *_vectors.npz: Vector field data (for analysis)
echo - *_visualization.png: Analysis and visualization plots
echo.
echo For three.js usage:
echo - Load GLB files directly (textures are embedded)
echo - Or use separate PNG textures with original GLB geometry
echo.

REM Open output directory in explorer
if exist "output\lic_textures" (
    set /p open="Open output directory? (Y/n): "
    if /i not "%open%"=="n" (
        explorer "output\lic_textures"
    )
)

echo.
echo Pipeline finished successfully!
pause