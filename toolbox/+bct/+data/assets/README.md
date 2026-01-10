# BCT Data Assets

This directory contains bundled mesh assets for testing, examples, and demonstrations.

## Directory Structure

```
assets/
├── fsaverage6/
│   └── surf/
│       ├── fsaverage6_hemi-lh_surf-pial.mat
│       └── fsaverage6_hemi-rh_surf-pial.mat
└── README.md
```

## Naming Convention

Asset files follow a BIDS-like naming pattern:

```
<dataset>_hemi-<lh|rh>_surf-<pial|white|inflated|sphere>.mat
```

**Components:**
- `<dataset>`: Dataset identifier (e.g., fsaverage6)
- `hemi-<lh|rh>`: Hemisphere (left or right)
- `surf-<type>`: Surface type (pial, white, inflated, sphere)

**Examples:**
- `fsaverage6_hemi-lh_surf-pial.mat` - Left hemisphere pial surface
- `fsaverage6_hemi-rh_surf-white.mat` - Right hemisphere white matter surface

## File Format

Each `.mat` file contains at minimum:
- `V` or `Vertices`: [N×3] double - vertex coordinates
- `F` or `Faces`: [M×3] int32 - face connectivity (1-indexed)

Optional fields:
- `Meta` or `meta`: struct with metadata
  - `dataset`: Dataset name
  - `hemi`: Hemisphere
  - `surface`: Surface type
  - `units`: Coordinate units (e.g., "mm")
  - `source`: Data source (e.g., "FreeSurfer")

## Current Assets

### fsaverage6

FreeSurfer's fsaverage6 standard brain template (downsampled to ~40k vertices per hemisphere).

**Available surfaces:**
- ✅ `fsaverage6_hemi-lh_surf-pial.mat` - Left pial (default)
- ✅ `fsaverage6_hemi-rh_surf-pial.mat` - Right pial

**Future surfaces:**
- ⏳ white matter (lh, rh)
- ⏳ inflated (lh, rh)
- ⏳ sphere (lh, rh)

## Usage

### Load Default Asset
```matlab
mesh = bct.data.load();
M = bct.Manifold(mesh);
```

### Load Specific Asset by ID
```matlab
mesh = bct.data.load("fsaverage6_hemi-rh_surf-pial");
```

### Load by Attributes
```matlab
mesh = bct.data.load(Dataset="fsaverage6", Hemi="lh", Surface="pial");
```

### List Available Assets
```matlab
ids = bct.data.list();
lh_only = bct.data.list(Hemi="lh");
```

### Get Asset Information
```matlab
info = bct.data.info("fsaverage6_hemi-lh_surf-pial");
fprintf('Vertices: %d, Faces: %d\n', info.NumVertices, info.NumFaces);
```

## Adding New Assets

To add a new dataset:

1. Create dataset directory: `assets/<dataset>/surf/`
2. Add `.mat` files following naming convention
3. Update `bct.data.index()` to register new assets
4. Include metadata in `.mat` files (recommended)
5. Update this README

## Data Sources

### fsaverage6
- **Source**: FreeSurfer (https://surfer.nmr.mgh.harvard.edu/)
- **License**: FreeSurfer license
- **Resolution**: ~40k vertices per hemisphere
- **Coordinate System**: RAS (Right-Anterior-Superior)
- **Units**: millimeters

## License

See individual dataset licenses. FreeSurfer data is distributed under the FreeSurfer Software License Agreement.
