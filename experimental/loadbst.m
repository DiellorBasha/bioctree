bstdatapath='C:\CodingProjects\bioctree\data\datasets\brainstorm\data';
  studyName = 'notch_high';
iStudy = load(fullfile(bstdatapath, studyName, 'brainstormstudy.mat' ));
studyPath = fullfile(bstdatapath, studyName);   

dSPM=load(fullfile(studyPath, 'results_dSPM-unscaled_MEG_KERNEL_210314_2210.mat'));
datafile=load(fullfile(studyPath,'data_block002.mat')); 
chanfile=load(fullfile(studyPath,"channel_ctf_acc1.mat"));
chanflag=load(fullfile(studyPath,"chan_flags_v1.mat"));
anat=load('toolbox\+bct\+data\assets\brainstorm\anat\sub-0002\tess_cortex_pial_low.mat');

megInd = find(strcmp({chanfile.Channel.Type}, 'MEG'));
flagInd = find(datafile.ChannelFlag==1);
chans=intersect(megInd, flagInd);
fs=2400;
IK= dSPM.ImagingKernel;
F=datafile.F;
F=F(chans,:);

MR=load("C:\CodingProjects\bioctree\toolbox\+bct\+data\assets\brainstorm\anat\sub-0002\subjectimage_MRI_T1.mat")

S = IK * F;
time = datafile.Time;
%%

% 1. Create initial Manifold from anatomical data
M = bct.Manifold(anat.Vertices, anat.Faces);

% 2. Rescale first (if in mm, common for anatomical data)
M = M.rescale('From', 'mm');

% 3. Repair topology defects
M = M.repair();  % Fixes: duplicates, unreferenced vertices, non-manifold edges, degenerates

% 4. Fix orientation (flip if inward)
h = M.health();
if isfield(h.is, 'outward') && ~h.is.outward
    M = M.flip();
end

% 5. Split into hemispheres (if needed as separate manifolds)
hemispheres = M.split();  % Returns cell array: {MRH, MLH} (sorted by size)

% Now you have clean, correctly-oriented, separate hemisphere manifolds
MRH = hemispheres{1};  % Right hemisphere (or largest)
MLH = hemispheres{2};  % Left hemisphere (or second)
%%

addpath("..\brainstorm3")
[rH, lH, isConnected, iStruct, iRightScout, iLeftScout] = tess_hemisplit(anat);

V=anat.Vertices; F=anat.Faces;
M=bct.Manifold(V, F);

gr=graph(M.adjacency);
grcomponents = conncomp(gr,'OutputForm','cell');


% Rescale from millimeters to meters
M = bct.manifold.metric.rescale(M, 'From', 'mm');

bct.ui.show(M)
h=M.health
h.issues
%% 
meshfs = bct.data.load();  % Loads fsaverage6_hemi-lh_surf-pial by default
Mfs = bct.Manifold(meshfs);
%%
% 2) Build hemisphere membership masks
isRH = false(size(V,1),1);
isLH = false(size(V,1),1);
isRH(rH) = true;
isLH(lH) = true;

% 3) Faces for each hemisphere (strict: all 3 vertices belong)
facesRH_mask = all(isRH(F), 2);
facesLH_mask = all(isLH(F), 2);
FRH = F(facesRH_mask, :);   % right hemi faces (original indexing)
FLH = F(facesLH_mask, :);   % left hemi faces  (original indexing)
% 4) Compact right hemisphere mesh: (VRH, FRH2)
usedRH = unique(FRH(:));
mapRH  = zeros(size(V,1),1);
mapRH(usedRH) = 1:numel(usedRH);
VRH  = V(usedRH, :);
FRH2 = mapRH(FRH);
% 5) Compact left hemisphere mesh: (VLH, FLH2)
usedLH = unique(FLH(:));
mapLH  = zeros(size(V,1),1);
mapLH(usedLH) = 1:numel(usedLH);
VLH  = V(usedLH, :);
FLH2 = mapLH(FLH);

%% 6) OPTIONAL: Split vertex-wise source time series by hemisphere
% IMPORTANT: do NOT use anat.Faces here.
% Use sensor data matrix (channels x time) or (time x channels) depending on your pipeline.

% Example assumption:
%   IK     : [N x nChannels]
%   dataF  : [nChannels x nTime]
% Then:
%   S      : [N x nTime] source time series on vertices

% --- Uncomment and adapt these lines to your actual variables ---
% S = IK * dataF;        % [N x nTime]
SRH = S(rH, :);        % right hemi vertex time series
SLH = S(lH, :);        % left hemi vertex time series
%%
clear M
M = bct.Manifold (VLH, FLH2);
[viewer, fig] = bct.ui.show(M);

    smesh = surfaceMesh(M.Vertices, M.Faces);
   viewer.setMesh(smesh.Vertices, smesh.Faces)

h=M.health
h.issues.message
%%
% Convert Manifold to surfaceMesh
mesh = surfaceMesh(M.Vertices, M.Faces);

% Apply fixes in sequence
removeDefects(mesh,"duplicate-vertices")
removeDefects(mesh,"duplicate-faces")
removeDefects(mesh,"unreferenced-vertices")
removeDefects(mesh,"degenerate-faces")
removeDefects(mesh,"nonmanifold-edges")

% Convert back to Manifold
M_clean = bct.Manifold(mesh.Vertices, mesh.Faces);

% Check health
h = M_clean.health();
h.summary
h.issues

% Fix orientation if still inward
if ~h.is.outward
    M_clean = M_clean.flip();
end

 viewer.clearMesh
viewer.setMesh(M_clean)

clear M; M=M_clean;
%%
M.geometry;
M.topology;
M.operators;
M.dec;
M.eigenmodes(500);
%%

Mflipped = M.flip; 
clear M
M=Mflipped; h=M.health
h.issues.message

mesh = surfaceMesh (M.Vertices, M.Faces);
removeDefects(mesh,"duplicate-vertices");
removeDefects(mesh,"duplicate-faces");
removeDefects(mesh,"unreferenced-vertices");
removeDefects(mesh,"degenerate-faces");
removeDefects(mesh,"nonmanifold-edges");
clear M
M=bct.Manifold(mesh.Vertices, mesh.Faces);
h2=M.health
h2.is

[viewer1, fig1] = bct.ui.show(M);
%%

V = data.V;  % Vertices [N×3]
F = data.F;  % Faces [M×3]

fprintf('  Loaded: %d vertices, %d faces\n', size(V, 1), size(F, 1));

%% Create bct.Manifold object
fprintf('\nCreating bct.Manifold object...\n');
Mtest = bct.Manifold(V, F);
Mtest.vertexGeometry
[viewer3 , fig2]=bct.ui.show(Mtest)