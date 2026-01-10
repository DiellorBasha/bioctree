# BCT Dependency Installation System

Complete dependency management for the Bioctree (BCT) toolbox.

## Overview

The `bct.install` package provides automated installation and configuration of required computational backends:

- **DECLab** - Discrete Exterior Calculus
- **GSPBox** - Graph Signal Processing
- **gptoolbox** - Geometry Processing

All dependencies use pinned commits for reproducible installations.

## Quick Start

```matlab
% Install dependencies (one-time setup)
bct.install.deps

% Start BCT
bct.start
```

That's it! BCT is ready to use.

## API Reference

### `bct.install.deps(...)`

Install and configure all required dependencies.

**Options:**
- `'root'` - Installation directory (default: auto-resolved)
- `'method'` - `'auto'`, `'git'`, or `'zip'` (default: `'auto'`)
- `'pin'` - `'tested'`, `'latest'`, or explicit SHA (default: `'tested'`)
- `'update'` - Update existing installations (default: `false`)
- `'overwrite'` - Force reinstall (default: `false`)
- `'quiet'` - Suppress output (default: `false`)
- `'writeLock'` - Create lock file (default: `true`)
- `'savepath'` - Save to pathdef.m (default: `false`)

**Examples:**

```matlab
% Standard installation with tested/pinned commits
bct.install.deps

% Force reinstall
bct.install.deps('overwrite', true)

% Install to custom location
bct.install.deps('root', 'C:\MyDeps\bct')

% Use ZIP downloads (no Git required)
bct.install.deps('method', 'zip')

% Install latest versions (non-reproducible)
bct.install.deps('pin', 'latest')
```

### `bct.install.status()`

Report dependency installation and readiness status.

```matlab
s = bct.install.status();

% Check if ready
if s.readyForStart
    bct.start
else
    bct.install.deps
end
```

### `bct.install.configure(root, ...)`

Configure BCT to use existing dependencies (e.g., lab shared installations).

**Options:**
- `'addToPath'` - Add to current session (default: `true`)
- `'savepath'` - Save to pathdef.m (default: `false`)

**Examples:**

```matlab
% Point to shared installation
bct.install.configure('\\server\share\MATLAB_Deps\bct')

% Configure and save path permanently
bct.install.configure('/opt/matlab_deps/bct', 'savepath', true)
```

### `bct.install.uninstall(...)`

Remove dependency configuration and optionally delete files.

**Options:**
- `'delete'` - Delete dependency folders (default: `false`)
- `'root'` - Explicit root (default: auto-resolved)
- `'removeFromPath'` - Remove from current session (default: `true`)
- `'quiet'` - Suppress output (default: `false`)

**Examples:**

```matlab
% Remove configuration only (keep files)
bct.install.uninstall

% Remove configuration and delete files
bct.install.uninstall('delete', true)
```

## Installation Root Resolution

The system uses the following precedence to determine where to install dependencies:

1. **Explicit `'root'` argument** - Highest priority
2. **Environment variable** - `BCT_DEPS_ROOT`
3. **MATLAB preference** - `getpref('bct', 'depsRoot')`
4. **Default** - `<userpath>/ThirdParty/bct`

On Windows, the default is typically:
```
C:\Users\<username>\Documents\MATLAB\ThirdParty\bct
```

On macOS/Linux:
```
~/Documents/MATLAB/ThirdParty/bct
```

## Pinned Commits (Tested & Verified)

The default `'tested'` pin mode uses these verified commits:

- **DECLab**: `bace86c2797025644d6b714c0ed02ff468d8374d`
- **GSPBox**: `a7d9aac5e239f1bcb37a9bb09998cc161be2732f`
- **gptoolbox**: `7c2838115799ab2736930158ce507a18c4961f4d`

These commits have been tested with BCT and are guaranteed to work.

## Installation Methods

### Git Mode (Recommended)

If Git is available, dependencies are cloned as repositories:

**Advantages:**
- Update capability (`update=true`)
- Track exact commits
- Smaller download size (shallow clones)

**Requirements:**
- Git installed and on system PATH

### ZIP Mode

If Git is unavailable, dependencies are downloaded as ZIP archives:

**Advantages:**
- No Git required
- Works on restricted systems

**Limitations:**
- No update capability (must use `overwrite=true` to reinstall)
- Cannot verify exact commit without Git

The system automatically selects the best method (`'auto'`).

## Enterprise/Lab Deployments

### Shared Installation

Lab administrators can install dependencies once:

```matlab
% Admin installs to shared location
bct.install.deps('root', '\\server\share\MATLAB_Deps\bct')
```

Users configure BCT to use the shared installation:

```matlab
% Users point to shared location
bct.install.configure('\\server\share\MATLAB_Deps\bct')
```

### Environment Variable

Set `BCT_DEPS_ROOT` to standardize across users:

**Windows:**
```cmd
setx BCT_DEPS_ROOT "\\server\share\MATLAB_Deps\bct"
```

**macOS/Linux:**
```bash
export BCT_DEPS_ROOT="/opt/matlab_deps/bct"
```

After setting the environment variable, `bct.install.deps` and `bct.start` automatically use that location.

## Lock File

When `writeLock=true` (default), a lock file is created at:
```
<depsRoot>/deps.lock.json
```

Contains:
- Installation timestamp
- Dependency root path
- Installation method used
- Requested and installed commit SHAs
- BCT version (if available)

This enables reproducibility and debugging.

## Troubleshooting

### Dependencies Not Found

If `bct.start` reports missing dependencies:

```matlab
bct.install.deps
```

### Git Not Available

Use ZIP mode:

```matlab
bct.install.deps('method', 'zip')
```

### Permission Errors

Install to a user-writable location:

```matlab
bct.install.deps('root', 'C:\Users\<you>\MyMATLAB\bct_deps')
```

### Force Reinstall

If installations are corrupted:

```matlab
bct.install.deps('overwrite', true)
```

### Check Status

See what's installed and available:

```matlab
bct.install.status()
```

## Integration with bct.start

The `bct.start` function automatically:

1. Calls `bct.install.addToPath(cfg)` to add dependencies to path
2. Calls `bct.install.require()` to validate availability
3. Fails with clear instructions if dependencies are missing

`bct.start` **never downloads** dependencies. Use `bct.install.deps` first.

## Internal Architecture

The implementation follows a clean separation:

**Public API** (`+bct/+install/`)
- `deps.m` - Main installation function
- `status.m` - Status reporting
- `configure.m` - Configuration
- `uninstall.m` - Removal
- `addToPath.m` - Path management (called by bct.start)
- `require.m` - Validation (called by bct.start)

**Internal Utilities** (`+bct/+install/+internal/`)
- `resolveRoot.m` - Root resolution with precedence
- `normalizeUserpath.m` - Userpath parsing
- `hasGit.m` - Git availability detection
- `gitCloneOrUpdate.m` - Git operations
- `zipDownloadAndExtract.m` - ZIP download operations
- `readManifest.m` - Manifest loading
- `detectSymbols.m` - Symbol validation
- `safeRmpath.m` - Safe path removal
- `writeLock.m` - Lock file creation

**Configuration** (`config/`)
- `deps.json` - Dependency manifest with pinned commits

## Files Excluded from .mltbx

When packaging BCT, the `/external` folder is **excluded** from the toolbox file. Dependencies are installed on first use, not bundled in the package.

This keeps the BCT package small and ensures users get fresh, verified dependency versions.

## See Also

- Main documentation: [README.md](../../README.md)
- Contract specification: [BCTINSTALLCONTRACT.md](../../notes/BCTINSTALLCONTRACT.md)
- BCT startup: `help bct.start`
