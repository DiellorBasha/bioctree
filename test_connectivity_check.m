% Test connectivity health check
addpath(genpath('toolbox'));
addpath('external');

fprintf('CONNECTIVITY HEALTH CHECK DEMONSTRATION\n');
fprintf('========================================\n\n');

% Test 1: Single connected mesh (icosphere)
fprintf('1. Connected mesh (icosphere):\n');
[V, F] = icosphere(3);
M = bct.Manifold(V, F);
h = M.health();
fprintf('   Status: %s\n', h.severity);
fprintf('   Connected: %d\n', h.is.connected);
fprintf('   Components: %d\n\n', h.statsByCheck.connectivity.numComponents);

% Test 2: Two disconnected spheres
fprintf('2. Disconnected mesh (two spheres):\n');
[V1, F1] = icosphere(2);
[V2, F2] = icosphere(2);

% Offset second sphere
V2 = V2 + 5;  % Move 5 units away

% Combine meshes
V_combined = [V1; V2];
F_combined = [F1; F2 + size(V1, 1)];  % Offset face indices

M_disconnected = bct.Manifold(V_combined, F_combined);
h_disconnected = M_disconnected.health();

fprintf('   Status: %s\n', h_disconnected.severity);
fprintf('   Connected: %d\n', h_disconnected.is.connected);
fprintf('   Components: %d\n', h_disconnected.statsByCheck.connectivity.numComponents);
fprintf('   Component sizes: [%s]\n', ...
    num2str(h_disconnected.statsByCheck.connectivity.componentSizes));

if ~isempty(h_disconnected.issues)
    for i = 1:length(h_disconnected.issues)
        if strcmp(h_disconnected.issues(i).id, 'disconnectedComponents')
            fprintf('   Message: %s\n', h_disconnected.issues(i).message);
        end
    end
end

fprintf('\n3. Many small components:\n');
% Create 5 small disconnected triangles
V_multi = [];
F_multi = [];
offset = 0;
for i = 1:5
    % Single triangle
    v = [0 0 0; 1 0 0; 0.5 1 0] + [i*3 0 0];
    f = [1 2 3];
    V_multi = [V_multi; v];
    F_multi = [F_multi; f + offset];
    offset = offset + 3;
end

M_multi = bct.Manifold(V_multi, F_multi);
h_multi = M_multi.health();

fprintf('   Status: %s\n', h_multi.severity);
fprintf('   Components: %d\n', h_multi.statsByCheck.connectivity.numComponents);
fprintf('   Component sizes: [%s]\n', ...
    num2str(h_multi.statsByCheck.connectivity.componentSizes));
