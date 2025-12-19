function boundFn = bind(spec, context)
%BIND Create bound function with representation captured from context
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
% Example:
%   % Original: bct.fem.heat(FEM, signal, t, k)
%   % Bound:    heat_fn(signal, t, k)
%
% See also: bct.runtime.operators

arguments
    spec struct
    context struct
end

% Get the base function
baseFn = spec.function;

% Bind representation based on domain
switch spec.domain
    case "fem"
        rep = context.FEM;
        % Create bound function: baseFn(FEM, ...)
        boundFn = @(varargin) baseFn(rep, varargin{:});
        
    case "dec"
        rep = context.DEC;
        boundFn = @(varargin) baseFn(rep, varargin{:});
        
    case "graph"
        rep = context.Graph;
        boundFn = @(varargin) baseFn(rep, varargin{:});
        
    case "spectral"
        % Spectral operators may work with Eigenpairs or FEM
        if strcmp(spec.representation, "bct.Eigenpairs")
            % These operators take Eigenpairs as first argument
            % Don't pre-bind, let caller provide
            boundFn = baseFn;
        elseif strcmp(spec.representation, "bct.FEM")
            % FEM-based spectral operators
            rep = context.FEM;
            boundFn = @(varargin) baseFn(rep, varargin{:});
        else
            boundFn = baseFn;
        end
        
    case "kernel"
        % Kernels are pure generators, no binding needed
        boundFn = baseFn;
        
    otherwise
        % Fallback: no binding
        boundFn = baseFn;
end

end
