% create_gsp_graphs_from_fsaverage.m
% Create GSP graphs from our FreeSurfer fsaverage pial surfaces

fprintf('Creating GSP graphs from FreeSurfer fsaverage pial surfaces\n');
fprintf('==========================================================\n\n');

%% Initialize GSPBOX
fprintf('0. Initializing Bioctree and GSPBOX...\n');
fprintf('--------------------------------------\n');

try
    % Initialize bioctree system which includes GSPBOX
    bioctree_start;
    fprintf('✓ Bioctree and GSPBOX initialized successfully\n');
    
    % Test if gsp_graph function is available
    which gsp_graph
    fprintf('✓ gsp_graph function is available\n');
    
catch ME
    fprintf('✗ Error initializing system: %s\n', ME.message);
    fprintf('Make sure bioctree system is properly configured\n');
    return;
end

%% Load FreeSurfer subject data
fprintf('1. Loading FreeSurfer subject data...\n');
fprintf('------------------------------------\n');

try
    combined_data = load('test-data/meshes/fsaverage/fsaverage_pial_surfaces.mat');
    subject = combined_data.subject;
    fprintf('✓ Loaded combined pial surface data\n');
    fprintf('  - LH vertices: %s\n', mat2str(size(subject.lh.pial.vertices)));
    fprintf('  - LH faces: %s\n', mat2str(size(subject.lh.pial.faces)));
    fprintf('  - RH vertices: %s\n', mat2str(size(subject.rh.pial.vertices)));
    fprintf('  - RH faces: %s\n', mat2str(size(subject.rh.pial.faces)));
catch ME
    fprintf('✗ Error loading data: %s\n', ME.message);
    return;
end

%% Process left hemisphere
fprintf('\n2. Processing left hemisphere pial surface...\n');
fprintf('---------------------------------------------\n');

try
    % Extract and correct LH data
    V_lh = double(subject.lh.pial.vertices);
    F_lh = double(subject.lh.pial.faces);
    
    % Convert from FreeSurfer 0-based to MATLAB 1-based indexing
    F_lh = F_lh + 1;
    
    % Flip faces for right-hand orientation (as done in fs2gsp)
    F_lh = F_lh(:, [1 3 2]);
    
    fprintf('Processing LH pial surface:\n');
    fprintf('  - Input vertices: %d\n', size(V_lh, 1));
    fprintf('  - Input faces: %d\n', size(F_lh, 1));
    fprintf('  - Face index range: [%d, %d]\n', min(F_lh(:)), max(F_lh(:)));
    
    % Create surface mesh
    fprintf('  - Creating surfaceMesh...\n');
    Gmesh_lh = surfaceMesh(V_lh, F_lh);
    
    % Compute normals
    fprintf('  - Computing normals...\n');
    computeNormals(Gmesh_lh);
    
    % Center the mesh
    fprintf('  - Centering mesh...\n');
    ctr_lh = vertexCenter(Gmesh_lh);
    translate(Gmesh_lh, -ctr_lh);
    fprintf('    Original center: [%.2f, %.2f, %.2f]\n', ctr_lh);
    
    % Clean up defects
    fprintf('  - Cleaning mesh defects...\n');
    removeDefects(Gmesh_lh, "duplicate-vertices");
    removeDefects(Gmesh_lh, "duplicate-faces");
    removeDefects(Gmesh_lh, "unreferenced-vertices");
    removeDefects(Gmesh_lh, "degenerate-faces");
    removeDefects(Gmesh_lh, "nonmanifold-edges");
    
    % Get cleaned vertices and faces
    V_lh_clean = Gmesh_lh.Vertices;
    F_lh_clean = Gmesh_lh.Faces;
    
    fprintf('  - Cleaned vertices: %d (removed %d)\n', size(V_lh_clean, 1), size(V_lh, 1) - size(V_lh_clean, 1));
    fprintf('  - Cleaned faces: %d (removed %d)\n', size(F_lh_clean, 1), size(F_lh, 1) - size(F_lh_clean, 1));
    
    % Compute cotangent weights
    fprintf('  - Computing cotangent weights...\n');
    [W_cot_lh, M_lh] = compute_cotangent_weights(V_lh_clean, F_lh_clean);
    fprintf('    Weight matrix: %d x %d, %d nonzeros (%.4f%% sparse)\n', ...
        size(W_cot_lh), nnz(W_cot_lh), 100 * (1 - nnz(W_cot_lh) / numel(W_cot_lh)));
    
    % Create GSP graph
    fprintf('  - Creating GSP graph...\n');
    G_lh = gsp_graph(W_cot_lh, V_lh_clean);
    G_lh.plotting.vertex_size = 1;
    G_lh.Faces = F_lh_clean;
    G_lh.M = M_lh;  % lumped vertex areas (mass)
    
    fprintf('✓ Successfully created LH GSP graph!\n');
    fprintf('  - Graph vertices (N): %d\n', G_lh.N);
    fprintf('  - Graph edges (Ne): %d\n', G_lh.Ne);
    fprintf('  - Is connected: %s\n', string(gsp_check_connectivity(G_lh)));
    
