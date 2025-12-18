
bioctree_start
fs6 = bct_fsaverage('lh', 'saved');

addpath 'C:\CodingProjects\bioctree-ui-library\controllers'
%% 

f = uifigure('Position',[100 100 1200 800]);

root = uigridlayout(f);
root.RowHeight = {'1x'};
root.ColumnWidth = {'1x'};

ec = EigenmodeController(root);
ec.Layout.Row = 1;
ec.Layout.Column = 1;

% Mesh
ec.setMeshFromVerticesFaces( ...
    fs6.Manifold.Vertices, ...
    fs6.Manifold.Faces);

% Eigenmodes
ec.setEigenmodes( ...
    fs6.Lambda.lambda, ...
    fs6.Lambda.U);
%% 
%% 

fs6Graph = bct.io.convert.manifoldToMatlabGraph(fs6.Manifold,'Weighted', true);
fs6Graph = bct.io.convert.manifoldToMatlabGraph(fs6.Manifold);
fs6GSP = bct.io.convert.manifoldToGspGraph(fs6.Manifold);
fs6Graph = graph(fs6GSP.W);

% Compute Euclidean edge lengths
summary(fs6Graph.Edges.Weight)
plot(fs6Graph)
source = 1;   % vertex index
target = 3;

                cmapM = ColormapModel();
                cmapM.Name = 'gray';

[path, dist] = shortestpath(fs6Graph, source, target);
brushSize = 10;
for k = 1:length(path)
nodeIDs = nearest(fs6Graph,path(k),brushSize, 'Method','unweighted'); 
patchTrajectory{k,:}=nodeIDs;
end

bgColor    = [0.8 0.8 0.8];   % light gray
patchColor = [1.0 0.0 0.0];   % red
N = fs6.Manifold.N;

mask = false(N,1);
mask(patchTrajectory{k,:}) = true;
C = single(mask).*patchColor + single(~mask).*bgColor;
fs6.showMesh
fs6.Viewer.CurrentObject.Color = C;
visitCount = zeros(N,1,'single');

for k = 1:length(patchTrajectory)
    visitCount(patchTrajectory{k}) = visitCount(patchTrajectory{k}) + 1;
end
visitCount = visitCount / max(visitCount);
RGB = visitCount .* patchColor + (1 - visitCount) .* bgColor;


 fs6.showMesh
fs6.Viewer.CurrentObject.Color=RGB;
SurfaceObj.Color = RGB;

vtcs=fs6.Viewer.CurrentObject.Data.Points;
P_local=vtcs(path,:);
fs6.Viewer.Annotations.Position(1,:)=single(vtcs(source,:));
fs6.Viewer.Annotations.Position(2,:)=single(vtcs(target,:));

%%
Triangul=fs6.Viewer.CurrentObject.Data
V=Triangul.Points;
for k=1:5
sourceIdx=path(k)
sourcePosition=V(sourceIdx,:)
vidx = nearestNeighbor(Triangul, sourcePosition)
isSame(k)=sourceIdx==vidx;
end
isSame

%% 
Triangul=fs6.Viewer.CurrentObject.Data
V=Triangul.Points;

sourceIdx=path(k)
for k=1:2
sourcePosition=double(fs6.Viewer.Annotations.Position(k,:))
vidx = nearestNeighbor(Triangul, sourcePosition)
V(vidx,:)
isSame(k)=sourceIdx==vidx;
end
isSame
%% 
viewer33=viewer3d
surfaceMeshShow(ffmesh,Title="Surface Mesh",ColorMap="hot",BackgroundColor="blue", Parent=viewer33)
%% 
% --------------------------------------------------
% Create signal model
% --------------------------------------------------
signalModel = CompositeSignalModel();

% Optional: start with one signal
reg = SignalRegistry.getRegistry();
signalModel.addSignal(reg.Delta.Constructor());

f = uifigure('Position',[100 100 600 400], ...
             'Name','Signal Factory Demo');

