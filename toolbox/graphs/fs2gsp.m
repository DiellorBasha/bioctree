function subject = fs2gsp(subject_dir, subject_name, hemi, surface_type)
%FS_SUBJECT_TO_GSP Build GSP graphs from FreeSurfer subject surfaces (cotangent Laplacian).
%   subject = FS_SUBJECT_TO_GSP(subject_dir, subject_name, hemi, surface_type)
%       subject_dir   : path to FreeSurfer subject (e.g., '.../subjects/fsaverage')
%       subject_name  : name of the subject
%       hemi          : 'lh', 'rh', or 'both' (default: 'both')
%       surface_type  : 'pial', 'white', 'sphere', etc. (default: 'pial')
%   Returns:
%       subject : FreeSurfer subject structure with added GSP graphs and cleaned meshes
%           For each hemisphere and surface, adds:
%           - subject.{hemi}.{surface_type}_gsp: GSP graph struct with cotangent weights
%           - subject.{hemi}.{surface_type}_mat: cleaned MATLAB surfaceMesh object
%   GSP graph fields:
%           - G.W: weighted adjacency (cotangent weights, symmetric, zero diagonal)
%           - G.L: Laplacian (D - W) computed by gsp_graph
%           - G.coords: vertex xyz
%           - G.M: lumped mass (vertex area) diagonal matrix
%           - G.Faces: triangulation (Nx3)
%           - G.face_normals: face normals (Nfaces x 3)
%           - G.vertex_normals: vertex normals (Nvertices x 3)
%   Example:
%       subject = fs2gsp('C:\CodingProjects\bioctree\test-data\freesurfer', 'fsaverage');
%       gsp_plot_signal(G, zeros(G.N,1)); axis equal off; title('fsaverage lh (cotangent graph)');

    % Set defaults
    if nargin < 3 || isempty(hemi), hemi = 'both'; end
    if nargin < 4 || isempty(surface_type), surface_type = 'pial'; end
    
    % --- Read subject (struct with lh/rh surfaces) ---
    subject = in_fs_read_subject(subject_dir, subject_name);
    
    % Determine which hemispheres to process
    if strcmp(hemi, 'both')
        hemis_to_process = {'lh', 'rh'};
        % When processing both hemispheres, join them first for consistent centering
        process_joined = true;
    else
        hemis_to_process = {hemi};
        process_joined = false;
    end
    
    if process_joined
        % === Joint processing for both hemispheres ===
        fprintf('\n=== Joint processing: joining hemispheres for consistent centering ===\n');
        
        % Check if surface exists for both hemispheres
        if ~isfield(subject.lh, surface_type) || ~isfield(subject.rh, surface_type)
            error('Surface %s not found for both hemispheres', surface_type);
        end
        
        % Source (mm)
        FL = subject.lh.(surface_type).faces;      VL = subject.lh.(surface_type).vertices;
        FR = subject.rh.(surface_type).faces;      VR = subject.rh.(surface_type).vertices;
        
        nL = size(VL,1);      nFL = size(FL,1);
        nR = size(VR,1);      nFR = size(FR,1);
        
        fprintf('LH: %d vertices, %d faces\n', nL, nFL);
        fprintf('RH: %d vertices, %d faces\n', nR, nFR);
        
        % --- Join hemispheres, then recenter once ---
        V = [VL; VR];
        F = [FL; FR + nL];
        GB = surfaceMesh(V, F);
        
        fprintf('Joint mesh: %d vertices, %d faces\n', length(GB.Vertices), length(GB.Faces));
        fprintf('Joint centering...\n');
        ctr = vertexCenter(GB);
        translate(GB, -ctr, ctr);     %
        
        % --- Split back to LH & RH (reindex faces properly) ---
        fprintf('Splitting back to hemispheres...\n');
        
        % Left
        VLc = GB.Vertices(1:nL, :);
        FLc = GB.Faces(1:nFL, :);
        
        % Right (faces come from the second block; reindex by subtracting nL)
        VRc = GB.Vertices(nL+1:nL+nR, :);
        FRc = GB.Faces(nFL+1:nFL+nFR, :) - nL;
        
        % Process each hemisphere with pre-centered coordinates
        for h = 1:length(hemis_to_process)
            current_hemi = hemis_to_process{h};
            fprintf('\n=== Processing split %s %s ===\n', current_hemi, surface_type);
            
            % Use pre-centered coordinates and properly reindexed faces
            switch current_hemi
                case 'lh'
                    F_split = FLc(:, [1 3 2]);   % flip to match right-hand orientation
                    V_split = VLc;
                case 'rh'
                    F_split = FRc(:, [1 3 2]);   % flip to match right-hand orientation
                    V_split = VRc;
            end
            
            % Create and clean surface mesh (skip centering/rotation as already done)
            [G, Gmesh] = process_surface_mesh_precentered(V_split, F_split);
            
            % Store results in subject structure
            gsp_field = [surface_type '_gsp'];
            mat_field = [surface_type '_mat'];
            subject.(current_hemi).(gsp_field) = G;
            subject.(current_hemi).(mat_field) = Gmesh;
        end
        
    else
        % === Single hemisphere processing ===
        for h = 1:length(hemis_to_process)
            current_hemi = hemis_to_process{h};
            fprintf('\n=== Processing %s %s ===\n', current_hemi, surface_type); 
            % Get vertices and faces for current hemisphere and surface
            if ~isfield(subject.(current_hemi), surface_type)
                warning('Surface %s not found for hemisphere %s, skipping...', surface_type, current_hemi);
                continue;
            end
            
            switch current_hemi
                case 'lh'
                    F = subject.lh.(surface_type).faces(:, [1 3 2]);   % flip to match right-hand orientation
                    V = subject.lh.(surface_type).vertices;
                case 'rh'
                    F = subject.rh.(surface_type).faces(:, [1 3 2]);
                    V = subject.rh.(surface_type).vertices;
            end
            
            % Create and clean surface mesh
            [G, Gmesh] = process_surface_mesh(V, F);
            
            % Store results in subject structure
            gsp_field = [surface_type '_gsp'];
            mat_field = [surface_type '_mat'];
            subject.(current_hemi).(gsp_field) = G;
            subject.(current_hemi).(mat_field) = Gmesh;
        end
    end
