1) Folder layout (inside your toolbox)
toolbox/
  +bct/
    +data/
      load.m
      list.m
      info.m
      index.m                % authoritative manifest (function returning struct array)
      assets/
        fsaverage6/
          surf/
            fsaverage6_hemi-lh_surf-pial.mat
            fsaverage6_hemi-rh_surf-pial.mat
            fsaverage6_hemi-lh_surf-white.mat
            fsaverage6_hemi-rh_surf-white.mat
            fsaverage6_hemi-lh_surf-inflated.mat
            fsaverage6_hemi-rh_surf-inflated.mat
            fsaverage6_hemi-lh_surf-sphere.mat
            fsaverage6_hemi-rh_surf-sphere.mat
          README.md


Rationale:

assets/ keeps test data separate from code.

A dataset subfolder (fsaverage6/) makes it easy to add other datasets later (e.g., fsaverage5, icbm152, toy/).

File naming encodes key dimensions (hemi, surf) so it is self-describing.

2) Naming convention (canonical ID)

Use a BIDS-like pattern:

<dataset>_hemi-<lh|rh>_surf-<pial|white|inflated|sphere>.mat

Examples:

fsaverage6_hemi-lh_surf-pial.mat

fsaverage6_hemi-rh_surf-pial.mat

Canonical asset ID string

Use the same tokens, but without the extension:

"fsaverage6_hemi-lh_surf-pial"

This is what bct.data.load should accept.

3) Standard .mat contents (contract)

Each .mat should contain at minimum:

V (double, N×3)

F (int32, M×3)

Optional but recommended:

meta struct:

meta.dataset = "fsaverage6"

meta.hemi = "lh"

meta.surface = "pial"

meta.units = "mm"

meta.source = "FreeSurfer"

meta.nVertices, meta.nFaces (redundant but convenient)

Your bct.data.load will normalize to:

mesh = struct( ...
  "Vertices", V, ...
  "Faces", F, ...
  "Meta", meta);


(You can also keep V/F aliases if you want backward compatibility.)

4) The manifest: bct.data.index()

bct.data.index is the authoritative catalog; it returns a struct array like:

S(i).Id        % canonical ID string
S(i).Dataset   % "fsaverage6"
S(i).Hemi      % "lh"|"rh"
S(i).Surface   % "pial"|"white"|...
S(i).Path      % relative path under +bct/+data/assets
S(i).Default   % logical flag for default asset
S(i).Tags      % string array (optional)


This allows:

bct.data.list() to show available assets

bct.data.info(id) to show metadata

bct.data.load() to resolve IDs robustly without hardcoded filenames

5) bct.data.load() behavior (committed spec)
Default call
mesh = bct.data.load();


Loads the canonical default:

fsaverage6_hemi-lh_surf-pial

Explicit selection
mesh = bct.data.load("fsaverage6_hemi-rh_surf-pial");
mesh = bct.data.load("dataset","fsaverage6","hemi","lh","surf","inflated");

Output

Always returns a struct with at least:

Vertices

Faces

Meta

This makes it directly consumable by:

bct.Manifold(mesh) (your constructor already supports V/F variants)

6) Concrete recommendation for your current files

Rename and relocate:

toolbox/+bct/+data/fsaverage_lh_pial.mat
→ toolbox/+bct/+data/assets/fsaverage6/surf/fsaverage6_hemi-lh_surf-pial.mat

toolbox/+bct/+data/fsaverage_rh_pial.mat
→ toolbox/+bct/+data/assets/fsaverage6/surf/fsaverage6_hemi-rh_surf-pial.mat

Then update the .mat files to include meta (optional but recommended).

7) Compatibility and future expansion

This organization scales cleanly to:

additional FreeSurfer surfaces (white, inflated, sphere)

downsampled meshes for fast unit tests (e.g., fsaverage6_hemi-lh_surf-pial_decim-10k)

non-brain meshes (cell mesh, toy sphere mesh)

volumetric meshes (add mesh/ vs surf/ subfolders)

If you add decimation levels, extend naming:

fsaverage6_hemi-lh_surf-pial_res-10k.mat
and include res token in the ID.

8) Minimal API set in bct.data

bct.data.load(...) — load asset by ID; default loads fsaverage6 lh pial

bct.data.list(...) — list IDs (filterable by dataset/hemi/surf)

bct.data.info(id) — returns manifest entry + meta in file (if present)

bct.data.index() — internal catalog used by all the above (public is fine)