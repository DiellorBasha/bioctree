function tf = validate(spec)
%VALIDATE Check if operator spec conforms to schema
%
% Syntax:
%   tf = bct.registry.operators.validate(spec)
%
% Inputs:
%   spec - Operator specification struct
%
% Returns:
%   tf - true if valid, false otherwise
%
% See also: bct.registry.operators.schema

tf = false;

% Check required fields
requiredFields = ["id", "name", "domain", "representation", ...
    "inputType", "outputType", "parameters", "requires", ...
    "dependency", "function", "purity", "description"];

for f = requiredFields
    if ~isfield(spec, f)
        warning('bct:registry:MissingField', ...
            'Operator spec missing required field: %s', f);
        return;
    end
end

% Validate types
if ~isstring(spec.id) && ~ischar(spec.id)
    warning('bct:registry:InvalidType', 'Field "id" must be string');
    return;
end

if ~isa(spec.function, 'function_handle')
    warning('bct:registry:InvalidType', 'Field "function" must be function_handle');
    return;
end

if ~isstruct(spec.dependency)
    warning('bct:registry:InvalidType', 'Field "dependency" must be struct');
    return;
end

% Validate dependency struct
depFields = ["provider", "kind", "requiredSymbols", "rootHint", "notes"];
for f = depFields
    if ~isfield(spec.dependency, f)
        warning('bct:registry:MissingDependencyField', ...
            'Dependency missing field: %s', f);
        return;
    end
end

tf = true;

end