root = uigridlayout(f);
root.RowHeight   = {'1x'};
root.ColumnWidth = {'1x'};

sf = SignalFactoryUI(root);
sf.Layout.Row = 1;
sf.Layout.Column = 1;

% Bind model
sf.Model = signalModel;


%% 

addpath 'C:\CodingProjects\bioctree-ui-library\controllers'
f = uifigure('Position',[100 100 1200 800]);

root = uigridlayout(f);
root.RowHeight = {'1x'};
root.ColumnWidth = {'1x'};

mc = ManifoldController(root);
mc.Layout.Row = 1;
mc.Layout.Column = 1;

mc.setMeshFromVerticesFaces( ...
    fs6.Manifold.Vertices, ...
    fs6.Manifold.Faces);

lambda = fs6.Lambda.lambda;
k=68
phi = fs6.Lambda.U(:, k);
phi = phi / max(abs(phi));
phiRGB = bct.show.x2rgb(phi, 'symmetric', true, 'colormap', 'redblue');

 mc.Viewer.CurrentObject.Color = phiRGB;
%%

B = bct_fsaverage('lh', 'saved');
B.Time = bct.Time(100, 200);

bioctree_start
% Import FreeSurfer surface (fastest - UV not computed)
fs6 = bct.io.import.mesh('C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage6\surf\rh.pial');
fs6 = fs6.computeEigenbasis(600);
% This automatically puts both files in the same location
fs6.save('data/bct/fs6_rh_pial.mat');
load('data/bct/fs6_rh_pial.mat', 'B');
% Simple save - automatically creates both .mat and .h5 files

fs6l = bct.io.import.mesh('C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage6\surf\lh.pial');
fs6l = fs6l.computeEigenbasis(600);
% This automatically puts both files in the same location
fs6l.save('data/bct/fs6_lh_pial.mat');

fs4l = bct.io.import.mesh('C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage4\surf\lh.pial');
fs5l = fs6l.computeEigenbasis(600);
% This automatically puts both files in the same location
fs5l.save('data/bct/fs5_lh_pial.mat');

%% 

% To do: Djikstra graph travel
        % Kernel library
        % Colorbars, scales
        % Spectral LIC - EigenmodeController

f = uifigure('Position',[664 556 421 363]);

root = uigridlayout(f);
root.RowHeight   = {'1x'};
root.ColumnWidth = {'1x'};
view1 = DensityStrip(root);
view1.Data = lambda;
view1.Bandwidth = 10;


%% 1 

lambda = fs6.Lambda.lambda;
model  = KernelModel(lambda);

f = uifigure('Position',[664 556 421 363]);

root = uigridlayout(f);
root.RowHeight   = {'1x'};
root.ColumnWidth = {'1x'};

ui = KernelFactoryUI(root);
ui.Layout.Row = 1;
ui.Layout.Column = 1;

ui.Model = model;


%%
lambda = fs6.Lambda.lambda;
model  = KernelModel(lambda);

f = uifigure('Position',[664 556 800 360]);

% --------------------------------------------------
% Root layout
% --------------------------------------------------
root = uigridlayout(f);
root.RowHeight   = {'1x'};
root.ColumnWidth = {'1x','1x'};   % two panels

% --------------------------------------------------
% Kernel factory UI (left)
% --------------------------------------------------
ui = KernelFactoryUI(root);
ui.Layout.Row = 1;
ui.Layout.Column = 1;
ui.Model = model;

% --------------------------------------------------
% Eigenmode weight viewer (right)
% --------------------------------------------------
wview = EigenmodeWeightViewer(root);
wview.Layout.Row = 1;
wview.Layout.Column = 2;
wview.Model = model;

%% Spatial Selector
f = uifigure('Position',[300 300 420 320], ...
             'Name','SpatialSelectorUI — Standalone');

root = uigridlayout(f);
root.RowHeight   = {'1x'};
root.ColumnWidth = {'1x'};
selectorModel = SpatialSelectorModel();
kernelModel   = KernelModel(fs6.Lambda.lambda);

