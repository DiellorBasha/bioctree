function solver = heatDistance(varargin)
%BCT.MANIFOLD.SOLVE.HEATDISTANCE  Build a reusable heat-based geodesic distance solver
%
%   solver = bct.manifold.solve.heatDistance(M)
%   solver = bct.manifold.solve.heatDistance(M, 't_heat', value)
%   solver = bct.manifold.solve.heatDistance(M, 'pinnedVertex', value)
%
% Purpose
%   Creates a cached solver for computing geodesic distances using the
%   heat method. Combines heat diffusion with Poisson solve to recover
%   distances on triangulated surfaces.
%
%   This is a MATLAB implementation based on the heat method described in:
%   Crane, K., Weischedel, C., & Wardetzky, M. (2017). 
%   "The Heat Method for Distance Computation." 
%   Communications of the ACM, 60(11), 90-99.
%   https://doi.org/10.1145/3131280
%
%   The implementation follows the halfedge-based approach from the
%   geometry-processing-js library (https://geometrycollective.github.io/geometry-processing-js/),
%   using efficient cached Cholesky factorizations of the heat and Poisson
%   operators for repeated distance queries.
%
%   Algorithm:
%   1. Solve heat equation: (M + t*K) * u = δ_seed
%   2. Compute normalized gradient: X = -∇u / |∇u|
%   3. Compute divergence: div = ∇·X
%   4. Solve Poisson equation: Δφ = -div with φ(seed) = 0
%
% Inputs
%   M - bct.Manifold object (required)
%
% Name-Value Arguments
%   t_heat       - Heat diffusion time (default: auto from mean edge length)
%   pinnedVertex - Vertex to pin in Poisson solve (default: 1)
%
% Output
%   solver - Struct with attributes and value fields:
%     .attributes       - Solver metadata struct:
%       .type             - "heatDistance"
%       .method           - "heat_method"
%       .t_heat           - Heat diffusion time
%       .t_heat_source    - "auto" | "manual"
%       .pinnedVertex     - Pinned vertex for Poisson
%       .nVertices        - Number of vertices
%       .nFaces           - Number of faces
%       .computed_utc     - Timestamp
%     .value            - Function handle: phi = solver.value(seed)
%     .valueAttributes  - Metadata about solver function
%
% Usage
%   % Build solver from Manifold
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   solver = bct.manifold.solve.heatDistance(M);
%   
%   % Compute geodesic distance from seed vertex
%   seed = 4841;
%   phi = solver.value(seed);  % [nV×1] distance field
%   
%   % Multiple seeds (returns matrix)
%   seeds = [100, 200, 300];
%   PHI = solver.value(seeds);  % [nV×3], each column is one distance field
%   
%   % Custom heat time
%   solver = bct.manifold.solve.heatDistance(M, 't_heat', 1.0);
%   
%   % Custom pinned vertex
%   solver = bct.manifold.solve.heatDistance(M, 'pinnedVertex', 100);
%
% Notes
%   - Caches heat solver, Poisson solver, and geometric data for efficiency
%   - Uses halfedge-based gradient and divergence computation
%   - Automatically normalizes distance: φ(seed) = 0
%   - Requires Manifold with topology data (halfedges)
%
% References
%   Crane, K., Weischedel, C., & Wardetzky, M. (2017).
%   "The Heat Method for Distance Computation."
%   Communications of the ACM, 60(11), 90-99.
%   https://doi.org/10.1145/3131280
%
% See also: bct.manifold.solve.heat, bct.manifold.solve.poisson

    % Parse inputs
    if nargin < 1 || ~isa(varargin{1}, 'bct.Manifold')
        error('bct:manifold:solve:heatDistance:InvalidInput', ...
            'First argument must be a bct.Manifold object');
    end
    
    M = varargin{1};
    
    % Parse optional parameters
    p = inputParser;
    p.addParameter('t_heat', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    p.addParameter('pinnedVertex', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
    p.parse(varargin{2:end});
    opt = p.Results;
    
    % Build heat solver
    if ~isempty(opt.t_heat)
        heatSolver = bct.manifold.solve.heat(M, 't_heat', opt.t_heat, 'input', 'seed');
        t_heat = opt.t_heat;
        t_heat_source = 'manual';
    else
        heatSolver = bct.manifold.solve.heat(M, 'input', 'seed');
        t_heat = heatSolver.attributes.t_heat;
        t_heat_source = 'auto';
    end
    
    % Build Poisson solver
    poissonSolver = bct.manifold.solve.poisson(M, 'input', 'rhs', ...
        'pinnedVertex', opt.pinnedVertex);
    
    % Get geometry and topology needed for gradient/divergence
    V = M.Vertices;
    nV = size(V, 1);
    nF = size(M.Faces, 1);
    
    % Get topology
    topo = M.topology;
    
    % Halfedge data
    tail = topo.tailVertex.value;      % nH×1: tail vertex of each halfedge
    head = topo.headVertex.value;      % nH×1: head vertex of each halfedge
    faceH = topo.face.value;           % nH×1: face of each halfedge
    prevH = topo.prev.value;           % nH×1: previous halfedge
    twinH = topo.twin.value;           % nH×1: twin halfedge
    isB = topo.isBoundary.value;       % nH×1: boundary flag
    
    nH = length(tail);
    
    % Face geometry
    geom = M.geometry;
    Af = geom.face.areas.value;            % nF×1: face areas
    Nf_unit = geom.face.normals.value;     % nF×3: unit face normals
    
    % Cotan weights
    cot = geom.face.cotan.value;           % nF×3: cotangent per corner
    
    % Convert cotan from nF×3 to nH×1
    if isfield(topo, 'faceHalfedges') && isfield(topo.faceHalfedges, 'value')
        FH = topo.faceHalfedges.value;     % nF×3: halfedge indices per face
        cotH = zeros(nH, 1);
        cotH(FH(:,1)) = cot(:,1);
        cotH(FH(:,2)) = cot(:,2);
        cotH(FH(:,3)) = cot(:,3);
    else
        % Assume already nH×1 aligned with halfedges
        cotH = cot;
    end
    
    % Halfedge edge vectors
    E = V(head, :) - V(tail, :);           % nH×3: edge vectors
    
    % Expand normals to halfedges
    Nh = Nf_unit(faceH, :);                % nH×3: normal per halfedge
    
    % Initialize attributes
    attrs = struct();
    attrs.type = "heatDistance";
    attrs.method = "heat_method";
    attrs.reference = "Crane et al. 2017, Commun. ACM, https://doi.org/10.1145/3131280";
    attrs.t_heat = t_heat;
    attrs.t_heat_source = t_heat_source;
    attrs.pinnedVertex = opt.pinnedVertex;
    attrs.nVertices = nV;
    attrs.nFaces = nF;
    attrs.nHalfedges = nH;
    attrs.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    
    % Create solver function
    solverFn = @(seed) computeHeatDistance(seed, heatSolver, poissonSolver, ...
        tail, head, faceH, prevH, twinH, isB, cotH, E, Nh, Af, nV, nF, nH);
    
    % Return solver structure
    solver.attributes = attrs;
    solver.value = solverFn;
    
    % Add metadata about solver function
    solver.valueAttributes = struct(...
        'name', 'heatDistanceSolver', ...
        'description', 'Heat-based geodesic distance solver', ...
        'dtype', 'function_handle', ...
        'signature', 'phi = solver.value(seed)', ...
        'input_description', 'seed vertex index/indices', ...
        'input_shape', 'scalar or [1×K] vector', ...
        'output_shape', '[nV×1] or [nV×K]', ...
        'input_support', 'vertex', ...
        'output_support', 'vertex', ...
        'complexity', 'O(N) per solve (heat + Poisson)', ...
        'computedBy', 'bct.manifold.solve.heatDistance');
end

function phi = computeHeatDistance(seed, heatSolver, poissonSolver, ...
    tail, head, faceH, prevH, twinH, isB, cotH, E, Nh, Af, nV, nF, nH)
%COMPUTEHEATDISTANCE  Compute heat-based geodesic distance from seed(s)
%
%   Implements the three-step heat method algorithm

    % Ensure seed is row vector
    seed = seed(:)';
    
    % Validate seeds
    if any(seed < 1) || any(seed > nV)
        error('bct:manifold:solve:heatDistance:InvalidSeed', ...
            'Seed indices must be in range [1, %d]', nV);
    end
    
    % Check for multiple seeds
    nSeeds = length(seed);
    
    if nSeeds == 1
        % Single seed - return column vector
        phi = computeSingleDistance(seed, heatSolver, poissonSolver, ...
            tail, head, faceH, prevH, twinH, isB, cotH, E, Nh, Af, nV, nF, nH);
    else
        % Multiple seeds - return matrix
        phi = zeros(nV, nSeeds);
        for k = 1:nSeeds
            phi(:, k) = computeSingleDistance(seed(k), heatSolver, poissonSolver, ...
                tail, head, faceH, prevH, twinH, isB, cotH, E, Nh, Af, nV, nF, nH);
        end
    end
end

function phi = computeSingleDistance(seed, heatSolver, poissonSolver, ...
    tail, head, faceH, prevH, twinH, isB, cotH, E, Nh, Af, nV, nF, nH)
%COMPUTESINGLEDISTANCE  Compute distance from a single seed vertex

    % Step I: Solve heat equation
    u = heatSolver.value(seed);  % nV×1
    
    % Step II: Compute normalized gradient X on faces
    % gradU_f = (1/(2*A_f)) * Σ_{h in face} (n_f × e_h) * u(tail(h))
    
    u_tail = u(tail);                      % nH×1
    C = cross(Nh, E, 2);                   % nH×3: n × e
    
    % Weighted contributions per halfedge
    Cx = C(:,1) .* u_tail;
    Cy = C(:,2) .* u_tail;
    Cz = C(:,3) .* u_tail;
    
    % Accumulate to faces
    gradUx = accumarray(faceH, Cx, [nF 1], @sum, 0);
    gradUy = accumarray(faceH, Cy, [nF 1], @sum, 0);
    gradUz = accumarray(faceH, Cz, [nF 1], @sum, 0);
    
    gradU = [gradUx, gradUy, gradUz] ./ (2 * Af);  % nF×3
    
    % Normalize and negate: X = -gradU / |gradU|
    gn = sqrt(sum(gradU.^2, 2));
    gn = max(gn, 1e-12);  % Avoid division by zero
    Xf = -gradU ./ gn;    % nF×3
    
    % Step III: Compute divergence at vertices
    % Only interior halfedges contribute
    mask = ~isB;
    h = find(mask);
    v = tail(h);          % Vertex receiving contribution
    f = faceH(h);         % Face for X
    
    % e1 = vector(h)
    e1 = E(h, :);
    
    % e2 = vector(h.prev.twin)
    hp = prevH(h);
    ht = twinH(hp);
    e2_tail = tail(ht);
    e2_head = head(ht);
    
    % Need V to compute e2 vector - reconstruct from tail/head
    % But we don't have V here... need to pass it or use precomputed E
    % Actually, E already contains all edge vectors, so we can use E(ht,:)
    e2 = E(ht, :);
    
    % Cotan weights
    cot1 = cotH(h);
    cot2 = cotH(hp);
    
    % X vectors at faces
    X = Xf(f, :);  % nInt×3
    
    % Divergence term
    term = cot1 .* sum(e1 .* X, 2) + cot2 .* sum(e2 .* X, 2);
    div = accumarray(v, 0.5 * term, [nV 1], @sum, 0);
    
    % Step IV: Solve Poisson equation: Δφ = -div
    phi = poissonSolver.value(-div);
    
    % Normalize: φ(seed) = 0
    phi = phi - phi(seed);
end
