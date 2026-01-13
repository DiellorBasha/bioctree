function tbl = list(input, options)
%LIST Get table of available operators from bct.manifold.operator
%
% Syntax:
%   tbl = bct.operators.list()
%   tbl = bct.operators.list(M)
%   tbl = bct.operators.list(..., Name=Value)
%
% Inputs:
%   M (optional) - bct.Manifold instance (if omitted, lists all registered operators)
%
% Name-Value Arguments:
%   Format - "table" | "struct" (default: "table")
%            Output format for operator listing
%
% Returns:
%   tbl - table or struct array with columns/fields:
%         ID          - Operator identifier
%         Name        - Display name
%         Backend     - Backend package name
%         InputSupport - Input support ("vertex", "edge", "face")
%         OutputSupport - Output support ("vertex", "edge", "face")
%         InputType   - Input semantic type
%         OutputType  - Output semantic type
%         IsMatrix    - Whether operator returns a matrix
%         IsLinear    - Whether operator is linear
%         Description - Brief description
%
% The listing shows operators available from bct.manifold.operator.
% When a Manifold is provided, all operators are available.
%
% Examples:
%   % List all registered operators
%   tbl = bct.operators.list();
%   disp(tbl);
%   
%   % List operators for specific manifold
%   M = bct.Manifold(struct('V', V, 'F', F));
%   tbl = bct.operators.list(M);
%   
%   % Get as struct array for programmatic use
%   s = bct.operators.list(Format="struct");
%   
%   % Filter table
%   decOps = tbl(contains(tbl.ID, ".dec"), :);
%   hodgeOps = tbl(contains(tbl.ID, "hodgelaplacian"), :);
%
% See also: bct.operators.get, bct.operators.apply, bct.manifold.operator

arguments
    input {mustBeManifoldOrEmpty(input)} = []
    options.Format (1,1) string {mustBeMember(options.Format, ["table", "struct"])} = "table"
end

% =========================================================================
% Get all operator specs from registry
% =========================================================================
specs = bct.registry.operators.defs();
opIds = keys(specs);
n = length(opIds);

% Preallocate cell arrays
ids = cell(n, 1);
names = cell(n, 1);
backends = cell(n, 1);
inputSupports = cell(n, 1);
outputSupports = cell(n, 1);
inputTypes = cell(n, 1);
outputTypes = cell(n, 1);
isMatrixVec = false(n, 1);
isLinearVec = false(n, 1);
descriptions = cell(n, 1);

for i = 1:n
    spec = specs(opIds(i));
    
    ids{i} = char(spec.id);
    names{i} = char(spec.name);
    backends{i} = char(spec.backend);
    inputSupports{i} = char(spec.inputSupport);
    outputSupports{i} = char(spec.outputSupport);
    inputTypes{i} = char(spec.inputType);
    outputTypes{i} = char(spec.outputType);
    isMatrixVec(i) = spec.isMatrix;
    isLinearVec(i) = spec.isLinear;
    descriptions{i} = char(spec.description);
end

% =========================================================================
% Build output table or struct
% =========================================================================
if options.Format == "table"
    tbl = table(ids, names, backends, inputSupports, outputSupports, ...
                inputTypes, outputTypes, isMatrixVec, isLinearVec, descriptions, ...
                'VariableNames', {'ID', 'Name', 'Backend', 'InputSupport', ...
                                  'OutputSupport', 'InputType', 'OutputType', ...
                                  'IsMatrix', 'IsLinear', 'Description'});
else % struct
    tbl = struct(...
        'ID', ids, ...
        'Name', names, ...
        'Backend', backends, ...
        'InputSupport', inputSupports, ...
        'OutputSupport', outputSupports, ...
        'InputType', inputTypes, ...
        'OutputType', outputTypes, ...
        'IsMatrix', num2cell(isMatrixVec), ...
        'IsLinear', num2cell(isLinearVec), ...
        'Description', descriptions);
end

end

function mustBeManifoldOrEmpty(input)
%MUSTBEMANIFOLDOREMPTY Validate input is Manifold or empty
if ~isempty(input) && ~isa(input, 'bct.Manifold')
    error('bct:operators:list:InvalidInput', ...
        'Input must be a bct.Manifold or empty');
end
end
