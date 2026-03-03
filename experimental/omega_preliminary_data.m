[rH, lH, isConnected, iStruct, iRightScout, iLeftScout] = tess_hemisplit(cortex15k);
[rH, lH] = deal(rH(:), lH(:));  % ensure column

V=cortex15k.Vertices;
F=cortex15k.Faces;
VertConn=cortex15k.VertConn;
vNormals = cortex15k.VertNormals;
%%
hemiVerts = rH;
% hemiVerts: vector of vertex indices from original mesh (e.g., rH or lH)
    hemiMask = false(size(V,1),1);
    hemiMask(hemiVerts) = true;
    % Keep only faces fully inside this hemisphere
    keepFace = hemiMask(F(:,1)) & hemiMask(F(:,2)) & hemiMask(F(:,3));
    keepFaceIdx = find(keepFace);
    Fkeep = F(keepFace,:);
    % Vertices actually used by those faces
    usedVerts = unique(Fkeep(:));
    new2old = usedVerts(:);
    old2new = zeros(size(V,1),1);
    old2new(usedVerts) = 1:numel(usedVerts);
    Vr = V(usedVerts,:);
    Fr = old2new(Fkeep);
%%
hemiVerts = lH;
% hemiVerts: vector of vertex indices from original mesh (e.g., rH or lH)
    hemiMask = false(size(V,1),1);
    hemiMask(hemiVerts) = true;
    % Keep only faces fully inside this hemisphere
    keepFace = hemiMask(F(:,1)) & hemiMask(F(:,2)) & hemiMask(F(:,3));
    keepFaceIdx = find(keepFace);
    Fkeep = F(keepFace,:);
    % Vertices actually used by those faces
    usedVerts = unique(Fkeep(:));
    new2old = usedVerts(:);
    old2new = zeros(size(V,1),1);
    old2new(usedVerts) = 1:numel(usedVerts);
    Vl = V(usedVerts,:);
    Fl = old2new(Fkeep);

%%
lMesh = surfaceMesh(Vl, Fl);
rMesh = surfaceMesh(Vr, Fr);
%% 
lMesh = surfaceMesh(Vl, Fl)
    allowBoundaryEdges = false;
    isEdgeManifold (lMesh, allowBoundaryEdges)	%Check if surface mesh is edge-manifold
    isVertexManifold(lMesh)	%Check if surface mesh is vertex-manifold
    isWatertight(lMesh)	%Check if surface mesh is watertight
    removeDefects(lMesh,"duplicate-faces");
    removeDefects(lMesh,"duplicate-vertices")
    removeDefects(lMesh,"unreferenced-vertices")
lMesh

triL = triangulation(double(lMesh.Faces),lMesh.Vertices)
[freeF, freeV] = freeBoundary(triL)   % often returns Px2 edges or Px3 triangles depending on class/version

removeDefects(lMesh,"nonmanifold-edges")
removeDefects(lMesh,"unreferenced-vertices")
lMesh
    % removeDefects(lMesh,"degenerate-faces")
    % removeDefects(lMesh,"nonmanifold-edges")
    % removeDefects(lMesh,"degenerate-faces")
allowBoundaryEdges = false;
isEdgeManifold (lMesh, allowBoundaryEdges)	%Check if surface mesh is edge-manifold
isVertexManifold(lMesh)	%Check if surface mesh is vertex-manifold
isWatertight(lMesh)	%Check if surface mesh is watertight

rMesh = surfaceMesh(Vr, Fr)
    allowBoundaryEdges = false;
    isEdgeManifold (rMesh, allowBoundaryEdges)	%Check if surface mesh is edge-manifold
    isVertexManifold(rMesh)	%Check if surface mesh is vertex-manifold
    isWatertight(rMesh)	%Check if surface mesh is watertight
    removeDefects(rMesh,"duplicate-faces");
    removeDefects(rMesh,"duplicate-vertices")
    removeDefects(rMesh,"unreferenced-vertices")
