%
addpath('toolbox')
bct.start
%%
clear 
%rmdir('data/cortex.zarr', 's');
mPath = 'toolbox\+bct\+data\assets\bunny.obj';
M2 = bct.Manifold.read(mPath);

mPath = 'toolbox\+bct\+data\assets\bunny.obj';
M2 = bct.Manifold.read(mPath);'Style', 'line', ...
    'Stride', 1, ...
    'LengthScale', 1.5, ...
       'Color', 0x0000ff, ...       % Blue  
    'LineWidth', 7


Mst=bct.data.load();
M=bct.Manifold(Mst.Vertices,Mst.Faces)
    Mf=M.flip;
    Maf=M;
    clear M
    M=Mf;
%Mr=M.rescale("from", "mm")
topo = M.topology;
geom = M.geometry;
ops=M.operators;
eigen=M.eigenmodes(500);
bct.file.write.manifold('C:\CodingProjects\Bioctreeapp\src\app\data\bctfsaverage.zarr', M);
%%
eigen=M.eigenmodes(1000);
%%
bct.file.write.manifold('C:\CodingProjects\Bioctreeapp\src\app\data\bctbunny.zarr', M);
mSt=M.toStruct;
%%
Mst=bct.data.load();
M=bct.Manifold(Mst.Vertices,Mst.Faces)
Mflip=M.flip;
Mresc=Mflip.rescale("from", "mm");
M=Mresc;
topo = M.topology;
geom = M.geometry;
ops=M.operators;
eigen=M.eigenmodes(500);
bct.file.write.manifold('C:\CodingProjects\Bioctreeapp\src\app\data\bctfsaverage.zarr', M);
%%
addpath('external\brainstorm3');
mgzFile = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage\mri\orig.mgz";

isApplyBst     = 0;   % keep raw orientation (no Brainstorm convention)
isApplyVox2ras = 0;   % don't apply extra transforms to the returned volume
[sMri, vox2ras, tReorient] = in_mri_mgh(mgzFile, isApplyBst, isApplyVox2ras);

% vox2ras is your key 4x4
disp(vox2ras);



mgzFile = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\mri\orig.mgz";

% 1) Copy to temp with a .gz extension so MATLAB gunzip is happy/predictable
tmpDir = tempdir;
gzFile = fullfile(tmpDir, "orig.gz");
copyfile(mgzFile, gzFile);

% 2) Decompress
outFiles = gunzip(gzFile, tmpDir);   % returns cell array of output filenames
rawOut   = outFiles{1};              % typically: ...\orig

% 3) Ensure it has .mgh extension (optional but helps some readers)
mghFile = fullfile(tmpDir, "orig.mgh");
if ~endsWith(rawOut, ".mgh", "IgnoreCase", true)
    movefile(rawOut, mghFile, "f");
else
    mghFile = rawOut;
end

% 4) Now header-only read works without zcat/rm
mri = MRIread(mghFile, 1);

% Inspect what you got
mgzFile = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage\mri\orig.mgz";

isApplyBst     = 0;   % keep raw orientation (no Brainstorm convention)
isApplyVox2ras = 0;   % don't apply extra transforms to the returned volume
[sMri, vox2ras, tReorient] = in_mri_mgh(mgzFile, isApplyBst, isApplyVox2ras);

%%
% orig is your Brainstorm MRI struct
T_vox2ras_mm = orig.InitTransf{2};      % because {'vox2ras', [4x4]}
S_mm2m = diag([1e-3 1e-3 1e-3 1]);

T_rasmm_to_rasm = S_mm2m;

V_mm = Mst.Vertices;                 % Nx3, currently mm
N = size(V_mm,1);
Vh = [V_mm, ones(N,1)];              % Nx4

V_m = (T_rasmm_to_rasm * Vh')';      % Nx4
V_m = V_m(:,1:3);                    % Nx3


bbox = [min(V_m); max(V_m)];
extent_m = bbox(2,:) - bbox(1,:);
disp(extent_m)
M=bct.Manifold(V_m, Mst.Faces)

aff = struct();
aff.name         = "RAS_mm_to_RAS_m";
aff.fromFrame    = "RAS_mm";
aff.toFrame      = "RAS_m";
aff.unitsIn      = "mm";
aff.unitsOut     = "m";
aff.storageOrder = "column-major";
aff.T            = T_rasmm_to_rasm;
aff.T_flat       = aff.T(:).';       % column-major flatten
aff.appliesTo    = "points";
aff.axisIn       = ["+X=Right","+Y=Anterior","+Z=Superior"];
aff.axisOut      = ["+X=Right","+Y=Anterior","+Z=Superior"];
M=bct.Manifold(V, Mst.Faces)


%%

fs4path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial'
fsdir = 'C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5';
aseg='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\label\lh.aparc.annot';
hemi='lh'
[vertices, faces] = freesurfer_read_surf(fs4path);
M=bct.Manifold(vertices,faces);
M=bct.Manifold(vertices,faces);
Mf=M.flip;clear M
M=Mf;
topo = M.topology;
geom = M.geometry;
ops=M.operators;
eigen=M.eigenmodes(1000);
bct.file.write.manifold('C:\CodingProjects\Bioctreeapp\src\app\data\bctfsaverage5.zarr', M);

[annots] = freesurfer_read_annotation(aseg);
[verticesfs, labelfs, colortablefs] = freesurfer_read_annotation_ctab(aseg);

bct.manifold.write(M, 'C:\CodingProjects\bioctree\data\mesh\fsaverage5.obj')
    mmesh=surfaceMesh(M.Vertices,M.Faces); surfaceMeshShow(mmesh)
    
[V_new, F_new, maskCortex, used] = bct_mask_medial_wall(M, fsdir, hemi);
meshCortex = surfaceMesh(V_new, F_new);
surfaceMeshShow(meshCortex);
S = 1e-3; % mm -> m
T = [ 1  0  0  0;
      0  0  1  0;
      0 -1  0  0;
      0  0  0  1 ];
% Apply:
V1 = [V_new, ones(size(V_new,1),1)];
    V_three = (T * V1')';
    V_three = V_three(:,1:3) * S;
meshCortex = surfaceMesh(V_three, F_new);
surfaceMeshShow(meshCortex);

Mmasked=bct.Manifold(V_three, F_new);
Mf=Mmasked.flip;clear Mmasked
Mmasked=Mf;

bct.manifold.write(Mmasked, 'C:\CodingProjects\bioctree\data\mesh\fsaverage5-masked.obj')