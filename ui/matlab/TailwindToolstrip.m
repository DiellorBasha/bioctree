classdef TailwindToolstrip < Component
    %TailwindToolstrip Wrapper for Tailwind-based Toolstrip component
    %
    %   Provides MATLAB interface for the Tailwind Toolstrip HTML component.
    %   This version is portable and not tied to the +bct package structure.
    %
    %   Location: ui/matlab/TailwindToolstrip.m
    %
    %   Usage:
    %       % Add ui/matlab to path
    %       addpath('ui/matlab');
    %       
    %       % In App Designer or figure
    %       app.Toolstrip = TailwindToolstrip(app, app.HTMLToolstrip);
    %       app.Toolstrip.addGroup(...);
    %
    %   See also: Component, TailwindSidebar, TailwindPlotPanel
    
    properties (Access = public)
        ButtonGroups = {}  % Cell array of button group configurations
    end
    
    properties (Access = private)
        ButtonState = struct()  % Tracks enabled/active state of buttons
    end
    
    methods
        function obj = TailwindToolstrip(app, htmlControl)
            % Call superclass constructor
            obj@Component(app, htmlControl, 'toolstrip');
            
            % Set path to Tailwind components directory
            % Find ui directory relative to this file
            thisFile = mfilename('fullpath');
            matlabDir = fileparts(thisFile);  % ui/matlab
            uiDir = fileparts(matlabDir);      % ui
            obj.HTMLPath = fullfile(uiDir, 'tailwind', 'components');
            
            % Load HTML
            obj.loadHTML('toolstrip.html');
        end
        
        function addGroup(obj, groupConfig)
            % Validate required fields
            assert(isfield(groupConfig, 'id'), 'Group must have an id field');
            assert(isfield(groupConfig, 'label'), 'Group must have a label field');
            assert(isfield(groupConfig, 'buttons'), 'Group must have a buttons field');
            
            % Add to internal list
            obj.ButtonGroups{end+1} = groupConfig;
            
            % Initialize button states
            for i = 1:numel(groupConfig.buttons)
                btn = groupConfig.buttons{i};
                obj.ButtonState.(btn.id) = struct('enabled', true, 'active', false);
            end
            
            % Send to JavaScript
            obj.send(struct('cmd', 'addGroup', 'group', groupConfig));
        end
        
        function removeGroup(obj, groupId)
            % Remove from internal list
            for i = 1:numel(obj.ButtonGroups)
                if strcmp(obj.ButtonGroups{i}.id, groupId)
                    % Clean up button states
                    for j = 1:numel(obj.ButtonGroups{i}.buttons)
                        btnId = obj.ButtonGroups{i}.buttons{j}.id;
                        if isfield(obj.ButtonState, btnId)
                            obj.ButtonState = rmfield(obj.ButtonState, btnId);
                        end
                    end
                    obj.ButtonGroups(i) = [];
                    break;
                end
            end
            
            % Send to JavaScript
            obj.send(struct('cmd', 'removeGroup', 'groupId', groupId));
        end
        
        function addButton(obj, groupId, buttonConfig)
            % Find the group
            for i = 1:numel(obj.ButtonGroups)
                if strcmp(obj.ButtonGroups{i}.id, groupId)
                    % Add to group
                    obj.ButtonGroups{i}.buttons{end+1} = buttonConfig;
                    
                    % Initialize state
                    obj.ButtonState.(buttonConfig.id) = struct('enabled', true, 'active', false);
                    
                    % Send to JavaScript
                    obj.send(struct('cmd', 'addButton', 'groupId', groupId, 'button', buttonConfig));
                    return;
                end
            end
            
            warning('TailwindToolstrip:GroupNotFound', 'Group "%s" not found', groupId);
        end
        
        function removeButton(obj, buttonId)
            % Remove from internal list
            for i = 1:numel(obj.ButtonGroups)
                for j = 1:numel(obj.ButtonGroups{i}.buttons)
                    if strcmp(obj.ButtonGroups{i}.buttons{j}.id, buttonId)
                        obj.ButtonGroups{i}.buttons(j) = [];
                        
                        % Clean up state
                        if isfield(obj.ButtonState, buttonId)
                            obj.ButtonState = rmfield(obj.ButtonState, buttonId);
                        end
                        
                        % Send to JavaScript
                        obj.send(struct('cmd', 'removeButton', 'buttonId', buttonId));
                        return;
                    end
                end
            end
        end
        
        function setButtonEnabled(obj, buttonId, enabled)
            % Update state
            if isfield(obj.ButtonState, buttonId)
                obj.ButtonState.(buttonId).enabled = enabled;
            end
            
            % Send to JavaScript
            obj.send(struct('cmd', 'setButtonEnabled', 'buttonId', buttonId, 'enabled', enabled));
        end
        
        function setButtonActive(obj, buttonId, active)
            % Update state
            if isfield(obj.ButtonState, buttonId)
                obj.ButtonState.(buttonId).active = active;
            end
            
            % Send to JavaScript
            obj.send(struct('cmd', 'setButtonActive', 'buttonId', buttonId, 'active', active));
        end
        
        function onMessage(obj, data)
            switch data.cmd
                case 'buttonClick'
                    % Route to app method based on button cmd
                    if isfield(data, 'button') && isfield(data.button, 'cmd')
                        methodName = data.button.cmd;
                        
                        % Call app method if it exists
                        if ismethod(obj.App, methodName)
                            try
                                obj.App.(methodName)();
                            catch ME
                                warning('TailwindToolstrip:CallbackError', ...
                                    'Error executing callback "%s": %s', methodName, ME.message);
                            end
                        else
                            warning('TailwindToolstrip:MethodNotFound', ...
                                'App method "%s" not found', methodName);
                        end
                    end
                    
                otherwise
                    warning('TailwindToolstrip:UnknownCommand', 'Unknown command: %s', data.cmd);
            end
        end
        
        function clearAll(obj)
            obj.ButtonGroups = {};
            obj.ButtonState = struct();
            obj.send(struct('cmd', 'clearAll'));
        end
    end
end
