@echo off
REM =======================================================
REM Complete LIC Pipeline with Automatic File Copying
REM =======================================================

echo === Complete LIC Texture Generation and Copy Pipeline ===
echo.

REM Change to project directory
cd /d "C:\CodingProjects\bioctree"

REM Step 1: Generate LIC textures
echo Step 1: Generating LIC textures...
echo.

REM Check if Python is available
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python not found in PATH
    echo Please install Python or activate your virtual environment
    pause
    exit /b 1
)

REM Run the LIC generation pipeline
echo Running LIC texture generation...
python generate_lic_texture.py

if %errorlevel% neq 0 (
    echo.
    echo ERROR: LIC generation failed
    echo Check the error messages above
    pause
    exit /b 1
)

echo.
echo ✓ LIC texture generation completed
echo.

REM Step 2: Copy textures to test-data/mesh
echo Step 2: Copying LIC textures to test-data/mesh...
echo.

python copy_lic_textures.py

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to copy textures
    echo Check the error messages above
    pause
    exit /b 1
)

echo.
echo ✓ LIC textures copied to test-data/mesh/
echo.

REM Summary
echo === Pipeline Complete ===
echo.
echo Generated LIC textures are available in:
echo   1. output/lic_textures/ (original location)
echo   2. test-data/mesh/ (copied for easy access)
echo.
echo Available LIC textures:
echo   - lh_lic_texture.png (Left hemisphere, 4096x2048)
echo   - rh_lic_texture.png (Right hemisphere, 4096x2048)
echo.
echo For three.js usage:
echo   - Load PNG textures directly
echo   - Or use GLB files with embedded textures
echo.

REM Open the mesh directory
set /p open="Open test-data/mesh directory? (Y/n): "
if /i not "%open%"=="n" (
    if exist "test-data\mesh" (
        explorer "test-data\mesh"
    )
)

echo.
echo Pipeline completed successfully!
pause