function domain = resolveDomain(spec, context)
%RESOLVEDOMAIN Resolve input domain descriptor from spec and context
%
% Syntax:
%   domain = bct.runtime.operators.resolveDomain(spec, context)
%
% Inputs:
%   spec    - OperatorSpec from registry
%   context - Runtime context struct
%
% Returns:
%   domain - struct with fields:
%            support      - "vertex" | "face" | "edge" | "halfedge" | "coefficients"
%            semanticType - "signal" | "0-form" | "1-form" | "2-form" | "vector-field"
%            sizeHint     - [N, T] or [N, 1] or [] for variable
%            formDegree   - double or [] (for DEC operators)
%
% The domain descriptor provides runtime type information about the operator's
% expected input. This is used for validation and UI hints.
%
% See also: bct.runtime.operators.resolveCodomain, bct.runtime.operators.bind

arguments
    spec struct
    context struct
end

% Initialize domain struct
domain = struct(...
    'support', "", ...
    'semanticType', "", ...
    'sizeHint', [], ...
    'formDegree', []);

% =========================================================================
% Extract semantic type from spec.inputType
% =========================================================================
if isfield(spec, 'inputType') && ~isempty(spec.inputType)
    domain.semanticType = spec.inputType;
else
    domain.semanticType = "unknown";
end

% =========================================================================
% Extract form degree (DEC-specific)
% =========================================================================
if isfield(spec, 'formDegree') && ~isempty(spec.formDegree)
    domain.formDegree = spec.formDegree;
end

% =========================================================================
% Map semantic type to support
% =========================================================================
semanticType = domain.semanticType;

switch semanticType
    case {"signal", "scalar_field", "0-form"}
        domain.support = "vertex";
        
    case {"vector_field", "1-form"}
        % Depends on representation
        if spec.representation == "DiscreteExteriorCalculus"
            domain.support = "edge";
        else
            domain.support = "face";  % FEM gradient typically gives face vectors
        end
        
    case "2-form"
        domain.support = "face";
        
    case "operator"
        % Matrix operator - no spatial support
        domain.support = "coefficients";
        
    otherwise
        domain.support = "vertex";  % Conservative default
end

% =========================================================================
% Compute size hint from mesh dimensions
% =========================================================================
if isfield(context, 'Manifold') && ~isempty(context.Manifold)
    M = context.Manifold;
    
    switch domain.support
        case "vertex"
            N = M.numVertices();
            domain.sizeHint = [N, 1];
            
        case "face"
            F = M.numFaces();
            domain.sizeHint = [F, 1];
            
        case "edge"
            if ismethod(M, 'numEdges')
                E = M.numEdges();
                domain.sizeHint = [E, 1];
            else
                domain.sizeHint = [];
            end
            
        case "halfedge"
            % Halfedges = 2 * edges (typically)
            if ismethod(M, 'numEdges')
                E = M.numEdges();
                domain.sizeHint = [2*E, 1];
            else
                domain.sizeHint = [];
            end
            
        otherwise
            domain.sizeHint = [];
    end
end

end
