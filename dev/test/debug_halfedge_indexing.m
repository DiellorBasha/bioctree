%% Debug Halfedge Indexing
clear; close all;

% Add paths
addpath(fullfile(pwd, '..', '..', 'external', 'bioelectromagnetism'));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'gptoolbox')));
addpath(fullfile(pwd, '..', '..', 'toolbox'));

%% Load Mesh
fs5path = 'C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
[vertices, faces] = freesurfer_read_surf(fs5path);
faces = fliplr(faces);
M = bct.Manifold(vertices, faces);

%% Get topology
topo = M.topology();
edges = topo.edgeList.value;

%% Test edge 157
e = 157;
v1 = edges(e,1);
v2 = edges(e,2);

fprintf('Edge %d:\n', e);
fprintf('  Vertices: (%d, %d)\n', v1, v2);

%% Calculate halfedge indices (2*e-1 convention)
he1_calc = 2*e - 1;
he2_calc = 2*e;

fprintf('\nCalculated halfedge indices (2*e-1):\n');
fprintf('  he1 = %d\n', he1_calc);
fprintf('  he2 = %d\n', he2_calc);

%% Get halfedges from topology
tailVertex = topo.tailVertex.value;
headVertex = topo.headVertex.value;

% Find all halfedges connecting these vertices
he_fwd = find(tailVertex == v1 & headVertex == v2);
he_rev = find(tailVertex == v2 & headVertex == v1);

fprintf('\nHalfedges from topology:\n');
for h = he_fwd'
    fprintf('  HE %d: (%d→%d)\n', h, tailVertex(h), headVertex(h));
end
for h = he_rev'
    fprintf('  HE %d: (%d→%d)\n', h, tailVertex(h), headVertex(h));
end

%% Check edge field
edgeField = topo.edge.value;
he_with_this_edge = find(edgeField == e);

fprintf('\nHalfedges with edge=%d:\n', e);
for h = he_with_this_edge'
    fprintf('  HE %d: (%d→%d)\n', h, tailVertex(h), headVertex(h));
end
