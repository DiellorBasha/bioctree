classdef d3Brush < matlab.ui.componentcontainer.ComponentContainer
    % D3Brush - Interactive brush component using D3.js with snapping
    % Based on https://observablehq.com/@d3/brush-snapping
    
    properties
        % Public properties that users can set
        Min (1,1) double = 0            % Minimum value of the range
        Max (1,1) double = 100          % Maximum value of the range
        SnapInterval (1,1) double = 5   % Snap interval
        Value (1,2) double = [20 60]    % Current selection [start, stop]
    end
    
    properties (Access = private, Transient, NonCopyable)
        % Internal components
        HTMLComponent matlab.ui.control.HTML
    end
    
    events (HasCallbackProperty, NotifyAccess = protected)
        % Event triggered when brush selection changes
        ValueChanged
        % Event triggered when brush interaction starts
        BrushStarted
        % Event triggered when brush interaction ends
        BrushEnded
    end
    
    methods (Access = protected)
        function setup(comp)
            % Create the HTML component that fills the container
            comp.HTMLComponent = uihtml(comp);
            comp.HTMLComponent.HTMLSource = fullfile(fileparts(mfilename('fullpath')), 'd3_brush.html');
            
            % Position the HTML component to fill the container
            comp.HTMLComponent.Position = [1 1 comp.Position(3) comp.Position(4)];
            
            % Set up event listener for HTML events from JavaScript
            comp.HTMLComponent.HTMLEventReceivedFcn = @(src, event) comp.handleBrushEvent(event);
        end
        
        function update(comp)
            % Resize the HTML component to fill the container
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Position = [1 1 comp.Position(3) comp.Position(4)];
            end
            
            % Update the HTML component data with current property values
            brushData = struct();
            brushData.min = comp.Min;
            brushData.max = comp.Max;
            brushData.snapInterval = comp.SnapInterval;
            brushData.initialSelection = comp.Value;
            
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = brushData;
            end
        end
        
        function handleBrushEvent(comp, event)
            % Handle events received from JavaScript via CustomEvent
            eventName = event.HTMLEventName;
            
            % Decode the JSON data from the CustomEvent detail
            eventData = jsondecode(event.HTMLEventData);
            
            switch eventName
                case 'BrushStarted'
                    % Notify that brush interaction started
                    notify(comp, 'BrushStarted');
                    
                case 'BrushMoving'
                    % Update Value during dragging (but don't notify yet)
                    if isfield(eventData, 'selection') && ~isempty(eventData.selection)
                        comp.Value = eventData.selection;
                    end
                    
                case 'ValueChanged'
                    if isfield(eventData, 'selection') && ~isempty(eventData.selection)
                        % Update Value property
                        oldValue = comp.Value;
                        comp.Value = eventData.selection;
                        
                        % Create event data with previous and new values
                        evtData = matlab.ui.eventdata.ValueChangedData(oldValue, comp.Value);
                        
                        % Notify listeners
                        notify(comp, 'ValueChanged', evtData);
                        notify(comp, 'BrushEnded');
                    else
                        % Brush was cleared
                        notify(comp, 'BrushEnded');
                    end
            end
        end
    end
end
