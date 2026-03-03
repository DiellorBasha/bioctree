function connection = trivial(M, varargin)
%TRIVIAL Compute trivial (coexact) connection on a manifold
%
%   connection = bct.manifold.connection.trivial(M, singularityVec)
%   connection = bct.manifold.connection.trivial(M, 'singularities', indices)
%   connection = bct.manifold.connection.trivial(M, 'singularities', indices, 'weights', w)
%
% Purpose
%   Computes a trivial (coexact) connection on a triangulated surface by
%   solving for a scalar potential that balances Gaussian curvature with
%   prescribed singularities. The connection is given as a 1-form on edges
%   and halfedges.
%
%   Algorithm:
%   1. Compute vertex angle defect K (integrated Gaussian curvature)
%   2. Build RHS: rhs = -K + 2π*s (where s is singularity vector)
%   3. Solve Poisson equation: Δβ = rhs (pinned gauge)
%   4. Compute coexact component: δβ = ⋆₁(d₀β)
%   5. Compute harmonic component: γ (from period matrix, genus 0: γ = 0)
%   6. Combine: φ = δβ + γ (trivial connection)
%   7. Lift to halfedges using edge orientation signs
%
%   Note: Harmonic component (step 5) not yet implemented for genus > 0.
%         For spherical meshes, this is correct as γ = 0.
%
% Inputs
%   M - bct.Manifold object (required)
%
% Input Modes
%   Mode 1: Direct singularity vector
%     singularityVec - [nV×1] vector with singularity weights at vertices
%
%   Mode 2: Singularity indices (Name-Value)
%     'singularities' - Vertex indices where singularities are placed
%     'weights'       - Weights for each singularity (default: all 1)
%
% Outputs
%   connection - Structure with fields:
%     .attributes         - Connection metadata
%     .trivialConnection  - Halfedge 1-form (struct with .value and .attributes)
%     .connectionEdge     - Edge 1-form (struct with .value and .attributes)
%     .scalarPotential    - Scalar potential (struct with .value and .attributes)
%     .singularityVector  - Singularity vector used (struct with .value and .attributes)
%
% Theory
%   For a closed surface, the Gauss-Bonnet theorem states:
%     ∫K dA = 2π·χ
%   where χ is the Euler characteristic (χ=2 for sphere).
%
%   A trivial connection ensures that the total singularity index
%   matches the topology: Σsᵢ = χ
%
%   The connection is computed as φ = δβ + γ where:
%   - δβ is the coexact component (from Poisson solve)
%   - γ is the harmonic component (from homology generators)
%
%   For genus 0 surfaces (spheres), γ = 0.
%   For genus > 0 surfaces, harmonic component is required but not yet implemented.
%
% Examples
%   % Sphere with two singularities (north/south poles)
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   conn = bct.manifold.connection.trivial(M, ...
%       'singularities', [6653, 978], 'weights', [1, 1]);
%   
%   % Access results
%   connectionEdge = conn.connectionEdge.value;        % [nE×1] edge 1-form
%   trivialConn = conn.trivialConnection.value;       % [nH×1] halfedge 1-form
%   potential = conn.scalarPotential.value;           % [nV×1] scalar potential
%   
%   % Direct singularity vector
%   s = zeros(size(M.Vertices, 1), 1);
%   s([100, 500]) = [1, 1];
%   conn = bct.manifold.connection.trivial(M, s);
%
% References
%   Trivial connections for vector field design on surfaces.
%   Based on geometry-processing-js TrivialConnections implementation:
%   https://github.com/GeometryCollective/geometry-processing-js
%
%   See also: "Trivial Connections on Discrete Surfaces" (2010)
%   Keenan Crane, Mathieu Desbrun, Peter Schröder
%
% See also: bct.manifold.solve.poisson, bct.manifold.geometry.vertex.angleDefect

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.connection.trivial';
addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
addOptional(p, 'singularityVec', [], @isnumeric);
addParameter(p, 'singularities', [], @isnumeric);
addParameter(p, 'weights', [], @isnumeric);

% Check if second argument is singularity vector or name-value pairs
if nargin >= 2 && isnumeric(varargin{1})
    % Mode 1: trivial(M, singularityVec)
    parse(p, M, varargin{:});
    singularityVec = p.Results.singularityVec;
    singularityIndices = [];
    singularityWeights = [];
else
    % Mode 2: trivial(M, 'singularities', indices, ...)
    parse(p, M, varargin{:});
    singularityVec = [];
    singularityIndices = p.Results.singularities;
    singularityWeights = p.Results.weights;
end

% Get manifold data
nV = size(M.Vertices, 1);
nE_topo = size(M.Edges, 1);
nF = size(M.Faces, 1);

% Compute Euler characteristic and genus
chi = nV - nE_topo + nF;
genus = (2 - chi) / 2;  % For orientable closed surface

% Warn if genus > 0 (harmonic component not implemented)
if genus > 1e-6  % Allow small numerical error
    warning('bct:manifold:connection:trivial:GenusNotSupported', ...
        'Genus g = %.1f detected. Harmonic component not yet implemented. Connection may be incorrect.', genus);
end

% Build or validate singularity vector
if isempty(singularityVec)
    % Build from indices and weights
    % Default weights to 1
    if isempty(singularityWeights) && ~isempty(singularityIndices)
        singularityWeights = ones(size(singularityIndices));
    end
    
    % Validate
    if numel(singularityIndices) ~= numel(singularityWeights)
        error('bct:manifold:connection:trivial:SizeMismatch', ...
            'singularities and weights must have same length');
    end
    
    % Build vector
    singularityVec = zeros(nV, 1);
    for i = 1:numel(singularityIndices)
        idx = singularityIndices(i);
        if idx < 1 || idx > nV
            error('bct:manifold:connection:trivial:InvalidIndex', ...
                'Singularity index %d out of range [1, %d]', idx, nV);
        end
        singularityVec(idx) = singularityVec(idx) + singularityWeights(i);
    end
