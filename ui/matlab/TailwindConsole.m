classdef TailwindConsole < Component
    %TailwindConsole Wrapper for Tailwind-based Console component
    %
    %   Provides MATLAB interface for the Tailwind Console HTML component.
    %   Terminal-style logging panel with filtering capabilities.
    %
    %   Location: ui/matlab/TailwindConsole.m
    %
    %   Usage:
    %       % Add ui/matlab to path
    %       addpath('ui/matlab');
    %       
    %       % In App Designer or figure
    %       fig = uifigure('Name', 'Console Test');
    %       console = TailwindConsole(fig, [0 0 800 400]);
    %       
    %       % Add messages
    %       console.log('info', 'Processing started...');
    %       console.log('success', 'Operation completed!');
    %       console.log('warning', 'High memory usage');
    %       console.log('error', 'Failed to load file');
    %
    %   See also: Component, TailwindToolstrip, TailwindSidebar
    
    properties (Access = public)
        Messages = {}  % Cell array of message structs
        MaxMessages = 1000  % Maximum messages to keep
    end
    
    properties (Access = private)
        CurrentFilter = 'all'  % Current filter level
    end
    
    methods
        function obj = TailwindConsole(parent, position)
            % Create HTML component
            if nargin < 2
                position = [0 0 800 400];
            end
            
            htmlControl = uihtml(parent);
            htmlControl.Position = position;
            
            % Call superclass constructor
            obj@Component([], htmlControl, 'console');
            
            % Set path to Tailwind components directory
            thisFile = mfilename('fullpath');
            matlabDir = fileparts(thisFile);
            uiDir = fileparts(matlabDir);
            obj.componentDir = fullfile(uiDir, 'tailwind', 'components');
            obj.distDir = fullfile(uiDir, 'tailwind', 'dist');
            
            % Load HTML
            html = obj.loadHTML('console');
            obj.HTMLComponent.HTMLSource = html;
        end
        
        function log(obj, level, text)
            % Add a message to the console
            % 
            % Inputs:
            %   level - 'info', 'success', 'warning', or 'error'
            %   text - Message text
            
            message = struct(...
                'level', level, ...
                'text', text, ...
                'timestamp', posixtime(datetime('now'))...
            );
            
            % Add to internal list
            obj.Messages{end+1} = message;
            
            % Enforce max messages
            if length(obj.Messages) > obj.MaxMessages
                obj.Messages(1) = [];
            end
            
            % Send to JavaScript
            obj.send(struct(...
                'cmd', 'addMessage', ...
                'message', message...
            ));
        end
        
        function info(obj, text)
            % Log info message
            obj.log('info', text);
        end
        
        function success(obj, text)
            % Log success message
            obj.log('success', text);
        end
        
        function warning(obj, text)
            % Log warning message
            obj.log('warning', text);
        end
        
        function error(obj, text)
            % Log error message
            obj.log('error', text);
        end
        
        function setFilter(obj, level)
            % Set message filter
            % 
            % Inputs:
            %   level - 'all', 'info', 'success', 'warning', or 'error'
            
            obj.CurrentFilter = level;
            obj.send(struct(...
                'cmd', 'setFilter', ...
                'filter', level...
            ));
        end
        
        function clear(obj)
            % Clear all messages
            obj.Messages = {};
            obj.send(struct('cmd', 'clear'));
        end
        
        function executeCommand(obj, command)
            % Execute a command (for command input)
            obj.send(struct(...
                'cmd', 'executeCommand', ...
                'command', command...
            ));
        end
    end
    
    methods
        function onMessage(obj, data)
            % Handle messages from JavaScript
            if ~isfield(data, 'cmd')
                return;
            end
            
            switch data.cmd
                case 'commandExecuted'
                    % Command was executed in console
                    if isfield(data, 'command')
                        % Could trigger callback here
                        obj.log('info', ['> ' data.command]);
                    end
                    
                case 'filterChanged'
                    % Filter was changed via UI
                    if isfield(data, 'filter')
                        obj.CurrentFilter = data.filter;
                    end
            end
        end
    end
end
