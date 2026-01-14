function [comp, fig] = show(obj, options)
%BCT.UI.SHOW  Display object in interactive inspector (primary UI entrypoint)
%
%   [comp, fig] = bct.ui.show(obj)
%   [comp, fig] = bct.ui.show(obj, Name, Value, ...)
%
% Purpose
%   Primary user-facing entrypoint for visualizing BCT objects.
%   Automatically selects appropriate inspector via runtime dispatch.
%
% Inputs
%   obj - Object to visualize (bct.Manifold, struct, etc.)
%
% Name-Value Arguments
%   Parent       - UI parent container (uigridlayout/uipanel/uifigure)
%                  If omitted, creates standalone figure with root layout
%   InspectorId  - string, override automatic inspector selection
%   Title        - string, figure title (only used if creating figure)
%   Position     - [x y w h], figure position (only used if creating figure)
%
% Outputs
%   comp - Inspector component instance
%   fig  - Figure handle ([] if Parent was provided)
%
% Contract Requirements (per BCTUIMANIFOLD_CONTRACT.md)
%   - MUST create root uigridlayout for standalone usage
%   - If Parent provided, assumes parent is already layout-managed
%   - Uses bct.runtime.ui.resolveInspector for dispatch
%
% Usage
%   % Standalone with automatic inspector selection
%   M = bct.Manifold(V, F);
%   [comp, fig] = bct.ui.show(M);
%
%   % Embedded in App Designer
%   [comp, ~] = bct.ui.show(M, "Parent", app.GridLayout);
%
%   % Override inspector selection
%   [comp, fig] = bct.ui.show(M, "InspectorId", "ManifoldViewer");
%
% See also: bct.ui.viewer, bct.runtime.ui.resolveInspector

    arguments
        obj
        options.Parent = []
        options.InspectorId (1,1) string = ""
        options.Title (1,1) string = "BCT Viewer"
        options.Position double = []
    end
    
    % Validate Position if provided
    if ~isempty(options.Position)
        validateattributes(options.Position, {'double'}, ...
            {'vector', 'numel', 4, 'finite'}, mfilename, 'Position');
    end
    
    % Resolve inspector via runtime
    try
        if options.InspectorId ~= ""
            [factory, def] = bct.runtime.ui.resolveInspector(obj, ...
                'InspectorId', options.InspectorId);
        else
            [factory, def] = bct.runtime.ui.resolveInspector(obj);
        end
    catch ME
        error('bct:ui:show:ResolverFailed', ...
            'Failed to resolve inspector for object of class "%s":\n%s', ...
            class(obj), ME.message);
    end
    
    % Create figure and root layout if no parent provided
    if isempty(options.Parent)
        fig = uifigure('Name', options.Title);
        
        if ~isempty(options.Position)
            fig.Position = options.Position;
        end
        
        % REQUIRED: Always create root uigridlayout for correct sizing
        root = uigridlayout(fig, [1 1]);
        root.RowHeight = {'1x'};
        root.ColumnWidth = {'1x'};
        root.Padding = 0;
        root.RowSpacing = 0;
        root.ColumnSpacing = 0;
        
        parent = root;
    else
        fig = [];
        parent = options.Parent;
    end
    
    % Instantiate inspector
    try
        comp = factory(parent);
    catch ME
        if ~isempty(fig)
            delete(fig);
        end
        error('bct:ui:show:InstantiationFailed', ...
            'Failed to instantiate inspector "%s" (class=%s):\n%s', ...
            def.Id, def.Class, ME.message);
    end
    
    % Bind object to inspector
    try
        bindObject(comp, obj);
    catch ME
        if ~isempty(fig)
            delete(fig);
        end
        error('bct:ui:show:BindingFailed', ...
            'Failed to bind object to inspector "%s":\n%s', ...
            def.Id, ME.message);
    end
    
    % Bring figure to front if standalone
    if ~isempty(fig)
        figure(fig);
    end
end

function bindObject(comp, obj)
    % Bind object to inspector using standard binding contract
    % Per contract: inspector must accept via Object property or setObject method
    
    % Try Object property
    if isprop(comp, 'Object')
        comp.Object = obj;
        return;
    end
    
    % Try Function property (for function_handle objects with Fplot)
    if isa(obj, 'function_handle') && isprop(comp, 'Function')
        comp.Function = obj;
        return;
    end
    
    % Special handling for bct.Manifold with manifold.Viewer
    if isa(obj, 'bct.Manifold') && isa(comp, 'bct.ui.manifold.Viewer')
        comp.setMesh(obj);
        return;
    end
    
    % Special handling for bct.Manifold with manifold.Selector
    if isa(obj, 'bct.Manifold') && isa(comp, 'bct.ui.manifold.Selector')
        [V, F] = bct.ui.data.manifoldToMesh(obj);
        comp.Vertices = V;
        comp.Faces = F;
        return;
    end
    
    % Try model-specific property (e.g., Manifold property)
    objClass = class(obj);
    if isprop(comp, objClass)
        comp.(objClass) = obj;
        return;
    end
    
    % Try setObject method
    if ismethod(comp, 'setObject')
        comp.setObject(obj);
        return;
    end
    
    % Fallback: try common property names
    if isprop(comp, 'Data')
        comp.Data = obj;
        return;
    end
    
    error('bct:ui:show:NoBindingMethod', ...
        ['Inspector does not support standard binding contract.\n' ...
         'Expected: Object property, %s property, setObject() method, or Data property.'], ...
        objClass);
end
