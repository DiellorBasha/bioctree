function op = bind(spec, context)
%BIND Create Operator struct with representation resolved from context
%
% Syntax:
%   op = bct.runtime.operators.bind(spec, context)
%
% Inputs:
%   spec    - OperatorSpec from registry
%   context - Runtime context struct
%
% Returns:
%   op - Operator struct with fields:
%        id, name, meshId, backend, domain, codomain, params, requires,
%        dependency, purity, applyFcn, matrix, isLinear, provenance, cacheKey
%
% The Operator struct is a runtime artifact that:
%   - Binds representation to the operator function
%   - Provides uniform metadata and execution interface
%   - Includes provenance and caching information
%
% Representation Resolution:
%   - DEC: Resolves context.DEC or calls Manifold.DEC()
%   - FEM: Resolves context.FEM or calls Manifold.FEM()
%   - Graph: Resolves context.Graph or calls Manifold.Graph()
%
% Example:
%   ctx = bct.runtime.context(M);
%   spec = bct.registry.operators.defs()("gradient.dec");
%   op = bct.runtime.operators.bind(spec, ctx);
%   y = op.applyFcn(x);
%
% See also: bct.runtime.operators.isAvailable, bct.runtime.operators.dictionary

arguments
    spec struct
    context struct
end

% =========================================================================
% Resolve representation from context
% =========================================================================
repType = spec.representation;
backend = spec.domain;  % Domain usually indicates backend

switch repType
    case "DiscreteExteriorCalculus"
        if isfield(context, 'DEC') && ~isempty(context.DEC)
            rep = context.DEC;
        elseif isfield(context, 'Manifold') && ~isempty(context.Manifold)
            rep = context.Manifold.DEC();
        else
            error('bct:runtime:NoRepresentation', ...
                'Cannot resolve DiscreteExteriorCalculus: no DEC or Manifold in context');
        end
        backend = "DECLab";
        
    case "FEM"
        if isfield(context, 'FEM') && ~isempty(context.FEM)
            rep = context.FEM;
        elseif isfield(context, 'Manifold') && ~isempty(context.Manifold)
            rep = context.Manifold.FEM();
        else
            error('bct:runtime:NoRepresentation', ...
                'Cannot resolve FEM: no FEM or Manifold in context');
        end
        backend = "gptoolbox";
        
    case "Graph"
        if isfield(context, 'Graph') && ~isempty(context.Graph)
            rep = context.Graph;
        elseif isfield(context, 'Manifold') && ~isempty(context.Manifold)
            rep = context.Manifold.Graph();
        else
            error('bct:runtime:NoRepresentation', ...
                'Cannot resolve Graph: no Graph or Manifold in context');
        end
        backend = "gspbox";
        
    case "bct.Eigenpairs"
        % Eigenpairs passed by caller - set rep to empty
        rep = [];
        backend = "MATLAB";
        
    otherwise
        error('bct:runtime:UnknownRepresentation', ...
            'Unknown representation type: %s', repType);
end

% =========================================================================
% Create bound applyFcn
% =========================================================================
baseFn = spec.function;

if ~isempty(rep)
    % Bind representation to function
    % Detect if baseFn is an unbound method handle
    % For unbound methods (e.g., @Class.method), the function string contains a dot
    fnInfo = functions(baseFn);
    fnStr = fnInfo.function;
    
    if contains(fnStr, '.')
        % Unbound method handle - call as method on the object instance
        % Extract method name from "ClassName.methodName"
        parts = split(fnStr, '.');
        methodName = parts{end};
        applyFcn = @(varargin) rep.(methodName)(varargin{:});
    else
        % Regular function handle - bind rep as first argument
        % E.g., @myFunction becomes myFunction(rep, varargin{:})
        applyFcn = @(varargin) baseFn(rep, varargin{:});
    end
else
    % No representation binding needed
    applyFcn = baseFn;
end

% =========================================================================
% Resolve domain and codomain descriptors
% =========================================================================
domain = bct.runtime.operators.resolveDomain(spec, context);
codomain = bct.runtime.operators.resolveCodomain(spec, context);

% =========================================================================
% Resolve parameters
% =========================================================================
% Merge defaults from spec with any context overrides
params = spec.parameters;
if isfield(context, 'OperatorOverrides') && isfield(context.OperatorOverrides, spec.id)
    overrides = context.OperatorOverrides.(spec.id);
    params = mergeParams(params, overrides);
end

% =========================================================================
% Extract mesh ID if available
% =========================================================================
meshId = "";
if isfield(context, 'Manifold') && ~isempty(context.Manifold)
    M = context.Manifold;
    if isprop(M, 'ID')
        meshId = M.ID;
    end
end

% =========================================================================
% Compute provenance and cache key
% =========================================================================
prov = bct.runtime.operators.provenance(spec, context);
ckey = bct.runtime.operators.cacheKey(spec, context);

% =========================================================================
% Assemble Operator struct
% =========================================================================
op = struct(...
    'id', spec.id, ...
    'name', spec.name, ...
    'meshId', meshId, ...
    'backend', backend, ...
    'domain', domain, ...
    'codomain', codomain, ...
    'params', params, ...
    'requires', spec.requires, ...
    'dependency', spec.dependency, ...
    'purity', spec.purity, ...
    'applyFcn', applyFcn, ...
    'matrix', [], ...  % Not populated by default; can be added later
    'isLinear', false, ...  % Conservative default
    'provenance', prov, ...
    'cacheKey', ckey);

end

% =========================================================================
% Helper: Merge parameter structs
% =========================================================================
function merged = mergeParams(base, overrides)
    merged = base;
    if isstruct(overrides)
        fields = fieldnames(overrides);
        for i = 1:length(fields)
            merged.(fields{i}) = overrides.(fields{i});
        end
    end
end
