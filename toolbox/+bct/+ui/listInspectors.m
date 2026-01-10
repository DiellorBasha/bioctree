function inspectors = listInspectors()
%BCT.UI.LISTINSPECTORS  List available UI inspectors
%
%   inspectors = bct.ui.listInspectors()
%
% Purpose
%   Discoverability function for UI inspectors.
%   Returns summary table of registered inspectors.
%
% Output
%   inspectors - table with columns:
%                Id, Class, Supports, Priority, Tags, Notes
%
% Usage
%   % See what's available
%   bct.ui.listInspectors()
%
%   % Use specific inspector
%   [comp, fig] = bct.ui.show(obj, "InspectorId", "ManifoldInspector");
%
% See also: bct.ui.show, bct.registry.ui.inspectors

    defs = bct.registry.ui.inspectors();
    
    if isempty(defs)
        inspectors = table();
        warning('bct:ui:listInspectors:EmptyRegistry', ...
            'No inspectors registered in bct.registry.ui.inspectors()');
        return;
    end
    
    % Convert struct array to table
    inspectors = struct2table(defs);
end
