# Documentation Assets

This directory contains assets for the Bioctree documentation.

## Structure

```
assets/
├── models/           # 3D mesh files (.glb, .obj)
├── data/             # Field data files (.json)
└── images/           # Static images (.png, .jpg, .svg)
```

## Models Directory

Store 3D mesh files in GLB or OBJ format:

- **GLB**: Recommended (binary, smaller, faster loading)
- **OBJ**: Text-based, larger but human-readable

Example models to add:
- `fsaverage_rh_pial.glb` - Right hemisphere pial surface
- `fsaverage_lh_pial.glb` - Left hemisphere pial surface
- `sphere.glb` - Simple sphere for testing

## Data Directory

Store field data as JSON files:

```json
{
  "support": "vertex",
  "valueType": "scalar",
  "values": [0.1, 0.5, -0.3, ...]
}
```

## Usage in Markdown

```markdown
<div class="mesh-viewer" 
     data-model="../assets/models/fsaverage_rh_pial.glb"
     data-field="../assets/data/eigenmode-1.json"
     data-height="600px">
</div>
```

## Export from MATLAB

To export models and fields for documentation, use:

```matlab
% Export mesh as GLB (requires external tool or manual conversion)
M = bct.data.load('Id', 'fsaverage_rh_pial');
% ... export to OBJ, then convert to GLB

% Export field data
field_data = struct();
field_data.support = 'vertex';
field_data.valueType = 'scalar';
field_data.values = your_field_values;
jsonStr = jsonencode(field_data);
fid = fopen('docs/docs/assets/data/field.json', 'w');
fprintf(fid, '%s', jsonStr);
fclose(fid);
```
