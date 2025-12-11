classdef TailwindModal < Component
    %TailwindModal Wrapper for Tailwind-based Modal component
    %
    %   Provides MATLAB interface for the Tailwind Modal HTML component.
    %   Reusable modal dialog system with alert, confirm, and prompt types.
    %
    %   Location: ui/matlab/TailwindModal.m
    %
    %   Usage:
    %       % Add ui/matlab to path
    %       addpath('ui/matlab');
    %       
    %       % In App Designer or figure
    %       fig = uifigure('Name', 'Modal Test');
    %       modal = TailwindModal(fig, [0 0 600 400]);
    %       
    %       % Show alert
    %       modal.alert('Information', 'Operation completed successfully!');
    %       
    %       % Show confirm (returns true/false when modal closes)
    %       modal.confirm('Confirm', 'Are you sure?', @(result) disp(result));
    %       
    %       % Show prompt (returns input value when modal closes)
    %       modal.prompt('Input', 'Enter name:', 'DefaultValue', @(value) disp(value));
    %
    %   See also: Component, TailwindToolstrip, TailwindSidebar
    
    properties (Access = public)
        IsOpen = false  % Whether modal is currently open
    end
    
    properties (Access = private)
        OnConfirmCallback = []  % Callback for confirm button
        OnCancelCallback = []   % Callback for cancel button
    end
    
    methods
        function obj = TailwindModal(parent, position)
            % Create HTML component
            if nargin < 2
                position = [0 0 600 400];
            end
            
            htmlControl = uihtml(parent);
            htmlControl.Position = position;
            
            % Call superclass constructor
            obj@Component([], htmlControl, 'modal');
            
            % Set path to Tailwind components directory
            thisFile = mfilename('fullpath');
            matlabDir = fileparts(thisFile);
            uiDir = fileparts(matlabDir);
            obj.componentDir = fullfile(uiDir, 'tailwind', 'components');
            obj.distDir = fullfile(uiDir, 'tailwind', 'dist');
            
            % Load HTML
            html = obj.loadHTML('modal');
            obj.HTMLComponent.HTMLSource = html;
        end
        
        function show(obj, title, content, type, options)
            % Show modal with custom content
            %
            % Inputs:
            %   title - Modal title
            %   content - Modal content (text or HTML)
            %   type - 'default', 'alert', 'confirm', or 'prompt'
            %   options - Optional struct with:
            %             - promptValue: Initial value for prompt type
            %             - onConfirm: Callback function for confirm
            %             - onCancel: Callback function for cancel
            
            if nargin < 4
                type = 'default';
            end
            if nargin < 5
                options = struct();
            end
            
            obj.IsOpen = true;
            
            % Store callbacks
            if isfield(options, 'onConfirm')
                obj.OnConfirmCallback = options.onConfirm;
            else
                obj.OnConfirmCallback = [];
            end
            
            if isfield(options, 'onCancel')
                obj.OnCancelCallback = options.onCancel;
            else
                obj.OnCancelCallback = [];
            end
            
            % Build message
            msg = struct(...
                'cmd', 'show', ...
                'title', title, ...
                'content', content, ...
                'type', type...
            );
            
            if isfield(options, 'promptValue')
                msg.promptValue = options.promptValue;
            end
            
            obj.send(msg);
        end
        
        function hide(obj)
            % Hide the modal
            obj.IsOpen = false;
            obj.send(struct('cmd', 'hide'));
        end
        
        function alert(obj, title, content, onClose)
            % Show alert modal
            %
            % Inputs:
            %   title - Alert title
            %   content - Alert message
            %   onClose - Optional callback when closed
            
            options = struct();
            if nargin >= 4 && ~isempty(onClose)
                options.onConfirm = onClose;
            end
            
            obj.show(title, content, 'alert', options);
        end
        
        function confirm(obj, title, content, onResult)
            % Show confirm modal
            %
            % Inputs:
            %   title - Confirm title
            %   content - Confirm message
            %   onResult - Callback function(confirmed) where confirmed is true/false
            
            options = struct();
            if nargin >= 4 && ~isempty(onResult)
                options.onConfirm = @() onResult(true);
                options.onCancel = @() onResult(false);
            end
            
            obj.show(title, content, 'confirm', options);
        end
        
        function prompt(obj, title, content, defaultValue, onResult)
            % Show prompt modal
            %
            % Inputs:
            %   title - Prompt title
            %   content - Prompt message
            %   defaultValue - Initial input value (optional)
            %   onResult - Callback function(value) with user input
            
            options = struct();
            
            if nargin >= 4 && ~isempty(defaultValue)
                options.promptValue = defaultValue;
            end
            
            if nargin >= 5 && ~isempty(onResult)
                options.onConfirm = @(value) onResult(value);
            end
            
            obj.show(title, content, 'prompt', options);
        end
    end
    
    methods
        function onMessage(obj, data)
            % Handle messages from JavaScript
            if ~isfield(data, 'cmd')
                return;
            end
            
            switch data.cmd
                case 'confirmed'
                    % User clicked confirm
                    obj.IsOpen = false;
                    
                    if ~isempty(obj.OnConfirmCallback)
                        if isfield(data, 'value')
                            % Prompt with value
                            obj.OnConfirmCallback(data.value);
                        else
                            % Simple confirm
                            obj.OnConfirmCallback();
                        end
                    end
                    
                case 'cancelled'
                    % User clicked cancel or close
                    obj.IsOpen = false;
                    
                    if ~isempty(obj.OnCancelCallback)
                        obj.OnCancelCallback();
                    end
            end
        end
    end
end
