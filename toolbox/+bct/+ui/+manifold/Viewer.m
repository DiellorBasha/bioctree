classdef Viewer < matlab.ui.componentcontainer.ComponentContainer
    % Viewer - Manifold visualization component
    %
    % Minimal MATLAB ComponentContainer wrapper around the bct.ui.manifold.viewer
    % three.js implementation.
    %
    % This component:
    % - Loads the modular three.js viewer from +viewer/web/
    % - Supports GLB and JSON geometry loading
    % - Provides lil-gui visualization controls
    % - Handles coordinate frame transforms (MATLAB Z-up ↔ three.js Y-up)
    % - No explicit data passing (loads from assets)
    % - No callbacks (pure visualization)
    %
    % Intended usage (grid-layout driven sizing):
    %   fig  = uifigure('Position', [100 100 1200 800]);
    %   grid = uigridlayout(fig, [1 1]);
    %   grid.RowHeight    = {'1x'};
    %   grid.ColumnWidth  = {'1x'};
    %   v = bct.ui.manifold.Viewer(grid);
    %   v.Layout.Row = 1; 
    %   v.Layout.Column = 1;

    properties (Access = private, Transient, NonCopyable)
        HTMLComponent matlab.ui.control.HTML
    end

    methods (Access = protected)
        function setup(comp)
            % Create the HTML component as a child of this container.
            comp.HTMLComponent = uihtml(comp);

            % Point to the viewer's index.html in +viewer/web/ subdirectory.
            comp.HTMLComponent.HTMLSource = bct.ui.manifold.Viewer.resolveHTMLSource();

            % Let the parent (e.g., uigridlayout) control sizing.
            % We will size the uihtml to fill this container in update().
            comp.update();
        end

        function update(comp)
            if isempty(comp.HTMLComponent) || ~isvalid(comp.HTMLComponent)
                return;
            end

            % Fill the ComponentContainer client area.
            % ComponentContainer Position is in pixels; in a uigridlayout the grid sets it.
            w = comp.Position(3);
            h = comp.Position(4);

            % Guard against transient 0-size states.
            if w < 2 || h < 2
                return;
            end

            comp.HTMLComponent.Position = [1 1 w h];
        end
    end

    methods (Access = private, Static)
        function htmlPath = resolveHTMLSource()
            % Resolve the absolute path to +viewer/web/index.html
            % Works in both development and packaged toolbox scenarios.
            classFile = mfilename('fullpath');
            classDir  = fileparts(classFile);
            htmlPath  = fullfile(classDir, '+viewer', 'web', 'index.html');
        end
    end
end
