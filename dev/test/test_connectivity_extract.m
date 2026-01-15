% Test connectivity check with component extraction
addpath(genpath('toolbox'));
addpath('external');

fprintf('CONNECTIVITY CHECK WITH COMPONENT EXTRACTION\n');
fprintf('=============================================\n\n');

% Create disconnected mesh: 3 separate spheres
[V1, F1] = icosphere(1);  % 42 vertices
[V2, F2] = icosphere(1);
[V3, F3] = icosphere(1);

% Offset spheres
V2 = V2 + [5 0 0];
V3 = V3 + [0 5 0];

% Combine
nV1 = size(V1, 1);
nV2 = size(V2, 1);
V_all = [V1; V2; V3];
F_all = [F1; F2 + nV1; F3 + nV1 + nV2];

% Create manifold
M = bct.Manifold(V_all, F_all);

fprintf('Total vertices: %d\n', M.numVertices);
fprintf('Total faces: %d\n\n', M.numFaces);

% Run health check with verbose mode to get components
h = M.health('Verbose', true);

fprintf('Health status: %s\n', h.severity);
fprintf('Is connected: %d\n', h.is.connected);
fprintf('Number of components: %d\n', h.statsByCheck.connectivity.numComponents);
fprintf('Component sizes: [%s]\n\n', ...
    num2str(h.statsByCheck.connectivity.componentSizes));

% Access component vertex indices from data
if isfield(h.data, 'connectivity') && isfield(h.data.connectivity, 'components')
    components = h.data.connectivity.components;
    fprintf('Component details:\n');
    for i = 1:length(components)
        fprintf('  Component %d: %d vertices (indices %d to %d)\n', ...
            i, length(components{i}), ...
            min(components{i}), max(components{i}));
    end
end

% Example: Extract largest component as separate manifold
if ~h.is.connected && isfield(h.data, 'connectivity')
    [~, largestIdx] = max(h.statsByCheck.connectivity.componentSizes);
    largestComponent = h.data.connectivity.components{largestIdx};
    
    fprintf('\nExtracting largest component (component %d)...\n', largestIdx);
    
    % Build vertex mapping
    vertexMap = zeros(M.numVertices, 1);
    vertexMap(largestComponent) = 1:length(largestComponent);
    
    % Extract vertices
    V_comp = M.Vertices(largestComponent, :);
    
    % Extract and remap faces
    faceInComponent = all(ismember(F_all, largestComponent), 2);
    F_comp = F_all(faceInComponent, :);
    F_comp = vertexMap(F_comp);  % Remap to new vertex indices
    
    % Create new manifold for this component
    M_comp = bct.Manifold(V_comp, F_comp);
    h_comp = M_comp.health();
    
    fprintf('Extracted manifold: %d vertices, %d faces\n', ...
        M_comp.numVertices, M_comp.numFaces);
    fprintf('Is connected: %d\n', h_comp.is.connected);
    fprintf('Components: %d\n', h_comp.statsByCheck.connectivity.numComponents);
end
