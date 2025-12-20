function ids = list()
%BCT.UI.COLOR.LIST  Return available colormap IDs
%
%   ids = bct.ui.color.list()
%
% Purpose
%   Discovery function for UI dropdowns. Returns all registered colormap IDs
%   in registry order.
%
% Outputs
%   ids - string array of available colormap IDs
%
% Behavior
%   Calls bct.registry.colormaps() and extracts the Id field.
%
% See also: bct.registry.colormaps, bct.ui.color.resolve

    defs = bct.registry.colormaps();
    ids = string({defs.Id});
end
