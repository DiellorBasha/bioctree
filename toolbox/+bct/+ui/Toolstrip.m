classdef Toolstrip < bct.ui.Component
    %TOOLSTRIP HTML-based toolstrip component for BCT applications
    %
    %   The Toolstrip provides a horizontal toolbar with buttons for
    %   common operations such as loading meshes, computing eigenbases,
    %   opening filter designers, and managing visualizations.
    %
    %   Properties:
    %       Buttons      - Cell array of button definitions
    %       ButtonGroups - Struct defining button groups
    %
    %   Methods:
    %       addButton       - Add a custom button to the toolstrip
    %       removeButton    - Remove a button by ID
    %       enableButton    - Enable a specific button
    %       disableButton   - Disable a specific button
    %       setButtonState  - Update button state (active/inactive)
    %
    %   Example:
    %       % In App Designer startupFcn:
    %       app.Toolstrip = bct.ui.Toolstrip(app, app.HTMLToolstrip);
    %
    %       % Add custom button:
    %       app.Toolstrip.addButton('myBtn', 'My Action', 'custom-icon', ...
    %           @(~,~) app.handleMyAction());
    %
    %   See also: bct.ui.Component, bct.ui.Sidebar
    
    properties (Access = public)
        Buttons      % Cell array of button definitions
        ButtonGroups % Button group definitions
    end
    
    methods
        function obj = Toolstrip(app, htmlComponent)
            %TOOLSTRIP Construct a Toolstrip instance
            %
            %   obj = Toolstrip(app, htmlComponent) creates a toolstrip
            %   component and loads its HTML interface.
            
            % Call superclass constructor
            obj@bct.ui.Component(app, htmlComponent, "Toolstrip");
            
            % Initialize button definitions
            obj.initializeButtons();
            
            % Load the HTML interface
            obj.loadHTML("toolstrip.html");
            
            % Send initial configuration
            obj.sendConfiguration();
        end
        
        function addButton(obj, id, label, icon, group)
            %ADDBUTTON Add a custom button to the toolstrip
            %
            %   addButton(obj, id, label, icon, group) adds a new button
            %   with the specified properties.
            %
            %   Inputs:
            %       id    - Unique button identifier
            %       label - Button display text
            %       icon  - Icon class or emoji
            %       group - Group name (optional)
            
            if nargin < 5
                group = 'custom';
            end
            
            button = struct(...
                'id', id, ...
                'label', label, ...
                'icon', icon, ...
                'group', group, ...
                'enabled', true);
            
            obj.Buttons{end+1} = button;
            obj.send(struct('cmd', 'addButton', 'button', button));
        end
        
        function removeButton(obj, id)
            %REMOVEBUTTON Remove a button from the toolstrip
            %
            %   removeButton(obj, id) removes the button with the given ID.
            
            obj.Buttons = obj.Buttons(~strcmp(cellfun(@(b) b.id, ...
                obj.Buttons, 'UniformOutput', false), id));
            obj.send(struct('cmd', 'removeButton', 'id', id));
        end
        
        function enableButton(obj, id)
            %ENABLEBUTTON Enable a specific button
            %
            %   enableButton(obj, id) enables the button with given ID.
            
            obj.send(struct('cmd', 'enableButton', 'id', id));
        end
        
        function disableButton(obj, id)
            %DISABLEBUTTON Disable a specific button
            %
            %   disableButton(obj, id) disables the button with given ID.
            
            obj.send(struct('cmd', 'disableButton', 'id', id));
        end
        
        function setButtonState(obj, id, isActive)
            %SETBUTTONSTATE Set button active/inactive state
            %
            %   setButtonState(obj, id, isActive) sets the visual state
            %   of a button (useful for toggle buttons).
            
            obj.send(struct('cmd', 'setButtonState', 'id', id, ...
                'active', isActive));
        end
        
        function onMessage(obj, data)
            %ONMESSAGE Handle messages from JavaScript
            %
            %   Processes button click events and routes them to the
            %   appropriate app methods.
            
            if ~isfield(data, 'cmd')
                return;
            end
            
            cmd = data.cmd;
            
            switch cmd
                case "buttonClick"
                    obj.handleButtonClick(data.id);
                    
                case "ready"
                    % Toolstrip is ready, send configuration
                    obj.sendConfiguration();
                    
                otherwise
                    warning('bct:ui:Toolstrip:UnknownCommand', ...
                        'Unknown command: %s', cmd);
            end
        end
    end
    
    methods (Access = private)
        function initializeButtons(obj)
            %INITIALIZEBUTTONS Set up default button definitions
            
            obj.Buttons = {
                % Data Group
                struct('id', 'loadMesh', 'label', 'Load Mesh', ...
                    'icon', '📊', 'group', 'data', 'enabled', true)
                struct('id', 'loadSignal', 'label', 'Load Signal', ...
                    'icon', '📈', 'group', 'data', 'enabled', true)
                struct('id', 'saveData', 'label', 'Save', ...
                    'icon', '💾', 'group', 'data', 'enabled', true)
                
                % Analysis Group
                struct('id', 'computeEigenbasis', 'label', 'Compute Eigenbasis', ...
                    'icon', '🔢', 'group', 'analysis', 'enabled', true)
                struct('id', 'transform', 'label', 'Transform', ...
                    'icon', '⚡', 'group', 'analysis', 'enabled', false)
                struct('id', 'filter', 'label', 'Filter Designer', ...
                    'icon', '🎛️', 'group', 'analysis', 'enabled', true)
                
                % Visualization Group
                struct('id', 'plot3D', 'label', '3D Plot', ...
                    'icon', '🌐', 'group', 'visualization', 'enabled', true)
                struct('id', 'plotSpectrum', 'label', 'Spectrum', ...
                    'icon', '📊', 'group', 'visualization', 'enabled', false)
                struct('id', 'animate', 'label', 'Animate', ...
                    'icon', '▶️', 'group', 'visualization', 'enabled', false)
            };
            
            obj.ButtonGroups = struct(...
                'data', struct('label', 'Data', 'order', 1), ...
                'analysis', struct('label', 'Analysis', 'order', 2), ...
                'visualization', struct('label', 'Visualization', 'order', 3));
        end
        
        function sendConfiguration(obj)
            %SENDCONFIGURATION Send button configuration to JavaScript
            
            config = struct(...
                'buttons', {obj.Buttons}, ...
                'groups', obj.ButtonGroups);
            
            obj.send(struct('cmd', 'configure', 'config', config));
        end
        
        function handleButtonClick(obj, buttonId)
            %HANDLEBUTTONCLICK Route button clicks to app methods
            
            switch buttonId
                case "loadMesh"
                    if ismethod(obj.App, 'loadMesh')
                        obj.App.loadMesh();
                    end
                    
                case "loadSignal"
                    if ismethod(obj.App, 'loadSignal')
                        obj.App.loadSignal();
                    end
                    
                case "saveData"
                    if ismethod(obj.App, 'saveData')
                        obj.App.saveData();
                    end
                    
                case "computeEigenbasis"
                    if ismethod(obj.App, 'computeEigenbasis')
                        obj.App.computeEigenbasis();
                    end
                    
                case "transform"
                    if ismethod(obj.App, 'performTransform')
                        obj.App.performTransform();
                    end
                    
                case "filter"
                    if ismethod(obj.App, 'openFilterDesigner')
                        obj.App.openFilterDesigner();
                    else
                        % Fallback: try to open the filter designer app
                        try
                            BctFilterDesigner;
                        catch ME
                            warning('bct:ui:Toolstrip:FilterDesignerError', ...
                                'Could not open filter designer: %s', ME.message);
                        end
                    end
                    
                case "plot3D"
                    if ismethod(obj.App, 'plot3D')
                        obj.App.plot3D();
                    end
                    
                case "plotSpectrum"
                    if ismethod(obj.App, 'plotSpectrum')
                        obj.App.plotSpectrum();
                    end
                    
                case "animate"
                    if ismethod(obj.App, 'animateSignal')
                        obj.App.animateSignal();
                    end
                    
                otherwise
                    % Handle custom buttons
                    if ismethod(obj.App, 'handleCustomButton')
                        obj.App.handleCustomButton(buttonId);
                    else
                        warning('bct:ui:Toolstrip:UnhandledButton', ...
                            'No handler for button: %s', buttonId);
                    end
            end
        end
    end
end
