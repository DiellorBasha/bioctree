function solver = heat(varargin)
%BCT.MANIFOLD.SOLVE.HEAT  Build a reusable heat equation solver on a manifold
%
%   solver = bct.manifold.solve.heat(M)
%   solver = bct.manifold.solve.heat(heatOp, massOp)
%   solver = bct.manifold.solve.heat(..., 't_heat', value)
%   solver = bct.manifold.solve.heat(..., 'input', 'seed')
%   solver = bct.manifold.solve.heat(..., 'input', 'rhs')
%   solver = bct.manifold.solve.heat(..., 'massVariant', 'lumped')
%
% Purpose
%   Creates a cached heat equation solver for efficient repeated solves.
%   Solver is based on Cholesky factorization of the heat operator:
%     H = mass + t_heat * stiffness
%
% Inputs
%   M          - bct.Manifold object
%   OR
%   heatOp     - Heat operator structure from bct.manifold.operator.heat
%   massOp     - Mass operator structure from bct.manifold.operator.mass
%
% Name-Value Arguments
%   t_heat       - Heat diffusion time (default: auto-calculated from M)
%   input        - Input type:
%                  'seed' (default) - User provides seed vertex index/indices
%                  'rhs'            - User provides RHS directly
%   massVariant  - Mass matrix handling for 'seed' input:
%                  'full' (default)   - Extract mass matrix column(s)
%                  'lumped'           - Use diagonal mass values
%
% Output
%   solver - Struct with attributes and value fields:
%     .attributes       - Solver metadata struct:
%       .type             - "heat"
%       .input            - "seed" | "rhs"
%       .massVariant      - "full" | "lumped"
%       .t_heat           - Heat diffusion time parameter
%       .t_heat_source    - "auto" | "manual"
%       .nVertices        - Number of vertices
%       .factor           - Factorization method
%       .computed_utc     - Timestamp of solver creation
%     .value            - Function handle: u = solver.value(input)
%     .valueAttributes  - Metadata about the solver function:
%       .name             - Function name
%       .description      - What the function does
%       .dtype            - Data type (function_handle)
%       .signature        - Function signature
%       .input_description - Input description
%       .input_shape      - Expected input shape
%       .output_shape     - Output shape
%       .input_support    - Input support type
%       .output_support   - Output support type
%       .complexity       - Computational complexity
%       .computedBy       - Source function
%
% Usage
%   % Build solver from Manifold (auto t_heat, seed input)
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   solver = bct.manifold.solve.heat(M);
%   
%   % Solve with single seed vertex
%   seed = 100;
%   u = solver.value(seed);  % Heat diffusion from vertex 100
%   
%   % Solve with multiple seeds (returns matrix)
%   seeds = [100, 200, 300];
%   U = solver.value(seeds);  % [nV x 3] matrix, each column is one solution
%   
%   % Manual t_heat
%   solver = bct.manifold.solve.heat(M, 't_heat', 1.0);
%   
%   % RHS input mode (user provides RHS directly)
%   solver_rhs = bct.manifold.solve.heat(M, 'input', 'rhs');
%   rhs = randn(M.nVertices, 1);
%   u = solver_rhs.value(rhs);
%   
%   % Lumped mass (faster for large meshes)
%   solver_lumped = bct.manifold.solve.heat(M, 'massVariant', 'lumped');
%   u = solver_lumped.value(seed);
%   
%   % Build from operators directly
%   heatOp = bct.manifold.operator.heat(M);
%   massOp = M.mass;
%   solver = bct.manifold.solve.heat(heatOp, massOp);
%
% Notes
%   - Seed input: Most common use case for heat diffusion from source points
%   - RHS input: General linear system solve
%   - Lumped mass: Faster but less accurate (diagonal approximation)
%   - Full mass: Exact but requires column extraction
%   - Solver caches Cholesky decomposition for O(N) repeated solves
%
% See also: bct.manifold.operator.heat, bct.manifold.solve.poisson

    % Parse inputs: either (M) or (heatOp, massOp)
    if nargin < 1
        error('bct:manifold:solve:heat:NotEnoughInputs', ...
            'At least one input required: Manifold or heat operator');
    end
    
    % Check if first argument is a Manifold
    if isa(varargin{1}, 'bct.Manifold')
        % Extract from Manifold
        M = varargin{1};
        nvArgs = varargin(2:end);
        fromManifold = true;
    elseif isstruct(varargin{1})
        % Direct operator input
        if nargin < 2 || ~isstruct(varargin{2})
            error('bct:manifold:solve:heat:MissingMass', ...
                'When providing heat operator, mass operator must also be provided');
        end
        heatOp = varargin{1};
        massOp = varargin{2};
        nvArgs = varargin(3:end);
        fromManifold = false;
        
        % Validate operator inputs
        if ~isfield(heatOp, 'value') || ~isfield(heatOp, 'attributes')
            error('bct:manifold:solve:heat:InvalidHeatOp', ...
                'heatOp must be a structure with .value and .attributes fields');
        end
        if ~isfield(massOp, 'value') || ~isfield(massOp, 'attributes')
            error('bct:manifold:solve:heat:InvalidMassOp', ...
                'massOp must be a structure with .value and .attributes fields');
        end
        
        % Extract matrices
        heat = heatOp.value;
        mass = massOp.value;
        
        % Validate matrix sizes
        if ~isequal(size(heat), size(mass))
            error('bct:manifold:solve:heat:SizeMismatch', ...
                'heat and mass operators must have the same size');
        end
        
        % Get t_heat from heat operator if available
        if isfield(heatOp.attributes, 't_heat')
            t_heat_from_op = heatOp.attributes.t_heat;
            t_heat_source_default = 'operator';
        else
            t_heat_from_op = [];
            t_heat_source_default = 'unknown';
        end
    else
        error('bct:manifold:solve:heat:InvalidInput', ...
            'First argument must be a bct.Manifold or a heat operator structure');
    end
    
    % Parse optional parameters
    p = inputParser;
    p.addParameter('t_heat', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
    p.addParameter('input', 'seed', @(x) ismember(lower(x), {'seed', 'rhs'}));
    p.addParameter('massVariant', 'full', @(x) ismember(lower(x), {'full', 'lumped'}));
    p.parse(nvArgs{:});
    opt = p.Results;
    
    % Build heat operator if from Manifold
    if fromManifold
        % Check if t_heat was manually specified
        if ~isempty(opt.t_heat)
            % Manual t_heat
            heatOp = bct.manifold.operator.heat(M, 't_heat', opt.t_heat);
            t_heat = opt.t_heat;
            t_heat_source = 'manual';
        else
            % Auto t_heat
            heatOp = bct.manifold.operator.heat(M);
            t_heat = heatOp.attributes.t_heat;
            t_heat_source = 'auto';
        end
        
        % Get operators
        heat = heatOp.value;
        mass = M.mass.value;
    else
        % From operators: use provided or manual t_heat
        if ~isempty(opt.t_heat)
            t_heat = opt.t_heat;
            t_heat_source = 'manual';
        elseif exist('t_heat_from_op', 'var') && ~isempty(t_heat_from_op)
            t_heat = t_heat_from_op;
            t_heat_source = t_heat_source_default;
        else
            t_heat = NaN;
            t_heat_source = 'unknown';
        end
    end
    
    nV = size(heat, 1);
    
    % Initialize attributes struct
    attrs = struct();
    attrs.type = "heat";
    attrs.input = string(lower(opt.input));
    attrs.massVariant = string(lower(opt.massVariant));
    attrs.t_heat = t_heat;
    attrs.t_heat_source = t_heat_source;
    attrs.nVertices = nV;
    attrs.factor = "chol(decomposition)";
    attrs.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
    
    % Factorize heat operator
    decompH = decomposition(heat, 'chol');
    
    % Build solver function based on input type
    if strcmpi(opt.input, 'seed')
        % Seed input mode: build RHS from mass matrix
        
        if strcmpi(opt.massVariant, 'lumped')
            % Lumped mass: extract diagonal
            mass_diag = full(diag(mass));
            
            solverFn = @(seed) solveHeatSeedLumped(decompH, mass_diag, seed);
            
            attrs.equation = "heat * u = mass_diag(seed) * e_seed";
            attrs.massType = "diagonal (lumped)";
        else
            % Full mass: column extraction
            solverFn = @(seed) solveHeatSeedFull(decompH, mass, seed);
            
            attrs.equation = "heat * u = mass(:, seed)";
            attrs.massType = "full (column extraction)";
        end
        
    else
        % RHS input mode: direct solve
        solverFn = @(rhs) decompH \ rhs;
        
        attrs.equation = "heat * u = rhs";
    end
    
    % Return conventional bct structure
    solver.attributes = attrs;
    solver.value = solverFn;
    
    % Add metadata about the solver.value field
    if strcmpi(opt.input, 'seed')
        inputDesc = 'seed vertex index/indices';
        inputShape = 'scalar or [1×K] vector';
        outputShape = '[nV×1] or [nV×K]';
    else
        inputDesc = 'right-hand side vector';
        inputShape = [nV, 1];
        outputShape = [nV, 1];
    end
    
    solver.valueAttributes = struct(...
        'name', 'heatSolver', ...
        'description', sprintf('Heat equation solver: %s', attrs.equation), ...
        'dtype', 'function_handle', ...
        'signature', 'u = solver.value(input)', ...
        'input_description', inputDesc, ...
        'input_shape', inputShape, ...
        'output_shape', outputShape, ...
        'input_support', 'vertex', ...
        'output_support', 'vertex', ...
        'complexity', 'O(N) per solve', ...
        'computedBy', 'bct.manifold.solve.heat');
end

function u = solveHeatSeedLumped(decompH, mass_diag, seed)
    %SOLVEHHEATSEEDLUMPED  Solve heat equation with lumped mass and seed input
    %
    %   Uses diagonal mass approximation: rhsHeat(seed) = mass_diag(seed)
    
    % Validate seed indices
    nV = length(mass_diag);
    seed = seed(:)';  % Ensure row vector
    
    if any(seed < 1) || any(seed > nV)
        error('bct:manifold:solve:heat:InvalidSeed', ...
            'Seed indices must be in range [1, %d]', nV);
    end
    
    if isscalar(seed)
        % Single seed: return column vector
        rhs = zeros(nV, 1);
        rhs(seed) = mass_diag(seed);
        u = decompH \ rhs;
    else
        % Multiple seeds: return matrix [nV x nSeeds]
        nSeeds = length(seed);
        RHS = zeros(nV, nSeeds);
        for k = 1:nSeeds
            RHS(seed(k), k) = mass_diag(seed(k));
        end
        u = decompH \ RHS;
    end
end

function u = solveHeatSeedFull(decompH, mass, seed)
    %SOLVEHEATSEEDFULL  Solve heat equation with full mass and seed input
    %
    %   Uses exact mass matrix: rhsHeat = mass(:, seed)
    
    % Validate seed indices
    nV = size(mass, 1);
    seed = seed(:)';  % Ensure row vector
    
    if any(seed < 1) || any(seed > nV)
        error('bct:manifold:solve:heat:InvalidSeed', ...
            'Seed indices must be in range [1, %d]', nV);
    end
    
    if isscalar(seed)
        % Single seed: extract column
        rhs = mass(:, seed);
        u = decompH \ rhs;
    else
        % Multiple seeds: extract columns (matrix RHS)
        RHS = mass(:, seed);
        u = decompH \ RHS;
    end
end
