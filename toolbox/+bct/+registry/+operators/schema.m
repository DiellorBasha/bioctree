function s = schema()
%SCHEMA Return operator specification schema
%
% Syntax:
%   s = bct.registry.operators.schema()
%
% Returns:
%   s - Struct describing required fields in operator specs
%
% See also: bct.registry.operators.validate

s = struct();
s.id = "string";
s.name = "string";
s.domain = "string";
s.representation = "string";
s.inputType = "string";
s.outputType = "string";
s.formDegree = "numeric_or_empty";
s.parameters = "struct";
s.requires = "string_array";
s.dependency = "struct";
s.function = "function_handle";
s.purity = "string";
s.description = "string";

s.dependency_schema = struct(...
    'provider', "string", ...
    'kind', "string", ...
    'requiredSymbols', "string_array", ...
    'rootHint', "string", ...
    'notes', "string");

end
