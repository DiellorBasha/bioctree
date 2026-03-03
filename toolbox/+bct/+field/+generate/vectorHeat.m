function result = vectorHeat(M, varargin)
%VECTORHEAT Generate smooth tangent vector field via vector heat method
%
% Syntax:
%   result = bct.field.generate.vectorHeat(M)
%   result = bct.field.generate.vectorHeat(M, 'SeedFace', 1, 'SeedDirection', 0)
%   result = bct.field.generate.vectorHeat(M, 'SeedPatch', struct(...))
%   result = bct.field.generate.vectorHeat(M, 'Connection', conn)
%
% Inputs:
%   M - bct.Manifold object
%
% Name-Value Arguments:
%
%   Seed specification (mutually exclusive, defines initial condition z0):
%     SeedFace          - Face index for delta seed (default: 1)
%     SeedDirection     - Direction angle in radians for SeedFace (default: 0)
%     SeedPatch         - Struct with fields:
%                         .center (vertex index)
%                         .radius (percentile 0-100)
%                         .direction (angle in radians)
%     SeedField         - Custom [nF×1] complex seed field z0
%                         Seed is independent of connection topology!
%
%   Connection (optional, defines parallel transport):
%     Connection        - Connection structure from M.connection()
%                         If not provided, uses trivial connection with no singularities
%                         Connection singularities control topology (winding/circulation),
%                         NOT seed placement!
%
%   Diffusion parameters:
%     DiffusionTime     - Diffusion time scale t (default: auto)
%                         Auto uses t = 16 * meanEdgeLength^2
%     TimeMultiplier    - Multiplier for auto time (default: 16)
%
%   Output control:
%     Normalize         - true (default) | false - Normalize to unit vectors
%     MaskPercentile    - Keep top N% by magnitude (default: 100, no masking)
%
% Outputs:
%   result - Structure with fields:
%     .vectors          - [nF×3] 3D tangent vectors (unit if normalized)
%     .magnitude        - [nF×1] Face magnitude before normalization
%     .vertexMagnitude  - [nV×1] Vertex magnitude (area-weighted from faces)
%     .mask             - [nF×1] logical mask of kept vectors
%     .complexField     - [nF×1] Complex solution z in tangent frames
%     .connection       - Connection structure used
%     .diffusionTime    - Diffusion time parameter used
%     .solver           - Structure with solver details
%       .operator       - H = Mf + t*Lconn
%       .factorization  - Cholesky decomposition object
%       .rhs            - Right-hand side Mf*z0
%
% Description:
%   Computes smooth tangent vector field by solving the vector heat equation:
%
%     (Mf + t*Lconn) z = Mf * z0
%
%   Where:
%   - z  : complex per-face field encoding tangent vectors
%   - Mf : face mass matrix (diagonal, face areas)
%   - Lconn : connection Laplacian (Hermitian PSD)
%   - t  : diffusion time (controls smoothness scale)
%   - z0 : seed field (localized initial condition)
%
%   The method:
%   1. Specifies seed field z0 (WHERE and WHAT DIRECTION field starts)
%   2. Specifies connection (HOW vectors transport - topology/rotation)
%   3. Assembles connection Laplacian with DEC edge weights
%   4. Solves heat equation: diffuses seed using connection
%   5. Converts complex solution to 3D tangent vectors
%   6. Optionally normalizes and masks by magnitude
%
%   Key Concept:
%   - SEED (z0) = Initial condition - defines where field originates
%   - CONNECTION = Parallel transport - defines topology (singularities/winding)
%   - These are INDEPENDENT: seed placement ≠ singularity placement!
%
% Examples:
%   % Basic: Single face seed, trivial connection (no singularities)
%   result = bct.field.generate.vectorHeat(M, ...
%       'SeedFace', 1, ...
%       'SeedDirection', 0);
%   
%   % Patch seed around vertex
%   patch = struct('center', 100, 'radius', 5, 'direction', pi/4);
%   result = bct.field.generate.vectorHeat(M, 'SeedPatch', patch);
%   
%   % Seed at face 1, connection with singularities at different locations
%   % (seed and singularities are INDEPENDENT!)
%   conn = M.connection('singularities', [1000, 2000], 'weights', [1, -1]);
%   result = bct.field.generate.vectorHeat(M, ...
%       'SeedFace', 1, ...           % Seed at face 1
%       'Connection', conn);          % Topology from singularities at 1000, 2000
%   
%   % More diffusion, show top 20% by magnitude
%   result = bct.field.generate.vectorHeat(M, ...
%       'SeedFace', 500, ...
%       'TimeMultiplier', 64, ...    % More smoothing
%       'MaskPercentile', 20);        % Keep top 20%
%
% See also: bct.field.direction, bct.manifold.connection,
%           bct.manifold.operator.connectionLaplacian, bct.field.toTangent

