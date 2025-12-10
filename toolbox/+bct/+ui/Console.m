classdef Console < bct.ui.Component
    %CONSOLE HTML-based console component for BCT applications
    %
    %   The Console provides a logging and output display panel with
    %   support for different message types (info, warning, error),
    %   filtering, and command input.
    %
    %   Properties:
    %       MaxMessages     - Maximum number of messages to keep (default: 1000)
    %       AutoScroll      - Automatically scroll to bottom (default: true)
    %       ShowTimestamps  - Show timestamps for messages (default: true)
    %       FilterLevel     - Minimum message level to display
    %
    %   Methods:
    %       log        - Log an info message
    %       warn       - Log a warning message
    %       error      - Log an error message
    %       success    - Log a success message
    %       clear      - Clear all messages
    %       setFilter  - Set message filter level
    %       export     - Export console contents
    %
    %   Example:
    %       % In App Designer:
    %       app.Console = bct.ui.Console(app, app.HTMLConsole);
    %
    %       % Log messages:
    %       app.Console.log('Mesh loaded successfully');
    %       app.Console.warn('Eigenbasis computation may take several minutes');
    %       app.Console.error('Invalid signal dimensions');
    %
    %   See also: bct.ui.Component, bct.ui.Toolstrip
    
    properties (Access = public)
        MaxMessages     % Maximum messages to keep
        AutoScroll      % Auto-scroll to bottom
        ShowTimestamps  % Show message timestamps
        FilterLevel     % Message filter level (0=all, 1=info, 2=warn, 3=error)
    end
    
    properties (Access = private)
        MessageCount    % Total number of messages logged
    end
    
    methods
        function obj = Console(app, htmlComponent)
            %CONSOLE Construct a Console instance
            %
            %   obj = Console(app, htmlComponent) creates a console
            %   component and loads its HTML interface.
            
            % Call superclass constructor
            obj@bct.ui.Component(app, htmlComponent, "Console");
            
            % Initialize properties
            obj.MaxMessages = 1000;
            obj.AutoScroll = true;
            obj.ShowTimestamps = true;
            obj.FilterLevel = 0;  % Show all by default
            obj.MessageCount = 0;
            
            % Load the HTML interface
            obj.loadHTML("console.html");
            
            % Send initial configuration
            obj.sendConfiguration();
        end
        
        function log(obj, message, varargin)
            %LOG Log an info message
            %
            %   log(obj, message) logs an informational message.
            %   log(obj, format, args...) logs a formatted message.
            
            if nargin > 2
                message = sprintf(message, varargin{:});
            end
            obj.sendMessage('info', message);
        end
        
        function warn(obj, message, varargin)
            %WARN Log a warning message
            %
            %   warn(obj, message) logs a warning message.
            
            if nargin > 2
                message = sprintf(message, varargin{:});
            end
            obj.sendMessage('warning', message);
        end
        
        function error(obj, message, varargin)
            %ERROR Log an error message
            %
            %   error(obj, message) logs an error message.
            
            if nargin > 2
                message = sprintf(message, varargin{:});
            end
            obj.sendMessage('error', message);
        end
        
        function success(obj, message, varargin)
            %SUCCESS Log a success message
            %
            %   success(obj, message) logs a success message.
            
            if nargin > 2
                message = sprintf(message, varargin{:});
            end
            obj.sendMessage('success', message);
        end
        
        function clear(obj)
            %CLEAR Clear all messages from the console
            
            obj.MessageCount = 0;
            obj.send(struct('cmd', 'clear'));
        end
        
        function setFilter(obj, level)
            %SETFILTER Set message filter level
            %
            %   setFilter(obj, level) sets the minimum message level to
            %   display. Levels: 0=all, 1=info+, 2=warn+, 3=error only
            
            obj.FilterLevel = level;
            obj.send(struct('cmd', 'setFilter', 'level', level));
        end
        
        function exportLog(obj, filename)
            %EXPORTLOG Export console contents to file
            %
            %   exportLog(obj, filename) saves console messages to a file.
            
            if nargin < 2
                [file, path] = uiputfile('*.txt', 'Save Console Log');
                if isequal(file, 0)
                    return;
                end
                filename = fullfile(path, file);
            end
            
            % Request export from JavaScript
            obj.send(struct('cmd', 'export', 'filename', filename));
        end
        
        function setMaxMessages(obj, maxMessages)
            %SETMAXMESSAGES Set maximum number of messages to keep
            
            obj.MaxMessages = maxMessages;
            obj.send(struct('cmd', 'setMaxMessages', 'max', maxMessages));
        end
        
        function setAutoScroll(obj, enabled)
            %SETAUTOSCROLL Enable/disable auto-scrolling
            
            obj.AutoScroll = enabled;
            obj.send(struct('cmd', 'setAutoScroll', 'enabled', enabled));
        end
        
        function onMessage(obj, data)
            %ONMESSAGE Handle messages from JavaScript
            
            if ~isfield(data, 'cmd')
                return;
            end
            
            cmd = data.cmd;
            
            switch cmd
                case "command"
                    obj.handleCommand(data.input);
                    
                case "exportData"
                    obj.handleExport(data.content, data.filename);
                    
                case "ready"
                    obj.sendConfiguration();
                    
                otherwise
                    warning('bct:ui:Console:UnknownCommand', ...
                        'Unknown command: %s', cmd);
            end
        end
    end
    
    methods (Access = private)
        function sendConfiguration(obj)
            %SENDCONFIGURATION Send configuration to JavaScript
            
            config = struct(...
                'maxMessages', obj.MaxMessages, ...
                'autoScroll', obj.AutoScroll, ...
                'showTimestamps', obj.ShowTimestamps, ...
                'filterLevel', obj.FilterLevel);
            
            obj.send(struct('cmd', 'configure', 'config', config));
        end
        
        function sendMessage(obj, level, text)
            %SENDMESSAGE Send a log message to JavaScript
            
            obj.MessageCount = obj.MessageCount + 1;
            
            msg = struct(...
                'id', obj.MessageCount, ...
                'level', level, ...
                'text', text, ...
                'timestamp', posixtime(datetime('now')));
            
            obj.send(struct('cmd', 'message', 'message', msg));
        end
        
        function handleCommand(obj, input)
            %HANDLECOMMAND Handle command input from console
            
            % Route to app if it has a command handler
            if ismethod(obj.App, 'handleConsoleCommand')
                obj.App.handleConsoleCommand(input);
            else
                % Try to evaluate as MATLAB code (use with caution!)
                try
                    evalin('base', input);
                    obj.success('Command executed');
                catch ME
                    obj.error('Command failed: %s', ME.message);
                end
            end
        end
        
        function handleExport(obj, content, filename)
            %HANDLEEXPORT Handle export request from JavaScript
            
            try
                fid = fopen(filename, 'w');
                if fid == -1
                    error('Could not open file for writing');
                end
                
                fprintf(fid, '%s', content);
                fclose(fid);
                
                obj.success('Log exported to: %s', filename);
            catch ME
                obj.error('Export failed: %s', ME.message);
            end
        end
    end
end
