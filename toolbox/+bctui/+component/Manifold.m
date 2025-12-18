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
        hSeed
        hSel
    end

    %% Interaction state
    properties (Access = private)
        IsRotating logical = false
        LastMousePos (1,2) double
        MeshCenter (1,3) double
        MeshRadius double
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

    % Markers
    comp.hSeed = plot3(comp.Ax,nan,nan,nan,'ro','LineWidth',2,'Visible','off');
    comp.hSel  = plot3(comp.Ax,nan,nan,nan,'yo','LineWidth',2,'Visible','off');


    % Mouse routing
    fig = ancestor(comp,'figure');
    comp.hPatch.ButtonDownFcn = @(~,~) comp.onMouseDown();
    fig.WindowButtonMotionFcn = @(~,~) comp.onMouseMove();
    fig.WindowButtonUpFcn     = @(~,~) comp.onMouseUp();
    fig.WindowScrollWheelFcn  = @(~,e) comp.onScroll(e);

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
                comp.IsRotating = true;
                return
            end

            % Picking
            pt = comp.Ax.CurrentPoint(1,:);
            [~,vid] = min(vecnorm(comp.Vertices - pt,2,2));

            if ismember('shift',fig.CurrentModifier)
                comp.hSel.XData = comp.Vertices(vid,1);
                comp.hSel.YData = comp.Vertices(vid,2);
                comp.hSel.ZData = comp.Vertices(vid,3);
                comp.hSel.Visible = 'on';
                notify(comp,'VertexSelected');

            elseif ismember('control',fig.CurrentModifier)
                comp.hSeed.XData = comp.Vertices(vid,1);
                comp.hSeed.YData = comp.Vertices(vid,2);
                comp.hSeed.ZData = comp.Vertices(vid,3);
                comp.hSeed.Visible = 'on';
                notify(comp,'SeedChanged');
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
    end
end
