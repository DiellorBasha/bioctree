%% Compare MATLAB Direction Field with JavaScript Reference
% This script loads the exported JSON from geometry-processing-js and
% compares it with the MATLAB implementation to identify discrepancies.

clear; close all;

% Add necessary paths (from workspace root)
addpath(fullfile(pwd, '..', '..', 'external', 'bioelectromagnetism'));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'DECLab')));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'gptoolbox')));

%% Load Reference Data
jsonFile = 'C:\CodingProjects\potpourri3d-scripts\direction_field_data.json';
if ~exist(jsonFile, 'file')
    error('Reference JSON file not found: %s', jsonFile);
end

refData = jsondecode(fileread(jsonFile));
fprintf('Loaded reference data from JavaScript implementation\n');
fprintf('  Singularities: %d\n', length(refData.singularities));
fprintf('  Edges: %d\n', length(refData.phi));
fprintf('  Faces: %d\n', length(refData.faceData));

%% Display Reference Singularities
fprintf('\nReference Singularities:\n');
for i = 1:length(refData.singularities)
    fprintf('  Vertex %d: weight = %.2f\n', ...
        refData.singularities(i).index, refData.singularities(i).weight);
end

%% Load Same Mesh in MATLAB  
% Use fsaverage5 lh.pial (same as JavaScript reference)
fprintf('\nLoading fsaverage5 lh.pial mesh...\n');
fs5path = 'C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
if ~exist(fs5path, 'file')
    error('Mesh file not found: %s', fs5path);
end

[vertices, faces] = freesurfer_read_surf(fs5path);
M = bct.Manifold(vertices, faces);
Mf = M.flip; 
clear M; 
M = Mf;

fprintf('Loaded fsaverage5 lh pial: %d vertices, %d faces, %d edges\n', ...
    size(M.Vertices, 1), size(M.Faces, 1), size(M.Edges, 1));

%% Check if mesh sizes match
fprintf('\nMesh size comparison:\n');
fprintf('  Reference vertices: (inferred from max edge vertex index)\n');
fprintf('  Reference edges: %d\n', length(refData.phi));
fprintf('  Reference faces: %d\n', length(refData.faceData));
fprintf('  MATLAB vertices: %d\n', size(M.Vertices, 1));
fprintf('  MATLAB edges: %d\n', size(M.Edges, 1));
fprintf('  MATLAB faces: %d\n', size(M.Faces, 1));

if length(refData.phi) ~= size(M.Edges, 1)
    warning('Edge count mismatch! Reference: %d, MATLAB: %d', ...
        length(refData.phi), size(M.Edges, 1));
    fprintf('\n⚠️  Different meshes detected!\n');
    fprintf('The reference used a different mesh than fsaverage_rh_pial.\n');
    fprintf('Re-run the JavaScript demo with the correct mesh to compare.\n');
    return;
end

%% Create Matching Singularities in MATLAB
singularities = zeros(size(M.Vertices, 1), 1);
for i = 1:length(refData.singularities)
    vIdx = refData.singularities(i).index + 1;  % JavaScript is 0-based, MATLAB is 1-based
    weight = refData.singularities(i).weight;
    singularities(vIdx) = weight;
end

fprintf('\nMATLAB Singularities (converted from 0-based to 1-based):\n');
singIdx = find(singularities ~= 0);
for i = 1:length(singIdx)
    fprintf('  Vertex %d: weight = %.2f\n', singIdx(i), singularities(singIdx(i)));
end

%% Compute MATLAB Direction Field
fprintf('\nComputing MATLAB direction field...\n');
conn = M.connection('trivial', 'singularities', singIdx);
connectionHE = conn.trivialConnection.value;

% Convert halfedge connection to edge connection (for comparison)
% JavaScript stores one value per edge
connectionEdge = zeros(size(M.Edges, 1), 1);
for e = 1:size(M.Edges, 1)
    he1 = 2*e - 1;  % First halfedge of edge
    connectionEdge(e) = connectionHE(he1);
end

%% Compare φ (Connection Values)
fprintf('\n=== COMPARING φ (CONNECTION VALUES) ===\n');
refPhi = [refData.phi]';  % Reference phi values

% Need to match edge ordering between MATLAB and JavaScript
% JavaScript edge index maps to vertex pairs, need to correlate
fprintf('Edge comparison (first 10 edges):\n');
for e = 1:min(10, length(refData.edgeIndex))
    refEdge = refData.edgeIndex(e);
    jsV1 = refEdge.v1 + 1;  % Convert to 1-based
    jsV2 = refEdge.v2 + 1;
    jsPhi = refData.phi(e+1);  % JavaScript arrays are 0-indexed in struct
    
    % Find matching MATLAB edge
    matlabEdgeIdx = find((M.Edges(:,1) == jsV1 & M.Edges(:,2) == jsV2) | ...
                         (M.Edges(:,1) == jsV2 & M.Edges(:,2) == jsV1));
    
    if ~isempty(matlabEdgeIdx)
        matlabPhi = connectionEdge(matlabEdgeIdx(1));
        diff = abs(matlabPhi - jsPhi);
        fprintf('  Edge %d (%d-%d): JS=%.6f, MATLAB=%.6f, diff=%.6f\n', ...
            e, jsV1, jsV2, jsPhi, matlabPhi, diff);
    else
        fprintf('  Edge %d (%d-%d): NOT FOUND in MATLAB\n', e, jsV1, jsV2);
    end
