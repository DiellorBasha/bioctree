function [f, spec] = get(id)
%BCT.KERNEL.GET Get raw kernel function and spec from registry
%
% Syntax:
%   f = bct.kernel.get(id)
%   [f, spec] = bct.kernel.get(id)
%
% Inputs:
%   id - Kernel identifier (string)
%
% Outputs:
%   f    - Raw function handle from dictionary
%   spec - KernelSpec from registry
%
% Description:
%   Retrieves both the raw function handle from the dictionary and
%   the corresponding semantic specification from the registry.
%
% Errors:
%   bct:kernel:UnknownKernel - if id not in dictionary
%   bct:kernel:MissingRegistryEntry - if id not in registry
%
% Example:
%   [f, spec] = bct.kernel.get("Gaussian");
%   w = f(x, 0, 0.2);  % Raw call with positional args
%
% See also: bct.kernel.bind, bct.kernel.dictionary, bct.registry.kernels

arguments
    id (1,1) string
end

% Get dictionary
D = bct.kernel.dictionary();

% Check if kernel exists in dictionary
if ~isKey(D, id)
    error('bct:kernel:UnknownKernel', ...
        'Kernel "%s" not found in dictionary', id);
end

% Get raw function handle
f = D(id);

% Get registry
registry = bct.registry.kernels();

% Find matching spec in registry
spec = [];
for i = 1:numel(registry)
    if registry(i).Id == id
        spec = registry(i);
        break;
    end
end

% Check if spec exists
if isempty(spec)
    error('bct:kernel:MissingRegistryEntry', ...
        'Kernel "%s" found in dictionary but missing from registry', id);
end

end
