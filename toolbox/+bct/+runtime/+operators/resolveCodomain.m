function codomain = resolveCodomain(spec, context)
%RESOLVECODOMAIN Resolve output domain descriptor from spec and context
%
% Syntax:
%   codomain = bct.runtime.operators.resolveCodomain(spec, context)
%
% Inputs:
%   spec    - OperatorSpec from registry
%   context - Runtime context struct
%
% Returns:
%   codomain - struct with fields:
%              support      - "vertex" | "face" | "edge" | "halfedge" | "coefficients"
%              semanticType - "signal" | "0-form" | "1-form" | "2-form" | "vector-field"
%              sizeHint     - [N, T] or [N, 1] or [] for variable
%              formDegree   - double or [] (for DEC operators)
%
% The codomain descriptor provides runtime type information about the operator's
% expected output. This is used for validation and visualization hints.
%
% See also: bct.runtime.operators.resolveDomain, bct.runtime.operators.bind

arguments
    spec struct
    context struct
end

% Initialize codomain struct
codomain = struct(...
    'support', "", ...
    'semanticType', "", ...
    'sizeHint', [], ...
    'formDegree', []);

% =========================================================================
% Extract semantic type from spec.outputType
% =========================================================================
if isfield(spec, 'outputType') && ~isempty(spec.outputType)
    codomain.semanticType = spec.outputType;
else
    codomain.semanticType = "unknown";
end

% =========================================================================
% Extract form degree (DEC-specific)
% =========================================================================
% For output, form degree typically increases by d (exterior derivative)
if isfield(spec, 'formDegree') && ~isempty(spec.formDegree)
    % For gradient: 0 -> 1, for divergence: 1 -> 0, etc.
    % Output degree depends on operation type
    if spec.id == "gradient.dec"
        codomain.formDegree = 1;
    elseif spec.id == "divergence.dec"
        codomain.formDegree = 0;
    elseif spec.id == "curl.dec"
        codomain.formDegree = 2;
    else
        codomain.formDegree = spec.formDegree;
    end
end

% =========================================================================
% Map semantic type to support
% =========================================================================
semanticType = codomain.semanticType;

switch semanticType
    case {"signal", "scalar_field", "0-form"}
        codomain.support = "vertex";
        
    case {"vector_field", "1-form"}
        % Depends on representation
        if spec.representation == "DiscreteExteriorCalculus"
            codomain.support = "edge";
        else
            codomain.support = "face";  % FEM gradient typically gives face vectors
        end
        
    case "2-form"
        codomain.support = "face";
        
    case "operator"
        % Matrix operator - no spatial support
        codomain.support = "coefficients";
        
    case "struct"
        % Structured output (e.g., HHD decomposition)
        codomain.support = "struct";
        
    otherwise
        codomain.support = "vertex";  % Conservative default
end

% =========================================================================
% Compute size hint from mesh dimensions
% =========================================================================
if isfield(context, 'Manifold') && ~isempty(context.Manifold)
    M = context.Manifold;
    
    switch codomain.support
        case "vertex"
            N = M.numVertices();
            codomain.sizeHint = [N, 1];
            
        case "face"
            F = M.numFaces();
            codomain.sizeHint = [F, 1];
            
        case "edge"
            if ismethod(M, 'numEdges')
                E = M.numEdges();
                codomain.sizeHint = [E, 1];
            else
                codomain.sizeHint = [];
            end
            
        case "halfedge"
            % Halfedges = 2 * edges (typically)
            if ismethod(M, 'numEdges')
                E = M.numEdges();
                codomain.sizeHint = [2*E, 1];
            else
                codomain.sizeHint = [];
            end
            
        otherwise
            codomain.sizeHint = [];
    end
end

end
