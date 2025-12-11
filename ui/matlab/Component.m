classdef Component < handle
    %COMPONENT Base class for HTML UI components
    %
    %   This abstract base class provides the foundation for creating
    %   reusable HTML-based UI components that communicate bidirectionally
    %   with MATLAB applications (App Designer or standalone figures).
    %
    %   Location: ui/matlab/Component.m (not in +bct package)
    %   This allows the Tailwind UI system to be portable and independent
    %   of the BCT package structure.
    %
    %   Properties:
    %       App          - Reference to parent application
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
    %       classdef MyComponent < Component
    %           methods
    %               function obj = MyComponent(app, htmlComponent)
    %                   obj@Component(app, htmlComponent, "MyComponent");
    %                   obj.HTMLPath = fullfile(pwd, 'ui', 'tailwind', 'components');
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
    %   See also: TailwindToolstrip, TailwindSidebar, TailwindPlotPanel
    
    properties (Access = public)
        App          % Reference to parent application
        HTML         % HTML UI Component handle
        ID           % Component ID for routing
        State        % Component state data
        Enabled      % Whether component is enabled
    end
    
    properties (Access = protected)
        HTMLPath     % Path to HTML files directory
    end
    
    methods
        function obj = Component(app, htmlComponent, id)
            %COMPONENT Construct a UI component instance
            %
            %   obj = Component(app, htmlComponent, id) creates a new
            %   component with the given ID attached to the app.
            %
            %   Inputs:
            %       app            - Parent application
            %       htmlComponent  - matlab.ui.control.HTML object
            %       id             - Unique string identifier
            
            obj.App = app;
            obj.HTML = htmlComponent;
            obj.ID = id;
            obj.State = struct();
            obj.Enabled = true;
            
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
            
            % Tag with component ID
            message.componentId = obj.ID;
            
            % Send to JavaScript via Data property
            obj.HTML.Data = message;
        end
        
        function setState(obj, newState)
            %SETSTATE Update component state and notify JavaScript
            %
            %   setState(obj, newState) merges newState into the current
            %   state and sends an update notification to JavaScript.
            %
            %   Input:
            %       newState - Struct with fields to update
            
            % Merge state
            fields = fieldnames(newState);
            for i = 1:numel(fields)
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
            
            obj.Enabled = true;
            obj.send(struct('cmd', 'enable'));
        end
        
        function disable(obj)
            %DISABLE Disable the component
            
            obj.Enabled = false;
            obj.send(struct('cmd', 'disable'));
        end
        
        function loadHTML(obj, filename)
            %LOADHTML Load HTML file into the component
            %
            %   loadHTML(obj, filename) loads the specified HTML file from
            %   the component's HTMLPath directory and inlines CSS/JS for
            %   MATLAB uihtml compatibility.
            %
            %   Input:
            %       filename - Name of HTML file (e.g., 'toolstrip.html')
            
            fullPath = fullfile(obj.HTMLPath, filename);
            
            if ~isfile(fullPath)
                error('ui:Component:HTMLNotFound', ...
                    'HTML file not found: %s', fullPath);
            end
            
            % Read HTML content
            htmlContent = fileread(fullPath);
            
            % Get directory paths
            componentDir = fileparts(fullPath);  % ui/tailwind/components
            tailwindDir = fileparts(componentDir);  % ui/tailwind
            distDir = fullfile(tailwindDir, 'dist');
            
            % Read CSS and JS files
            cssPath = fullfile(distDir, 'bct-ui.css');
            jsPath = fullfile(distDir, 'bct-ui.js');
            componentJsPath = fullfile(componentDir, strrep(filename, '.html', '.js'));
            
            if ~isfile(cssPath)
                error('ui:Component:CSSNotFound', 'CSS file not found: %s', cssPath);
            end
            if ~isfile(jsPath)
                error('ui:Component:JSNotFound', 'JS file not found: %s', jsPath);
            end
            
            cssContent = fileread(cssPath);
            jsContent = fileread(jsPath);
            
            % Read component-specific JS if it exists
            componentJsContent = '';
            if isfile(componentJsPath)
                componentJsContent = fileread(componentJsPath);
            end
            
            % Replace external CSS link with inline style
            htmlContent = strrep(htmlContent, ...
                '<link rel="stylesheet" href="../dist/bct-ui.css">', ...
                ['<style>' cssContent '</style>']);
            
            % Replace external JS script with inline script
            htmlContent = strrep(htmlContent, ...
                '<script src="../dist/bct-ui.js"></script>', ...
                ['<script>' jsContent '</script>']);
            
            % Replace component JS script with inline script
            if ~isempty(componentJsContent)
                componentJsName = strrep(filename, '.html', '.js');
                htmlContent = strrep(htmlContent, ...
                    ['<script src="./' componentJsName '"></script>'], ...
                    ['<script>' componentJsContent '</script>']);
            end
            
            % Set HTML source as string
            obj.HTML.HTMLSource = htmlContent;
        end
    end
    
    methods (Abstract)
        % Handle incoming messages from JavaScript
        %
        % Must be implemented by subclasses to define component-specific
        % message handling logic.
        %
        % Input:
        %   data - Struct containing message data from JavaScript
        onMessage(obj, data)
    end
    
    methods (Access = private)
        function handleMessage(obj, data)
            %HANDLEMESSAGE Internal message handler with error checking
            %
            %   This method wraps the abstract onMessage method with error
            %   handling and logging.
            
            try
                obj.onMessage(data);
            catch ME
                warning('ui:Component:MessageError', ...
                    'Error handling message in component "%s": %s', ...
                    obj.ID, ME.message);
            end
        end
    end
end