end

%% Compute MATLAB Direction Field Angles
fprintf('\n=== COMPUTING MATLAB DIRECTION FIELD ===\n');

% Get face-to-face connections via halfedges
ops = M.operators();
geom = M.geometry();
topo = M.topology();

% BFS to propagate angles (matching JavaScript algorithm)
nF = size(M.Faces, 1);
alpha = nan(nF, 1);
visited = false(nF, 1);
parent = zeros(nF, 1);

% Start from face 1 (same as JavaScript root = mesh.faces[0])
seedFace = 1;
alpha(seedFace) = 0;
visited(seedFace) = true;
parent(seedFace) = seedFace;

queue = seedFace;
queuePos = 1;

while queuePos <= length(queue)
    fI = queue(queuePos);
    queuePos = queuePos + 1;
    
    % Get halfedges of this face
    hes = [3*fI-2, 3*fI-1, 3*fI];
    
    for he = hes
        twinHE = topo.twin.value(he);
        if twinHE == 0
            continue;  % Boundary halfedge
        end
        fJ = topo.face.value(twinHE);
        
        if fJ > 0 && ~visited(fJ)  % Valid adjacent face not yet visited
            % Get geometric transport for this halfedge
            % This is the pre-computed dTheta = -theta_i + theta_j
            geometricTransport = geom.face.transport.value(he);
            
            % Connection transport (with sign)
            connectionValue = connectionHE(he);
            
            % Combined transport
            combinedTransport = geometricTransport - connectionValue;
            
            % Propagate angle
            alpha(fJ) = alpha(fI) + combinedTransport;
            
            visited(fJ) = true;
            parent(fJ) = fI;
            queue(end+1) = fJ;
        end
    end
end

fprintf('Computed BFS angles for %d faces\n', sum(visited));

%% Compare α (Face Angles)
fprintf('\n=== COMPARING α (FACE ANGLES) ===\n');

% Extract reference alpha values
refAlpha = nan(length(refData.faceData), 1);
for i = 1:length(refData.faceData)
    fIdx = refData.faceData(i).faceIndex + 1;  % Convert to 1-based
    refAlpha(fIdx) = refData.faceData(i).alpha;
end

% Compare wrapped angles (modulo 2π)
angleDiff = zeros(nF, 1);
for f = 1:nF
    if ~isnan(refAlpha(f)) && ~isnan(alpha(f))
        % Wrap difference to [-π, π]
        diff = mod(alpha(f) - refAlpha(f) + pi, 2*pi) - pi;
        angleDiff(f) = diff;
    end
end

fprintf('Angle comparison statistics:\n');
fprintf('  Mean abs difference: %.6f rad (%.2f deg)\n', ...
    mean(abs(angleDiff)), rad2deg(mean(abs(angleDiff))));
fprintf('  Max abs difference: %.6f rad (%.2f deg)\n', ...
    max(abs(angleDiff)), rad2deg(max(abs(angleDiff))));
fprintf('  RMS difference: %.6f rad (%.2f deg)\n', ...
    rms(angleDiff), rad2deg(rms(angleDiff)));

fprintf('\nFirst 10 face angles:\n');
for f = 1:min(10, nF)
    if ~isnan(refAlpha(f))
        fprintf('  Face %d: JS=%.6f, MATLAB=%.6f, diff=%.6f rad\n', ...
            f, refAlpha(f), alpha(f), angleDiff(f));
    end
end

%% Find Large Discrepancies
threshold = 0.1;  % 0.1 rad ≈ 5.7 degrees
largeDiff = find(abs(angleDiff) > threshold);
if ~isempty(largeDiff)
    fprintf('\n⚠️  %d faces with angle difference > %.2f deg:\n', ...
        length(largeDiff), rad2deg(threshold));
    for i = 1:min(10, length(largeDiff))
        f = largeDiff(i);
        fprintf('  Face %d: JS=%.6f, MATLAB=%.6f, diff=%.6f rad (%.2f deg)\n', ...
            f, refAlpha(f), alpha(f), angleDiff(f), rad2deg(angleDiff(f)));
    end
end

%% Summary
fprintf('\n====== SUMMARY ======\n');
if max(abs(angleDiff)) < 1e-6
    fprintf('✅ Perfect match! Implementations are identical.\n');
elseif max(abs(angleDiff)) < 0.01
    fprintf('✅ Excellent match! Differences likely due to numerical precision.\n');
elseif max(abs(angleDiff)) < 0.1
    fprintf('⚠️  Small differences detected. May be due to:\n');
    fprintf('   - Different BFS seed face\n');
    fprintf('   - Different edge/halfedge ordering\n');
    fprintf('   - Numerical precision\n');
else
    fprintf('❌ Significant differences detected! Possible causes:\n');
    fprintf('   - Different connection formula\n');
    fprintf('   - Different geometric transport\n');
    fprintf('   - Bug in one implementation\n');
end
