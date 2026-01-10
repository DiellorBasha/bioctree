classdef Manifold < matlab.ui.componentcontainer.ComponentContainer
    % Canonical 3D scene viewer with object-centric camera control

    %% Public data
    properties
        Vertices (:,3) double = []
        Faces    (:,3) double = []
    end

    %% Appearance
    properties
        BaseColor (1,3) double = [0.6 0.6 0.6]
    end

    %% Graphics handles
    properties (Access = private)
        Grid matlab.ui.container.GridLayout
        Ax   matlab.ui.control.UIAxes
        hPatch
        hQuiver
        hStream
        hSeed
        hSel
    end

    %% Interaction state
    properties (Access = private)
        IsRotating logical = false
        LastMousePos (1,2) double
        MeshCenter (1,3) double
        MeshRadius double
        
        % Selection state
        SelectionMode char {mustBeMember(SelectionMode,{'single','pair'})} = 'single'
        SourceVertex double = NaN
        TargetVertex double = NaN
        ActiveEdit char {mustBeMember(ActiveEdit,{'none','source','target'})} = 'none'
    end
%%
properties (Access = private)
    HasInitializedCamera logical = false
end
properties (Access = private)
    hKeyLight  matlab.graphics.primitive.Light
    hFillLight matlab.graphics.primitive.Light
end
    

%% Events
    events
        SourceSelected
        TargetSelected
        SelectionCleared
        SeedChanged
        VertexSelected
    end

    %% ============================================================
    %% Component lifecycle
    %% ============================================================
    methods (Access = protected)

function setup(comp)

    % Root layout
    comp.Grid = uigridlayout(comp,[1 1], ...
        'Padding',0,'RowSpacing',0,'ColumnSpacing',0);
comp.Grid.BackgroundColor = 'k';
    % Axes
    comp.Ax = uiaxes(comp.Grid);
    hold(comp.Ax,'on');

    % Axes as scene canvas
    comp.Ax.Color      = 'k';
    comp.Ax.Visible    = 'off';
    comp.Ax.Clipping   = 'off';
    %comp.Ax.Projection = 'perspective';
    comp.Ax.Projection = 'orthographic';

    axis(comp.Ax,'vis3d');

    % Disable built-in interactions
    disableDefaultInteractivity(comp.Ax);
    comp.Ax.Toolbar.Visible = 'off';

    % Lock camera
    comp.Ax.CameraPositionMode  = 'manual';
    comp.Ax.CameraTargetMode    = 'manual';
    comp.Ax.CameraUpVectorMode  = 'manual';
    comp.Ax.CameraViewAngleMode = 'manual';

    % Mesh patch
    comp.hPatch = patch(comp.Ax, ...
        'Vertices',[], 'Faces',[], ...
        'FaceColor',comp.BaseColor, ...
        'EdgeColor','none', ...
        'FaceLighting','gouraud', ...
        'PickableParts','visible', ...
        'HitTest','on');
% Material (explicit, not material())
set(comp.hPatch, ...
    'AmbientStrength',  0.15, ...
    'DiffuseStrength',  0.7, ...
    'SpecularStrength', 0.05, ...
    'SpecularExponent', 35, ...
    'BackFaceLighting', 'reverselit');
% Remove any existing lights
delete(findall(comp.Ax,'Type','light'));

% Create lights ONCE
comp.hKeyLight  = camlight(comp.Ax,'headlight');
comp.hFillLight = camlight(comp.Ax,'right');

% Dim fill light
comp.hFillLight.Color = [0.15 0.15 0.15];
comp.hFillLight.Position = comp.hFillLight.Position .* [1 -1 1];