ui = SpatialSelectorUI(root);
ui.Model       = selectorModel;
ui.KernelModel = kernelModel;   % ← MUST be set before using Spectral

% --------------------------------------------------
% Create selector model
% --------------------------------------------------
selectorModel = SpatialSelectorModel();

% Attach a Delta selector
selectorModel.Selector = DeltaSpatialSelector();

% --------------------------------------------------
% Create UI
% --------------------------------------------------
selectorUI = SpatialSelectorUI(root);
selectorUI.Layout.Row    = 1;
selectorUI.Layout.Column = 1;

selectorUI.Model = selectorModel;
%%
fs6Graph = bct.io.convert.manifoldToMatlabGraph(Manifold,'Weighted', true);

%% 
f = uifigure('Position',[100 100 400 400]);

root = uigridlayout(f);
root.RowHeight = {'1x'};
root.ColumnWidth = {'1x'};

mc = ManifoldController(root);
mc.Layout.Row = 1;
mc.Layout.Column = 1;

% Initialize with Manifold geometry
mc.initializeFromManifold(fs6.Manifold);

f = uifigure('Position',[100 100 400 400]);

root = uigridlayout(f);
root.RowHeight = {'1x'};
root.ColumnWidth = {'1x'};

mc = EigenmodeController(root);
mc.Layout.Row = 1;
mc.Layout.Column = 1;

% Initialize with Manifold geometry
mc.initializeFromManifold(fs6.Manifold);

% Set spectral basis (automatically refreshes spatial selector)
mc.setEigenmodes(fs6.Lambda.lambda, fs6.Lambda.U);


f = uifigure('Position',[100 100 800 400]);

root = uigridlayout(f);
root.RowHeight = {'1x'};
root.ColumnWidth = {'1x'};

ui = SpatialSelectorUI(root);
ui.Layout.Row = 1;
ui.Layout.Column = 1;
ui.Model = SpatialSelectorModel();


%%
% Create UI
fig = uifigure('Position', [100 100 800 600]);
context = ManifoldBrushContext();
context.Manifold = fs6.Manifold;

% Create toolbar
toolbar = ManifoldBrushToolbar(fig, 'Context', context);
toolbar.Position = [10 10 60 400];

% Listen for selection
addlistener(toolbar, 'BrushSelected', @(src, evt) ...
    fprintf('Selected: %s\n', evt.BrushType));


%%
fs6.showMesh
V=fs6.Manifold.Vertices;
F=fs6.Manifold.Faces;
ManifoldTriangulation = triangulation(double(fs6.Manifold.Faces), fs6.Manifold.Vertices);
mesh = surfaceMesh(fs6.Manifold.Vertices,fs6.Manifold.Faces);
mesh.computeNormals;
scalingFactor = 0.9;
mesh.scale(scalingFactor);
translationVec = [1 2 3];
pivot = vertexCenter(mesh);
translate(mesh,translationVec,pivot)


BrushTriangulation=triangulation(double(mesh.Faces),mesh.Vertices);
BrushTriangulation=ManifoldTriangulation;
nV = fs6.Manifold.N;

bgColor  = single([0.6 0.6 0.6]);
selColor = single([1 0 0]);

rgb = repmat(bgColor, nV, 1);   % allocate ONCE
bgRow  = repmat(bgColor,  nV, 1);        % nV×3
selRow = repmat(selColor, nnz(sel), 1);  % nnz(sel)×3

%%
viewer=viewer3d ("BackgroundColor",[0 0 0 ],"BackgroundGradient","off","RenderingQuality","high");
ManifoldSurf = images.ui.graphics.Surface(viewer,...
    'Data',  ManifoldTriangulation, ...
    'Alpha', 0.7, ...
    'Color',[0.6 0.6 0.6]);
BrushSurf = images.ui.graphics.Surface(viewer,...
    'Data',  BrushTriangulation, ...
    'Alpha', 1, ...
     'Color',[0.6 0.6 0.6]);


