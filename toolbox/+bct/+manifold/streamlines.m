function curves = streamlines(signal, seedVertex, options)
    % STREAMLINES Compute streamlines on a manifold surface
    %
    % Syntax:
    %   curves = bct.show.streamlines(signal, seedVertex)
    %   curves = bct.show.streamlines(signal, seedVertex, 'Sigma', 10)
    %
    % Inputs:
    %   signal     - bct.Signal object on Manifold domain
    %   seedVertex - Vertex index to seed streamlines from
    %
    % Name-Value Arguments:
    %   Sigma      - Radius in mesh units for seed region (default: 10)
    %   NumSeeds   - Number of seed points (default: 30)
    %   TimeStep   - Integration time step (default: 0.5)
    %   NumSteps   - Number of integration steps (default: 150)
    %   VectorField - Vector field [N×3] on vertices (default: use gradient)
    %   Negate     - Negate vector field (default: false)
    %
    % Outputs:
    %   curves     - Cell array of streamline curves, each [K×3]
    %
    % Description:
    %   Computes streamlines on a manifold surface by integrating a vector
    %   field using Euler steps with surface projection. Seeds are placed
    %   in a geodesic-like neighborhood around seedVertex.
    %
    %   By default, uses the negative normalized gradient of the signal
    %   (downhill flow). Custom vector fields can be provided.
    %
    % Example:
    %   % Load mesh
    %   data = load('data/mesh/fsaverage_rh_pial.mat');
    %   M = bct.bct.fromMesh(data.V, data.F);
    %   
    %   % Create signal
    %   w = M.Vertices(:,1);  % x-coordinate
    %   sig = bct.Signal(w, M);
    %   
    %   % Compute streamlines from vertex 100
    %   curves = bct.show.streamlines(sig, 100, 'Sigma', 15);
    %   
    %   % Visualize
    %   figure; patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %                 'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none');
    %   hold on;
    %   for i = 1:numel(curves)
    %       plot3(curves{i}(:,1), curves{i}(:,2), curves{i}(:,3), ...
    %             'r-', 'LineWidth', 2);
    %   end
    %   axis equal; view(3); camlight;
    
    arguments
        signal (1,1) bct.Signal
        seedVertex (1,1) double {mustBeInteger, mustBePositive}
        options.Sigma (1,1) double = 10
        options.NumSeeds (1,1) double {mustBeInteger, mustBePositive} = 30
        options.TimeStep (1,1) double = 0.5
        options.NumSteps (1,1) double {mustBeInteger, mustBePositive} = 150
        options.VectorField (:,3) double = []
        options.Negate (1,1) logical = false
    end
    
    % Validate signal is on Manifold domain
    if ~isa(signal.Domain, 'bct.Manifold')
        error('bct:streamlines:InvalidDomain', ...
            'Signal must be defined on Manifold domain');
    end
    
    % Validate signal is static (not joint)
    if signal.IsJoint
        error('bct:streamlines:JointSignal', ...
            'Streamlines not implemented for joint signals');
    end
    
    % Get manifold
    M = signal.Domain;
    V = M.Vertices;
    F = M.Faces;
    Nv = size(V, 1);
    
    % Validate seed vertex
    if seedVertex > Nv
        error('bct:streamlines:InvalidSeed', ...
            'Seed vertex %d exceeds number of vertices (%d)', seedVertex, Nv);
    end
    
    % Get or compute vector field on vertices
    if isempty(options.VectorField)
        % Compute gradient (face-based)
        [~, gradW_unit] = signal.gradient();
        
        % Negate for downhill flow
        if options.Negate
            U_face = -gradW_unit;
        else
            U_face = gradW_unit;
        end
        
        % Convert face vectors to vertex vectors (average)
        Uvtx = zeros(Nv, 3);
        for dim = 1:3
            Uvtx(:, dim) = accumarray(F(:), repmat(U_face(:,dim), 3, 1), ...
                                       [Nv 1], @mean, 0);
        end
    else
        % Use provided vector field
        Uvtx = options.VectorField;
        
        if size(Uvtx, 1) ~= Nv
            error('bct:streamlines:InvalidVectorField', ...
                'Vector field must have %d rows (number of vertices)', Nv);
        end
        
        if options.Negate
            Uvtx = -Uvtx;
        end
    end
    
    % Compute seed region (geodesic-like neighborhood)
    seedRadius = 2 * options.Sigma;
    d = vecnorm(V - V(seedVertex,:), 2, 2);
    seedVerts = find(d < seedRadius);
    
    % Subsample to avoid clutter
    nSeeds = min(options.NumSeeds, numel(seedVerts));
    if nSeeds < numel(seedVerts)
        seedVerts = seedVerts(randperm(numel(seedVerts), nSeeds));
    end
    
    % Precompute face centroids and normals for projection
    COM = M.centroid();
    faceNormals = M.faceNormal();
    
    % Integration parameters
    dt = options.TimeStep;
    nSteps = options.NumSteps;
    
    % Compute streamlines
    curves = cell(numel(seedVerts), 1);
    
    for s = 1:numel(seedVerts)
        % Initialize at seed vertex
        p = V(seedVerts(s), :);
        curve = zeros(nSteps, 3);
        
        for k = 1:nSteps
            curve(k, :) = p;
            
            % Nearest vertex for vector lookup
            [~, vid] = min(vecnorm(V - p, 2, 2));
            v = Uvtx(vid, :);
            
            % Euler step
            p_new = p + dt * v;
            
            % Nearest-face projection (project back onto surface)
            [~, fID] = min(vecnorm(COM - p_new, 2, 2));
            v0 = V(F(fID, 1), :);
            n = faceNormals(fID, :);
            
            % Project onto face plane
            p = p_new - dot(p_new - v0, n) * n;
        end
        
        % Remove zero rows (if any)
        curves{s} = curve(any(curve, 2), :);
    end
end
