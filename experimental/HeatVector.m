
fs5path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial'
[vertices, faces] = freesurfer_read_surf(fs4path);
M=bct.Manifold(vertices,faces);
%Mf=M.flip;clear M; M=Mf;
    topo = M.topology;
    geom = M.geometry('includeDual', true);
    ops=M.operators;
    solvers = M.solvers;
    
    %eigen = M.eigenmodes(1000);
%%
% Generate smooth tangent vector field
% Option 1: Increase the time multiplier (default is 16)
% Place seed patch at anterior pole
anterior_vertex = 6653;
posterior_vertex = 978;

patch = struct('center', anterior_vertex, 'radius', 85);
% No 'direction' field - defaults to radial outward from seed vertex
result = bct.field.generate.vectorHeat(M, ...
    'SeedPatch', patch, ...
    'TimeMultiplier', 100);
%%
viewer = bct.ui.show(M);

%%

viewer.setVector(result.vectors, ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Style', 'arrow', ...
    'Stride', 1);  % Every 5th vector
%%
% Scale normalized vectors by magnitude
scaledVectors = result.vectors .* result.magnitude *500;
viewer.setVector(scaledVectors, ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Style', 'arrow', ...
    'Stride', 1);  % Every 5th vector
%%
viewer.setScalar(result.vertexMagnitude)