catch ME
    fprintf('✗ Error processing LH: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    return;
end

%% Process right hemisphere
fprintf('\n3. Processing right hemisphere pial surface...\n');
fprintf('----------------------------------------------\n');

try
    % Extract and correct RH data
    V_rh = double(subject.rh.pial.vertices);
    F_rh = double(subject.rh.pial.faces);
    
    % Convert from FreeSurfer 0-based to MATLAB 1-based indexing
    F_rh = F_rh + 1;
    
    % Flip faces for right-hand orientation
    F_rh = F_rh(:, [1 3 2]);
    
    fprintf('Processing RH pial surface:\n');
    fprintf('  - Input vertices: %d\n', size(V_rh, 1));
    fprintf('  - Input faces: %d\n', size(F_rh, 1));
    
    % Create and process surface mesh
    fprintf('  - Creating and processing surfaceMesh...\n');
    Gmesh_rh = surfaceMesh(V_rh, F_rh);
    computeNormals(Gmesh_rh);
    
    ctr_rh = vertexCenter(Gmesh_rh);
    translate(Gmesh_rh, -ctr_rh);
    
    % Clean up defects
    removeDefects(Gmesh_rh, "duplicate-vertices");
    removeDefects(Gmesh_rh, "duplicate-faces");
    removeDefects(Gmesh_rh, "unreferenced-vertices");
    removeDefects(Gmesh_rh, "degenerate-faces");
    removeDefects(Gmesh_rh, "nonmanifold-edges");
    
    % Get cleaned data
    V_rh_clean = Gmesh_rh.Vertices;
    F_rh_clean = Gmesh_rh.Faces;
    
    % Compute cotangent weights and create GSP graph
    fprintf('  - Computing cotangent weights and creating GSP graph...\n');
    [W_cot_rh, M_rh] = compute_cotangent_weights(V_rh_clean, F_rh_clean);
    
    G_rh = gsp_graph(W_cot_rh, V_rh_clean);
    G_rh.plotting.vertex_size = 1;
    G_rh.Faces = F_rh_clean;
    G_rh.M = M_rh;
    
    fprintf('✓ Successfully created RH GSP graph!\n');
    fprintf('  - Graph vertices (N): %d\n', G_rh.N);
    fprintf('  - Graph edges (Ne): %d\n', G_rh.Ne);
    fprintf('  - Is connected: %s\n', string(gsp_check_connectivity(G_rh)));
    
catch ME
    fprintf('✗ Error processing RH: %s\n', ME.message);
    return;
end

%% Analyze graph properties
fprintf('\n4. Analyzing graph properties...\n');
fprintf('--------------------------------\n');

fprintf('Left Hemisphere Graph:\n');
fprintf('  - Vertices: %d\n', G_lh.N);
fprintf('  - Edges: %d\n', G_lh.Ne);
w_min = full(min(nonzeros(G_lh.W)));
w_max = full(max(G_lh.W(:)));
fprintf('  - Weight range: [%.6f, %.6f]\n', w_min, w_max);
fprintf('  - Average degree: %.2f\n', 2 * G_lh.Ne / G_lh.N);
fprintf('  - Mass matrix trace: %.2f\n', full(trace(G_lh.M)));

fprintf('\nRight Hemisphere Graph:\n');
fprintf('  - Vertices: %d\n', G_rh.N);
fprintf('  - Edges: %d\n', G_rh.Ne);
w_min_rh = full(min(nonzeros(G_rh.W)));
w_max_rh = full(max(G_rh.W(:)));
fprintf('  - Weight range: [%.6f, %.6f]\n', w_min_rh, w_max_rh);
fprintf('  - Average degree: %.2f\n', 2 * G_rh.Ne / G_rh.N);
fprintf('  - Mass matrix trace: %.2f\n', full(trace(G_rh.M)));

%% Save results
fprintf('\n5. Saving GSP graph results...\n');
fprintf('------------------------------\n');

try
    % Create output directory if needed
    output_dir = 'test-data/meshes/fsaverage';
    
    % Save individual hemisphere graphs
    save(fullfile(output_dir, 'fsaverage_lh_pial_gsp_graph.mat'), ...
        'G_lh', 'Gmesh_lh', 'V_lh_clean', 'F_lh_clean', 'W_cot_lh', 'M_lh', '-v7.3');
    
    save(fullfile(output_dir, 'fsaverage_rh_pial_gsp_graph.mat'), ...
        'G_rh', 'Gmesh_rh', 'V_rh_clean', 'F_rh_clean', 'W_cot_rh', 'M_rh', '-v7.3');
    
    % Save combined graphs
    save(fullfile(output_dir, 'fsaverage_pial_gsp_graphs_complete.mat'), ...
        'G_lh', 'G_rh', 'Gmesh_lh', 'Gmesh_rh', '-v7.3');
    
    fprintf('✓ Saved GSP graph files:\n');
    fprintf('  - fsaverage_lh_pial_gsp_graph.mat\n');
    fprintf('    Contains: G_lh (GSP graph), Gmesh_lh (surfaceMesh), cotangent weights, mass matrix\n');
    fprintf('  - fsaverage_rh_pial_gsp_graph.mat\n');
    fprintf('    Contains: G_rh (GSP graph), Gmesh_rh (surfaceMesh), cotangent weights, mass matrix\n');
    fprintf('  - fsaverage_pial_gsp_graphs_complete.mat\n');
    fprintf('    Contains: G_lh, G_rh (GSP graphs), Gmesh_lh, Gmesh_rh (surfaceMesh objects)\n');
    
catch ME
    fprintf('✗ Error saving files: %s\n', ME.message);
end

%% Create usage examples
fprintf('\n6. Usage examples:\n');
fprintf('------------------\n');

fprintf('MATLAB usage:\n');
fprintf('  %% Load GSP graphs and surfaceMesh objects\n');
fprintf('  load(''test-data/meshes/fsaverage/fsaverage_pial_gsp_graphs_complete.mat'');\n');
fprintf('  \n');
fprintf('  %% Access GSP graphs\n');
fprintf('  G_lh      %% GSP graph for left hemisphere\n');
fprintf('  G_rh      %% GSP graph for right hemisphere\n');
fprintf('  \n');
fprintf('  %% Access surfaceMesh objects (cleaned and processed)\n');
fprintf('  Gmesh_lh  %% MATLAB surfaceMesh object for LH (with normals, centered)\n');
fprintf('  Gmesh_rh  %% MATLAB surfaceMesh object for RH (with normals, centered)\n');
fprintf('  \n');
fprintf('  %% SurfaceMesh object properties:\n');
fprintf('  vertices_clean = Gmesh_lh.Vertices;     %% Cleaned vertex coordinates\n');
fprintf('  faces_clean = Gmesh_lh.Faces;           %% Cleaned face indices\n');
fprintf('  vertex_normals = Gmesh_lh.VertexNormals; %% Computed vertex normals\n');
fprintf('  face_normals = Gmesh_lh.FaceNormals;     %% Computed face normals\n');
fprintf('  \n');
fprintf('  %% Create test signals\n');
fprintf('  signal_lh = randn(G_lh.N, 1);  %% Random signal on LH\n');
fprintf('  signal_rh = randn(G_rh.N, 1);  %% Random signal on RH\n');
fprintf('  \n');
fprintf('  %% Visualize on brain surface\n');
fprintf('  figure; gsp_plot_signal(G_lh, signal_lh); title(''LH Signal'');\n');
fprintf('  figure; gsp_plot_signal(G_rh, signal_rh); title(''RH Signal'');\n');
fprintf('  \n');
fprintf('  %% Alternative: Use surfaceMesh for visualization\n');
fprintf('  figure; \n');
fprintf('  trisurf(Gmesh_lh.Faces, Gmesh_lh.Vertices(:,1), ...\n');
fprintf('          Gmesh_lh.Vertices(:,2), Gmesh_lh.Vertices(:,3), signal_lh);\n');
fprintf('  axis equal; shading interp; title(''LH using surfaceMesh'');\n');
fprintf('  \n');
fprintf('  %% Compute graph Fourier transform\n');
fprintf('  gft_lh = gsp_gft(G_lh, signal_lh);\n');
fprintf('  \n');
fprintf('  %% Apply graph filters\n');
fprintf('  h_lowpass = gsp_design_meyer(G_lh, 0.1);  %% Low-pass filter\n');
fprintf('  filtered_signal = gsp_filter(G_lh, h_lowpass, signal_lh);\n');
fprintf('  \n');
fprintf('  %% Mesh operations using surfaceMesh\n');
fprintf('  mesh_area = area(Gmesh_lh);              %% Total surface area\n');
fprintf('  mesh_volume = volume(Gmesh_lh);          %% Enclosed volume\n');
fprintf('  edge_lengths = edgeLengths(Gmesh_lh);    %% Edge length statistics\n');

fprintf('\n==========================================================\n');
fprintf('✓ GSP graph creation completed successfully!\n');
fprintf('==========================================================\n');

%% Helper function for cotangent weights
function [W_cot, M] = compute_cotangent_weights(V, F)
    % Compute symmetric cotangent-weight adjacency W and lumped mass M (vertex areas).
    V = double(V); F = double(F);
    N = size(V,1);

    i1 = F(:,1); i2 = F(:,2); i3 = F(:,3);
    v1 = V(i1,:); v2 = V(i2,:); v3 = V(i3,:);

    % Twice triangle area
    tri2A = vecnorm(cross(v2 - v1, v3 - v1, 2), 2, 2);
    Atri  = 0.5 * tri2A;

    % Cotangents (guard denominator)
    denom = max(tri2A, eps);
    cotA = dot(v2 - v1, v3 - v1, 2) ./ denom;  % angle at v1 (opposite edge i2-i3)
    cotB = dot(v3 - v2, v1 - v2, 2) ./ denom;  % angle at v2 (opposite edge i3-i1)
    cotC = dot(v1 - v3, v2 - v3, 2) ./ denom;  % angle at v3 (opposite edge i1-i2)

    % Assemble symmetric off-diagonal weights: 0.5*cot(angle opposite edge)
    I = [i2; i3; i3; i1; i1; i2];
    J = [i3; i2; i1; i3; i2; i1];
    S = 0.5 * [cotA; cotA; cotB; cotB; cotC; cotC];

    W_cot = sparse(I, J, S, N, N);
    W_cot = 0.5*(W_cot + W_cot.');                 % symmetrize
    W_cot = W_cot - spdiags(diag(W_cot), 0, N, N); % zero diagonal

    % Lumped mass matrix (barycentric area per vertex)
    Mv = accumarray([i1; i2; i3], [Atri; Atri; Atri]/3, [N 1], @sum, 0);
    M  = spdiags(Mv, 0, N, N);
end