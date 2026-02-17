function solvers = solve(varargin)
%BCT.MANIFOLD.SOLVE  Build or access solvers for differential equations on manifolds
%
% Syntax:
%   solvers = bct.manifold.solve()           % Get function handles only
%   solvers = bct.manifold.solve(M)          % Build all solvers for Manifold M
%   solvers = bct.manifold.solve(M, Name, Value)
%
% Inputs:
%   M - bct.Manifold object (optional)
%
% Name-Value Arguments (when M is provided):
%   't_heat'         - Heat time for heat/heatDistance solvers (default: auto)
%   'pinnedVertex'   - Vertex to pin in Poisson solver (default: 1)
%   'alpha'          - Regularization for screened Poisson (default: 0.01)
%   'method'         - Poisson method: 'pinned' or 'screened' (default: 'pinned')
%
% Outputs:
%   solvers - Structure containing:
%     Without M (function handles only):
%       .poisson      - Function handle to bct.manifold.solve.poisson
%       .heat         - Function handle to bct.manifold.solve.heat
%       .heatDistance - Function handle to bct.manifold.solve.heatDistance
%     
%     With M (actual solver instances):
%       .attributes   - Group-level metadata
%       .poisson      - Cached Poisson solver instance
%       .heat         - Cached heat solver instance
%       .heatDistance - Cached heat distance solver instance
%
% Description:
%   Aggregator function providing access to all differential equation
%   solvers available in the bct.manifold.solve package. Each solver
%   provides a reusable cached factorization for efficient repeated solves.
%
%   All solvers accept either:
%   - A bct.Manifold object (automatically extracts operators)
%   - Direct matrix inputs (stiffness, mass, etc.)
%
%   All solvers return a structure with:
%   - .attributes: Solver metadata (equation, gauge, method, computed_utc)
%   - .value: Function handle for solving (accepts RHS, returns solution)
%   - .valueAttributes: Solution metadata (solver reference, nRHS)
%
% Available Solvers:
%
%   POISSON - Solve Laplace/Poisson equations on manifolds
%   
%     solver = solvers.poisson(M)
%     solver = solvers.poisson(stiffness, mass)
%     solver = solvers.poisson(..., 'input', 'rhs')      % Direct RHS (default)
%     solver = solvers.poisson(..., 'input', 'density')  % Density input
%     
%     Input Types:
%       'rhs' (default) - User provides RHS directly: stiffness*phi = rhs
%       'density'       - User provides density rho: stiffness*phi = mass*rho
%     
%     Methods:
%       'pinned'   - Pin a vertex to remove nullspace (default)
%       'screened' - Add mass regularization (Tikhonov)
%     
%     Equations:
%       pinned + rhs:      Δφ = f  with φ(v₀) = 0
%       pinned + density:  Δφ = Mρ with φ(v₀) = 0
%       screened + rhs:    (Δ + αM)φ = f
%       screened + density: (Δ + αM)φ = Mρ
%
%   HEAT - Solve heat diffusion equation on manifolds
%   
%     solver = solvers.heat(M)
%     solver = solvers.heat(heatOp, massOp)
%     solver = solvers.heat(..., 'input', 'seed')      % Seed input (default)
%     solver = solvers.heat(..., 'input', 'rhs')       % Direct RHS
%     solver = solvers.heat(..., 'massVariant', 'lumped')
%     
%     Input Types:
%       'seed' (default) - User provides seed vertex index: heat*u = mass(:,seed)
%       'rhs'            - User provides RHS directly: heat*u = rhs
%     
%     Mass Variants:
%       'full' (default) - Exact mass column extraction
%       'lumped'         - Diagonal mass approximation (faster)
%     
%     Equation:
%       (M + t*K)u = rhs  where M=mass, K=stiffness, t=t_heat
%
%   HEATDISTANCE - Compute geodesic distances using heat method
%   
%     solver = solvers.heatDistance(M)
%     solver = solvers.heatDistance(M, 't_heat', value)
%     solver = solvers.heatDistance(M, 'pinnedVertex', value)
%     
%     Algorithm:
%       1. Solve heat equation from seed
%       2. Compute normalized gradient on faces
%       3. Compute divergence at vertices
%       4. Solve Poisson equation for distance
%     
%     Reference: Crane et al. 2017, Commun. ACM
%                https://doi.org/10.1145/3131280
%
% Future Solvers (planned):
%   - biharmonic: Δ²φ = f for smooth surfaces
%   - helmholtz:  (Δ + k²)φ = f for wave equations
%
% Examples:
%   % Get solver function handles only
%   solvers = bct.manifold.solve();
%   
%   % Build all solvers for a manifold
%   M = bct.Manifold(V, F);
%   solvers = bct.manifold.solve(M);
%   
%   % Use cached solvers
%   phi = solvers.poisson.value(rhs);
%   u = solvers.heat.value(100);
%   dist = solvers.heatDistance.value(100);
%   
%   % Build with custom parameters
%   solvers = bct.manifold.solve(M, 't_heat', 1.0, 'pinnedVertex', 100);
%   
%   % Direct call (bypass aggregator)
%   solver = bct.manifold.solve.poisson(M);
%   heat = bct.manifold.solve.heat(M);
%   dist = bct.manifold.solve.heatDistance(M);
%
% See also: bct.manifold.solve.poisson, bct.manifold.solve.heat,
%           bct.manifold.solve.heatDistance

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.solve';

% Check if first argument is Manifold
if nargin == 0 || ~isa(varargin{1}, 'bct.Manifold')
    % No Manifold provided - return function handles only
    solvers = struct();
    solvers.poisson = @bct.manifold.solve.poisson;
    solvers.heat = @bct.manifold.solve.heat;
    solvers.heatDistance = @bct.manifold.solve.heatDistance;
    return;
end

% Manifold provided - build actual solvers
addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
addParameter(p, 't_heat', [], @isnumeric);
addParameter(p, 'pinnedVertex', 1, @isnumeric);
addParameter(p, 'alpha', 0.01, @isnumeric);
addParameter(p, 'method', 'pinned', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

M = p.Results.M;
t_heat = p.Results.t_heat;
pinnedVertex = p.Results.pinnedVertex;
alpha = p.Results.alpha;
method = string(p.Results.method);

% Initialize output structure
solvers = struct();

% Group-level attributes
solvers.attributes = struct();
solvers.attributes.schema = 'bct.manifold.solve@1.0.0';
solvers.attributes.package = 'bct.manifold.solve';
solvers.attributes.t_heat = t_heat;
solvers.attributes.pinnedVertex = pinnedVertex;
solvers.attributes.method = char(method);
solvers.attributes.alpha = alpha;
solvers.attributes.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

% Build Poisson solver
solvers.poisson = bct.manifold.solve.poisson(M, ...
    'method', method, ...
    'pinnedVertex', pinnedVertex, ...
    'alpha', alpha);

% Build heat solver
if isempty(t_heat)
    solvers.heat = bct.manifold.solve.heat(M);
else
    % Get heat operator with custom t_heat
    heatOp = bct.manifold.operator.heat(M, 't_heat', t_heat);
    ops = M.operators();
    solvers.heat = bct.manifold.solve.heat(heatOp.value, ops.mass.value);
end

% Build heat distance solver
if isempty(t_heat)
    solvers.heatDistance = bct.manifold.solve.heatDistance(M, ...
        'pinnedVertex', pinnedVertex);
else
    solvers.heatDistance = bct.manifold.solve.heatDistance(M, ...
        't_heat', t_heat, ...
        'pinnedVertex', pinnedVertex);
end

end
