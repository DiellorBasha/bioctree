classdef Sidebar < bct.ui.Component
    %SIDEBAR HTML-based sidebar component for BCT applications
    %
    %   The Sidebar provides a collapsible navigation panel with sections
    %   for viewing properties, adjusting parameters, and controlling
    %   visualization settings.
    %
    %   Properties:
    %       Sections     - Cell array of sidebar sections
    %       IsCollapsed  - Whether the sidebar is collapsed
    %       Width        - Sidebar width in pixels
    %
    %   Methods:
    %       addSection      - Add a new section to the sidebar
    %       removeSection   - Remove a section by ID
    %       updateSection   - Update section content
    %       collapse        - Collapse the sidebar
    %       expand          - Expand the sidebar
    %       toggle          - Toggle collapsed state
    %       setWidth        - Set sidebar width
    %
    %   Example:
    %       % In App Designer:
    %       app.Sidebar = bct.ui.Sidebar(app, app.HTMLSidebar);
    %
    %       % Add custom section:
    %       section = struct('id', 'props', 'title', 'Properties', ...
    %           'content', struct('domain', 'Manifold', 'nodes', 10242));
    %       app.Sidebar.addSection(section);
    %
    %   See also: bct.ui.Component, bct.ui.Toolstrip
    
    properties (Access = public)
        Sections     % Cell array of section definitions
        IsCollapsed  % Collapsed state
        Width        % Sidebar width in pixels
    end
    
    methods
        function obj = Sidebar(app, htmlComponent)
            %SIDEBAR Construct a Sidebar instance
            %
            %   obj = Sidebar(app, htmlComponent) creates a sidebar
            %   component and loads its HTML interface.
            
            % Call superclass constructor
            obj@bct.ui.Component(app, htmlComponent, "Sidebar");
            
            % Initialize properties
            obj.Sections = {};
            obj.IsCollapsed = false;
            obj.Width = 280;
            
            % Load the HTML interface
            obj.loadHTML("sidebar.html");
            
            % Send initial configuration
            obj.sendConfiguration();
        end
        
        function addSection(obj, section)
            %ADDSECTION Add a new section to the sidebar
            %
            %   addSection(obj, section) adds a section with the specified
            %   configuration.
            %
            %   Input:
            %       section - Struct with fields: id, title, content, collapsed
            
            if ~isfield(section, 'id') || ~isfield(section, 'title')
                error('bct:ui:Sidebar:InvalidSection', ...
                    'Section must have id and title fields');
            end
            
            if ~isfield(section, 'collapsed')
                section.collapsed = false;
            end
            
            obj.Sections{end+1} = section;
            obj.send(struct('cmd', 'addSection', 'section', section));
        end
        
        function removeSection(obj, id)
            %REMOVESECTION Remove a section from the sidebar
            %
            %   removeSection(obj, id) removes the section with given ID.
            
            obj.Sections = obj.Sections(~strcmp(cellfun(@(s) s.id, ...
                obj.Sections, 'UniformOutput', false), id));
            obj.send(struct('cmd', 'removeSection', 'id', id));
        end
        
        function updateSection(obj, id, content)
            %UPDATESECTION Update the content of a section
            %
            %   updateSection(obj, id, content) updates the section
            %   identified by id with new content.
            
            % Update in local state
            for i = 1:length(obj.Sections)
                if strcmp(obj.Sections{i}.id, id)
                    obj.Sections{i}.content = content;
                    break;
                end
            end
            
            obj.send(struct('cmd', 'updateSection', 'id', id, ...
                'content', content));
        end
        
        function collapse(obj)
            %COLLAPSE Collapse the sidebar
            
            obj.IsCollapsed = true;
            obj.send(struct('cmd', 'setCollapsed', 'collapsed', true));
        end
        
        function expand(obj)
            %EXPAND Expand the sidebar
            
            obj.IsCollapsed = false;
            obj.send(struct('cmd', 'setCollapsed', 'collapsed', false));
        end
        
        function toggle(obj)
            %TOGGLE Toggle sidebar collapsed state
            
            if obj.IsCollapsed
                obj.expand();
            else
                obj.collapse();
            end
        end
        
        function setWidth(obj, width)
            %SETWIDTH Set the sidebar width
            %
            %   setWidth(obj, width) sets the sidebar width in pixels.
            
            obj.Width = width;
            obj.send(struct('cmd', 'setWidth', 'width', width));
        end
        
        function onMessage(obj, data)
            %ONMESSAGE Handle messages from JavaScript
            
            if ~isfield(data, 'cmd')
                return;
            end
            
            cmd = data.cmd;
            
            switch cmd
                case "sectionToggle"
                    obj.handleSectionToggle(data.id, data.collapsed);
                    
                case "toggleSidebar"
                    obj.toggle();
                    
                case "propertyChange"
                    obj.handlePropertyChange(data.section, data.property, ...
                        data.value);
                    
                case "ready"
                    obj.sendConfiguration();
                    
                otherwise
                    warning('bct:ui:Sidebar:UnknownCommand', ...
                        'Unknown command: %s', cmd);
            end
        end
    end
    
    methods (Access = private)
        function sendConfiguration(obj)
            %SENDCONFIGURATION Send configuration to JavaScript
            
            config = struct(...
                'sections', {obj.Sections}, ...
                'collapsed', obj.IsCollapsed, ...
                'width', obj.Width);
            
            obj.send(struct('cmd', 'configure', 'config', config));
        end
        
        function handleSectionToggle(obj, sectionId, collapsed)
            %HANDLESECTIONTOGGLE Handle section collapse/expand
            
            % Update local state
            for i = 1:length(obj.Sections)
                if strcmp(obj.Sections{i}.id, sectionId)
                    obj.Sections{i}.collapsed = collapsed;
                    break;
                end
            end
            
            % Notify app if it has a handler
            if ismethod(obj.App, 'onSidebarSectionToggle')
                obj.App.onSidebarSectionToggle(sectionId, collapsed);
            end
        end
        
        function handlePropertyChange(obj, sectionId, propertyName, value)
            %HANDLEPROPERTYCHANGE Handle property value changes
            
            % Route to app-specific handler
            if ismethod(obj.App, 'onSidebarPropertyChange')
                obj.App.onSidebarPropertyChange(sectionId, propertyName, value);
            end
        end
    end
end
