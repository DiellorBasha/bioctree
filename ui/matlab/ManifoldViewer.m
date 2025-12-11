classdef ManifoldViewer < Component
    %MANIFOLDVIEWER Interactive 3D manifold visualization component
    %
    %   High-performance 3D viewer for BCT Manifold objects with signal
    %   visualization, animation, and interactive controls. Integrates all
    %   functionality from bct.show package.
    %
    %   Properties:
    %       BctObject       - Reference to Bct object being visualized
    %       Viewer3D        - Handle to MATLAB viewer3d object
    %       CurrentSignal   - Index of currently displayed signal
    %       CurrentTimePoint- Current time point for time-varying signals
    %       ColorMap        - Current colormap name
    %       IsAnimating     - Whether animation is running
    %       AnimationSpeed  - Animation speed (frames per second)
    %
    %   Methods:
    %       loadBct         - Load a Bct object for visualization
    %       showMesh        - Display mesh with default gray coloring
    %       showSignal      - Display a specific signal on the mesh
    %       setColorMap     - Change the colormap
    %       setTimePoint    - Jump to specific time point
    %       animate         - Start/stop animation for time-varying signals
    %       setAnimationSpeed - Control animation playback speed
    %       center          - Center mesh at origin
    %       setWireframe    - Toggle wireframe display
    %       setAlpha        - Set mesh transparency
    %       export          - Export current view as image
    %       reset           - Reset view to defaults
    %
    %   Example:
    %       % In App Designer or figure
    %       fig = uifigure('Name', 'Manifold Viewer');
    %       panel = uipanel(fig, 'Position', [0 0 800 600]);
    %       
    %       viewer = ManifoldViewer([], panel);
    %       viewer.loadBct(B);
    %       viewer.showSignal(1);  % Show first signal
    %       viewer.setColorMap('turbo');
    %       viewer.animate();  % Start animation if time-varying
    %
    %   See also: Component, bct.show.visualizer, bct.show.mesh
    
    properties (Access = public)
        BctObject       % Bct object being visualized
        Viewer3D        % viewer3d handle
        CurrentSignal   % Current signal index
        CurrentTimePoint% Current time point
        ColorMap        % Current colormap
        IsAnimating     % Animation state
        AnimationSpeed  % FPS for animation
    end
    
    properties (Access = private)
        ParentContainer % Parent UI container
        AnimationTimer  % Timer for animation
        ShowPath        % Path to show functions
        CenterMesh      % Whether to center mesh
        WireframeMode   % Wireframe display
        AlphaValue      % Transparency value
    end
    
    methods
        function obj = ManifoldViewer(app, parentContainer)
            %MANIFOLDVIEWER Construct a ManifoldViewer instance
            %
            %   obj = ManifoldViewer(app, parentContainer) creates a viewer
            %   in the specified container.
            %
            %   Inputs:
            %       app             - Parent application (can be [])
            %       parentContainer - uipanel, uifigure, or axes3d parent
            
            % Call superclass constructor
            obj@Component(app, [], 'ManifoldViewer');
            
            % Initialize properties
            obj.ParentContainer = parentContainer;
            obj.BctObject = [];
            obj.Viewer3D = [];
            obj.CurrentSignal = 1;
            obj.CurrentTimePoint = 1;
            obj.ColorMap = 'parula';
            obj.IsAnimating = false;
            obj.AnimationSpeed = 30;  % 30 FPS default
            obj.CenterMesh = true;
            obj.WireframeMode = false;
            obj.AlphaValue = 1.0;
            
            % Set path to show functions
            thisFile = mfilename('fullpath');
            matlabDir = fileparts(thisFile);
            obj.ShowPath = fullfile(matlabDir, 'show');
            
            % Add show functions to path
            addpath(obj.ShowPath);
        end
        
        function loadBct(obj, B)
            %LOADBCT Load a Bct object for visualization
            %
            %   loadBct(obj, B) loads and displays a Bct object's mesh.
            %
            %   Input:
            %       B - Bct object with Manifold (and optionally Signals)
            
            if isempty(B) || ~isa(B, 'bct.bct')
                error('ManifoldViewer:InvalidInput', ...
                    'Input must be a valid Bct object');
            end
            
            obj.BctObject = B;
            obj.CurrentSignal = 1;
            obj.CurrentTimePoint = 1;
            
            % Display the mesh
            obj.showMesh();
            
            % Send state update if we have HTML component
            if ~isempty(obj.HTML)
                obj.send(struct(...
                    'cmd', 'bctLoaded', ...
                    'hasSignals', ~isempty(B.Signals), ...
                    'numSignals', length(B.Signals), ...
                    'hasTime', ~isempty(B.Time), ...
                    'numTimePoints', obj.getNumTimePoints()...
                ));
            end
        end
        
        function showMesh(obj)
            %SHOWMESH Display mesh with default gray coloring
            
            if isempty(obj.BctObject)
                warning('ManifoldViewer:NoBct', 'No Bct object loaded');
                return;
            end
            
            % Use the copied visualizer function
            obj.Viewer3D = visualizer(obj.BctObject, ...
                'Parent', obj.ParentContainer, ...
                'ColorMap', 'gray', ...
                'WireFrame', obj.WireframeMode, ...
                'Center', obj.CenterMesh, ...
                'Alpha', obj.AlphaValue);
            
            obj.CurrentSignal = [];
        end
        
        function showSignal(obj, signalIdx, varargin)
            %SHOWSIGNAL Display a specific signal on the mesh
            %
            %   showSignal(obj, signalIdx) displays signal at index signalIdx
            %   showSignal(obj, signalIdx, 'TimePoint', t) displays time point t
            %
            %   Inputs:
            %       signalIdx - Signal index (1-based)
            %
            %   Name-Value Parameters:
            %       'TimePoint' - Time point to display (default: current)
            
            if isempty(obj.BctObject)
                warning('ManifoldViewer:NoBct', 'No Bct object loaded');
                return;
            end
            
            if isempty(obj.BctObject.Signals)
                warning('ManifoldViewer:NoSignals', ...
                    'Bct object has no signals. Use showMesh() instead.');
                obj.showMesh();
                return;
            end
            
            % Parse optional time point
            p = inputParser;
            addParameter(p, 'TimePoint', obj.CurrentTimePoint, @isnumeric);
            parse(p, varargin{:});
            
            obj.CurrentSignal = signalIdx;
            obj.CurrentTimePoint = p.Results.TimePoint;
            
            % Use the copied visualizer function
            obj.Viewer3D = visualizer(obj.BctObject, ...
                'Parent', obj.ParentContainer, ...
                'Signal', signalIdx, ...
                'TimePoint', obj.CurrentTimePoint, ...
                'ColorMap', obj.ColorMap, ...
                'WireFrame', obj.WireframeMode, ...
                'Center', obj.CenterMesh, ...
                'Alpha', obj.AlphaValue);
            
            % Update HTML component if exists
            if ~isempty(obj.HTML)
                obj.send(struct(...
                    'cmd', 'signalChanged', ...
                    'signalIdx', signalIdx, ...
                    'timePoint', obj.CurrentTimePoint...
                ));
            end
        end
        
        function setColorMap(obj, colormapName)
            %SETCOLORMAP Change the colormap
            %
            %   setColorMap(obj, 'parula') sets colormap to parula
            %
            %   Available: parula, turbo, jet, hot, viridis, etc.
            
            obj.ColorMap = colormapName;
            
            % Refresh display if signal is shown
            if ~isempty(obj.CurrentSignal)
                obj.showSignal(obj.CurrentSignal);
            end
        end
        
        function setTimePoint(obj, timePoint)
            %SETTIMEPOINT Jump to specific time point
            %
            %   setTimePoint(obj, t) displays time point t
            
            if isempty(obj.BctObject)
                return;
            end
            
            numTimePoints = obj.getNumTimePoints();
            if timePoint < 1 || timePoint > numTimePoints
                warning('ManifoldViewer:InvalidTimePoint', ...
                    'Time point must be between 1 and %d', numTimePoints);
                return;
            end
            
            obj.CurrentTimePoint = timePoint;
            
            % Refresh display if signal is shown
            if ~isempty(obj.CurrentSignal)
                obj.showSignal(obj.CurrentSignal);
            end
        end
        
        function animate(obj, varargin)
            %ANIMATE Start/stop animation for time-varying signals
            %
            %   animate(obj) toggles animation on/off
            %   animate(obj, 'start') starts animation
            %   animate(obj, 'stop') stops animation
            %   animate(obj, 'speed', fps) sets animation speed
            
            if isempty(obj.BctObject) || isempty(obj.CurrentSignal)
                warning('ManifoldViewer:NoSignal', ...
                    'Load a Bct object and display a signal first');
                return;
            end
            
            numTimePoints = obj.getNumTimePoints();
            if numTimePoints <= 1
                warning('ManifoldViewer:NoTimeVariation', ...
                    'Signal is not time-varying');
                return;
            end
            
            % Parse inputs
            if nargin > 1
                action = varargin{1};
            else
                action = 'toggle';
            end
            
            switch lower(action)
                case 'start'
                    obj.startAnimation();
                case 'stop'
                    obj.stopAnimation();
                case 'toggle'
                    if obj.IsAnimating
                        obj.stopAnimation();
                    else
                        obj.startAnimation();
                    end
                case 'speed'
                    if nargin > 2
                        obj.AnimationSpeed = varargin{2};
                    end
            end
        end
        
        function setAnimationSpeed(obj, fps)
            %SETANIMATIONSPEED Control animation playback speed
            %
            %   setAnimationSpeed(obj, 30) sets speed to 30 frames/second
            
            obj.AnimationSpeed = max(1, min(120, fps));  % Clamp to 1-120 FPS
            
            % Update timer if animating
            if obj.IsAnimating && ~isempty(obj.AnimationTimer)
                obj.AnimationTimer.Period = 1 / obj.AnimationSpeed;
            end
        end
        
        function center(obj, doCenter)
            %CENTER Center mesh at origin
            %
            %   center(obj, true) enables centering
            %   center(obj, false) disables centering
            
            obj.CenterMesh = doCenter;
            obj.refresh();
        end
        
        function setWireframe(obj, enable)
            %SETWIREFRAME Toggle wireframe display
            %
            %   setWireframe(obj, true) shows wireframe
            %   setWireframe(obj, false) hides wireframe
            
            obj.WireframeMode = enable;
            obj.refresh();
        end
        
        function setAlpha(obj, alpha)
            %SETALPHA Set mesh transparency
            %
            %   setAlpha(obj, 0.5) sets 50% transparency
            %
            %   Input:
            %       alpha - Value between 0 (transparent) and 1 (opaque)
            
            obj.AlphaValue = max(0, min(1, alpha));
            obj.refresh();
        end
        
        function exportImage(obj, filename, varargin)
            %EXPORTIMAGE Export current view as image
            %
            %   exportImage(obj, 'output.png') saves to PNG
            %   exportImage(obj, 'output.png', 'Resolution', 300) sets DPI
            
            if isempty(obj.Viewer3D)
                warning('ManifoldViewer:NoViewer', 'No active visualization');
                return;
            end
            
            % Get viewer figure
            fig = ancestor(obj.Viewer3D, 'figure');
            if isempty(fig)
                warning('ManifoldViewer:NoFigure', 'Cannot find figure');
                return;
            end
            
            % Export
            exportgraphics(fig, filename, varargin{:});
        end
        
        function reset(obj)
            %RESET Reset view to defaults
            
            obj.CurrentTimePoint = 1;
            obj.ColorMap = 'parula';
            obj.CenterMesh = true;
            obj.WireframeMode = false;
            obj.AlphaValue = 1.0;
            obj.stopAnimation();
            
            if ~isempty(obj.BctObject)
                if ~isempty(obj.CurrentSignal)
                    obj.showSignal(obj.CurrentSignal);
                else
                    obj.showMesh();
                end
            end
        end
    end
    
    methods (Access = private)
        function numTimePoints = getNumTimePoints(obj)
            %GETNUMTIMEPOINTS Get number of time points
            
            if isempty(obj.BctObject) || isempty(obj.BctObject.Time)
                numTimePoints = 1;
            else
                numTimePoints = obj.BctObject.Time.T;
            end
        end
        
        function startAnimation(obj)
            %STARTANIMATION Start animation timer
            
            obj.IsAnimating = true;
            
            % Create timer if doesn't exist
            if isempty(obj.AnimationTimer) || ~isvalid(obj.AnimationTimer)
                obj.AnimationTimer = timer(...
                    'ExecutionMode', 'fixedRate', ...
                    'Period', 1 / obj.AnimationSpeed, ...
                    'TimerFcn', @(~,~) obj.advanceFrame());
            end
            
            start(obj.AnimationTimer);
            
            % Update HTML component
            if ~isempty(obj.HTML)
                obj.send(struct('cmd', 'animationStarted'));
            end
        end
        
        function stopAnimation(obj)
            %STOPANIMATION Stop animation timer
            
            obj.IsAnimating = false;
            
            if ~isempty(obj.AnimationTimer) && isvalid(obj.AnimationTimer)
                stop(obj.AnimationTimer);
            end
            
            % Update HTML component
            if ~isempty(obj.HTML)
                obj.send(struct('cmd', 'animationStopped'));
            end
        end
        
        function advanceFrame(obj)
            %ADVANCEFRAME Advance to next time point
            
            numTimePoints = obj.getNumTimePoints();
            obj.CurrentTimePoint = obj.CurrentTimePoint + 1;
            
            if obj.CurrentTimePoint > numTimePoints
                obj.CurrentTimePoint = 1;  % Loop
            end
            
            % Update display
            obj.showSignal(obj.CurrentSignal, 'TimePoint', obj.CurrentTimePoint);
            
            % Update HTML component
            if ~isempty(obj.HTML)
                obj.send(struct(...
                    'cmd', 'timePointChanged', ...
                    'timePoint', obj.CurrentTimePoint...
                ));
            end
        end
        
        function refresh(obj)
            %REFRESH Refresh the current display
            
            if ~isempty(obj.CurrentSignal)
                obj.showSignal(obj.CurrentSignal);
            elseif ~isempty(obj.BctObject)
                obj.showMesh();
            end
        end
    end
    
    methods
        function onMessage(obj, data)
            %ONMESSAGE Handle messages from JavaScript (if HTML component exists)
            
            if ~isfield(data, 'cmd')
                return;
            end
            
            switch data.cmd
                case 'loadBct'
                    % Could trigger file browser or load from workspace
                    
                case 'showMesh'
                    obj.showMesh();
                    
                case 'showSignal'
                    if isfield(data, 'signalIdx')
                        obj.showSignal(data.signalIdx);
                    end
                    
                case 'setColorMap'
                    if isfield(data, 'colormap')
                        obj.setColorMap(data.colormap);
                    end
                    
                case 'setTimePoint'
                    if isfield(data, 'timePoint')
                        obj.setTimePoint(data.timePoint);
                    end
                    
                case 'animate'
                    if isfield(data, 'action')
                        obj.animate(data.action);
                    else
                        obj.animate();
                    end
                    
                case 'setAnimationSpeed'
                    if isfield(data, 'fps')
                        obj.setAnimationSpeed(data.fps);
                    end
                    
                case 'setWireframe'
                    if isfield(data, 'enable')
                        obj.setWireframe(data.enable);
                    end
                    
                case 'setAlpha'
                    if isfield(data, 'alpha')
                        obj.setAlpha(data.alpha);
                    end
                    
                case 'center'
                    if isfield(data, 'enable')
                        obj.center(data.enable);
                    end
                    
                case 'reset'
                    obj.reset();
                    
                case 'export'
                    if isfield(data, 'filename')
                        obj.exportImage(data.filename);
                    end
            end
        end
        
        function delete(obj)
            %DELETE Cleanup when object is destroyed
            
            % Stop and delete timer
            if ~isempty(obj.AnimationTimer) && isvalid(obj.AnimationTimer)
                stop(obj.AnimationTimer);
                delete(obj.AnimationTimer);
            end
            
            % Remove show path
            if ~isempty(obj.ShowPath) && exist(obj.ShowPath, 'dir')
                rmpath(obj.ShowPath);
            end
        end
    end
end
