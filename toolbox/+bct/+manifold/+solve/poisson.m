function solver = poisson(varargin)
%BCT.MANIFOLD.SOLVE.POISSON  Build a reusable Poisson solver on a manifold
%
%   solver = bct.manifold.solve.poisson(M)
%   solver = bct.manifold.solve.poisson(stiffness, mass)
%   solver = bct.manifold.solve.poisson(..., 'input', 'rhs')
%   solver = bct.manifold.solve.poisson(..., 'input', 'density')
%   solver = bct.manifold.solve.poisson(..., 'method', 'pinned', 'pinnedVertex', 1)
%   solver = bct.manifold.solve.poisson(..., 'method', 'screened', 'alpha', 0.01)
%
% Purpose
%   Creates a cached Poisson solver for efficient repeated solves on the
%   same manifold. Solver is based on Cholesky factorization and can be
%   reused for multiple right-hand sides.
%
% Inputs
%   M          - bct.Manifold object
%   OR
%   stiffness  - [N×N] stiffness matrix (sparse double)
%   mass       - [N×N] mass matrix (sparse double)
%
% Name-Value Arguments
%   input         - Input type:
%                   'rhs' (default)  - User provides RHS directly (stiffness*phi = rhs)
%                   'density'        - User provides density rho (stiffness*phi = mass*rho)
%   method        - Solver method:
%                   'pinned' (default) - Pin one vertex to zero
%                   'screened'         - Add mass matrix term (stiffness + alpha*mass)
%   pinnedVertex  - Vertex index to pin (default: 1), only for 'pinned' method
%   alpha         - Screening parameter (required for 'screened' method)
%
% Output
%   solver - Struct with attributes and value fields:
%     .attributes       - Solver metadata struct:
%       .type             - "poisson"
%       .input            - "rhs" | "density"
%       .method           - "pinned" | "screened"
%       .equation         - Mathematical equation being solved
%       .gauge            - Gauge condition applied
%       .nVertices        - Number of vertices
%       .factor           - Factorization method
%       .pinnedVertex     - (pinned) Pinned vertex index
%       .keep             - (pinned) Logical mask of free vertices
%       .reducedSize      - (pinned) Size of reduced system
%       .alpha            - (screened) Screening parameter
%       .regularization   - (screened) Regularization type
%       .computed_utc     - Timestamp of solver creation
%     .value            - Function handle: phi = solver.value(rhs)
%     .valueAttributes  - Metadata about the solver function:
%       .name             - Function name
%       .description      - What the function does
%       .dtype            - Data type (function_handle)
%       .signature        - Function signature
%       .input_shape      - Expected input shape
%       .output_shape     - Output shape
%       .input_support    - Input support type
%       .output_support   - Output support type
%       .complexity       - Computational complexity
%       .computedBy       - Source function
%
% Usage
%   % Build solver once from Manifold
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   solver = bct.manifold.solve.poisson(M);
%
%   % Build solver from matrices directly
%   stiffness = M.stiffness.value;
%   mass = M.mass.value;
%   solver = bct.manifold.solve.poisson(stiffness, mass);
%
%   % Solve multiple times with different right-hand sides
%   phi1 = solver.value(rhs1);
%   phi2 = solver.value(rhs2);
%
%   % Density input (solver applies mass matrix)
%   solver_density = bct.manifold.solve.poisson(M, 'input', 'density');
%   phi = solver_density.value(rho);  % Solves stiffness*phi = mass*rho
%
%   % Screened Poisson (regularized)
%   solver_screened = bct.manifold.solve.poisson(M, 'method', 'screened', 'alpha', 0.01);
%   phi_reg = solver_screened.value(rhs);
%
% Notes
%   - Input 'rhs': Direct solve (most general)
%   - Input 'density': Applies mass matrix first (rhs = mass*rho)
%   - Pinned method: Removes one vertex from system (makes it non-singular)
%   - Screened method: Adds regularization term, useful when stiffness is near-singular
%   - Solver caches Cholesky decomposition for O(N) repeated solves
%   - Both stiffness and mass matrices are symmetrized before use
%
% See also: bct.Manifold, bct.operators.apply, decomposition

    % Parse inputs: either (M) or (stiffness, mass)
    if nargin < 1
        error('bct:manifold:solve:poisson:NotEnoughInputs', ...
            'At least one input required: Manifold or stiffness matrix');
    end
    
    % Check if first argument is a Manifold
    if isa(varargin{1}, 'bct.Manifold')
        % Extract from Manifold
        M = varargin{1};
        stiffness = M.stiffness.value;
        mass = M.mass.value;
        nvArgs = varargin(2:end);
    elseif isnumeric(varargin{1})
        % Direct matrix input
        if nargin < 2 || ~isnumeric(varargin{2})
            error('bct:manifold:solve:poisson:MissingMass', ...
                'When providing stiffness matrix, mass matrix must also be provided');
        end
        stiffness = varargin{1};
        mass = varargin{2};
        nvArgs = varargin(3:end);
        
        % Validate matrix inputs
        if ~ismatrix(stiffness) || ~ismatrix(mass)
            error('bct:manifold:solve:poisson:InvalidMatrix', ...
                'stiffness and mass must be 2D matrices');
        end
        if size(stiffness,1) ~= size(stiffness,2) || size(mass,1) ~= size(mass,2)
            error('bct:manifold:solve:poisson:NonSquareMatrix', ...
                'stiffness and mass must be square matrices');
        end
        if ~isequal(size(stiffness), size(mass))
            error('bct:manifold:solve:poisson:SizeMismatch', ...
                'stiffness and mass must have the same size');
        end
    else
        error('bct:manifold:solve:poisson:InvalidInput', ...
            'First argument must be a bct.Manifold or a stiffness matrix');
    end
    
    % Parse optional parameters
    p = inputParser;
    p.addParameter('input', 'rhs', @(x) ismember(lower(x), {'rhs', 'density'}));
    p.addParameter('method', 'pinned', @(x) ismember(lower(x), {'pinned', 'screened'}));
    p.addParameter('pinnedVertex', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
    p.addParameter('alpha', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    p.parse(nvArgs{:});
    opt = p.Results;
    
    % Symmetrize (handle numerical asymmetry from FEM assembly)
    stiffness = (stiffness + stiffness') / 2;
    mass = (mass + mass') / 2;
    
    nV = size(stiffness, 1);
    
    % Initialize attributes struct
    attrs = struct();
    attrs.type = "poisson";
    attrs.input = string(lower(opt.input));
    attrs.nVertices = nV;
    attrs.factor = "chol(decomposition)";
    attrs.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    
    % Build solver based on method
    switch lower(opt.method)
        case 'pinned'
            % Pin one vertex to remove singularity
            pinnedVertex = opt.pinnedVertex;
            
            % Validate pinned vertex
            if pinnedVertex > nV || pinnedVertex < 1
                error('bct:manifold:solve:poisson:InvalidPinnedVertex', ...
                    'pinnedVertex must be in range [1, %d]', nV);
            end
            
            % Build reduced system (remove pinned vertex)
            keep = true(nV, 1);
            keep(pinnedVertex) = false;
            
            A = stiffness(keep, keep);
            decompA = decomposition(A, 'chol');
            
            % Create solver function (depends on input type)
            if strcmpi(opt.input, 'density')
                % Density input: apply mass matrix first
                M_keep = mass(keep, keep);
                solverFn = @(rho) solvePinnedDensity(decompA, rho, M_keep, keep, pinnedVertex);
            else
                % RHS input: direct solve
                solverFn = @(rhs) solvePinned(decompA, rhs, keep, pinnedVertex);
            end
            
            % Store method-specific metadata
            attrs.method = "pinned";
            if strcmpi(opt.input, 'density')
                attrs.equation = "stiffness * phi = mass * rho";
            else
                attrs.equation = "stiffness * phi = rhs";
            end
            attrs.gauge = sprintf("phi(%d) = 0", pinnedVertex);
            attrs.pinnedVertex = pinnedVertex;
            attrs.keep = keep;
            attrs.reducedSize = sum(keep);
            
        case 'screened'
            % Screened Poisson: K + alpha*M
            alpha = opt.alpha;
            
            % Validate alpha was provided
            if isempty(alpha)
                error('bct:manifold:solve:poisson:MissingAlpha', ...
                    'alpha parameter is required for screened method');
            end
            
            % Build regularized system
            A = stiffness + alpha * mass;
            decompA = decomposition(A, 'chol');
            
            % Create solver function (depends on input type)
            if strcmpi(opt.input, 'density')
                % Density input: apply mass matrix first
                solverFn = @(rho) decompA \ (mass * rho);
            else
                % RHS input: direct solve
                solverFn = @(rhs) decompA \ rhs;
            end
            
            % Store method-specific metadata
            attrs.method = "screened";
            if strcmpi(opt.input, 'density')
                attrs.equation = "(stiffness + alpha*mass) * phi = mass * rho";
            else
                attrs.equation = "(stiffness + alpha*mass) * phi = rhs";
            end
            attrs.gauge = "none (regularized)";
            attrs.alpha = alpha;
            attrs.regularization = "Tikhonov (mass-based)";
            
        otherwise
            error('bct:manifold:solve:poisson:UnknownMethod', ...
                'Unknown method: %s', opt.method);
    end
    
    % Return conventional bct structure
    solver.attributes = attrs;
    solver.value = solverFn;
    
    % Add metadata about the solver.value field (following bct.manifold.geometry pattern)
    if strcmpi(opt.input, 'density')
        inputDesc = 'density (rho)';
        equationDesc = 'stiffness*phi = mass*rho';
    else
        inputDesc = 'right-hand side (rhs)';
        equationDesc = 'stiffness*phi = rhs';
    end
    
    solver.valueAttributes = struct(...
        'name', 'poissonSolver', ...
        'description', sprintf('Poisson equation solver: %s', equationDesc), ...
        'dtype', 'function_handle', ...
        'signature', 'phi = solver.value(input)', ...
        'input_description', inputDesc, ...
        'input_shape', [nV, 1], ...
        'output_shape', [nV, 1], ...
        'input_support', 'vertex', ...
        'output_support', 'vertex', ...
        'complexity', 'O(N)', ...
        'computedBy', 'bct.manifold.solve.poisson');
end

function phi = solvePinned(decompA, rhs, keep, pinnedVertex)
    %SOLVEPINNED  Apply pinned Poisson solver to right-hand side
    %
    %   Solves the reduced system and inserts zero at pinned vertex
    
    % Ensure rhs is column vector
    rhs = rhs(:);
    
    % Initialize solution
    phi = zeros(size(rhs));
    
    % Solve reduced system
    phi(keep) = decompA \ rhs(keep);
    
    % Pin vertex to zero
    phi(pinnedVertex) = 0;
end

function phi = solvePinnedDensity(decompA, rho, M_keep, keep, pinnedVertex)
    %SOLVEPINNEDDENSITY  Apply pinned Poisson solver to density input
    %
    %   Solves stiffness*phi = mass*rho with pinned vertex
    
    % Ensure rho is column vector
    rho = rho(:);
    
    % Initialize solution
    phi = zeros(size(rho));
    
    % Build RHS: (mass*rho) restricted to free vertices
    rhs_keep = M_keep * rho(keep);
    
    % Solve reduced system
    phi(keep) = decompA \ rhs_keep;
    
    % Pin vertex to zero
    phi(pinnedVertex) = 0;
end
