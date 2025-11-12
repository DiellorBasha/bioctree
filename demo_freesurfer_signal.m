% FreeSurfer Signal Analysis Example
bioctree_start

% Load mesh and graph
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.graph.Import.fromFreeSurfer(path);
fprintf('Loaded mesh with %d vertices and %d faces\n', B.N, size(B.Faces, 1));

% Import curvature signal
curv_path = 'test-data\freesurfer\fsaverage\surf\lh.curv';
B = bct.io.signal.Import.fromFreeSurfer(curv_path, B);

% Display signal information
signals = B.signals;
fprintf('\nSignal Import Results:\n');
fprintf('Number of signals: %d\n', length(signals.data));
fprintf('Signal label: %s\n', signals.labels{1});
fprintf('Signal metadata fields: %s\n', strjoin(fieldnames(signals.metadata{1}), ', '));

% Get the curvature signal data
curv_signal = B.getSignal(1);  % Get by index
% curv_signal = B.getSignal('lh.curv');  % Alternative: get by label

% Analyze the curvature signal
fprintf('\nCurvature Signal Statistics:\n');
fprintf('Signal length: %d values\n', length(curv_signal));
fprintf('Data range: [%.4f, %.4f]\n', min(curv_signal), max(curv_signal));
fprintf('Mean curvature: %.4f\n', mean(curv_signal));
fprintf('Std deviation: %.4f\n', std(curv_signal));

% Categorize vertices by curvature
gyral_vertices = curv_signal > 0;    % Positive curvature (gyri)
sulcal_vertices = curv_signal < 0;   % Negative curvature (sulci)
flat_vertices = abs(curv_signal) < 0.01;  % Nearly flat

fprintf('\nCortical Surface Analysis:\n');
fprintf('Gyral vertices (positive curvature): %d (%.1f%%)\n', ...
    sum(gyral_vertices), 100*sum(gyral_vertices)/length(curv_signal));
fprintf('Sulcal vertices (negative curvature): %d (%.1f%%)\n', ...
    sum(sulcal_vertices), 100*sum(sulcal_vertices)/length(curv_signal));
fprintf('Flat vertices (near zero curvature): %d (%.1f%%)\n', ...
    sum(flat_vertices), 100*sum(flat_vertices)/length(curv_signal));

% Visualize the curvature on the mesh if possible
try
    figure(1); clf;
    surfaceMeshShow(B.mesh, 'FaceVertexCData', curv_signal);
    colorbar;
    title('FreeSurfer Curvature Signal on Left Hemisphere');
    xlabel('X'); ylabel('Y'); zlabel('Z');
    
    fprintf('\nVisualization created in Figure 1\n');
catch ME
    fprintf('Visualization failed: %s\n', ME.message);
end

% Show metadata details
fprintf('\nSignal Metadata:\n');
metadata = signals.metadata{1};
disp(metadata);