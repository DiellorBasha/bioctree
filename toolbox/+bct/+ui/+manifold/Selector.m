classdef Selector < matlab.ui.componentcontainer.ComponentContainer
    %BCT.UI.MANIFOLD.SELECTOR  Lightweight viewer3d-based manifold selector
    %
    % Purpose:
    %   High-performance viewer3d component for rendering manifolds with
    %   vertex selection via annotation system. Integrates with bct.ui
    %   architecture using data adapters.
    %
    % Features:
    %   - Fast triangulation-based rendering with viewer3d
    %   - Interactive vertex selection via Point annotations
    %   - Scalar field overlay support
    %   - Minimal memory footprint (no Manifold ownership)
    %
    % Usage:
    %   % Standalone
    %   M = bct.Manifold(V, F);
    %   sel = bct.ui.manifold.Selector(parent);
    %   [V, F] = bct.ui.data.manifoldToMesh(M);
    %   sel.Vertices = V;
    %   sel.Faces = F;
    %
    %   % With bct.ui.show registry
    %   [sel, fig] = bct.ui.show(M, 'InspectorId', 'ManifoldSelector');
    %
    % Architecture:
    %   - Does NOT own bct.Manifold (uses Vertices/Faces only)
    %   - Uses bct.ui.data adapters for data extraction
    %   - Uses bct.ui.color for scalar → RGB mapping (future)
    %
    % See also: bct.ui.show

    %% Public properties
    properties (SetObservable)
        Seed (1,1) double = 1  % Selected vertex index (1-based)
    end
    
    properties
        Vertices (:,3) double = []  % Vertex coordinates [N×3]
        Faces    (:,3) double = []  % Face connectivity [M×3]
    end

    properties (SetAccess = protected)
        Viewer images.ui.graphics3d.Viewer3D  % viewer3d instance
    end

    %% Private state
    properties (Access = private, Transient, NonCopyable)
        GridLayout   matlab.ui.container.GridLayout
        SurfaceObj   images.ui.graphics3d.Surface
        SeedAnnotation images.ui.graphics.roi.Point
        Triangulation  % triangulation object (initialized dynamically)
    end

    %% Events
    events
        SeedChanged
    end

    %% Component lifecycle
    methods (Access = protected)
        function setup(comp)
            % Initialize viewer3d and event handlers
            
            comp.GridLayout = uigridlayout(comp, [1, 1]);
            comp.GridLayout.Padding = 0;
            comp.GridLayout.RowSpacing = 0;
            comp.GridLayout.ColumnSpacing = 0;
            
            % Create viewer3d with clean black background
            comp.Viewer = viewer3d( ...
                comp.GridLayout, ...
                'BackgroundColor', [0 0 0], ...
                'BackgroundGradient', 'off', ...
                'RenderingQuality', 'high');
            
            % Default camera orientation
            comp.Viewer.Mode.Default.CameraVector = [-1 -1 1];
            
            % Listen for annotation events
            addlistener(comp.Viewer, 'AnnotationAdded', ...
                @(~,evt) comp.onAnnotationEvent(evt));
            addlistener(comp.Viewer, 'AnnotationMoved', ...
                @(~,evt) comp.onAnnotationEvent(evt));
            
            % Listen to Seed changes
            addlistener(comp, 'Seed', 'PostSet', ...
                @(~,~) comp.onSeedChanged());
        end

        function update(comp)
            % Update surface when Vertices/Faces change
            
            if isempty(comp.Vertices) || isempty(comp.Faces)
                return;
            end
            
            % Build or update triangulation
            comp.Triangulation = triangulation(double(comp.Faces), comp.Vertices);
            
            % Create or update surface
            if isempty(comp.SurfaceObj) || ~isvalid(comp.SurfaceObj)
                comp.SurfaceObj = images.ui.graphics3d.Surface( ...
                    comp.Viewer, ...
                    'Data', comp.Triangulation, ...
                    'Color', [0.8 0.8 0.8], ...
                    'Alpha', 1, ...
                    'Wireframe', false);
            else
                comp.SurfaceObj.Data = comp.Triangulation;
            end
            
            % Sync annotation to seed
            comp.syncAnnotationToSeed();
        end
    end

    %% Public methods
    methods
        function setScalarField(comp, values)
            %SETSCALARFIELD Apply scalar field as vertex colors
            %
            % Syntax:
            %   comp.setScalarField(values)
            %
            % Inputs:
            %   values - [N×1] scalar values (one per vertex)
            %
            % Note: Uses bct.ui.color for mapping (future integration)
            
            arguments
                comp
                values (:,1) double
            end
            
            if isempty(comp.SurfaceObj) || ~isvalid(comp.SurfaceObj)
                return;
            end
            
            % Normalize to [0, 1]
            vmin = min(values);
            vmax = max(values);
            if vmax > vmin
                values_norm = (values - vmin) / (vmax - vmin);
            else
                values_norm = zeros(size(values));
            end
            
            % Simple grayscale mapping (future: use bct.ui.color)
            RGB = repmat(values_norm, 1, 3);
            
            % Apply to surface
            comp.SurfaceObj.Color = RGB;
        end
        
        function clearScalarField(comp)
            %CLEARSCALARFIELD Reset surface to default gray color
            
            if isempty(comp.SurfaceObj) || ~isvalid(comp.SurfaceObj)
                return;
            end
            
            comp.SurfaceObj.Color = [0.8 0.8 0.8];
        end
        
        function clearMesh(comp)
            %CLEARMESH Remove surface and annotation
            
            if ~isempty(comp.SurfaceObj) && isvalid(comp.SurfaceObj)
                delete(comp.SurfaceObj);
            end
            
            if ~isempty(comp.SeedAnnotation) && isvalid(comp.SeedAnnotation)
                delete(comp.SeedAnnotation);
            end
            
            comp.SurfaceObj = [];
            comp.SeedAnnotation = [];
            comp.Triangulation = [];
            comp.Vertices = [];
            comp.Faces = [];
            comp.Seed = 1;
        end
    end

    %% Internal methods
    methods (Access = private)
        function syncAnnotationToSeed(comp)
            %SYNCANNOTATIONTOSEED Update annotation position to match Seed
            
            if isempty(comp.Triangulation)
                return;
            end
            
            V = comp.Triangulation.Points;
            
            if comp.Seed < 1 || comp.Seed > size(V, 1)
                return;
            end
            
            pos = V(comp.Seed, :);
            
            if isempty(comp.SeedAnnotation) || ~isvalid(comp.SeedAnnotation)
                comp.SeedAnnotation = images.ui.graphics.roi.Point( ...
                    'Parent', comp.Viewer, ...
                    'Position', pos);
            else
                % Programmatic move (does not fire AnnotationMoved)
                comp.SeedAnnotation.Position = pos;
            end
        end

        function onAnnotationEvent(comp, evt)
            %ONANNOTATIONEVENT Handle AnnotationAdded/AnnotationMoved events
            
            if isempty(comp.Triangulation)
                return;
            end
            
            roi = evt.Annotation;
            pos = roi.Position;
            
            % Validate position
            if ~isnumeric(pos) || size(pos, 2) ~= 3
                return;
            end
            
            % Handle multi-point annotations by centroid
            if size(pos, 1) > 1
                pos = mean(pos, 1);
            end
            
            pos = double(pos);
            
            % Find nearest vertex
            vidx = nearestNeighbor(comp.Triangulation, pos);
            
            % Update Seed if changed
            if comp.Seed ~= vidx
                comp.Seed = vidx;
                notify(comp, 'SeedChanged');
            end
            
            comp.SeedAnnotation = roi;
        end
        
        function onSeedChanged(comp)
            %ONSEEDCHANGED React to Seed property changes
            
            % Sync annotation to new seed position
            comp.syncAnnotationToSeed();
        end
    end
end
