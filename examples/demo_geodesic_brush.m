%% Demo: Geodesic Trajectory Brush
% Demonstrates how to use the geodesic trajectory brush to select
% shortest paths between vertices on a cortical surface.

clear; close all;

% =========================================================================
% 1. Load cortical surface
% =========================================================================

B = bct_fsaverage('rh', 'saved');
M = B.Manifold;

fprintf('Loaded fsaverage right hemisphere: %d vertices\n', M.N);

% =========================================================================
% 2. Define source and target vertices
% =========================================================================

source = 1000;   % anterior region
target = 35000;  % posterior region

fprintf('Source vertex: %d\n', source);
fprintf('Target vertex: %d\n', target);

% =========================================================================
% 3. Apply geodesic trajectory brush (geometry metric)
% =========================================================================

params_geo = struct();
params_geo.source = source;
params_geo.target = target;
params_geo.metric = "geometry";  % Euclidean distance

w_geo = bct.brush.apply('trajectory_geodesic', M, params_geo);

fprintf('Geodesic path (geometry): %d vertices\n', nnz(w_geo));

% =========================================================================
% 4. Apply geodesic trajectory brush (FEM metric)
% =========================================================================

params_fem = struct();
params_fem.source = source;
params_fem.target = target;
params_fem.metric = "fem";  % Cotangent weights

w_fem = bct.brush.apply('trajectory_geodesic', M, params_fem);

fprintf('Geodesic path (FEM): %d vertices\n', nnz(w_fem));

% =========================================================================
% 5. Visualize both paths
% =========================================================================

figure('Position', [100 100 1400 600]);

% --- Geometry metric path ---
subplot(1,2,1);
patch('Vertices', M.Vertices, 'Faces', M.Faces, ...
      'FaceVertexCData', full(w_geo), ...
      'FaceColor', 'interp', 'EdgeColor', 'none');
colormap('hot'); caxis([0 1]);
axis equal off; view(3); camlight; lighting gouraud;
title('Geodesic Path (Geometry Metric)');

% Highlight endpoints
hold on;
plot3(M.Vertices(source,1), M.Vertices(source,2), M.Vertices(source,3), ...
      'go', 'MarkerSize', 12, 'LineWidth', 3);
plot3(M.Vertices(target,1), M.Vertices(target,2), M.Vertices(target,3), ...
      'ro', 'MarkerSize', 12, 'LineWidth', 3);
hold off;

% --- FEM metric path ---
subplot(1,2,2);
patch('Vertices', M.Vertices, 'Faces', M.Faces, ...
      'FaceVertexCData', full(w_fem), ...
      'FaceColor', 'interp', 'EdgeColor', 'none');
colormap('hot'); caxis([0 1]);
axis equal off; view(3); camlight; lighting gouraud;
title('Geodesic Path (FEM Metric)');

% Highlight endpoints
hold on;
plot3(M.Vertices(source,1), M.Vertices(source,2), M.Vertices(source,3), ...
      'go', 'MarkerSize', 12, 'LineWidth', 3);
plot3(M.Vertices(target,1), M.Vertices(target,2), M.Vertices(target,3), ...
      'ro', 'MarkerSize', 12, 'LineWidth', 3);
hold off;

% =========================================================================
% 6. Alternative: Direct function call (bypass registry)
% =========================================================================

% You can also call the brush function directly:
w_direct = bct.brush.trajectory.geodesic(M, params_geo);

fprintf('\nDirect call produced same result: %s\n', ...
        string(isequal(w_direct, w_geo)));

% =========================================================================
% 7. Extract path indices
% =========================================================================

path_indices = find(w_geo);
fprintf('\nPath vertices: [%d', path_indices(1));
fprintf(' %d', path_indices(2:min(5,end)));
if numel(path_indices) > 5
    fprintf(' ... %d', path_indices(end));
end
fprintf(']\n');

% =========================================================================
% 8. Combine with patch brush for region-based selection
% =========================================================================

% Select all vertices within 50mm of the geodesic path
params_patch = struct();
params_patch.seed = path_indices(round(end/2));  % midpoint of path
params_patch.k = 100;  % 100 nearest neighbors

w_patch = bct.brush.apply('patch_nearest', M, params_patch);

fprintf('\nPatch around path midpoint: %d vertices\n', nnz(w_patch));

% Visualize combined selection
figure('Position', [100 100 700 600]);
w_combined = max(w_geo, w_patch);  % union of path and patch
patch('Vertices', M.Vertices, 'Faces', M.Faces, ...
      'FaceVertexCData', full(w_combined), ...
      'FaceColor', 'interp', 'EdgeColor', 'none');
colormap('hot'); caxis([0 1]);
axis equal off; view(3); camlight; lighting gouraud;
title('Geodesic Path + Nearest Patch (Combined)');
