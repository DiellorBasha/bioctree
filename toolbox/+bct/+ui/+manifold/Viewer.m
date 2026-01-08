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
    
    properties (Access = private)
        Vertices (:,3) double = []
        Faces (:,3) uint32 = []
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
    
    methods (Access = public)
        function setMesh(comp, V, F)
            % setMesh - Set the mesh to display in the viewer
            %
            % Syntax:
            %   comp.setMesh(V, F)
            %
            % Inputs:
            %   V - Vertices matrix [N×3] double, MATLAB Z-up coordinates
            %   F - Faces matrix [M×3] uint32, 1-based indexing
            %
            % Notes:
            %   - Vertices are expected in MATLAB Z-up coordinates
            %   - Faces are converted from 1-based to 0-based indexing
            %   - Arrays are flattened for JSON transfer
            %   - Updates HTMLComponent.Data to trigger JavaScript viewer
            
            % Validate inputs
            arguments
                comp (1,1) bct.ui.manifold.Viewer
                V (:,3) double {mustBeReal, mustBeFinite}
                F (:,3) {mustBeInteger, mustBePositive}
            end
            
            % Convert faces to uint32 and ensure 1-based
            F = uint32(F);
            
            % Store mesh data
            comp.Vertices = V;
            comp.Faces = F;
            
            % Flatten vertices: [x1 y1 z1 x2 y2 z2 ...]
            % IMPORTANT: Use .' to transpose then reshape to preserve XYZ order
            verticesFlat = reshape(V.', 1, []);
            
            % Flatten faces and convert to 0-based indexing: [i1 i2 i3 ...] - 1
            facesFlat = double(reshape(F.', 1, [])) - 1;
            
            % Create mesh data payload
            meshData = struct(...
                'vertices', verticesFlat, ...
                'faces', facesFlat, ...
                'indexBase', 0, ...
                'frame', 'matlab' ...
            );
            
            % Set HTMLComponent.Data to trigger DataChanged event in JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('mesh', meshData);
                fprintf('[Viewer.setMesh] Sent mesh data: %d vertices, %d faces\n', ...
                    size(V, 1), size(F, 1));
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Mesh data stored but not sent.');
            end
        end
    end
end
