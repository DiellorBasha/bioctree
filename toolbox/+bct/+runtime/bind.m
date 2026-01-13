function boundFn = bind(spec, context)
%BIND Create bound function with representation resolved from context
%
% Syntax:
%   boundFn = bct.runtime.bind(spec, context)
%
% Inputs:
%   spec    - OperatorSpec from registry
%   context - Runtime context struct
%
% Returns:
%   boundFn - Function handle with representation pre-bound
%
% The bound function has a clean signature that hides the representation,
% making it suitable for UI callbacks and interactive use.
%
% Representation Resolution:
%   - DEC: Resolves context.DEC or calls Manifold.DEC()
%   - Graph: Resolves context.Graph or calls Manifold.Graph()
%   - Manifold: Used directly for Vertices/Faces access
%
% Method Handles:
%   - Unbound method handles (e.g., @DiscreteExteriorCalculus.gradient)
%     are called as: spec.function(rep, args...)
%   - Regular function handles are called normally
%
% Example:
%   % Registry: function = @DiscreteExteriorCalculus.gradient
%   % Bound:    gradient_fn = @(f0) gradient(dec, f0)
%
% See also: bct.runtime.isApplicable, bct.runtime.operators.dictionary

arguments
    spec struct
    context struct
end

% Get the base function
baseFn = spec.function;

% =========================================================================
% Resolve representation from context
% =========================================================================
repType = spec.representation;

switch repType
    case "DiscreteExteriorCalculus"
        % Resolve DEC representation
        if isfield(context, 'DEC') && ~isempty(context.DEC)
            rep = context.DEC;
        elseif isfield(context, 'Manifold') && ~isempty(context.Manifold)
            rep = context.Manifold.DEC();
        else
            error('bct:runtime:NoRepresentation', ...
                'Cannot resolve DiscreteExteriorCalculus: no DEC or Manifold in context');
        end
        
    case "Manifold"
        % Resolve Manifold directly
        if isfield(context, 'Manifold') && ~isempty(context.Manifold)
            rep = context.Manifold;
        else
            error('bct:runtime:NoRepresentation', ...
                'Cannot resolve Manifold in context');
        end
        
    case "Graph"
        % Resolve Graph representation
        if isfield(context, 'Graph') && ~isempty(context.Graph)
            rep = context.Graph;
        elseif isfield(context, 'Manifold') && ~isempty(context.Manifold)
            rep = context.Manifold.Graph();
        else
            error('bct:runtime:NoRepresentation', ...
                'Cannot resolve Graph: no Graph or Manifold in context');
        end
        
    case "bct.Eigenpairs"
        % Eigenpairs are passed by caller, don't pre-bind
        boundFn = baseFn;
        return;
        
    otherwise
        error('bct:runtime:UnknownRepresentation', ...
            'Unknown representation type: %s', repType);
end

% =========================================================================
% Validate required capabilities
% =========================================================================
if isfield(spec, 'requires') && ~isempty(spec.requires)
    for req = string(spec.requires)
        hasCapability = false;
        
        % Check if representation has the required capability
        if isobject(rep)
            % For objects, check properties and methods
            hasCapability = isprop(rep, req) || ismethod(rep, req);
        elseif isstruct(rep)
            % For structs, check fields
            hasCapability = isfield(rep, req);
        end
        
        if ~hasCapability
            error('bct:runtime:MissingCapability', ...
                'Operator "%s" requires capability "%s" which is not available in %s', ...
                spec.id, req, repType);
        end
    end
end

% =========================================================================
% Bind representation to function
% =========================================================================
% Detect if baseFn is an unbound method handle
% For unbound methods (e.g., @Class.method), the function string contains a dot
fnInfo = functions(baseFn);
fnStr = fnInfo.function;

if contains(fnStr, '.')
    % Unbound method handle - call as method on the object instance
    % Extract method name from "ClassName.methodName"
    parts = split(fnStr, '.');
    methodName = parts{end};
    boundFn = @(varargin) rep.(methodName)(varargin{:});
else
    % Regular function handle - bind rep as first argument
    % E.g., @myFunction becomes myFunction(rep, varargin{:})
    boundFn = @(varargin) baseFn(rep, varargin{:});
end

end