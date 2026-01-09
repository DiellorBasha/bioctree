function y = apply(input, idOrOp, x, varargin)
%APPLY Apply operator to data with optional validation
%
% Syntax:
%   y = bct.operators.apply(M, id, x, ...)
%   y = bct.operators.apply(ctx, id, x, ...)
%   y = bct.operators.apply(ops, id, x, ...)
%   y = bct.operators.apply(_, op, x, ...)
%
% Inputs:
%   M      - bct.Manifold instance
%   ctx    - Runtime context struct
%   ops    - Dictionary of operators (from bct.operators)
%   id     - Operator ID (string)
%   op     - Operator struct
%   x      - Input data
%   ...    - Additional arguments passed to operator function
%
% Returns:
%   y - Output data from operator
%
% This function provides a uniform interface for applying operators with
% optional validation of input dimensions against domain metadata.
%
% Examples:
%   % Apply using manifold and operator ID
%   M = bct.Manifold(struct('V', V, 'F', F));
%   f0 = randn(M.numVertices(), 1);
%   gradF = bct.operators.apply(M, "gradient.dec", f0);
%   
%   % Apply using operator struct directly
%   op = bct.operators.get(M, "gradient.dec");
%   gradF = bct.operators.apply(M, op, f0);
%   
%   % Apply with additional arguments
%   y = bct.operators.apply(M, "custom.op", x, param1, param2);
%
% See also: bct.operators, bct.operators.get, bct.operators.list

arguments
    input  % bct.Manifold, struct (context), or dictionary
    idOrOp  % string (operator ID) or struct (Operator)
    x  % Input data
end

arguments (Repeating)
    varargin  % Additional arguments for operator
end

% =========================================================================
% Resolve operator struct
% =========================================================================
if isstruct(idOrOp)
    % Already an Operator struct
    op = idOrOp;
elseif isstring(idOrOp) || ischar(idOrOp)
    % Look up operator by ID
    if isa(input, 'dictionary')
        ops = input;
    else
        ops = bct.operators(input);
    end
    
    id = string(idOrOp);
    if ~isKey(ops, id)
        error('bct:operators:apply:NotFound', ...
            'Operator "%s" not found in context', id);
    end
    op = ops(id);
else
    error('bct:operators:apply:InvalidOperator', ...
        'Second argument must be operator ID (string) or Operator struct');
end

% =========================================================================
% Validate input dimensions (optional, conservative)
% =========================================================================
if isfield(op, 'domain') && isfield(op.domain, 'sizeHint') && ...
        ~isempty(op.domain.sizeHint) && isnumeric(x)
    
    sizeHint = op.domain.sizeHint;
    expectedRows = sizeHint(1);
    actualRows = size(x, 1);
    
    if actualRows ~= expectedRows
        warning('bct:operators:apply:SizeMismatch', ...
            'Input has %d rows, expected %d for domain type "%s"', ...
            actualRows, expectedRows, op.domain.support);
    end
end

% =========================================================================
% Apply operator
% =========================================================================
try
    y = op.applyFcn(x, varargin{:});
catch ME
    error('bct:operators:apply:ExecutionFailed', ...
        'Operator "%s" execution failed: %s', op.id, ME.message);
end

end
