%% Test Single Edge Mapping
clear; close all;

% Add paths
addpath(fullfile(pwd, '..', '..', 'external', 'bioelectromagnetism'));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'DECLab')));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'gptoolbox')));
addpath(fullfile(pwd, '..', '..', 'toolbox'));

%% Load Reference
jsonFile = 'C:\CodingProjects\potpourri3d-scripts\direction_field_data.json';
refData = jsondecode(fileread(jsonFile));

%% Load Mesh
fs5path = 'C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
[vertices, faces] = freesurfer_read_surf(fs5path);
faces = fliplr(faces);
M = bct.Manifold(vertices, faces);

%% Compute Connection
singularities = zeros(size(M.Vertices, 1), 1);
for i = 1:length(refData.singularities)
    vIdx = refData.singularities(i).index + 1;
    weight = refData.singularities(i).weight;
    singularities(vIdx) = weight;
end

singIdx = find(singularities ~= 0);
conn = M.connection('trivial', 'singularities', singIdx);
phi_he = conn.trivialConnection.value;

%% Get topology
topo = M.topology();
tailVertex = topo.tailVertex.value;
headVertex = topo.headVertex.value;
edgeField = topo.edge.value;
edges = topo.edgeList.value;

%% Test JavaScript edge 171
jsIdx = 171;
jsEdgeData = refData.edgeIndex(jsIdx);
jsV1 = jsEdgeData.v1 + 1;  % 2731
jsV2 = jsEdgeData.v2 + 1;  % 29
jsPhi = refData.phi(jsIdx);  % -2.402786

fprintf('JavaScript Edge %d:\n', jsIdx);
fprintf('  (v1, v2) = (%d, %d)\n', jsV1, jsV2);
fprintf('  φ = %.6f\n', jsPhi);

%% Find matching MATLAB edge
mlEdgeIdx = find((edges(:,1) == jsV1 & edges(:,2) == jsV2) | ...
                 (edges(:,1) == jsV2 & edges(:,2) == jsV1), 1);

fprintf('\nMATLAB Edgeint %d:\n', mlEdgeIdx);
fprintf('  Vertices: (%d, %d)\n', edges(mlEdgeIdx,1), edges(mlEdgeIdx,2));

%% Find halfedges for this edge
he_for_edge = find(edgeField == mlEdgeIdx);

fprintf('\nHalfedges for MATLAB edge %d:\n', mlEdgeIdx);
for he = he_for_edge'
    fprintf('  HE %d: (%d→%d), φ=%.6f\n', he, tailVertex(he), headVertex(he), phi_he(he));
end

%% Find the halfedge matching JavaScript orientation (2731→29)
he_matching = find(tailVertex == jsV1 & headVertex == jsV2);

if isempty(he_matching)
    fprintf('\n⚠ No halfedge found matching JS orientation (%d→%d)!\n', jsV1, jsV2);
else
    fprintf('\n✓ Halfedge matching JS orientation (%d→%d):\n', jsV1, jsV2);
    for he = he_matching'
        fprintf('  HE %d: φ=%.6f\n', he, phi_he(he));
    end
    
    % Compare
    ml_phi_correct = phi_he(he_matching(1));
    fprintf('\nComparison:\n');
    fprintf('  JS φ:  %.6f\n', jsPhi);
    fprintf('  ML φ:  %.6f\n', ml_phi_correct);
    fprintf('  Diff:  %.6f\n', abs(jsPhi - ml_phi_correct));
end
