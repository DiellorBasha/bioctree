function ids = list()
%LIST Return list of all operator IDs
%
% Syntax:
%   ids = bct.registry.operators.list()
%
% Returns:
%   ids - String array of operator identifiers
%
% See also: bct.registry.operators.defs

specs = bct.registry.operators.defs();
ids = keys(specs);

end
