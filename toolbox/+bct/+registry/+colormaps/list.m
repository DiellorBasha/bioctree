function ids = list()
%BCT.REGISTRY.COLORMAPS.LIST  List all registered colormap IDs
%
%   ids = bct.registry.colormaps.list()
%
% Purpose
%   Convenience function to get list of all colormap IDs from registry.
%
% Output
%   ids - string column vector of colormap IDs
%
% See also: bct.registry.colormaps.defs, bct.ui.color.list

    defs = bct.registry.colormaps.defs();
    ids = string({defs.Id}).';
end
