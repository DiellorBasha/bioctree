function solvers = solve()
%BCT.MANIFOLD.SOLVE  Access solvers for differential equations on manifolds
%
% Syntax:
%   solvers = bct.manifold.solve()
%
% Outputs:
%   solvers - Structure containing solver constructors:
%     .poisson      - Function handle to bct.manifold.solve.poisson
%     .heat         - Function handle to bct.manifold.solve.heat
%     .heatDistance - Function handle to bct.manifold.solve.heatDistance
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
%   % Get solver structure
%   solvers = bct.manifold.solve();
%   
%   % Poisson solver
%   poisson = solvers.poisson(M);
%   phi = poisson.value(rhs);
%   
%   % Heat solver
%   heat = solvers.heat(M);
%   u = heat.value(100);  % Heat diffusion from vertex 100
%   
%   % Geodesic distance solver
%   distSolver = solvers.heatDistance(M);
%   phi = distSolver.value(100);  % Distance from vertex 100
%   
%   % Direct call (bypass aggregator)
%   solver = bct.manifold.solve.poisson(M);
%   heat = bct.manifold.solve.heat(M);
%   dist = bct.manifold.solve.heatDistance(M);
%
% See also: bct.manifold.solve.poisson, bct.manifold.solve.heat,
%           bct.manifold.solve.heatDistance

% Build solver structure
solvers.poisson = @bct.manifold.solve.poisson;
solvers.heat = @bct.manifold.solve.heat;
solvers.heatDistance = @bct.manifold.solve.heatDistance;

end