else
    % Validate singularity vector
    if numel(singularityVec) ~= nV
        error('bct:manifold:connection:trivial:InvalidVector', ...
            'singularityVec must be [nV×1] = [%d×1]', nV);
    end
    singularityVec = singularityVec(:);  % Ensure column vector
    
    % Extract indices and weights from vector
    singularityIndices = find(singularityVec ~= 0);
    singularityWeights = singularityVec(singularityIndices);
end

% Get cached manifold properties
topo = M.topology;
geom = M.geometry;
ops = M.operators;
solvers = M.solvers;

% Extract operators
d0 = ops.d0.value;          % [nE×nV] exterior derivative
star1 = ops.hd1.value;      % [nE×nE] Hodge star on 1-forms

nE = size(d0, 1);

% Extract topology
tail = topo.tailVertex.value;   % [nH×1] halfedge tail vertices
head = topo.headVertex.value;   % [nH×1] halfedge head vertices
edgeH = topo.edge.value;        % [nH×1] halfedge to edge mapping
nH = numel(tail);

% Step 1: Get vertex angle defect K (Gaussian curvature)
K = geom.vertex.angleDefect.value;  % [nV×1]

% Step 2: Build RHS for coexact solve
% JS formulation: rhs = -K + 2π*s
rhs = -K + 2*pi*singularityVec;  % [nV×1]

% Step 3: Solve Poisson equation Δβ = rhs (pinned gauge)
scalarPotential = solvers.poisson.value(rhs);  % [nV×1]

% Step 4: Compute coexact component δβ = ⋆₁(d₀β)
deltaBeta = star1 * (d0 * scalarPotential);  % [nE×1]

% Step 5: Compute harmonic component γ
% For genus 0: γ = 0 (no harmonic component)
% For genus > 0: γ requires period matrix (not implemented, warning issued above)
gamma = zeros(nE, 1);  % [nE×1]

% Step 6: Combine coexact and harmonic components
% φ = δβ + γ (trivial connection formula)
connectionEdge = deltaBeta + gamma;  % [nE×1]

% Step 7: Lift to halfedges using edge orientation signs
% Sign is +1 if halfedge points same direction as edge, -1 otherwise
% Determined by: sgn = sign(d0(edge, head))
sgn = full(d0(sub2ind(size(d0), edgeH, head)));  % [nH×1]
trivialConnection = sgn .* connectionEdge(edgeH);  % [nH×1]

% Apply sign correction to match geometry-processing-js convention
% The reference implementation uses the negative of our connection
trivialConnection = -trivialConnection;  % [nH×1]
connectionEdge = -connectionEdge;  % [nE×1] (keep consistent)

% Build output structure
connection = struct();

% Top-level attributes
connection.attributes = struct();
connection.attributes.schema = 'bct.manifold.connection.trivial@1.0.0';
connection.attributes.type = 'trivial';
connection.attributes.method = 'coexact+harmonic';
connection.attributes.nSingularities = numel(singularityIndices);
connection.attributes.totalSingularityIndex = sum(singularityWeights);
connection.attributes.totalCurvature = sum(K);
connection.attributes.eulerCharacteristic = chi;
connection.attributes.genus = genus;
connection.attributes.formula = 'Δβ = -K + 2π*s, φ = δβ + γ (γ=0 for genus 0)';
connection.attributes.reference = 'geometry-processing-js TrivialConnections';
connection.attributes.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

% Dataset 1: singularityVector
connection.singularityVector.value = singularityVec;
connection.singularityVector.attributes = struct(...
    'name', 'singularityVector', ...
    'description', 'Singularity weight at each vertex', ...
    'shape', [nV, 1], ...
    'dtype', 'double', ...
    'units', '1', ...
    'support', 'vertex', ...
    'singularityIndices', singularityIndices(:)', ...
    'singularityWeights', singularityWeights(:)');

% Dataset 2: scalarPotential (β)
connection.scalarPotential.value = scalarPotential;
connection.scalarPotential.attributes = struct(...
    'name', 'scalarPotential', ...
    'description', 'Scalar potential from Poisson solve', ...
    'shape', [nV, 1], ...
    'dtype', class(scalarPotential), ...
    'units', 'rad', ...
    'support', 'vertex', ...
    'equation', 'Δβ = -K + 2π*s', ...
    'computedBy', 'bct.manifold.solve.poisson');

% Dataset 3: connectionEdge (edge 1-form)
connection.connectionEdge.value = connectionEdge;
connection.connectionEdge.attributes = struct(...
    'name', 'connectionEdge', ...
    'description', 'Connection 1-form on edges', ...
    'shape', [nE, 1], ...
    'dtype', class(connectionEdge), ...
    'units', 'rad', ...
    'support', 'edge', ...
    'formula', 'φ_edge = ⋆₁(d₀β)', ...
    'computedBy', 'bct.manifold.connection.trivial');

% Dataset 4: trivialConnection (halfedge 1-form)
connection.trivialConnection.value = trivialConnection;
connection.trivialConnection.attributes = struct(...
    'name', 'trivialConnection', ...
    'description', 'Trivial connection 1-form on halfedges (signed lift from edges)', ...
    'shape', [nH, 1], ...
    'dtype', class(trivialConnection), ...
    'units', 'rad', ...
    'support', 'halfedge', ...
    'formula', 'φ_h = sgn(h) · φ_edge(e(h))', ...
    'computedBy', 'bct.manifold.connection.trivial');

end
