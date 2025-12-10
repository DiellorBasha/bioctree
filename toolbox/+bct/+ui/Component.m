classdef Component < handle
    %COMPONENT Base class for all HTML UI components in the BCT system
    %
    %   This abstract base class provides the foundation for creating
    %   reusable HTML-based UI components that communicate bidirectionally
    %   with MATLAB App Designer applications.
    %
    %   Properties:
    %       App          - Reference to parent App Designer app
    %       HTML         - Handle to matlab.ui.control.HTML object
    %       ID           - Unique identifier for this component instance
    %       State        - Component state data (struct)
    %       Enabled      - Whether the component is enabled
    %
    %   Methods:
    %       send         - Send data from MATLAB to JavaScript
    %       onMessage    - Handle incoming messages from JavaScript (abstract)
    %       loadHTML     - Load HTML file into the component
    %       setState     - Update component state and notify JavaScript
    %       getState     - Get current component state
    %       enable       - Enable the component
    %       disable      - Disable the component
    %
    %   Example:
    %       classdef MyComponent < bct.ui.Component
    %           methods
    %               function obj = MyComponent(app, htmlComponent)
    %                   obj@bct.ui.Component(app, htmlComponent, "MyComponent");
    %                   obj.loadHTML("mycomponent.html");
    %               end
    %
    %               function onMessage(obj, data)
    %                   % Handle messages from JavaScript
    %                   switch data.cmd
    %                       case "click"
    %                           obj.App.handleClick(data.value);
    %                   end
    %               end
    %           end
    %       end
    %
    %   See also: bct.ui.Toolstrip, bct.ui.Sidebar, bct.ui.Console
    
    properties (Access = public)
        App          % Reference to App Designer app
        HTML         % HTML UI Component handle
        ID           % Component ID for routing
        State        % Component state data
        Enabled      % Whether component is enabled
    end
    
    properties (Access = protected)
        HTMLPath     % Path to HTML files
        JSPath       % Path to JS files
        CSSPath      % Path to CSS files
    end
    
    methods
        function obj = Component(app, htmlComponent, id)
            %COMPONENT Construct a UI component instance
            %
            %   obj = Component(app, htmlComponent, id) creates a new
            %   component with the given ID attached to the app.
            %
            %   Inputs:
            %       app            - Parent App Designer application
            %       htmlComponent  - matlab.ui.control.HTML object
            %       id             - Unique string identifier
            
            obj.App = app;
            obj.HTML = htmlComponent;
            obj.ID = id;
            obj.State = struct();
            obj.Enabled = true;
            
            % Set up paths to component resources
            componentPath = fileparts(mfilename('fullpath'));
            obj.HTMLPath = fullfile(componentPath, 'html');
            obj.JSPath = fullfile(componentPath, 'js');
            obj.CSSPath = fullfile(componentPath, 'css');
            
            % Setup MATLAB->JS messaging callback
            obj.HTML.DataChangedFcn = @(src, evt) obj.handleMessage(evt.Data);
        end
        
        function send(obj, message)
            %SEND Send data from MATLAB to JavaScript
            %
            %   send(obj, message) sends a message struct to the JavaScript
            %   environment. The message is automatically tagged with the
            %   component ID.
            %
            %   Input:
            %       message - Struct containing data to send
            %
            %   Example:
            %       obj.send(struct('cmd', 'update', 'value', 42));
            
            if ~isstruct(message)
                message = struct('data', message);
            end
            
            message.id = obj.ID;
            message.timestamp = posixtime(datetime('now'));
            
            obj.HTML.Data = message;
        end
        
        function setState(obj, newState)
            %SETSTATE Update component state and notify JavaScript
            %
            %   setState(obj, newState) updates the component state with
            %   the provided struct and sends a state update message to
            %   the JavaScript side.
            %
            %   Input:
            %       newState - Struct with state fields to update
            
            % Merge new state with existing state
            fields = fieldnames(newState);
            for i = 1:length(fields)
                obj.State.(fields{i}) = newState.(fields{i});
            end
            
            % Notify JavaScript
            obj.send(struct('cmd', 'stateUpdate', 'state', obj.State));
        end
        
        function state = getState(obj)
            %GETSTATE Get current component state
            %
            %   state = getState(obj) returns the current state struct.
            
            state = obj.State;
        end
        
        function enable(obj)
            %ENABLE Enable the component
            %
            %   enable(obj) enables the component and notifies JavaScript.
            
            obj.Enabled = true;
            obj.send(struct('cmd', 'enable'));
        end
        
        function disable(obj)
            %DISABLE Disable the component
            %
            %   disable(obj) disables the component and notifies JavaScript.
            
            obj.Enabled = false;
            obj.send(struct('cmd', 'disable'));
        end
        
        function loadHTML(obj, filename)
            %LOADHTML Load HTML file into the component
            %
            %   loadHTML(obj, filename) loads the specified HTML file from
            %   the component's html directory.
            %
            %   Input:
            %       filename - Name of HTML file (e.g., 'toolstrip.html')
            
            fullPath = fullfile(obj.HTMLPath, filename);
            
            if ~isfile(fullPath)
                error('bct:ui:Component:HTMLNotFound', ...
                    'HTML file not found: %s', fullPath);
            end
            
            obj.HTML.HTMLSource = fullPath;
        end
    end
    
    methods (Access = private)
        function handleMessage(obj, data)
            %HANDLEMESSAGE Internal message handler with error checking
            %
            %   This method wraps the abstract onMessage method with error
            %   handling and logging.
            
            if isempty(data)
                return;
            end
            
            try
                % Call the subclass implementation
                obj.onMessage(data);
            catch ME
                warning('bct:ui:Component:MessageError', ...
                    'Error handling message in %s: %s', obj.ID, ME.message);
                
                % Send error back to JavaScript
                obj.send(struct('cmd', 'error', 'message', ME.message));
            end
        end
    end
    
    methods (Abstract)
        %ONMESSAGE Handle incoming messages from JavaScript
        %
        %   onMessage(obj, data) is called when JavaScript sends a message
        %   to MATLAB. Subclasses must implement this method to handle
        %   component-specific messages.
        %
        %   Input:
        %       data - Struct containing message data from JavaScript
        onMessage(obj, data)
    end
end
