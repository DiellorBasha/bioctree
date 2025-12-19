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
%   1. Its required representation exists in context
%   2. All required capabilities are available
%
% See also: bct.runtime.operators

arguments
    spec struct
    context struct
end

applicable = false;

% Check representation requirement
rep = spec.representation;

switch spec.domain
    case "fem"
        if ~isfield(context, 'FEM') || isempty(context.FEM)
            return;
        end
        
    case "dec"
        if ~isfield(context, 'DEC') || isempty(context.DEC)
            return;
        end
        
    case "graph"
        if ~isfield(context, 'Graph') || isempty(context.Graph)
            return;
        end
        
    case "spectral"
        % Spectral operators work with Eigenpairs or FEM
        if strcmp(rep, "bct.Eigenpairs")
            % This is handled specially - Eigenpairs are created on demand
            applicable = true;
            return;
        elseif strcmp(rep, "bct.FEM")
            if ~isfield(context, 'FEM') || isempty(context.FEM)
                return;
            end
        else
            return;
        end
        
    case "kernel"
        % Kernels are always applicable (pure generators)
        applicable = true;
        return;
        
    otherwise
        warning('bct:runtime:UnknownDomain', ...
            'Unknown operator domain: %s', spec.domain);
        return;
end

% If we got here, basic representation check passed
applicable = true;

end
