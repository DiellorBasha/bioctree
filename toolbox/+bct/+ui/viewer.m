function comp = viewer(obj, parent, options)
%BCT.UI.VIEWER  Create inspector in existing parent container (embed-friendly)
%
%   comp = bct.ui.viewer(obj, parent)
%   comp = bct.ui.viewer(obj, parent, Name, Value, ...)
%
% Purpose
%   Embed-friendly constructor for UI inspectors.
%   Does NOT create figure or grid - caller provides managed parent.
%
% Inputs
%   obj    - Object to visualize
%   parent - UI parent container (uigridlayout/uipanel/figure)
%            Caller responsible for layout management
%
% Name-Value Arguments
%   InspectorId  - string, override automatic inspector selection
%
% Output
%   comp - Inspector component instance
%
% Contract
%   Per BCTUIMANIFOLD_CONTRACT.md:
%   - Does not create figure or layout
%   - Caller must provide properly configured parent
%   - For standalone usage with automatic layout, use bct.ui.show() instead
%
% Usage
%   % In App Designer
%   M = bct.Manifold(V, F);
%   comp = bct.ui.viewer(M, app.GridLayout);
%
%   % In custom layout
%   fig = uifigure;
%   grid = uigridlayout(fig, [2 1]);
%   comp1 = bct.ui.viewer(obj1, grid);
%   comp2 = bct.ui.viewer(obj2, grid);
%
% See also: bct.ui.show

    arguments
        obj
        parent {mustBeValidParent}
        options.InspectorId (1,1) string = ""
    end
    
    % Delegate to show() with Parent parameter
    [comp, ~] = bct.ui.show(obj, ...
        "Parent", parent, ...
        "InspectorId", options.InspectorId);
end

function mustBeValidParent(p)
    % Validate parent is a valid UI container
    if ~isvalid(p)
        error('bct:ui:viewer:InvalidParent', 'Parent must be a valid graphics object');
    end
    
    validTypes = {'matlab.ui.container.GridLayout', ...
                  'matlab.ui.container.Panel', ...
                  'matlab.ui.Figure', ...
                  'matlab.ui.control.UIAxes'};
    
    if ~any(cellfun(@(t) isa(p, t), validTypes))
        error('bct:ui:viewer:InvalidParent', ...
            'Parent must be a UI container (GridLayout, Panel, Figure, or UIAxes)');
    end
end