end

% ================== helpers ==================
function [G, Gmesh] = process_surface_mesh_precentered(V, F)
% Process a surface mesh that has already been centered and rotated

Gmesh=surfaceMesh(V,F);
fprintf('\nComputing normals for %d vertices\n', length(V))
fprintf('Computing normals for %d faces\n', length(F))
computeNormals(Gmesh);

% Skip centering and rotation as already done in joint processing

% Cleanup using explicit removeDefects passes (safe order)
fprintf('Removing defects... \n ')
removeDefects(Gmesh,"duplicate-vertices");
removeDefects(Gmesh,"duplicate-faces");
removeDefects(Gmesh,"unreferenced-vertices");
removeDefects(Gmesh,"degenerate-faces");
removeDefects(Gmesh,"nonmanifold-edges");
%fprintf('\nSmoothing... \n');
%smoothSurfaceMesh(Gmesh,2);

fprintf('\nCalculating cotangent weights... \n');

    % --- Build cotangent-weight adjacency & mass matrix ---
    [W_cot, M] = cotangent_weights(V, F);
    % --- Build GSP graph (use cotangent adjacency as W, attach coords) ---
    G = gsp_graph(W_cot, V);
    %G.type = 'mesh-cotangent';
    G.plotting.vertex_size = 1;
    G.Faces = F;
    G.M = M;                      % lumped vertex areas (mass)

fprintf('\nMesh loaded succesfully \n'); 
fprintf('\nFreesurfer %d vertices\n', length(V));
fprintf('Final %d vertices\n', length(Gmesh.Vertices));
fprintf('\nFreesurfer %d faces\n', length(F));
fprintf('Final %d faces\n', length(Gmesh.Faces));
end

function [G, Gmesh] = process_surface_mesh(V, F)
% Process a single surface mesh with cleaning and GSP graph creation

Gmesh=surfaceMesh(V,F);
fprintf('\nComputing normals for %d vertices\n', length(V))
fprintf('Computing normals for %d faces\n', length(F))
computeNormals(Gmesh);
fprintf('Setting mesh center to 0\n')
ctr = vertexCenter(Gmesh);               % 1x3
translate(Gmesh, -ctr, ctr);              % shift so origin is at center

% Cleanup using explicit removeDefects passes (safe order)
fprintf('Removing defects... \n ')
removeDefects(Gmesh,"duplicate-vertices");
removeDefects(Gmesh,"duplicate-faces");
removeDefects(Gmesh,"unreferenced-vertices");
removeDefects(Gmesh,"degenerate-faces");
removeDefects(Gmesh,"nonmanifold-edges");
%fprintf('\nSmoothing... \n');
%smoothSurfaceMesh(Gmesh,2);

fprintf('\nCalculating cotangent weights... \n');

    % --- Build cotangent-weight adjacency & mass matrix ---
    [W_cot, M] = cotangent_weights(V, F);
    % --- Build GSP graph (use cotangent adjacency as W, attach coords) ---
    G = gsp_graph(W_cot, V);
    %G.type = 'mesh-cotangent';
    G.plotting.vertex_size = 1;
    G.Faces = F;
    G.M = M;                      % lumped vertex areas (mass)

fprintf('\nMesh loaded succesfully \n'); 
fprintf('\nFreesurfer %d vertices\n', length(V));
fprintf('Final %d vertices\n', length(Gmesh.Vertices));
fprintf('\nFreesurfer %d faces\n', length(F));
fprintf('Final %d faces\n', length(Gmesh.Faces));
end
function [W_cot, M] = cotangent_weights(V, F)
% Compute symmetric cotangent-weight adjacency W and lumped mass M (vertex areas).
    V = double(V); F = double(F);
    N = size(V,1);

    i1 = F(:,1); i2 = F(:,2); i3 = F(:,3);
    v1 = V(i1,:); v2 = V(i2,:); v3 = V(i3,:);

    % Twice triangle area
    tri2A = vecnorm(cross(v2 - v1, v3 - v1, 2), 2, 2);     % ||(v2-v1) x (v3-v1)||
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
    W_cot = W_cot - spdiags(diag(W_cot), 0, N, N); % zero diagonal (paranoia)

    % Lumped mass matrix (barycentric area per vertex)
    Mv = accumarray([i1; i2; i3], [Atri; Atri; Atri]/3, [N 1], @sum, 0);
    M  = spdiags(Mv, 0, N, N);
end

