bioctree_start
bctDir='C:\CodingProjects\bioctree\'
subject_dir='C:\CodingProjects\bioctree\test-data\freesurfer\'
subject_name='fsaverage'

%% Make a matlab mesh
subject = fs2gsp(subject_dir, subject_name);
fig1 = uifigure('Position',[100 100 600 600]);

v1   = viewer3d(fig1, BackgroundColor="k", BackgroundGradient="off");
cmap=repmat([0.7,0.7,0.7], subject.lh.pial_mat.NumVertices, 1);
surfaceMeshShow(subject.lh.pial_mat, 'Title','LH', 'Parent',v1, 'BackgroundColor','k', 'Colormap', cmap);
surfaceMeshShow(subject.rh.pial_mat, 'Title','LH', 'Parent',v1, 'BackgroundColor','k', 'Colormap', cmap);

%% 
GLs=smoothSurfaceMesh(subject.lh.pial_mat, 2);
GRs=smoothSurfaceMesh(subject.rh.pial_mat, 2);
numIterations = 3;
scaleFactor   = [-0.31, 0.30];
GLs = smoothSurfaceMesh(subject.lh.pial_mat, numIterations, Method="Taubin", ScaleFactor=scaleFactor);

fig2 = uifigure('Position',[720 100 600 600]);
v2   = viewer3d(fig2, BackgroundColor="k", BackgroundGradient="off");
surfaceMeshShow(GLs, 'Title','LH', 'Parent',v2, 'BackgroundColor','k', 'Colormap', cmap);
surfaceMeshShow(subject.rh.pial_mat, 'Title','LH', 'Parent',v2, 'BackgroundColor','k', 'Colormap', cmap);

%% 
nV=subject.lh.pial_mat.NumVertices;
tag=sprintf('_lh_%d', nV)
fname_glb=strcat('test-data/mesh/', subject_name,tag, '.glb');
fname_gltf=strcat('test-data/mesh/', subject_name,tag, '.gltf');
writeSurfaceMesh(subject.lh.pial_mat,fullfile(bctDir, fname_glb))
writeSurfaceMesh(subject.lh.pial_mat,fullfile(bctDir, fname_gltf))

nV=subject.rh.pial_mat.NumVertices;
tag=sprintf('_rh_%d', nV)
fname_glb=strcat('test-data/mesh/', subject_name,tag, '.glb');
fname_gltf=strcat('test-data/mesh/', subject_name,tag, '.gltf');
writeSurfaceMesh(subject.rh.pial_mat,fullfile(bctDir, fname_glb))
writeSurfaceMesh(subject.rh.pial_mat,fullfile(bctDir, fname_gltf))

% % 
%% 
G=subject.lh.pial_gsp;
V0 = G.coords;           % N x 3
F0  = G.Faces;  
G = gsp_estimate_lmax(G);
%% 
taus = [64, 256, 1024, 4096, 16384];  % ~8,16,32,64,128 mm blur radii
meshes = fem_heat_smooth(G, taus, struct('solver',"chol", 'recenter',false));
K=length(taus)
for k=1:K
    cmap=repmat([0.7,0.7,0.7], Gt.NumVertices, 1);
fig2 = uifigure('Position',[720 100 600 600]);
v2   = viewer3d(fig2, BackgroundColor="k", BackgroundGradient="off");
surfaceMeshShow(meshes{k}, 'Title','LH', 'Parent',v2, 'BackgroundColor','k', 'Colormap', cmap);
end

%% 

% 2) Very coarse heat kernels (normalized by lmax internally)
alpha = [0.1 0.05 0.02 0.01 0.005 0.001];     % cutoffs at α*lmax
g      = 0.01;                                % -40 dB at cutoff
taus_param = (-log(g)) ./ alpha;              % *** pass these τ to design_heat ***
Hk = gsp_design_heat(G, taus_param);

