function ids = list()
%BCT.REGISTRY.KERNELS.LIST  List all registered kernel IDs
%
%   ids = bct.registry.kernels.list()
%
% Purpose
%   Convenience function to get list of all kernel IDs from registry.
%
% Output
%   ids - string column vector of kernel IDs
%
% See also: bct.registry.kernels.defs, bct.kernel.list

    defs = bct.registry.kernels.defs();
    ids = string({defs.Id}).';
end