seed = 1000;
params = struct( ...
    'seed',  seed, ...
    'k',     50 );

w = bct.brush.apply('patch_nearest', fs6.Manifold, params);
w = full(w);          % dense kernel
w = w / max(w);       % normalize to [0,1]
sel = w > 0;                 % logical 40962×1
nV = numel(w);
rgb = repmat([0.6 0.6 0.6], nV, 1);   % background color
selColor = [1 0 0];   % or any RGB triplet
rgb(sel, :) = repmat(selColor, nnz(sel), 1);


BrushPoint = images.ui.graphics.roi.Point(Position=fs6.Manifold.Vertices(seed,:));
viewer.Annotations=BrushPoint;
BrushSurf.Color=rgb;
%% 

source = 1000;
target=16000 ;
params_geo = struct();
params_geo.source = source;
params_geo.target = target;
params_geo.metric = "geometry";  % Euclidean distance
    [path, ~] = fs6.Manifold.Graph.shortestPath(source, target, "geometry");

w_geo = bct.brush.apply('trajectory_geodesic', fs6.Manifold, params_geo);
w = full(w_geo);          % dense kernel
w = w / max(w);       % normalize to [0,1]
sel = w > 0;    % logical index

rgb = repmat(bgColor, nV, 1);
rgb(sel,:) = repmat(selColor, nnz(sel), 1);
BrushSurf.Color = rgb;


%% 

% Path with 10mm corridor
SourcePoint = images.ui.graphics.roi.Point(Position=fs6.Manifold.Vertices(params.source ,:));
TargetPoint = images.ui.graphics.roi.Point(Position=fs6.Manifold.Vertices(params.target ,:));
SourcePoint.Label = "Source";
TargetPoint.Label = "Target";
viewer.Annotations=[SourcePoint TargetPoint];
%%
params.source = 24567 ;
params.target=145  ;

params.metric = "geometry";
params.width = 10;  % 10mm corridor
w_corridor = bct.brush.apply('trajectory_geodesic', fs6.Manifold, params);
w = full(w_corridor);          % dense kernel
w = w / max(w);       % normalize to [0,1]
sel = w > 0;    % logical index

rgb = repmat(bgColor, nV, 1);
rgb(sel,:) = repmat(selColor, nnz(sel), 1);
BrushSurf.Color = rgb;
SourcePoint.Position=fs6.Manifold.Vertices(params.source,:);
TargetPoint.Position=fs6.Manifold.Vertices(params.target,:);


viewer.Annotations(2).Position=fs6.Manifold.Vertices(params.target,:);

%% 

% Gaussian patch with 20mm width
params.source = 1000;
params.sigma = 4;  % Gaussian width (standard deviation)
params.metric = "geometry";  % optional

w = bct.brush.apply('patch_gaussian', fs6.Manifold, params);
w = full(w);          % dense kernel
cmap = turbo(256);          % or parula, viridis, hot, etc.
idx  = max(1, round(w*255));

rgb = repmat(bgColor, nV, 1);
mask = w > 0;
rgb(mask,:) = cmap(idx(mask),:);

BrushSurf.Color = rgb;

SourcePoint.Position=fs6.Manifold.Vertices(params.source,:);
viewer.Annotations(2).Visible="off";
%% 
% Gaussian weighting along geodesic path
params.source = 1000;
params.target = 1;
params.sigma = 4;  % Gaussian width (standard deviation)
params.metric = "geometry";  % optional

w = bct.brush.apply('trajectory_gaussian', fs6.Manifold, params);
cmap = turbo(256);          % or parula, viridis, hot, etc.
idx  = max(1, round(w*255));

rgb = repmat(bgColor, nV, 1);
mask = w > 0;
rgb(mask,:) = cmap(idx(mask),:);

BrushSurf.Color = rgb;
SourcePoint.Position=fs6.Manifold.Vertices(params.source,:);
viewer.Annotations(2).Visible="on";
viewer.Annotations(2).Position=fs6.Manifold.Vertices(params.target,:);

