mesh = surfaceMesh (M.Vertices, M.Faces);
removeDefects(mesh,"duplicate-vertices")
removeDefects(mesh,"duplicate-faces")
removeDefects(mesh,"unreferenced-vertices")
removeDefects(mesh,"degenerate-faces")
removeDefects(mesh,"nonmanifold-edges")
mesh.computeNormals


%%
V = M.Vertices;
F = M.Faces;

[V2, F2, log] = bct.manifold.health.repair.clearForDec(V, F, ...
    'ExpectWatertight', true, ...
    'AllowBoundaryEdges', false, ...
    'FixNonmanifoldEdges', true);

M2 = bct.Manifold(V2, F2);  % rebuild canonical edges etc.
%%
V=M.Vertices; F=M.Faces;
a = V(F(:,1), :);
b = V(F(:,2), :);
c = V(F(:,3), :);

signedVol = sum(dot(a, cross(b, c, 2), 2)) / 6;

Fout = F;
flipped = false;

if signedVol < 0
    Fout(:, [2 3]) = Fout(:, [3 2]);
    flipped = true;
    signedVolAfter = -signedVol;
else
    signedVolAfter = signedVol;
end

info = struct( ...
    'signedVolumeBefore', signedVol, ...
    'signedVolumeAfter',  signedVolAfter, ...
    'flippedAllFaces',    flipped ...
);

mesh = surfaceMesh(V, Fout);
writeSurfaceMesh(mesh, 'C:\CodingProjects\bioctree\data\mesh\fsaverageflippedout.obj')\


meshFile = fullfile('data', 'mesh', 'fsaverage_lh_pial.mat');

if ~isfile(meshFile)
    error('Mesh file not found: %s\nPlease ensure the data folder is in your MATLAB path.', meshFile);
end

data = load(meshFile);
V = data.V;  % Vertices [N×3]
F = data.F;  % Faces [M×3]
Mleft=bct.Manifold(V,F);
Mleft=Mleft.flip;
bct.manifold.write(Mleft, 'C:\CodingProjects\Bioctreeapp\src\app\components\viewer\assets\fsaverage_lh.glb')
bct.manifold.write(Mleft, 'C:\CodingProjects\Bioctreeapp\src\app\components\viewer\assets\fsaverage_lh.obj')