% Shading model
lighting(comp.Ax,'gouraud');

    % Quiver for vector fields
    comp.hQuiver = quiver3(comp.Ax, nan,nan,nan, nan,nan,nan, ...
        'Color','w','LineWidth',1.5,'Visible','off');
    
    % Streamlines container
    comp.hStream = gobjects(0);

    % Markers
    comp.hSeed = plot3(comp.Ax,nan,nan,nan,'ro','LineWidth',2,'Visible','off');
    comp.hSel  = plot3(comp.Ax,nan,nan,nan,'yo','LineWidth',2,'Visible','off');


    % Mouse routing
    fig = ancestor(comp,'figure');
    comp.hPatch.ButtonDownFcn = @(~,~) comp.onMouseDown();
    fig.WindowButtonMotionFcn = @(~,~) comp.onMouseMove();
    fig.WindowButtonUpFcn     = @(~,~) comp.onMouseUp();
    fig.WindowScrollWheelFcn  = @(~,e) comp.onScroll(e);
    fig.WindowKeyPressFcn     = @(~,e) comp.onKeyPress(e);

drawnow;
end


function update(comp)

    if isempty(comp.Vertices) || isempty(comp.Faces)
        return
    end

    % Update geometry ONLY
    comp.hPatch.Vertices = comp.Vertices;
    comp.hPatch.Faces    = comp.Faces;

    % Initialize camera ONCE per geometry load
if ~comp.HasInitializedCamera
    ctr = mean(comp.Vertices,1);
    rad = max(vecnorm(comp.Vertices - ctr,2,2));

    comp.MeshCenter = ctr;
    comp.MeshRadius = rad;

    comp.Ax.CameraTarget    = ctr;
    comp.Ax.CameraPosition  = ctr + [-2.5*rad 0 0];
    comp.Ax.CameraUpVector  = [0 0 1];
    comp.Ax.CameraViewAngle = 45;

    camlight(comp.hKeyLight,'headlight');
    camlight(comp.hFillLight,'right');

    comp.HasInitializedCamera = true;
end

end

    end

    %% ============================================================
    %% Interaction
    %% ============================================================
    methods (Access = private)

        function onMouseDown(comp)
            fig = ancestor(comp,'figure');
            comp.LastMousePos = fig.CurrentPoint;

            if isempty(fig.CurrentModifier)
                % No modifier → rotation
                comp.IsRotating = true;
                return
            end

            % Modifier-based selection
            vid = comp.pickVertex();
            if ~isnan(vid)
                % Check for editing existing selections
                if ~isnan(comp.SourceVertex) && comp.isClickOnVertex(comp.SourceVertex)
                    comp.ActiveEdit = 'source';
                elseif ~isnan(comp.TargetVertex) && comp.isClickOnVertex(comp.TargetVertex)
                    comp.ActiveEdit = 'target';
                else
                    comp.ActiveEdit = 'none';
                end
                
                comp.handleVertexSelection(vid);
            end
        end
        
        function vid = pickVertex(comp)
            % PICKVERTEX Find nearest vertex to click point
            if isempty(comp.Vertices)
                vid = NaN;
                return
            end
            
            pt = comp.Ax.CurrentPoint(1,:);
            [~, vid] = min(vecnorm(comp.Vertices - pt, 2, 2));
        end
        
        function hit = isClickOnVertex(comp, vid, tol)
            % ISCLICKONVERTEX Test if click is near a specific vertex
            if nargin < 3, tol = 0.05 * comp.MeshRadius; end
            if isnan(vid) || vid > size(comp.Vertices,1)
                hit = false;
                return
            end
            
            pt = comp.Ax.CurrentPoint(1,:);
            hit = norm(comp.Vertices(vid,:) - pt) < tol;
        end
        
        function handleVertexSelection(comp, vid)
            % HANDLEVERTEXSELECTION Core selection state machine
            
            switch comp.SelectionMode
                
                case 'single'
                    % Single mode: always update source
                    comp.SourceVertex = vid;
                    comp.TargetVertex = NaN;
                    comp.updateSelectionGraphics();
                    notify(comp,'SourceSelected');
                    
                case 'pair'
                    if isnan(comp.SourceVertex)
                        % First click → source
                        comp.SourceVertex = vid;
                        comp.updateSelectionGraphics();
                        notify(comp,'SourceSelected');
                        
                    elseif isnan(comp.TargetVertex)
                        % Second click → target
                        comp.TargetVertex = vid;
                        comp.updateSelectionGraphics();
                        notify(comp,'TargetSelected');
                        
                    else
                        % Third click → reset cycle
                        comp.SourceVertex = vid;
                        comp.TargetVertex = NaN;
                        comp.updateSelectionGraphics();
                        notify(comp,'SourceSelected');
                    end
            end
        end
        
        function updateSelectionGraphics(comp)
            % UPDATESELECTIONGRAPHICS Reflect selection state in visuals
            
            V = comp.Vertices;
            
            % Source marker (red)
            if ~isnan(comp.SourceVertex) && comp.SourceVertex <= size(V,1)
                v = V(comp.SourceVertex,:);
                set(comp.hSeed, ...
                    'XData',v(1), 'YData',v(2), 'ZData',v(3), ...
                    'Visible','on');
            else
                comp.hSeed.Visible = 'off';
            end
            
            % Target marker (yellow)
            if ~isnan(comp.TargetVertex) && comp.TargetVertex <= size(V,1)
                v = V(comp.TargetVertex,:);
                set(comp.hSel, ...
                    'XData',v(1), 'YData',v(2), 'ZData',v(3), ...
                    'Visible','on');
            else
                comp.hSel.Visible = 'off';
            end
        end

        function onMouseMove(comp)
            if ~comp.IsRotating
                return
            end

            fig = ancestor(comp,'figure');
            cp = fig.CurrentPoint;
            delta = cp - comp.LastMousePos;
            comp.LastMousePos = cp;

            camorbit(comp.Ax, ...
                -0.3*delta(1), ...
                -0.3*delta(2), ...
                'camera');
             
