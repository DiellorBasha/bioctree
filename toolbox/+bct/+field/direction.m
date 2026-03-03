function out = direction(M, varargin)
%DIRECTION Generate direction field from singularities on manifold
%
% Syntax:
%   out = bct.field.direction(M, 'singularities', indices)
%   out = bct.field.direction(M, 'singularities', indices, 'weights', w)
%   out = bct.field.direction(M, conn)
%
% Inputs:
%   M - bct.Manifold object (required)
%
% Input Modes:
%   Mode 1: Connection structure (direct)
%     conn - Connection structure from M.connection()
%
%   Mode 2: Singularity specification (Name-Value)
%     'singularities' - Vertex indices where singularities are placed
%     'weights'       - Weights for each singularity (default: all 1)
%
% Optional Name-Value Arguments:
%   'seedFace'  - Seed face index for BFS propagation (default: 1)
%   'seedValue' - Initial direction angle at seed face in radians (default: 0)
%   'wrap'      - Wrap angles to (-π, π] after propagation (default: false)
%
% Outputs:
%   out - Structure with fields:
%     .directionVectors  - [nF×3] Unit direction vectors in 3D (tangent to surface)
%     .orthogonalVectors - [nF×3] Orthogonal vectors (rotated π/2)
%     .directionAngles   - [nF×1] Direction angles in face tangent frames (radians)
%     .connection        - Connection structure used (from M.connection)
%     .propagation       - BFS propagation result from bct.manifold.query.dual
%
% Description:
%   Generates a direction field on the surface from prescribed singularities.
%   The workflow:
%     1. Compute trivial connection from singularities (uses cached M.connection)
%     2. Extract combined transport (geometric - connection)
%     3. Propagate direction angles via BFS on dual graph
%     4. Convert angles to 3D direction vectors using face tangent frames
%     5. Compute orthogonal vectors (rotated by π/2)
%
%   Direction field properties:
%   - Tangent to surface at each face centroid
%   - Unit-length 3D vectors
%   - Smooth propagation from seed face
%   - Singularities (sources/sinks) at prescribed vertices
%
% Theory:
%   A direction field α on a surface is defined by an angle in each face's
%   tangent frame. Transport across edges adds the combined transport angle:
%   
%     α_j = α_i + combinedTransport_ij
%   
%   where combinedTransport = geometricTransport - connectionTransport.
%   
%   The trivial connection ensures that the field has prescribed singularities
%   with total index matching the Euler characteristic (χ=2 for sphere).
%
%   Direction vectors are reconstructed as:
%     d = cos(α) * t1 + sin(α) * t2
%   where (t1, t2) is the face tangent frame.
%
% Examples:
%   % Sphere with two singularities (north/south poles)
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   result = bct.field.direction(M, ...
%       'singularities', [6653, 978], 'weights', [1, 1]);
%   
%   dirVec = result.directionVectors;    % [nF×3] direction field
%   orthVec = result.orthogonalVectors;  % [nF×3] orthogonal field
%   
%   % Visualize
%   viewer = bct.ui.show(M);
%   geom = M.geometry();
%   viewer.setVector(dirVec, ...
%       'Positions', geom.face.centroids.value, ...
%       'Normals', geom.face.normals.value);
%   
%   % Use existing connection structure
%   conn = M.connection('singularities', [100, 500], 'weights', [1, 1]);
%   result = bct.field.direction(M, conn);
%   
%   % Custom seed face and initial angle
%   result = bct.field.direction(M, ...
%       'singularities', [100, 500], ...
%       'seedFace', 10, ...
%       'seedValue', pi/4);
%
% See also: bct.manifold.connection, bct.manifold.query.dual,
%           bct.field.cross, bct.field.generate.faceGradient

% Validate M
if ~isa(M, 'bct.Manifold')
    error('bct:field:direction:InvalidInput', ...
        'First argument must be a bct.Manifold object');
end

% Parse inputs - check for connection structure first
if nargin >= 2 && isstruct(varargin{1})
    % Mode 1: direction(M, conn, ...)
    conn = varargin{1};
    remainingArgs = varargin(2:end);
else
    % Mode 2: direction(M, 'singularities', indices, ...)
    conn = [];
    remainingArgs = varargin;
end

% Parse propagation and connection parameters
p = inputParser;
p.FunctionName = 'bct.field.direction';
addParameter(p, 'singularities', [], @isnumeric);
addParameter(p, 'weights', [], @isnumeric);
addParameter(p, 'seedFace', 1, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'seedValue', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'wrap', false, @islogical);
parse(p, remainingArgs{:});

seedFace = p.Results.seedFace;
seedValue = p.Results.seedValue;
doWrap = p.Results.wrap;

% Get or compute connection
if isempty(conn)
    % Compute connection from singularities (uses cached M.connection)
    singularities = p.Results.singularities;
    weights = p.Results.weights;
    
    if isempty(singularities)
        error('bct:field:direction:MissingSingularities', ...
            'Either provide connection structure or singularities parameter');
    end
    
    % Call M.connection (trivial is default type, so omit it)
    if ~isempty(weights)
        conn = M.connection('singularities', singularities, 'weights', weights);
    else
        conn = M.connection('singularities', singularities);
    end
else
    % Validate connection structure
    if ~isfield(conn, 'combinedTransport')
        error('bct:field:direction:InvalidConnection', ...
            'Connection structure must contain combinedTransport field');
    end
end

% Extract combined transport (geometric - connection)
combinedTransport = conn.combinedTransport.value;  % [nH×1]

% Propagate direction field via BFS on dual graph
propagation = bct.manifold.query.dual(M, combinedTransport, ...
    'seedFace', seedFace, ...
    'seedValue', seedValue, ...
    'wrap', doWrap);

alpha_face = propagation.alpha_face;  % [nF×1] direction angles

% Get face tangent frames
geom = M.geometry();
tangent1 = geom.face.tangent1.value;  % [nF×3]
tangent2 = geom.face.tangent2.value;  % [nF×3]

% Convert angles to 3D direction vectors
directionVectors = cos(alpha_face) .* tangent1 + sin(alpha_face) .* tangent2;

% Compute orthogonal vectors (rotate by π/2)
orthogonalVectors = -sin(alpha_face) .* tangent1 + cos(alpha_face) .* tangent2;

% Verify unit length
norms = vecnorm(directionVectors, 2, 2);
meanNorm = mean(norms);
stdNorm = std(norms);

if abs(meanNorm - 1.0) > 1e-6
    warning('bct:field:direction:NonUnitNorm', ...
        'Direction vectors not unit length: mean norm = %.6f', meanNorm);
end

% Build output structure
out = struct();
out.directionVectors = directionVectors;
out.orthogonalVectors = orthogonalVectors;
out.directionAngles = alpha_face;
out.connection = conn;
out.propagation = propagation;

% Add metadata
out.attributes = struct();
out.attributes.schema = 'bct.field.direction@1.0.0';
out.attributes.numFaces = M.numFaces();
out.attributes.seedFace = seedFace;
out.attributes.seedValue = seedValue;
out.attributes.wrapped = doWrap;
out.attributes.meanNorm = meanNorm;
out.attributes.stdNorm = stdNorm;
out.attributes.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

end
