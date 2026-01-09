function ops = operators(input, options)
%OPERATORS Get dictionary of available operators for context or manifold
%
% Syntax:
%   ops = bct.operators(M)
%   ops = bct.operators(ctx)
%   ops = bct.operators(..., Name=Value)
%
% Inputs:
%   M   - bct.Manifold instance
%   ctx - Runtime context struct
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
% OperatorStruct Fields:
%   id            - Operator identifier (string)
%   name          - Display name
%   meshId        - Manifold identifier
%   backend       - Toolbox/backend name (e.g., "DECLab", "gptoolbox")
%   domain        - Input domain descriptor (support, semanticType, sizeHint)
%   codomain      - Output domain descriptor
%   params        - Resolved parameters
%   requires      - Required capabilities
%   dependency    - External dependency metadata
%   purity        - "pure" or "impure"
%   applyFcn      - function_handle: y = applyFcn(x, varargin{:})
%   matrix        - Sparse matrix (if applicable, else [])
%   isLinear      - logical (true if operator is linear)
%   provenance    - Creation metadata
%   cacheKey      - String key for caching
%
% Examples:
%   % Get operators for a manifold
%   M = bct.Manifold(struct('V', V, 'F', F));
%   ops = bct.operators(M);
%   
%   % Check available operators
%   opIds = keys(ops);
%   
%   % Use an operator
%   if isKey(ops, "gradient.dec")
%       op = ops("gradient.dec");
%       gradF = op.applyFcn(f0);
%   end
%   
%   % Get operator metadata
%   fprintf('Domain: %s (%s)\n', op.domain.support, op.domain.semanticType);
%   fprintf('Backend: %s\n', op.backend);
%   
%   % Legacy mode (returns function handles)
%   opsLegacy = bct.operators(M, LegacyHandles=true);
%   gradF = opsLegacy("gradient.dec")(f0);
%
% See also: bct.operators.get, bct.operators.list, bct.operators.apply,
%           bct.runtime.operators.dictionary

arguments
    input  % bct.Manifold or struct (context)
    options.LegacyHandles (1,1) logical = false
end

% =========================================================================
% Convert input to context
% =========================================================================
if isa(input, 'bct.Manifold')
    % Create runtime context from Manifold
    ctx = bct.runtime.context(input);
elseif isstruct(input)
    % Already a context struct
    ctx = input;
else
    error('bct:operators:InvalidInput', ...
        'Input must be a bct.Manifold or runtime context struct');
end

% =========================================================================
% Delegate to runtime dictionary builder
% =========================================================================
ops = bct.runtime.operators.dictionary(ctx, ...
    LegacyHandles=options.LegacyHandles);

end
