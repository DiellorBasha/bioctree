function ops = dictionary(M, options)
%DICTIONARY Create dictionary of operator artifacts from bct.Manifold
%
% Syntax:
%   ops = bct.runtime.operators.dictionary(M)
%   ops = bct.runtime.operators.dictionary(M, Name=Value)
%
% Inputs:
%   M - bct.Manifold instance
%
% Name-Value Arguments:
%   LegacyHandles - logical (default: false)
%                   If true, returns dictionary(string → function_handle)
%                   for backward compatibility. If false, returns
%                   dictionary(string → OperatorStruct).
%
% Returns:
%   ops - dictionary of operator artifacts
%         Default: string → OperatorStruct
%         Legacy:  string → function_handle
%
% All operators come from bct.manifold.operator and are matrix-based.
% The dictionary is built from cached operators when available.
%
% OperatorStruct Fields:
%   id            - Operator identifier (string)
%   name          - Display name
%   backend       - "bct.manifold.operator"
%   inputSupport  - "vertex" | "edge" | "face"
%   outputSupport - "vertex" | "edge" | "face"
%   inputType     - Input semantic type
%   outputType    - Output semantic type
%   matrix        - Sparse matrix (operator)
%   isLinear      - true (all manifold operators are linear)
%   isMatrix      - true (all manifold operators return matrices)
%   purity        - "pure" (all manifold operators are pure)
%   applyFcn      - function_handle: y = applyFcn(x)
%
% Example (new API):
%   M = bct.Manifold(V, F);
%   ops = bct.runtime.operators.dictionary(M);
%   
%   % Use operator struct
%   if isKey(ops, "gradient")
%       op = ops("gradient");
%       gradF = op.applyFcn(f0);
%       % or directly: gradF = op.matrix * f0;
%   end
%
% Example (legacy mode):
%   ops = bct.runtime.operators.dictionary(M, LegacyHandles=true);
%   grad_fn = ops("gradient");
%   gradF = grad_fn(f0);
%
% See also: bct.manifold.operator, bct.Manifold.operators, 
%           bct.registry.operators.defs

arguments
    M bct.Manifold
    options.LegacyHandles (1,1) logical = false
end

% Initialize output dictionary
if options.LegacyHandles
    ops = dictionary(string.empty, @() []);
else
    ops = dictionary(string.empty, struct.empty);
end

% Load operator specifications from registry
specs = bct.registry.operators.defs();
allIds = keys(specs);

% Get or compute all operators from manifold
if M.hasCached('operators')
    manifoldOps = M.operators();
else
    manifoldOps = bct.manifold.operator(M);
end

% Build dictionary from manifold operators and specs
for i = 1:length(allIds)
    id = allIds(i);
    spec = specs(id);
    
    try
        % Extract operator matrix from manifold operators
        opMatrix = extractOperatorMatrix(id, manifoldOps, M);
        
        if isempty(opMatrix)
            continue; % Skip if not available
        end
        
        % Build operator struct
        opStruct = buildOperatorStruct(id, spec, opMatrix, M);
        
        if options.LegacyHandles
            % Extract function handle for legacy mode
            ops(id) = opStruct.applyFcn;
        else
            % Store full Operator struct
            ops(id) = opStruct;
        end
    catch ME
        % Operator extraction failed - skip
        warning('bct:runtime:operators:dictionary:ExtractionFailed', ...
            'Failed to extract operator "%s": %s', char(id), ME.message);
    end
end

end

%% ========================================================================
%  Helper Functions
% =========================================================================

function opMatrix = extractOperatorMatrix(id, manifoldOps, M)
%EXTRACTOPERATORMATRIX Extract operator matrix from manifold operators struct

% Map operator ID to manifold operator field
switch char(id)
    % Matrix operators
    case 'mass'
        opMatrix = manifoldOps.mass;
    case 'stiffness'
        opMatrix = manifoldOps.stiffness;
    case 'laplacebeltrami'
        opMatrix = manifoldOps.laplacebeltrami;
    
    % Composition operators
    case 'gradient'
        opMatrix = manifoldOps.gradient;
    case 'divergence.primal'
        opMatrix = manifoldOps.divergence;
    case 'divergence.dual'
        [~, opMatrix] = bct.manifold.operator.divergence(M, 'route', 'dual');
    case 'curl.primal'
        opMatrix = manifoldOps.curl;
    case 'curl.dual'
        [~, opMatrix] = bct.manifold.operator.curl(M, 'route', 'dual');
    
    % Hodge Laplacians
    case 'hodgelaplacian.0'
        opMatrix = manifoldOps.hodgelaplacian.kform0;
    case 'hodgelaplacian.1'
        opMatrix = manifoldOps.hodgelaplacian.kform1;
    case 'hodgelaplacian.2'
        opMatrix = manifoldOps.hodgelaplacian.kform2;
    
    % Primitive DEC operators (flat naming)
    case {'d0', 'd1', 'dd0', 'dd1', 'hd0', 'hd1', 'hd2', 'hdd0', 'hdd1', 'hdd2'}
        % Extract from dec substructure
        if isfield(manifoldOps, 'dec') && isfield(manifoldOps.dec, char(id))
            opMatrix = manifoldOps.dec.(char(id));
        else
            opMatrix = [];
        end
    
    otherwise
        opMatrix = [];
end

end

function opStruct = buildOperatorStruct(id, spec, opMatrix, M)
%BUILDOPERATORSTRUCT Build operator struct with metadata and apply function

opStruct = struct();
opStruct.id = id;
opStruct.name = spec.name;
opStruct.backend = spec.backend;
opStruct.inputSupport = spec.inputSupport;
opStruct.outputSupport = spec.outputSupport;
opStruct.inputType = spec.inputType;
opStruct.outputType = spec.outputType;
opStruct.matrix = opMatrix;
opStruct.isLinear = true;
opStruct.isMatrix = true;
opStruct.purity = "pure";

% Create apply function (matrix multiplication)
opStruct.applyFcn = @(x) opMatrix * x;

% Add dimensions metadata
opStruct.dimensions = struct();
opStruct.dimensions.input = size(opMatrix, 2);
opStruct.dimensions.output = size(opMatrix, 1);
opStruct.dimensions.numVertices = M.numVertices();
opStruct.dimensions.numEdges = M.numEdges();
opStruct.dimensions.numFaces = M.numFaces();

end
