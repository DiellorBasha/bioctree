function ids = list()
%BCT.UI.COLOR.LIST  Return available colormap IDs (façade)
%
%   ids = bct.ui.color.list()
%
% Purpose
%   Discovery function for UI dropdowns. Returns all registered colormap IDs
%   in registry order.
%
% Output
%   ids - string column vector of available colormap IDs
%
% Note
%   This is a façade function. For new code, prefer:
%     ids = bct.registry.colormaps.list();
%
% See also: bct.registry.colormaps.list, bct.ui.color.resolve

    % Delegate to authoritative registry
    ids = bct.registry.colormaps.list();
end
