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

% Get raw function and spec
[f_raw, spec] = bct.kernel.get(id);

% Validate and merge with defaults
params = bct.kernel.validate(id, params);

% Map parameters to positional arguments based on signature
args = cell(1, numel(spec.Signature));
for i = 1:numel(spec.Signature)
    paramName = spec.Signature(i);
    if isfield(params, paramName)
        args{i} = params.(paramName);
    else
        error('bct:kernel:MissingParameter', ...
            'Parameter "%s" required but not provided for kernel "%s"', ...
            paramName, id);
    end
end

% Create bound unary kernel handle
k = @(x) f_raw(x, args{:});

end
