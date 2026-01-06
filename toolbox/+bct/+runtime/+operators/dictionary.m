function ops = dictionary(ctx)
%DICTIONARY Create dictionary of bound operator handles for context
%
% Syntax:
%   ops = bct.runtime.operators.dictionary(ctx)
%
% Inputs:
%   ctx - Runtime context struct (must contain Manifold or representations)
%
% Returns:
%   ops - dictionary (string → function_handle) of bound operators
%
% The dictionary contains only operators that are:
%   1. Applicable to the context (dependencies + representation available)
%   2. Successfully bound to the context's representations
%
% Example:
%   M = bct.Manifold(struct('V', V, 'F', F));
%   ctx = bct.runtime.context(M);
%   ops = bct.runtime.operators.dictionary(ctx);
%   
%   % Use bound operators
%   if isKey(ops, "gradient.dec")
%       grad_fn = ops("gradient.dec");
%       gradF = grad_fn(f0);  % No need to pass DEC backend
%   end
%
% See also: bct.registry.operators.defs, bct.runtime.bind, bct.runtime.isApplicable

arguments
    ctx struct
end

% Initialize output dictionary
ops = dictionary(string.empty, @() []);

% Load operator specifications
specs = bct.registry.operators.defs();

% Filter and bind applicable operators
allIds = keys(specs);
for i = 1:length(allIds)
    id = allIds(i);
    spec = specs(id);
    
    % Check if operator is applicable to this context
    if bct.runtime.isApplicable(spec, ctx)
        try
            % Bind operator to context
            boundFn = bct.runtime.bind(spec, ctx);
            ops(id) = boundFn;
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