G = fs6.Manifold.Graph.matlabGraph(params.metric);
    d = distances(G, source);  % [N×1] distances from source to all vertices
[sOut,tOut] = findedge(G,1);
embedEdge = [G.Nodes{sOut, :}; G.Nodes{tOut, :}];


[x,y] = meshgrid(1:15,1:15);

dataDir = fullfile(toolboxdir("images"),"imdata","BrainMRILabeled");
load(fullfile(dataDir,"images","vol_001.mat"))
load(fullfile(dataDir,"labels","label_001.mat"))


vol = zeros(255,255,255,'single');
volViewer=viewer3d;
Volume = volshow(vol,Parent=volViewer, ...
    RenderingStyle="MaximumIntensityProjection", ...
    OverlayData=label, ...
    OverlayAlpha=0.5, ....
    OverlayColormap=turbo, ...
    OverlayDisplayRangeMode="data-range");
s = images.ui.graphics.Surface(volViewer, ManifoldTriangulation)

dx = 1; dy = 1; dz = 1;  % voxel size in mm

R = imref3d(size(vol), dx, dy, dz);
%% Gradient and divergece

% w must be a column vector
w=w(:);
V = Manifold.Vertices;
F = Manifold.Faces;
w = w(:);

% Triangle vertices
v1 = V(F(:,1),:);
v2 = V(F(:,2),:);
v3 = V(F(:,3),:);

% Triangle edges
e12 = v2 - v1;
e13 = v3 - v1;

% Triangle normals and areas
n = cross(e12, e13, 2);
dblA = vecnorm(n,2,2);      % 2 * area
n_unit = n ./ dblA;

% Gradients of barycentric basis functions
grad_phi1 = cross(n_unit, v3 - v2, 2) ./ dblA;
grad_phi2 = cross(n_unit, v1 - v3, 2) ./ dblA;
grad_phi3 = cross(n_unit, v2 - v1, 2) ./ dblA;

% FEM gradient per face
grad_w = ...
    grad_phi1 .* w(F(:,1)) + ...
    grad_phi2 .* w(F(:,2)) + ...
    grad_phi3 .* w(F(:,3));

%% divergence
L = Manifold.CotangentMatrix;   % stiffness matrix
M = Manifold.MassMatrix;
lap_w = M \ (L * w);   % divergence of gradient
%% flux through each edge segment
V = Manifold.Vertices;   % N × 3
F = Manifold.Faces;      % F × 3
nV = size(V,1);
nF = size(F,1);

v1 = V(F(:,1),:);
v2 = V(F(:,2),:);
v3 = V(F(:,3),:);

e12 = v2 - v1;
e13 = v3 - v1;

faceNormal = cross(e12, e13, 2);
dblA = vecnorm(faceNormal,2,2);
faceArea = 0.5 * dblA;

faceNormal = faceNormal ./ dblA;   % unit normal
e1 = v3 - v2;   % opposite vertex 1
e2 = v1 - v3;   % opposite vertex 2
e3 = v2 - v1;   % opposite vertex 3

n1 = cross(faceNormal, e1, 2);
n2 = cross(faceNormal, e2, 2);
n3 = cross(faceNormal, e3, 2);
flux1 = dot(grad_w, n1, 2) .* 0.5;
flux2 = dot(grad_w, n2, 2) .* 0.5;
flux3 = dot(grad_w, n3, 2) .* 0.5;

div = zeros(nV,1);
for k = 1:nF
    div(F(k,1)) = div(F(k,1)) + flux1(k);
    div(F(k,2)) = div(F(k,2)) + flux2(k);
    div(F(k,3)) = div(F(k,3)) + flux3(k);
end
Adual = full(sum(Manifold.MassMatrix,2));
div = div ./ Adual;
lap_w = Manifold.MassMatrix \ (Manifold.CotangentMatrix * w);

err = norm(div - lap_w) / norm(lap_w)


%%