% ----------------------------
% Parse inputs
% ----------------------------
p = inputParser;
p.FunctionName = 'bct.field.generate.vectorHeat';
p.KeepUnmatched = false;

p.addRequired('M', @(x) isa(x, 'bct.Manifold'));

% Seed specification (defines initial condition z0)
p.addParameter('SeedFace', 1, @(x) isnumeric(x) && isscalar(x));
p.addParameter('SeedDirection', 0, @(x) isnumeric(x) && isscalar(x));
p.addParameter('SeedPatch', [], @(x) isempty(x) || isstruct(x));
p.addParameter('SeedField', [], @(x) isempty(x) || (isnumeric(x) && ~isreal(x)));

% Connection (defines parallel transport, independent of seed)
p.addParameter('Connection', [], @(x) isempty(x) || isstruct(x));

% Diffusion parameters
p.addParameter('DiffusionTime', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
p.addParameter('TimeMultiplier', 16, @(x) isnumeric(x) && isscalar(x) && x > 0);

% Output control
p.addParameter('Normalize', true, @islogical);
p.addParameter('MaskPercentile', 100, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 100);

p.parse(M, varargin{:});

% ----------------------------
% Get or construct connection
% ----------------------------
if ~isempty(p.Results.Connection)
    % Use provided connection
    conn = p.Results.Connection;
else
    % Default: trivial connection with NO singularities
    % This gives flat parallel transport (no topological constraints)
    conn = M.connection();
end

% Get combined transport angles
delta = double(conn.combinedTransport.value(:));

% ----------------------------
% Assemble connection Laplacian
% ----------------------------
[~, Lconn] = bct.manifold.operator.connectionLaplacian(M, delta, 'WeightType', 'dec');

% ----------------------------
% Get face mass matrix (diagonal matrix of face areas)
% ----------------------------
geom = M.geometry();
Af = geom.face.areas.value;
nF = size(M.Faces, 1);
Mf = spdiags(Af(:), 0, nF, nF);

% ----------------------------
% Determine diffusion time
% ----------------------------
if ~isempty(p.Results.DiffusionTime)
    t = p.Results.DiffusionTime;
else
    % Auto: t = timeMultiplier * meanEdgeLength^2
    ell = geom.edge.lengths.value;
    meanEll = mean(ell);
    t = p.Results.TimeMultiplier * meanEll^2;
end

% ----------------------------
% Construct seed field z0
% ----------------------------
nF = size(M.Faces, 1);

if ~isempty(p.Results.SeedField)
    % User-provided seed
    z0 = double(p.Results.SeedField(:));
    if numel(z0) ~= nF
        error('bct:field:generate:vectorHeat:InvalidSeedSize', ...
            'SeedField must be [nF×1] = [%d×1], got [%d×1]', nF, numel(z0));
    end
    
elseif ~isempty(p.Results.SeedPatch)
    % Patch seed around vertex
    patch = p.Results.SeedPatch;
    
    if ~isfield(patch, 'center') || ~isfield(patch, 'radius')
        error('bct:field:generate:vectorHeat:InvalidPatch', ...
            'SeedPatch must have fields: center, radius');
    end
    
    geom = M.geometry();
    C = double(geom.face.centroids.value);
    p_vertex = double(M.Vertices(patch.center, :));
    d = vecnorm(C - p_vertex, 2, 2);
    r = prctile(d, patch.radius);
    
    % Get patch direction (default: radial outward from seed vertex)
    if isfield(patch, 'direction') && ~isempty(patch.direction)
        % User provided a global 3D direction vector
        if isnumeric(patch.direction) && numel(patch.direction) == 3
            globalDir = patch.direction(:)' / norm(patch.direction);  % [1×3] unit vector
        elseif isscalar(patch.direction)
            % Legacy: scalar angle interpreted as rotation in first face's frame
            % This is problematic - use 3D vector instead!
            warning('bct:field:generate:vectorHeat:ScalarDirection', ...
                'Scalar direction is ambiguous. Interpreting as radial with rotation angle.');
            % Use radial direction rotated by this angle
            patchMaskIdx = find(d < r);
            if isempty(patchMaskIdx)
                error('bct:field:generate:vectorHeat:EmptyPatch', ...
                    'Patch is empty - no faces within radius');
            end
            % Use centroid of patch faces as reference
            patchCenter = mean(C(patchMaskIdx, :), 1);
            globalDir = patchCenter - p_vertex;
            globalDir = globalDir / norm(globalDir);
            % TODO: apply rotation angle
        else
            error('bct:field:generate:vectorHeat:InvalidDirection', ...
                'patch.direction must be a 3D vector [x,y,z] or scalar angle');
        end
    else
        % Default: radial outward from seed vertex
        % Compute average radial direction from patchfaces
        patchMaskIdx = find(d < r);
        if isempty(patchMaskIdx)
            error('bct:field:generate:vectorHeat:EmptyPatch', ...
                'Patch is empty - no faces within radius');
        end
        patchCenter = mean(C(patchMaskIdx, :), 1);
        globalDir = patchCenter - p_vertex;  % [1×3]
        globalDir = globalDir / norm(globalDir);
    end
    
    % Get tangent frames for all faces
    t1 = double(geom.face.tangent1.value);  % [nF×3]
    t2 = double(geom.face.tangent2.value);  % [nF×3]
    
    % For each face in patch, project global direction onto tangent plane
    z0 = complex(zeros(nF, 1));
    for f = find(d < r)'
        % Project global direction onto this face's tangent plane
        % Remove component normal to the face
        projDir = globalDir - dot(globalDir, geom.face.normals.value(f,:)) * geom.face.normals.value(f,:);
        projDir = projDir / (norm(projDir) + 1e-12);
        
        % Express in face's tangent frame: z = (dir·t1) + i(dir·t2)
        Re_z = dot(projDir, t1(f,:));
        Im_z = dot(projDir, t2(f,:));
        z0(f) = Re_z + 1i * Im_z;
    end
    
    % Normalize seed field
    z0Norm = norm(z0);
    if z0Norm > 1e-12
        z0 = z0 / z0Norm;
    else
        warning('bct:field:generate:vectorHeat:ZeroSeed', ...
            'Seed field has zero norm after projection. Using delta seed.');
        z0(patchMaskIdx(1)) = 1;
    end
    
else
    % Delta seed at single face
    seedFace = p.Results.SeedFace;
    seedDirection = p.Results.SeedDirection;
    
    z0 = complex(zeros(nF, 1));
    z0(seedFace) = exp(1i * seedDirection);
end

% ----------------------------
% Solve vector heat equation
% ----------------------------
% (Mf + t*Lconn) z = Mf * z0

H = Mf + t * Lconn;

% Numerically enforce Hermitian
H = (H + H') / 2;

% Factor with Cholesky
Hchol = decomposition(H, 'chol');

% Solve
rhs = Mf * z0;
z = Hchol \ rhs;

% ----------------------------
% Convert to 3D tangent vectors
% ----------------------------
convertResult = bct.field.toTangent(M, z, ...
    'Normalize', p.Results.Normalize, ...
    'MaskPercentile', p.Results.MaskPercentile);

% ----------------------------
% Map face magnitude to vertices
% ----------------------------
% Use area-weighted averaging: vertex_mag(v) = sum(A_f * mag_f) / sum(A_f)
nF = size(M.Faces, 1);
nV = size(M.Vertices, 1);
F = double(M.Faces);
mag = convertResult.magnitude;

% Build sparse face-to-vertex mapping matrix [nV × nF]
% Each face contributes to its 3 vertices weighted by face area
I = [F(:,1); F(:,2); F(:,3)];
J = [1:nF, 1:nF, 1:nF]';
W = repmat(Af(:), 3, 1);  % Area weights
F2V = sparse(I, J, W, nV, nF);

% Normalize rows (so each vertex gets average of adjacent face areas)
rowSums = sum(F2V, 2);
rowSums(rowSums == 0) = 1;  % Avoid division by zero
F2V = spdiags(1 ./ rowSums, 0, nV, nV) * F2V;

% Map magnitude from faces to vertices
vertexMagnitude = F2V * mag;

% ----------------------------
% Assemble output structure
% ----------------------------
result = struct();
result.vectors = convertResult.vectors;
result.magnitude = convertResult.magnitude;           % [nF×1] face magnitudes
result.vertexMagnitude = vertexMagnitude;             % [nV×1] vertex magnitudes
result.mask = convertResult.mask;
result.complexField = z;
result.connection = conn;
result.diffusionTime = t;

result.solver = struct();
result.solver.operator = H;
result.solver.factorization = Hchol;
result.solver.rhs = rhs;
result.solver.residual = norm(H * z - rhs) / max(norm(rhs), 1e-12);

end