rMesh
triR = triangulation(double(rMesh.Faces),rMesh.Vertices)
[freeFr, freeVr] = freeBoundary(triR)   % often returns Px2 edges or Px3 triangles depending on class/version
removeDefects(rMesh,"nonmanifold-edges")
removeDefects(rMesh,"unreferenced-vertices")
rMesh
    % removeDefects(lMesh,"degenerate-faces")
    % removeDefects(lMesh,"nonmanifold-edges")
    % removeDefects(lMesh,"degenerate-faces")
allowBoundaryEdges = false;
isEdgeManifold (rMesh, allowBoundaryEdges)	%Check if surface mesh is edge-manifold
isVertexManifold(rMesh)	%Check if surface mesh is vertex-manifold
isWatertight(rMesh)	%Check if surface mesh is watertight

%%
  rep2old = knnsearch(Vl, lMesh.Vertices);
  d = vecnorm(Vl(rep2old,:) - lMesh.Vertices, 2, 2);
  keptOriginal = unique(rep2old);
  removedVertIdxL = setdiff((1:size(Vl,1))', keptOriginal);
  size(removedVertIdxL);

  rep2old = knnsearch(Vr, rMesh.Vertices);
  d = vecnorm(Vr(rep2old,:) - rMesh.Vertices, 2, 2);
  keptOriginal = unique(rep2old);
  removedVertIdxR = setdiff((1:size(Vr,1))', keptOriginal);
  size(removedVertIdxR);
%% 
 ikmaskL = true(length(V));
 ikmaskL(rH) = false;
 ikmaskL(removedVertIdxL)=false;

 ikmaskR = true(length(V));
 ikmaskR(lH) = false;
 ikmaskR(removedVertIdxR)=false;
%%

IKL=dSPM.ImagingKernel; 
%%
surfaceMeshShow(lMesh);
tr = meshTopologyReport(Fr);
tl = meshTopologyReport(Fl);

disp(tr.isClosed);  % true means already closed
disp(tl.isClosed);

%%
triL = triangulation(double(lMesh.Faces),lMesh.Vertices)
[freeF, freeV] = freeBoundary(triL);   % often returns Px2 edges or Px3 triangles depending on class/version


%%

F = double(lMesh.Faces);

E = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];
E = sort(E,2);
[Eu,~,ic] = unique(E,'rows');
counts = accumarray(ic,1);

nBoundary = nnz(counts==1);
nNonManifold = nnz(counts>2);

fprintf('boundaryEdges=%d, nonmanifoldEdges=%d\n', nBoundary, nNonManifold);

%%

V = lMesh.Vertices;
nV = size(V,1);

% adjacency from faces
I = [F(:,1); F(:,2); F(:,3)];
J = [F(:,2); F(:,3); F(:,1)];
A = sparse([I;J],[J;I],1,nV,nV);
A = spones(A);

G = graph(A);
bins = conncomp(G);
nComp = max(bins);

fprintf('connected components = %d\n', nComp);

%%
Eunique = size(Eu,1);
chi = size(V,1) - Eunique + size(F,1);
fprintf('Euler characteristic chi=%g\n', chi);

%%
V = Vl;
F = Fl;

opts = struct();
opts.nearTol = [];     % set to e.g. 1e-6 to merge "nearly duplicate" vertices
opts.maxPasses = 3;
opts.fixNonManifold = true;
opts.verbose = true;

[Vfix, Ffix, defects, map] = repair_mesh_defects(V, F, opts);

% Re-run your topology checks on the repaired mesh:
fprintf('\nFinal checks:\n');
F = Ffix; V = Vfix;
E = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];
E = sort(E,2); [Eu,~,ic] = unique(E,'rows'); counts = accumarray(ic,1);
fprintf('boundaryEdges=%d, nonmanifoldEdges=%d\n', nnz(counts==1), nnz(counts>2));