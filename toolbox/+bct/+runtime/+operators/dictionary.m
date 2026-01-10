function ops = dictionary(ctx, options)
%DICTIONARY Create dictionary of operator artifacts for context
%
% Syntax:
%   ops = bct.runtime.operators.dictionary(ctx)
%   ops = bct.runtime.operators.dictionary(ctx, Name=Value)
%
% Inputs:
%   ctx - Runtime context struct (must contain Manifold or representations)
%
% Name-Value Arguments:
%   LegacyHandles - logical (default: false)
%                   If true, returns dictionary(string → function_handle)
%                   for backward compatibility. If false, returns
%                   dictionary(string → OperatorStruct).
%
% Returns:
%   ops - dictionary of operator artifacts
%         Default: string → OperatorStruct
%         Legacy:  string → function_handle
%
% The dictionary contains only operators that are:
%   1. Available in the context (dependencies + representation exist)
%   2. Successfully bound to the context's representations
%
% OperatorStruct Fields:
%   id, name, meshId, backend, domain, codomain, params, requires,
%   dependency, purity, applyFcn, matrix, isLinear, provenance, cacheKey
%
% Example (new API):
%   M = bct.Manifold(struct('V', V, 'F', F));
%   ctx = bct.runtime.context(M);
%   ops = bct.runtime.operators.dictionary(ctx);
%   
%   % Use operator struct
%   if isKey(ops, "gradient.dec")
%       op = ops("gradient.dec");
%       gradF = op.applyFcn(f0);
%   end
%
% Example (legacy mode):
%   ops = bct.runtime.operators.dictionary(ctx, LegacyHandles=true);
%   grad_fn = ops("gradient.dec");
%   gradF = grad_fn(f0);
%
% See also: bct.registry.operators.defs, bct.runtime.operators.bind, 
%           bct.runtime.operators.isAvailable

arguments
    ctx struct
    options.LegacyHandles (1,1) logical = false
end

% Initialize output dictionary
if options.LegacyHandles
    ops = dictionary(string.empty, @() []);
else
    ops = dictionary(string.empty, struct.empty);
end

% Load operator specifications
specs = bct.registry.operators.defs();

% Filter and bind available operators
allIds = keys(specs);
for i = 1:length(allIds)
    id = allIds(i);
    spec = specs(id);
    
    % Check if operator is available for this context
    [available, reason] = bct.runtime.operators.isAvailable(spec, ctx);
    
    if available
        try
            % Bind operator to context -> returns Operator struct
            opStruct = bct.runtime.operators.bind(spec, ctx);
            
            if options.LegacyHandles
                % Extract function handle for legacy mode
                ops(id) = opStruct.applyFcn;
            else
                % Store full Operator struct
                ops(id) = opStruct;
            end
        catch ME
            % Binding failed - skip this operator
            warning('bct:runtime:BindFailed', ...
                'Failed to bind operator "%s": %s', char(id), ME.message);
        end
    end
end

% Add deprecated ID aliases for backward compatibility
% This allows old IDs to work but issues deprecation warnings
deprecatedIds = ["dec_gradient", "dec_divergence", "dec_curl", ...
                 "dec_laplacian", "dec_hhd", "fem_gradient", "fem_divergence"];

for oldId = deprecatedIds
    newId = bct.runtime.operators.resolveAlias(oldId);
    if ~isempty(newId) && isKey(ops, newId)
        % Suppress warning here since resolveAlias will warn on first access
        ops(oldId) = ops(newId);
    end
end

end
