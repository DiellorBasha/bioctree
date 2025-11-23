%% INPUT: your surfaceMesh
% Gmesh = subject.lh.pial_mat;   % <- example
bioctree_start
bctDir='C:\CodingProjects\bioctree\'
subject_dir='C:\CodingProjects\bioctree\test-data\freesurfer\'
subject_name='fsaverage'

%% Make a matlab mesh
subject = fs2gsp(subject_dir, subject_name);
G0 = subject.rh.pial_mat; 
%% Parameters (tweak to taste)
nV=subject.rh.pial_mat.NumVertices;
tag=sprintf('lod_rh_%d', nV)
fname_glb=strcat('test-data/mesh/', subject_name,tag, '.glb')
outDir        = "test-data/mesh/";      % where GLBs go
numLevels     = 10;              % e.g., hi/mid/low
minFracFaces  = 0.001;           % coarsest level ~20% faces
taubinIters   = 6;              % gentle denoise after decimation
taubinScale   = [-0.51, 0.50];  % Taubin (mu, lambda)
boundaryW     = 10;             % protect open boundaries a bit
doCenter      = true;           % recenter to origin
doScaleMeters = false;          % set true to export in meters (three.js-friendly

V0 = G0.Vertices; F0 = G0.Faces;
% (3) Target face counts via a geometric schedule
Fhi = size(F0,1);
if numLevels==1
    targets = Fhi;
else
    r = minFracFaces^(1/(numLevels-1));
    targets = round(Fhi * r.^(0:numLevels-1));   % e.g., [100% 63% 40% 25%...]
end

%% (4) Build, smooth, and export each LOD
clear M SM
for L = 1:numLevels
    % fresh clone from the ORIGINAL each time (avoid compounding artifacts)
    M = surfaceMesh(V0,F0);

    if L>1
        simplify(M, SimplificationMethod="quadric-decimation", ...
                     TargetNumFaces=max(200,targets(L)), ...
                     BoundaryWeight=boundaryW);
        if taubinIters > 0
            M = smoothSurfaceMesh(M, taubinIters, ...
                                     Method="Taubin", ...
                                     ScaleFactor=taubinScale);
        end
    end

computeNormals(M);  % face+vertex normals for good shading
SM(L).M=M;
cmap=repmat([0.7,0.7,0.7], M.NumVertices, 1);
fig2 = uifigure('Position',[720 100 600 600]);
v2   = viewer3d(fig2, BackgroundColor="k", BackgroundGradient="off");
surfaceMeshShow(M, 'Title','LH', 'Parent',v2, 'BackgroundColor','k', 'Colormap', cmap);
    % Export GLB (three.js friendly). Use consistent names: L1=hi, L2=mid...
    outName = fullfile(outDir, sprintf("rh_L%d.glb", L));
    writeSurfaceMesh(M, outName);
    fprintf("Wrote %s  (faces=%d)\n", outName, M.NumFaces);
end


%% 
G = subject.rh.pial_gsp; 

num_levels = 4; % or until the node count is in the few-thousands
Gs = gsp_graph_multiresolution(G, num_levels);