taus_param = (-log(g)) ./ alpha;   % *** this is the tau to pass to gsp_design_heat ***
Hk = gsp_design_heat(G, taus_param);
cheb.order = 400;                              
% Filter coordinates x,y,z (reshape handling included)
V0 = G.coords; N = G.N; K = numel(taus_param);
Xt = cell(K,1);
for j = 1:3
    Sj = gsp_filter_analysis(G, Hk, V0(:,j), cheb);  % N×K or (N*K)×1
    if size(Sj,1)==N && size(Sj,2)==K, SjM = Sj; else, SjM = reshape(Sj,[N,K]); end
    for k=1:K
        if j==1, Xt{k} = zeros(N,3,'like',V0); end
        Xt{k}(:,j) = SjM(:,k);
    end
end


for k=1:K
    Gt = surfaceMesh(Xt{k}, G.Faces);
    cmap=repmat([0.7,0.7,0.7], Gt.NumVertices, 1);
fig2 = uifigure('Position',[720 100 600 600]);
v2   = viewer3d(fig2, BackgroundColor="k", BackgroundGradient="off");
surfaceMeshShow(Gt, 'Title','LH', 'Parent',v2, 'BackgroundColor','k', 'Colormap', cmap);
end

%% 

% Build meshes per tau (faces stay the same), recompute normals, export
for k=1:K
    Gt = surfaceMesh(Xt{k}, G.Faces);
    computeNormals(Gt);
    outname = sprintf('fsavg_L_t%g.glb', taus(k));
    writeSurfaceMesh(Gt, outname, VertexNormals=vn);
end

cmap=repmat([0.7,0.7,0.7], Gt.NumVertices, 1);
fig2 = uifigure('Position',[720 100 600 600]);
v2   = viewer3d(fig2, BackgroundColor="k", BackgroundGradient="off");
surfaceMeshShow(Gt, 'Title','LH', 'Parent',v2, 'BackgroundColor','k', 'Colormap', cmap);


%%
%Analyze signal
meshL=subject.lh.pial_mat; meshR=subject.rh.pial_mat; 
nV=double(meshL.NumVertices);
S=generateTestSignals(double(nV));
X1=S.morlet;
colormaplist
cmap = hot(nV);
idx  = max(1, min(nV, round(1 + X1*(size(cmap,1)-1))));
C    = cmap(idx,:);

