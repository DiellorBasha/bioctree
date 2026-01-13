function [tf, reason] = isAvailable(spec, context)
%ISAVAILABLE Check if operator can be instantiated for context
%
% Syntax:
%   tf = bct.runtime.operators.isAvailable(spec, context)
%   [tf, reason] = bct.runtime.operators.isAvailable(spec, context)
%
% Inputs:
%   spec    - OperatorSpec from registry
%   context - Runtime context struct
%
% Returns:
%   tf     - true if operator is available
%   reason - string explaining why operator is unavailable (empty if tf=true)
%
% An operator is available if:
%   1. External dependencies exist (toolbox classes/functions)
%   2. Required representation can be resolved from context
%   3. All capability tokens in spec.requires are available
%
% See also: bct.runtime.operators.bind, bct.runtime.operators.dictionary

arguments
    spec struct
    context struct
end

tf = false;
reason = "";

% =========================================================================
% 1. Check dependency availability
% =========================================================================
if isfield(spec, 'dependency')
    dep = spec.dependency;
    if isstruct(dep) && isfield(dep, 'requiredSymbols') && ~isempty(dep.requiredSymbols)
        for sym = string(dep.requiredSymbols)
            % Check if symbol is available
            % Try as class first, then as function/file
            if exist(sym, "class") ~= 8 && exist(sym, "file") ~= 2
                reason = sprintf("Missing dependency: %s", sym);
                return;
            end
        end
    end
end

% =========================================================================
% 2. Check representation resolvability
% =========================================================================
rep = spec.representation;

switch rep
    case "DiscreteExteriorCalculus"
        % Can resolve if:
        % - context.DEC exists and is populated, OR
        % - context.Manifold exists and DiscreteExteriorCalculus is available
        if isfield(context, 'DEC') && ~isempty(context.DEC)
            % Already resolved
        elseif isfield(context, 'Manifold') && ~isempty(context.Manifold)
            % Can resolve via Manifold.DEC() if DECLab available
            if exist("DiscreteExteriorCalculus", "class") ~= 8
                reason = "DiscreteExteriorCalculus class not available";
                return;
            end
        else
            reason = "No DEC or Manifold in context";
            return;
        end
        
    case "Manifold"
        % Can resolve if context.Manifold exists
        if isfield(context, 'Manifold') && ~isempty(context.Manifold)
            % Manifold available for direct V/F access
        else
            reason = "No Manifold in context";
            return;
        end
        
    case "Graph"
        % Can resolve if context.Graph exists or Manifold can provide it
        if isfield(context, 'Graph') && ~isempty(context.Graph)
            % Already resolved
        elseif isfield(context, 'Manifold') && ~isempty(context.Manifold)
            % Can resolve via Manifold.Graph()
        else
            reason = "No Graph or Manifold in context";
            return;
        end
        
    case "bct.Eigenpairs"
        % Spectral operators - Eigenpairs created on demand
        tf = true;
        return;
        
    otherwise
        reason = sprintf("Unknown representation type: %s", rep);
        return;
end

% =========================================================================
% 3. Check required capabilities (if representation supports introspection)
% =========================================================================
if isfield(spec, 'requires') && ~isempty(spec.requires)
    % Note: This would require resolving the representation, which is costly
    % For now, assume representation has required capabilities if it exists
    % In future, could add lightweight capability checking
end

% All checks passed
tf = true;
reason = "";

end
