%DEMO_VERTEX_TANGENTS Demonstration of face and vertex tangent computation
%
% This script demonstrates the new Domain parameter in tangents() which
% allows computing orthonormal tangent frames for both faces and vertices.

% Initialize BCT
bct_start;

% Load test mesh
fprintf('Loading mesh...\n');
data = load('data/mesh/fsaverage_rh_pial.mat');
M = bct.Manifold(data.V, data.F);
fprintf('Mesh: %d vertices, %d faces\n\n', size(M.Vertices,1), size(M.Faces,1));

%% Face Tangents (default behavior)
fprintf('=== Face Tangents ===\n');
[N_f, e1_f, e2_f] = M.tangents();  % Default: 'Domain'='face'
fprintf('Computed %d face tangent frames\n', size(N_f,1));

% Visualize a subset of face tangents at centroids
C = M.centroids();
subsample = 1:1000:size(C,1);  % Sample every 1000th face

figure('Name', 'Face Tangent Frames');
M.show('FaceColor', [0.9 0.9 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
hold on;
quiver3(C(subsample,1), C(subsample,2), C(subsample,3), ...
        e1_f(subsample,1), e1_f(subsample,2), e1_f(subsample,3), ...
        0.5, 'r', 'LineWidth', 1.5);
quiver3(C(subsample,1), C(subsample,2), C(subsample,3), ...
        e2_f(subsample,1), e2_f(subsample,2), e2_f(subsample,3), ...
        0.5, 'g', 'LineWidth', 1.5);
quiver3(C(subsample,1), C(subsample,2), C(subsample,3), ...
        N_f(subsample,1), N_f(subsample,2), N_f(subsample,3), ...
        0.5, 'b', 'LineWidth', 1.5);
legend('Mesh', 'e1 (red)', 'e2 (green)', 'Normal (blue)');
title('Face Tangent Frames at Face Centroids');
axis equal;
view(3);
lighting gouraud;
camlight;
fprintf('Figure created: Face tangent frames (sampled)\n\n');

%% Vertex Tangents (new feature)
fprintf('=== Vertex Tangents ===\n');
[N_v, e1_v, e2_v] = M.tangents('Domain', 'vertex');
fprintf('Computed %d vertex tangent frames\n', size(N_v,1));

% Visualize a subset of vertex tangents
V = M.Vertices;
subsample_v = 1:500:size(V,1);  % Sample every 500th vertex

figure('Name', 'Vertex Tangent Frames');
M.show('FaceColor', [0.9 0.9 0.9], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
hold on;
quiver3(V(subsample_v,1), V(subsample_v,2), V(subsample_v,3), ...
        e1_v(subsample_v,1), e1_v(subsample_v,2), e1_v(subsample_v,3), ...
        0.5, 'r', 'LineWidth', 1.5);
quiver3(V(subsample_v,1), V(subsample_v,2), V(subsample_v,3), ...
        e2_v(subsample_v,1), e2_v(subsample_v,2), e2_v(subsample_v,3), ...
        0.5, 'g', 'LineWidth', 1.5);
quiver3(V(subsample_v,1), V(subsample_v,2), V(subsample_v,3), ...
        N_v(subsample_v,1), N_v(subsample_v,2), N_v(subsample_v,3), ...
        0.5, 'b', 'LineWidth', 1.5);
legend('Mesh', 'e1 (red)', 'e2 (green)', 'Normal (blue)');
title('Vertex Tangent Frames at Vertices');
axis equal;
view(3);
lighting gouraud;
camlight;
fprintf('Figure created: Vertex tangent frames (sampled)\n\n');

%% Comparison: Simple Triangle
fprintf('=== Simple Triangle Example ===\n');
V_tri = [0 0 0; 1 0 0; 0 1 0];
F_tri = [1 2 3];
M_tri = bct.Manifold(V_tri, F_tri);

% Face tangents
[N_tri_f, e1_tri_f, e2_tri_f] = M_tri.tangents('Domain', 'face');
fprintf('Face tangent frame:\n');
fprintf('  N  = [%.4f, %.4f, %.4f]\n', N_tri_f);
fprintf('  e1 = [%.4f, %.4f, %.4f]\n', e1_tri_f);
fprintf('  e2 = [%.4f, %.4f, %.4f]\n', e2_tri_f);

% Vertex tangents
[N_tri_v, e1_tri_v, e2_tri_v] = M_tri.tangents('Domain', 'vertex');
fprintf('Vertex tangent frames:\n');
for i = 1:3
    fprintf('  Vertex %d:\n', i);
    fprintf('    N  = [%.4f, %.4f, %.4f]\n', N_tri_v(i,:));
    fprintf('    e1 = [%.4f, %.4f, %.4f]\n', e1_tri_v(i,:));
    fprintf('    e2 = [%.4f, %.4f, %.4f]\n', e2_tri_v(i,:));
end

%% Demonstrate different calling conventions
fprintf('\n=== API Examples ===\n');

% Method 1: Instance method with default (face)
[N1, e1_1, e2_1] = M.tangents();
fprintf('M.tangents() -> %d frames\n', size(N1,1));

% Method 2: Instance method with explicit domain
[N2, e1_2, e2_2] = M.tangents('Domain', 'vertex');
fprintf('M.tangents(''Domain'', ''vertex'') -> %d frames\n', size(N2,1));

% Method 3: Package function with Manifold
[N3, e1_3, e2_3] = bct.manifold.tangents(M, 'Domain', 'face');
fprintf('bct.manifold.tangents(M, ''Domain'', ''face'') -> %d frames\n', size(N3,1));

% Method 4: Package function with V, F
[N4, e1_4, e2_4] = bct.manifold.tangents(M.Vertices, M.Faces, 'Domain', 'vertex');
fprintf('bct.manifold.tangents(V, F, ''Domain'', ''vertex'') -> %d frames\n', size(N4,1));

fprintf('\nDemo complete!\n');
