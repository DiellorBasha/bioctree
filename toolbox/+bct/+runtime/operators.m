function rtOps = operators(context)
%OPERATORS Create runtime operator dictionary from context
%
% Syntax:
%   rtOps = bct.runtime.operators(context)
%
% Inputs:
%   context - Struct with fields:
%             .Manifold - bct.Manifold object (required)
%             .FEM      - bct.FEM object (optional)
%             .DEC      - DEC object (optional)
%             .Graph    - bct.Graph object (optional)
%
% Returns:
%   rtOps - MATLAB dictionary mapping operator IDs to bound function handles
%
% Design principles (from RegistryRuntimeOperators):
%   - Runtime is contextual and dynamic
%   - Filters operators based on available representations
%   - Binds representations to create clean execution signatures
%   - Returns ephemeral dictionary for UI/interaction
%
% Example:
%   M = bct.Manifold(struct('V', V, 'F', F));
%   ctx = struct('Manifold', M, 'FEM', M.FEM());
%   ops = bct.runtime.operators(ctx);
%   
%   % Execute operator
%   heat_fn = ops("fem_heat");
%   signal_t = heat_fn(signal, t, k);
%
% See also: bct.registry.operators, bct.runtime.context

arguments
    context struct
end

% Validate context
assert(isfield(context, 'Manifold'), ...
    'bct:runtime:MissingManifold', 'Context must have Manifold field');

% Get authoritative operator catalog
specs = bct.registry.operators();

% Create dictionary for runtime operators
rtOps = dictionary(string.empty, {});

% Get list of all operator IDs
opIds = fieldnames(specs);

% Filter and bind each operator based on context
for i = 1:numel(opIds)
    opId = opIds{i};
    spec = specs.(opId);
    
    % Check if operator is applicable to this context
    if bct.runtime.isApplicable(spec, context)
        % Bind representation to create clean signature
        boundFn = bct.runtime.bind(spec, context);
        rtOps(spec.id) = boundFn;
    end
end

end
