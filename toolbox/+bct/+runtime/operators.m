function rtOps = operators(context)
%OPERATORS Create runtime operator dictionary from context
%
% ⚠️  FACADE: This function delegates to bct.runtime.operators.dictionary()
%
% Syntax:
%   rtOps = bct.runtime.operators(context)
%
% Inputs:
%   context - Struct with fields:
%             .Manifold - bct.Manifold object (required or auto-create)
%             .FEM      - FEM struct (optional, lazy-resolved)
%             .DEC      - DiscreteExteriorCalculus (optional, lazy-resolved)
%             .Graph    - bct.Graph object (optional, lazy-resolved)
%
% Returns:
%   rtOps - MATLAB dictionary mapping operator IDs to bound function handles
%
% Design principles (from RegistryRuntimeOperators):
%   - Runtime is contextual and dynamic
%   - Filters operators based on available representations and dependencies
%   - Binds representations to create clean execution signatures
%   - Returns ephemeral dictionary for UI/interaction
%
% Example:
%   M = bct.Manifold(struct('V', V, 'F', F));
%   ctx = bct.runtime.context(M);
%   ops = bct.runtime.operators(ctx);
%   
%   % Execute operator with new hierarchical IDs
%   if isKey(ops, "gradient.dec")
%       grad_fn = ops("gradient.dec");
%       gradF = grad_fn(f0);  % Representation already bound
%   end
%
% Migration:
%   - Old IDs (dec_gradient) deprecated, use new IDs (gradient.dec)
%   - Dictionary-based instead of struct-based
%
% See also: bct.registry.operators.defs, bct.runtime.operators.dictionary

% Delegate to new implementation
rtOps = bct.runtime.operators.dictionary(context);

end
