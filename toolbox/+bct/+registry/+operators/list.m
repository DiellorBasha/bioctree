function ids = list()
%LIST Return list of all operator IDs from bct.manifold.operator
%
% Syntax:
%   ids = bct.registry.operators.list()
%
% Returns:
%   ids - String array of operator identifiers
%
% All IDs correspond to operators available via bct.manifold.operator:
%   - mass, stiffness, laplacebeltrami (FEM operators)
%   - dec.* (15 primitive DEC operators)
%   - gradient, divergence.primal, divergence.dual (DEC compositions)
%   - curl.primal, curl.dual (DEC curl)
%   - hodgelaplacian.0, hodgelaplacian.1, hodgelaplacian.2 (Hodge Laplacians)
%
% See also: bct.registry.operators.defs, bct.manifold.operator

specs = bct.registry.operators.defs();
ids = keys(specs);

end
