# MEG-GSP Toolbox Git Setup

This file contains instructions for setting up the git repository and submodules.

## Initial Setup

1. Initialize git repository (if not already done):
```bash
git init
```

2. Add GSPBOX as a submodule:
```bash
git submodule add https://github.com/epfl-lts2/gspbox.git external/gspbox
```

3. Initialize and update all submodules:
```bash
git submodule update --init --recursive
```

## For Contributors

When cloning this repository:
```bash
git clone --recursive <repository-url>
```

Or if already cloned without submodules:
```bash
git submodule update --init --recursive
```

## Submodule Management

To update GSPBOX to latest version:
```bash
cd external/gspbox
git pull origin master
cd ../..
git add external/gspbox
git commit -m "Update GSPBOX submodule"
```