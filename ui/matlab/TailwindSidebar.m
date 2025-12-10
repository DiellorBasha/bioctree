classdef TailwindSidebar < Component
    %TailwindSidebar Wrapper for Tailwind-based Sidebar component
    %
    %   Provides MATLAB interface for the Tailwind Sidebar HTML component.
    %   This version is portable and not tied to the +bct package structure.
    %
    %   Location: ui/matlab/TailwindSidebar.m
    %
    %   Usage:
    %       % Add ui/matlab to path
    %       addpath('ui/matlab');
    %       
    %       % In App Designer or figure
    %       app.Sidebar = TailwindSidebar(app, app.HTMLSidebar);
    %       app.Sidebar.addSection(...);
    %
    %   See also: Component, TailwindToolstrip, TailwindPlotPanel
    
    properties (Access = public)
        Sections = struct()  % Struct of section configurations
    end
    
    properties (Access = private)
        ControlValues = struct()  % Cache of current control values
    end
    
    methods
        function obj = TailwindSidebar(app, htmlControl)
            % Call superclass constructor
            obj@Component(app, htmlControl, 'sidebar');
            
            % Set path to Tailwind components directory
            % Find ui directory relative to this file
            thisFile = mfilename('fullpath');
            matlabDir = fileparts(thisFile);  % ui/matlab
            uiDir = fileparts(matlabDir);      % ui
            obj.HTMLPath = fullfile(uiDir, 'tailwind', 'components');
            
            % Load HTML
            obj.loadHTML('sidebar.html');
        end
        
        function addSection(obj, sectionConfig)
            % Validate required fields
            assert(isfield(sectionConfig, 'id'), 'Section must have an id field');
            assert(isfield(sectionConfig, 'title'), 'Section must have a title field');
            assert(isfield(sectionConfig, 'controls'), 'Section must have a controls field');
            
            % Set default collapsed state
            if ~isfield(sectionConfig, 'collapsed')
                sectionConfig.collapsed = false;
            end
            
            % Add to internal struct
            obj.Sections.(sectionConfig.id) = sectionConfig;
            
            % Cache control values
            for i = 1:numel(sectionConfig.controls)
                ctrl = sectionConfig.controls{i};
                if isfield(ctrl, 'value')
                    obj.ControlValues.(ctrl.id) = ctrl.value;
                end
            end
            
            % Send to JavaScript
            obj.send(struct('cmd', 'addSection', 'section', sectionConfig));
        end
        
        function removeSection(obj, sectionId)
            % Remove from internal struct
            if isfield(obj.Sections, sectionId)
                % Clean up control values
                section = obj.Sections.(sectionId);
                for i = 1:numel(section.controls)
                    ctrlId = section.controls{i}.id;
                    if isfield(obj.ControlValues, ctrlId)
                        obj.ControlValues = rmfield(obj.ControlValues, ctrlId);
                    end
                end
                
                obj.Sections = rmfield(obj.Sections, sectionId);
            end
            
            % Send to JavaScript
            obj.send(struct('cmd', 'removeSection', 'sectionId', sectionId));
        end
        
        function updateSection(obj, sectionId, updates)
            if isfield(obj.Sections, sectionId)
                % Update internal state
                fields = fieldnames(updates);
                for i = 1:numel(fields)
                    obj.Sections.(sectionId).(fields{i}) = updates.(fields{i});
                end
                
                % Send to JavaScript
                obj.send(struct('cmd', 'updateSection', 'sectionId', sectionId, 'updates', updates));
            end
        end
        
        function updateControl(obj, sectionId, controlId, value)
            % Update cached value
            obj.ControlValues.(controlId) = value;
            
            % Update section config
            if isfield(obj.Sections, sectionId)
                for i = 1:numel(obj.Sections.(sectionId).controls)
                    if strcmp(obj.Sections.(sectionId).controls{i}.id, controlId)
                        obj.Sections.(sectionId).controls{i}.value = value;
                        break;
                    end
                end
            end
            
            % Send to JavaScript
            obj.send(struct('cmd', 'updateControl', 'sectionId', sectionId, ...
                'controlId', controlId, 'value', value));
        end
        
        function value = getControlValue(obj, controlId)
            if isfield(obj.ControlValues, controlId)
                value = obj.ControlValues.(controlId);
            else
                value = [];
                warning('TailwindSidebar:ControlNotFound', 'Control "%s" not found', controlId);
            end
        end
        
        function setCollapsed(obj, sectionId, collapsed)
            if isfield(obj.Sections, sectionId)
                obj.Sections.(sectionId).collapsed = collapsed;
                obj.send(struct('cmd', 'setCollapsed', 'sectionId', sectionId, 'collapsed', collapsed));
            end
        end
        
        function onMessage(obj, data)
            switch data.cmd
                case 'controlChange'
                    % Update cached value
                    obj.ControlValues.(data.controlId) = data.value;
                    
                    % Call app callback: <controlId>Changed(value)
                    methodName = sprintf('%sChanged', data.controlId);
                    if ismethod(obj.App, methodName)
                        try
                            obj.App.(methodName)(data.value);
                        catch ME
                            warning('TailwindSidebar:CallbackError', ...
                                'Error executing callback "%s": %s', methodName, ME.message);
                        end
                    end
                    
                case 'buttonClick'
                    % Call app method based on button command
                    if isfield(data, 'command')
                        methodName = data.command;
                        if ismethod(obj.App, methodName)
                            try
                                obj.App.(methodName)();
                            catch ME
                                warning('TailwindSidebar:CallbackError', ...
                                    'Error executing callback "%s": %s', methodName, ME.message);
                            end
                        end
                    end
                    
                case 'sectionToggle'
                    % Update collapsed state
                    if isfield(data, 'sectionId') && isfield(obj.Sections, data.sectionId)
                        obj.Sections.(data.sectionId).collapsed = data.collapsed;
                    end
                    
                otherwise
                    warning('TailwindSidebar:UnknownCommand', 'Unknown command: %s', data.cmd);
            end
        end
        
        function clearAll(obj)
            obj.Sections = struct();
            obj.ControlValues = struct();
            obj.send(struct('cmd', 'clearAll'));
        end
    end
end