fs6 = bct_fsaverage('lh', 'saved');

% Gaussian patch with 20mm width
params.source = 1000;
params.sigma = 4;  % Gaussian width (standard deviation)
params.metric = "geometry";  % optional

w = bct.brush.apply('patch_gaussian', fs6.Manifold, params);
w=full(w);
% Convert to Signal object
sig = bct.Signal(w', fs6.Manifold);
% Compute gradient (returns face-based vectors)
[gradW, gradW_unit, amplitude, phase] = sig.gradient();
% gradW       - [M×3] gradient vectors on faces
% gradW_unit  - [M×3] normalized gradient vectors
% amplitude   - [M×1] gradient magnitude in tangent frame
% phase       - [M×1] gradient direction in tangent frame (radians)

% Compute divergence of the gradient flow (using negative gradient)
divU = sig.divergence(gradW_unit, 'Negate', true);
% divU - [N×1] divergence on vertices

% Compute curl of the gradient (should be near zero for gradient fields)
curlU = sig.curl(gradW_unit);
% curlU - [N×1] curl on vertices

%%
% Visualize the signal
figure;
patch('Faces', fs6.Manifold.Faces, 'Vertices', fs6.Manifold.Vertices, ...
      'FaceVertexCData', sig.Data, 'FaceColor', 'interp', 'EdgeColor', 'none');
colorbar; title('Gaussian Brush Signal');
axis equal; camlight; lighting gouraud;

% Visualize gradient magnitude
gradMag = bct.operator.transform.faceVec2vertMag(fs6.Manifold, gradW);
figure;
patch('Faces', fs6.Manifold.Faces, 'Vertices', fs6.Manifold.Vertices, ...
      'FaceVertexCData', gradMag, 'FaceColor', 'interp', 'EdgeColor', 'none');
colorbar; title('Gradient Magnitude');
axis equal; camlight; lighting gouraud;
% Compute and visualize Helmholtz-Hodge decomposition
[rotU_mag, divU_mag, harmU_mag] = sig.hhdecomposition();
figure;
subplot(1,3,1);
patch('Faces', fs6.Manifold.Faces, 'Vertices', fs6.Manifold.Vertices, ...
      'FaceVertexCData', rotU_mag, 'FaceColor', 'interp', 'EdgeColor', 'none');
colorbar; title('Curl-Free Component'); axis equal;

subplot(1,3,2);
patch('Faces', fs6.Manifold.Faces, 'Vertices', fs6.Manifold.Vertices, ...
      'FaceVertexCData', divU_mag, 'FaceColor', 'interp', 'EdgeColor', 'none');
colorbar; title('Divergence-Free Component'); axis equal;

subplot(1,3,3);
patch('Faces', fs6.Manifold.Faces, 'Vertices', fs6.Manifold.Vertices, ...
      'FaceVertexCData', harmU_mag, 'FaceColor', 'interp', 'EdgeColor', 'none');
colorbar; title('Harmonic Component'); axis equal;

%%
% Heat kernel brush (smooth diffusion)
params.source = 1000;
params.kernel = 'heat';
params.sigma = 10;
w = bct.brush.patch.spectral(fs6.Manifold, params);

% Gaussian brush with bandwidth limit
params.kernel = 'gaussian';
params.sigma = 15;
params.bandwidth = 50;  % Use only first 50 modes
w = bct.brush.patch.spectral(fs6.Manifold, params);

% Low-pass filter brush
params.kernel = 'lowpass';
params.cutoff = 20;
w = bct.brush.patch.spectral(fs6.Manifold, params);

%%
% Create model with manifold
model = bctui.model.ManifoldBrushModel(fs6.Manifold);

% Create UI
fig = uifigure;
root = uigridlayout(fig);
root.RowHeight = {'1x'};
root.ColumnWidth = {'1x'};
ui = bctui.component.ManifoldBrushUI('Parent', root);
ui.Model = model;
ui.Seed = 1000;
ui.initialize();

% Evaluate brush
w = model.evaluate();