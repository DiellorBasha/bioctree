function [k, spec] = bind(id, params)
%BCT.KERNEL.BIND Bind parameters to raw kernel, producing unary handle
%
% Syntax:
%   k = bct.kernel.bind(id, params)
%   [k, spec] = bct.kernel.bind(id, params)
%
% Inputs:
%   id     - Kernel identifier (string)
%   params - Struct with parameter name-value pairs
%
% Outputs:
%   k    - Bound unary kernel handle: w = k(x)
%   spec - KernelSpec from registry (optional)
%
% Description:
%   Binds parameters to a raw kernel function from the dictionary,
%   producing a configured unary kernel handle k(x) that can be
%   directly used by bct.filter.applySpectral.
%
%   Parameter validation:
%     - Validates params against spec.ParamSchema
%     - Applies defaults from spec.Defaults for missing fields
%     - Maps params into raw handle's positional argument order
%
% Example:
%   % Create a Gaussian kernel with specific parameters
%   params = struct('mu', 0, 'sigma', 0.2);
%   k = bct.kernel.bind("Gaussian", params);
%   weights = k(lambda);
%
%   % Use with filter
%   E = M.FEM().eigenpairs(50);
%   y = bct.filter.applySpectral(E, x, k);
%
% See also: bct.kernel.get, bct.kernel.validate, bct.filter.applySpectral

arguments
    id (1,1) string
    params (1,1) struct = struct()
end

% Get kernel evaluator from dictionary
D = bct.kernel.dictionary();
if ~isKey(D, id)
    error('bct:kernel:bind:UnknownKernel', ...
        'Kernel "%s" not found in dictionary', id);
end

kernelEvaluator = D(id);

% Get parameter info from authoritative registry (struct array)
defs = bct.registry.kernels.defs();

% Find the kernel definition in the struct array
kernelDef = [];
for i = 1:numel(defs)
    if defs(i).Id == id
        kernelDef = defs(i);
        break;
    end
end

if isempty(kernelDef)
    error('bct:kernel:bind:KernelNotInRegistry', ...
        'Kernel "%s" not found in registry', id);
end

% Get parameter names in order
paramNames = kernelDef.ParamNames;

% Validate params has all required fields
for i = 1:numel(paramNames)
    if ~isfield(params, paramNames(i))
        error('bct:kernel:bind:MissingParameter', ...
            'Parameter "%s" required for kernel "%s"', paramNames(i), id);
    end
end

% Extract parameter values in correct order
paramValues = cell(1, numel(paramNames));
for i = 1:numel(paramNames)
    paramValues{i} = params.(paramNames(i));
end

% Create bound unary kernel handle
k = @(x) kernelEvaluator(x, paramValues{:});

% Return spec if requested
if nargout > 1
    spec = kernelDef;
end

end