meshL.VertexColors = C;     
fig2 = uifigure('Position',[720 100 600 600]);
v2   = viewer3d(fig2, BackgroundColor="k", BackgroundGradient="off");
surfaceMeshShow(meshL, 'Title','LH', 'Parent',v2, 'BackgroundColor','k');
surfaceMeshShow(meshR, 'Title','LH', 'Parent',v2, 'BackgroundColor','k');
%% Reduce the mesh
clear R_low R_low_S
% Originals (don't touch)
meshL = subject.lh.pial_mat;
meshR = subject.rh.pial_mat;


taus = [1, 10, 100, 1000];
Hk = gsp_design_heat(G, taus);

S = zeros(G.N, 1);
vertex_delta = 8785;
S(vertex_delta) = 1;

Sf_vec = gsp_filter_analysis(G, Hk, S);
Sf = gsp_vec2mat(Sf_vec, length(taus));

%% 
outDir = fullfile(pwd, 'test-data', 'mesh');% Measures to export (fields under subject.lh / subject.rh)
measures = {'curv','thickness','sulc','area'};
hemis = {'lh','rh'};
if ~exist(outDir,'dir'), mkdir(outDir); end
oldDir = pwd; cleanupObj = onCleanup(@() cd(oldDir));
cd(outDir);

for h = 1:numel(hemis)
    H = hemis{h};
    % use your surfaceMesh to validate vertex count
    nV = subject.(H).pial_mat.NumVertices;
    for m = 1:numel(measures)
        M = measures{m};
        % Some subjects might miss a field; skip gracefully
        if ~isfield(subject.(H), M) || ~isfield(subject.(H).(M), 'data')
            warning('%s_%s missing; skipping.', H, M);
            continue;
        end
        data = subject.(H).(M).data(:);
        if numel(data) ~= nV
            warning('%s_%s has %d values but mesh has %d vertices — skipping.', H, M, numel(data), nV);
            continue;
        end
        % Ensure Float32 for compact files (NaNs preserved for NoData)
        data = single(data);
        % Base name like "lh_curv", "rh_thickness", ...
        baseName = sprintf('%s_%s', H, M);
        % Your writer makes <base>.bin + <base>.json (or whatever it does)
        writeCurvJSON(baseName, data);
        fprintf('Wrote %s.{bin,json}\n', baseName);
    end
end



%% 

Nlevel = 5;
Gs = gsp_graph_multiresolution(G, Nlevel);
gsp_plot_graph(G)
param_plot.cp = [0.1223, -0.3828, 12.3666];

figure (1);
clf
for ii = 1:numel(Gs)
    subplot(2,3,ii)
    gsp_plot_graph(Gs{ii}, param_plot)
    title(['Reduction level: ', num2str(ii-1)]);
end


clf
gsp_plot_signal(G1,X)

[ca,pe]=gsp_pyramid_analysis(Gs,X, Nlevel);
%% 
figure (1)
paramplot.show_edges = 0;
for ii = 1:numel(Gs)
    subplot(2,3,ii)
    gsp_plot_signal(Gs{ii},pe{ii},paramplot);
    title(['P. E. level: ', num2str(ii-1)]);
end
%% 

figure(1)
clf
for ii = 1:numel(Gs)
    subplot(2,3,ii)
    gsp_plot_signal(Gs{ii},ca{ii},paramplot)
    title(['C. A. level: ', num2str(ii-1)]);
end
%% 
wW = nonzeros(W);       % vector of weights
wC = nonzeros(W_cot);

figure('Name','Weight histograms');
subplot(1,2,1); histogram(wW, 100);    title('W weights');   xlabel('w'); ylabel('count');
subplot(1,2,2); histogram(wC, 100);    title('W\_cot weights');

figure('Name','Log-weight histograms');
subplot(1,2,1); histogram(log10(wW), 100); title('log10 W'); xlabel('log10 w');
subplot(1,2,2); histogram(log10(abs(wC)), 100); title('log10 |W\_cot|');
%% 
degW = full(sum(W,2));          % weighted degree (strength)
degC = full(sum(W_cot,2));

% Basic surface maps (Vertices: N×3, Faces: M×3 (1-based))
figure('Name','Degree map: W');
trisurf(Faces, Vertices(:,1),Vertices(:,2),Vertices(:,3), degW, ...
        'EdgeColor','none'); axis equal off; camlight; lighting gouraud
title('Weighted degree (W)'); colorbar

figure('Name','Degree map: W\_cot');
trisurf(Faces, Vertices(:,1),Vertices(:,2),Vertices(:,3), degC, ...
        'EdgeColor','none'); axis equal off; camlight; lighting gouraud
title('Weighted degree (W\_cot)'); colorbar
%% 
% Choose a percentile (e.g., top 1% by weight) and plot as lines
pct = 99;  % try 99, 99.5, 99.9
[iW,jW,sW] = find(W);
thrW = prctile(sW, pct);
maskW = sW >= thrW;
Ew = [iW(maskW), jW(maskW)];

figure('Name','Top edges (W)');
trisurf(Faces, Vertices(:,1),Vertices(:,2),Vertices(:,3), ...
        'FaceColor',[0.9 0.9 0.9],'EdgeColor','none'); hold on
for k=1:size(Ew,1)
    P = Vertices(Ew(k,:),:);
    plot3(P(:,1),P(:,2),P(:,3),'-','LineWidth',0.5);
end
axis equal off; camlight; lighting gouraud; title(sprintf('Top %.1f%% edges (W)',100-pct));

% Repeat for W_cot (use absolute value if you want strongest magnitude)
[iC,jC,sC] = find(W_cot);
thrC = prctile(abs(sC), pct);
maskC = abs(sC) >= thrC;
Ec = [iC(maskC), jC(maskC)];

figure('Name','Top edges (W\_cot)');
trisurf(Faces, Vertices(:,1),Vertices(:,2),Vertices(:,3), ...
        'FaceColor',[0.9 0.9 0.9],'EdgeColor','none'); hold on
for k=1:size(Ec,1)
    P = Vertices(Ec(k,:),:);
    plot3(P(:,1),P(:,2),P(:,3),'-','LineWidth',0.5);
end
axis equal off; camlight; lighting gouraud; title(sprintf('Top %.1f%% edges (W\\_cot)',100-pct));

%% 

[lap,edge] = mesh_laplacian(pial.lh.pial.vertices,pial.lh.pial.faces);

%% 
mesh = surfaceMesh(vertices,faces);
surfaceMeshShow(mesh)


 simplify(mesh,SimplificationMethod="quadric-decimation", ...
             TargetNumFaces=30)


 removeDefects(mesh,"unreferenced-vertices")
surfaceMeshShow(mesh,WireFrame=true)


translate(mesh,translationVector)

ptCloud = mesh2pc(mesh);

figure
pcshow(ptCloud);
%% 

isEdgeManifold	Check if surface mesh is edge-manifold
isOrientable	Check if surface mesh is orientable
isSelfIntersecting	Check if surface mesh is self-intersecting
isVertexManifold	Check if surface mesh is vertex-manifold
isWatertight	Check if surface mesh is watertight
%% 

reduceSurf = 0;

if reduceSurf,
  
  fprintf('...running reducepatch\n');
  surfReduced = reducepatch(surf, 80000);
  
  % find vertices in the reduced tesselation that match those of the dense
  % tesselation it's fast with nearpoints, but this can take several hours to
  % run with dsearchn!
  indexSparseInPial = [];
  if exist('nearpoints','file')
    fprintf('...running nearpoints\n');
    indexSparseInPial = nearpoints(surfReduced.vertices',surf.vertices');
    indexSparseInPial = indexSparseInPial';
  else
    fprintf('...running dsearchn\n');
    indexSparseInPial = dsearchn(surf.vertices,surfReduced.vertices);
  end
  
  % assign the curvature from the dense tesselation
  % into the reduced tesselation
  surfReduced.curv = surf.curv(indexSparseInPial,:);

  [Hf,Hp] = freesurfer_plot_curv(surfReduced, surfReduced.curv)
  
else
  
  [Hf,Hp] = freesurfer_plot_curv(surf, surf.curv)
  
end

%surf = mesh_smooth_vertex(surf);
%% How do we recalculate the surface curvature?
%[Hf,Hp] = freesurfer_plot_surf([],surf)

colormap(flipud(gray(200)))


colorbar off


% plot view config:
daspect([1,1,1]);
camproj perspective 
camva(7)
camtarget([0,0,0])

Hlight = camlight('headlight');

%lighting phong
%set(gcf,'Renderer','zbuffer')
%lighting gouraud
%set(gcf,'Renderer','OpenGL')

drawnow

saveImages = 0;

viewL = [-90,  0];
viewR = [ 90,  0];
viewA = [180,  0];
viewP = [  0,  0];
viewD = [  0, 90];
viewV = [  0,-90];

view(viewL)
camlight(Hlight,'headlight');
drawnow
if saveImages,
  save_png('pialSurfL.png',Hf);
else
  pause(2)
end

view(viewR)
camlight(Hlight,'headlight');
drawnow
if saveImages,
  save_png('pialSurfR.png',Hf);
else
  pause(2)
end

view(viewA)
camlight(Hlight,'headlight');
drawnow
if saveImages,
  save_png('pialSurfA.png',Hf);
else
  pause(2)
end

view(viewP)
camlight(Hlight,'headlight');
drawnow
if saveImages,
  save_png('pialSurfP.png',Hf);
else
  pause(2)
end

view(viewD)
camlight(Hlight,'headlight');
drawnow
if saveImages,
  save_png('pialSurfD.png',Hf);
else
  pause(2)
end

view(viewV)
camlight(Hlight,'headlight');
drawnow
if saveImages,
  save_png('pialSurfV.png',Hf);
else
  pause(2)
end
