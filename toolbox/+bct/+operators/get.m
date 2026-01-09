function op = get(input, id, options)
%GET Retrieve a single operator by ID
%
% Syntax:
%   op = bct.operators.get(M, id)
%   op = bct.operators.get(ctx, id)
%   op = bct.operators.get(ops, id)
%   op = bct.operators.get(..., Name=Value)
%
% Inputs:
%   M   - bct.Manifold instance
%   ctx - Runtime context struct
%   ops - Dictionary of operators (from bct.operators)
%   id  - Operator ID (string)
%
% Name-Value Arguments:
%   AllowMissing - logical (default: false)
%                  If false, error when operator not found.
%                  If true, return [] when operator not found.
%
% Returns:
%   op - Operator struct, or [] if not found and AllowMissing=true
%
% Examples:
%   % Get operator from manifold
%   M = bct.Manifold(struct('V', V, 'F', F));
%   op = bct.operators.get(M, "gradient.dec");
%   
%   % Get operator from existing dictionary
%   ops = bct.operators(M);
%   op = bct.operators.get(ops, "gradient.dec");
%   
%   % Allow missing
%   op = bct.operators.get(M, "nonexistent", AllowMissing=true);
%   if isempty(op)
%       warning('Operator not available');
%   end
%
% See also: bct.operators, bct.operators.list, bct.operators.apply

arguments
    input  % bct.Manifold, struct (context), or dictionary
    id (1,1) string
    options.AllowMissing (1,1) logical = false
end

% =========================================================================
% Resolve input to operator dictionary
% =========================================================================
if isa(input, 'dictionary')
    % Already a dictionary
    ops = input;
elseif isa(input, 'bct.Manifold') || isstruct(input)
    % Convert to operator dictionary
    ops = bct.operators(input);
else
    error('bct:operators:get:InvalidInput', ...
        'Input must be a bct.Manifold, context struct, or operator dictionary');
end

% =========================================================================
% Look up operator
% =========================================================================
if isKey(ops, id)
    op = ops(id);
else
    if options.AllowMissing
        op = [];
    else
        error('bct:operators:get:NotFound', ...
            'Operator "%s" not found in context', id);
    end
end

end
