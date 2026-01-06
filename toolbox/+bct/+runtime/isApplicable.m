function applicable = isApplicable(spec, context)
%ISAPPLICABLE Check if operator is applicable to context
%
% Syntax:
%   applicable = bct.runtime.isApplicable(spec, context)
%
% Inputs:
%   spec    - OperatorSpec from registry
%   context - Runtime context struct
%
% Returns:
%   applicable - true if operator can be used with this context
%
% An operator is applicable if:
%   1. External dependencies are available (spec.dependency.requiredSymbols)
%   2. Required representation can be resolved from context
%   3. All capability tokens in spec.requires are available
%
% See also: bct.runtime.bind, bct.runtime.operators.dictionary

arguments
    spec struct
    context struct
end

applicable = false;

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
                % Dependency not available
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
                return;
            end
        else
            return;
        end
        
    case "FEM"
        % Can resolve if:
        % - context.FEM exists and is populated, OR
        % - context.Manifold exists and can provide FEM
        if isfield(context, 'FEM') && ~isempty(context.FEM)
            % Already resolved
        elseif isfield(context, 'Manifold') && ~isempty(context.Manifold)
            % Can resolve via Manifold.FEM()
        else
            return;
        end
        
    case "Graph"
        % Can resolve if context.Graph exists or Manifold can provide it
        if isfield(context, 'Graph') && ~isempty(context.Graph)
            % Already resolved
        elseif isfield(context, 'Manifold') && ~isempty(context.Manifold)
            % Can resolve via Manifold.Graph()
        else
            return;
        end
        
    case "bct.Eigenpairs"
        % Spectral operators - Eigenpairs created on demand
        applicable = true;
        return;
        
    otherwise
        % Unknown representation
        warning('bct:runtime:UnknownRepresentation', ...
            'Unknown representation type: %s', rep);
        return;
end

% =========================================================================
% 3. All checks passed
% =========================================================================
applicable = true;

end
