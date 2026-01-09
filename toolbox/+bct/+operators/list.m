function tbl = list(input, options)
%LIST Get table of available operators with metadata
%
% Syntax:
%   tbl = bct.operators.list(M)
%   tbl = bct.operators.list(ctx)
%   tbl = bct.operators.list(ops)
%   tbl = bct.operators.list(..., Name=Value)
%
% Inputs:
%   M   - bct.Manifold instance
%   ctx - Runtime context struct
%   ops - Dictionary of operators (from bct.operators)
%
% Name-Value Arguments:
%   Format - "table" | "struct" (default: "table")
%            Output format for operator listing
%
% Returns:
%   tbl - table or struct array with columns/fields:
%         ID          - Operator identifier
%         Name        - Display name
%         Backend     - Toolbox/backend name
%         InputType   - Input data type
%         OutputType  - Output data type
%         Description - Brief description
%
% The listing is useful for UI menus, documentation, and debugging.
%
% Examples:
%   % List operators for manifold
%   M = bct.Manifold(struct('V', V, 'F', F));
%   tbl = bct.operators.list(M);
%   disp(tbl);
%   
%   % Get as struct array for programmatic use
%   s = bct.operators.list(M, Format="struct");
%   
%   % Filter table
%   decOps = tbl(contains(tbl.ID, ".dec"), :);
%
% See also: bct.operators, bct.operators.get, bct.operators.apply

arguments
    input  % bct.Manifold, struct (context), or dictionary
    options.Format (1,1) string {mustBeMember(options.Format, ["table", "struct"])} = "table"
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
    error('bct:operators:list:InvalidInput', ...
        'Input must be a bct.Manifold, context struct, or operator dictionary');
end

% =========================================================================
% Extract metadata from all operators
% =========================================================================
opIds = keys(ops);
n = length(opIds);

% Preallocate cell arrays
ids = cell(n, 1);
names = cell(n, 1);
backends = cell(n, 1);
inputTypes = cell(n, 1);
outputTypes = cell(n, 1);
descriptions = cell(n, 1);

for i = 1:n
    op = ops(opIds(i));
    
    ids{i} = char(op.id);
    names{i} = char(op.name);
    backends{i} = char(op.backend);
    
    % Extract domain/codomain semantic types
    if isfield(op.domain, 'semanticType')
        inputTypes{i} = char(op.domain.semanticType);
    else
        inputTypes{i} = 'unknown';
    end
    
    if isfield(op.codomain, 'semanticType')
        outputTypes{i} = char(op.codomain.semanticType);
    else
        outputTypes{i} = 'unknown';
    end
    
    % Extract description from dependency if available
    if isfield(op, 'dependency') && isfield(op.dependency, 'notes')
        descriptions{i} = char(op.dependency.notes);
    else
        descriptions{i} = '';
    end
end

% =========================================================================
% Format output
% =========================================================================
switch options.Format
    case "table"
        tbl = table(ids, names, backends, inputTypes, outputTypes, descriptions, ...
            'VariableNames', {'ID', 'Name', 'Backend', 'InputType', 'OutputType', 'Description'});
        
    case "struct"
        tbl = struct(...
            'ID', ids, ...
            'Name', names, ...
            'Backend', backends, ...
            'InputType', inputTypes, ...
            'OutputType', outputTypes, ...
            'Description', descriptions);
        tbl = struct2table(tbl);
        tbl = table2struct(tbl);
end

end