% Reposition existing lights (NO creation)
camlight(comp.hKeyLight,'headlight');
camlight(comp.hFillLight,'right');
        end

        function onMouseUp(comp)
            comp.IsRotating = false;
        end

        function onScroll(comp,evt)
            camzoom(comp.Ax, 1 - 0.1*evt.VerticalScrollCount);
        end
        
        function onKeyPress(comp, evt)
            % ONKEYPRESS Handle keyboard shortcuts
            switch evt.Key
                case {'delete','backspace'}
                    comp.clearSelection();
            end
        end
    end
    
    %% ============================================================
    %% Public API for visualization layers
    %% ============================================================
    methods
        
        function setSelectionMode(comp, mode)
            % SETSELECTIONMODE Switch between 'single' and 'pair' selection
            %   comp.setSelectionMode('single') - single source vertex
            %   comp.setSelectionMode('pair')   - source → target pair
            mustBeMember(mode, {'single','pair'});
            comp.SelectionMode = mode;
            comp.ActiveEdit = 'none';
            comp.clearSelection();
        end
        
        function clearSelection(comp)
            % CLEARSELECTION Reset selection state
            comp.SourceVertex = NaN;
            comp.TargetVertex = NaN;
            comp.ActiveEdit = 'none';
            comp.updateSelectionGraphics();
            notify(comp,'SelectionCleared');
        end
        
        function setSourceVertex(comp, vid)
            % SETSOURCEVERTEX Programmatically set source vertex
            %   comp.setSourceVertex(vid) sets source to vertex vid
            validateattributes(vid, {'double'}, {'scalar','positive','integer','<=',size(comp.Vertices,1)});
            comp.SourceVertex = vid;
            comp.TargetVertex = NaN;
            comp.updateSelectionGraphics();
            notify(comp,'SourceSelected');
        end
        
        function setTargetVertex(comp, vid)
            % SETTARGETVERTEX Programmatically set target vertex
            %   comp.setTargetVertex(vid) sets target to vertex vid
            %   Requires source to be set first (pair mode)
            if isnan(comp.SourceVertex)
                error('Manifold:NoSource', 'Source vertex must be set before target.');
            end
            validateattributes(vid, {'double'}, {'scalar','positive','integer','<=',size(comp.Vertices,1)});
            comp.TargetVertex = vid;
            comp.updateSelectionGraphics();
            notify(comp,'TargetSelected');
        end
        
        function setScalarField(comp, values)
            % SETSCALARFIELD Apply vertex-wise color mapping
            %   comp.setScalarField(values) where values is Nx1 double
            validateattributes(values, {'double'}, {'numel',size(comp.Vertices,1)});
            comp.hPatch.FaceVertexCData = values;
            comp.hPatch.FaceColor = 'interp';
        end
        
        function showVectorField(comp, positions, U, V, W, varargin)
            % SHOWVECTORFIELD Display 3D vector field on mesh
            %   comp.showVectorField(positions, U, V, W, ...) where:
            %     positions - Nx3 base point coordinates
            %     U, V, W   - Nx1 vector components (X, Y, Z directions)
            %
            %   Additional name-value pairs:
            %     'Color'     - Arrow color (default: 'w')
            %     'LineWidth' - Arrow line width (default: 1.5)
            %     'AutoScale' - 'on' or 'off' (default: 'on')
            %
            %   Example:
            %     comp.showVectorField(COM, gradU, gradV, gradW, ...
            %         'Color', 'k', 'LineWidth', 1);
            
            % Update quiver data
            comp.hQuiver.XData = positions(:,1);
            comp.hQuiver.YData = positions(:,2);
            comp.hQuiver.ZData = positions(:,3);
            comp.hQuiver.UData = U(:);
            comp.hQuiver.VData = V(:);
            comp.hQuiver.WData = W(:);
            comp.hQuiver.Visible = 'on';
            
            % Apply additional properties
            if ~isempty(varargin)
                set(comp.hQuiver, varargin{:});
            end
        end
        
        function hideVectorField(comp)
            % HIDEVECTORFIELD Hide vector field display
            comp.hQuiver.Visible = 'off';
        end
        
        function setStreamlines(comp, curves, varargin)
            % SETSTREAMLINES Display multiple streamlines
            %   comp.setStreamlines(curves, ...) where curves is cell array
            %   of Nx3 path matrices. Additional args passed to plot3.
            delete(comp.hStream);
            comp.hStream = gobjects(numel(curves),1);
            for i = 1:numel(curves)
                comp.hStream(i) = plot3(comp.Ax, ...
                    curves{i}(:,1),curves{i}(:,2),curves{i}(:,3), ...
                    varargin{:});
            end
        end
        
        function clearStreamlines(comp)
            % CLEARSTREAMLINES Remove all streamlines
            delete(comp.hStream);
            comp.hStream = gobjects(0);
        end
        
        function setColormap(comp, cmap)
            % SETCOLORMAP Set colormap for axes
            %   comp.setColormap('jet')
            %   comp.setColormap('hot')
            %   comp.setColormap(myCustomColormap)
            colormap(comp.Ax, cmap);
        end
        
        function h = showColorbar(comp)
            % SHOWCOLORBAR Display colorbar
            %   comp.showColorbar()
            %   h = comp.showColorbar()  % Returns colorbar handle
            h = colorbar(comp.Ax);
            h.Color = 'w';  % White text for black background
        end
        
        function hideColorbar(comp)
            % HIDECOLORBAR Hide colorbar
            colorbar(comp.Ax, 'off');
        end
        
        function setColorLimits(comp, limits)
            % SETCOLORLIMITS Set color axis limits
            %   comp.setColorLimits([0 1])
            %   comp.setColorLimits([-max abs(data), max(abs(data))])
            caxis(comp.Ax, limits);
        end
        
        function setTitle(comp, txt, varargin)
            % SETTITLE Set axes title
            %   comp.setTitle('My Title')
            %   comp.setTitle('My Title', 'Color', 'w', 'FontSize', 14)
            if isempty(varargin)
                title(comp.Ax, txt, 'Color', 'w');
            else
                title(comp.Ax, txt, varargin{:});
            end
        end
        
        function ax = getAxes(comp)
            % GETAXES Get underlying axes handle (for advanced usage)
            %   ax = comp.getAxes()
            %
            % Warning: Direct manipulation of axes may interfere with
            % component behavior. Use public methods when possible.
            ax = comp.Ax;
        end
    end
end
